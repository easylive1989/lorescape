import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/core/errors/app_error_type.dart';
import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/narration/domain/errors/narration_error.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/narration/providers.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// The lifecycle of a narration generation session.
enum NarrationGenerationStatus {
  /// Waiting for the user to press "Start".
  idle,

  /// AI is generating the narration content.
  generating,

  /// Narration content is ready.
  success,

  /// An error occurred during generation.
  error,
}

/// Immutable state for [NarrationGenerationController].
class NarrationGenerationState {
  final NarrationGenerationStatus status;
  final NarrationContent? content;
  final NarrationGenerationErrorType? errorType;
  final String? errorMessage;

  const NarrationGenerationState({
    this.status = NarrationGenerationStatus.idle,
    this.content,
    this.errorType,
    this.errorMessage,
  });

  bool get isIdle => status == NarrationGenerationStatus.idle;
  bool get isGenerating => status == NarrationGenerationStatus.generating;
  bool get isSuccess => status == NarrationGenerationStatus.success;
  bool get hasError => status == NarrationGenerationStatus.error;
}

/// Error types for narration generation.
enum NarrationGenerationErrorType {
  network,
  server,
  configurationError,
  contentGenerationFailed,

  /// Backend reported insufficient_source — the place genuinely has no
  /// historical content to tell a story about. Not retryable.
  insufficientSource,

  /// Backend returned 402 — the free daily quota is exhausted. The paywall
  /// is back (see the `/subscription` route), so this navigates the user
  /// there instead of showing an error dialog.
  quotaExceeded,
  unknown;

  bool get isRetryable => switch (this) {
    network || server => true,
    _ => false,
  };
}

/// Manages the narration generation flow on the config screen.
///
/// Handles AI generation before navigating to the player screen.
class NarrationGenerationController
    extends AutoDisposeNotifier<NarrationGenerationState> {
  @override
  NarrationGenerationState build() => const NarrationGenerationState();

  /// Generates narration content for the given place and aspects.
  ///
  /// On success, auto-saves to journey and sets state to [success].
  /// On error, sets state to [error] with the appropriate error type.
  Future<void> generate({
    required Place place,
    required Language language,
    StoryHook? hook,
  }) async {
    final generationId = const Uuid().v4();
    final stopwatch = Stopwatch()..start();
    final usedHook = hook != null;
    state = const NarrationGenerationState(
      status: NarrationGenerationStatus.generating,
    );
    _emit(
      StoryGenerationRequested(
        generationId: generationId,
        placeId: place.id,
        language: language.code,
        usedHook: usedHook,
      ),
    );

    try {
      final content = await ref
          .read(startNarrationUseCaseProvider)
          .execute(place: place, language: language, hook: hook);

      await _autoSaveToJourney(place, hook, content, language);

      state = NarrationGenerationState(
        status: NarrationGenerationStatus.success,
        content: content,
      );
      _emit(
        StoryGenerationReturned(
          generationId: generationId,
          placeId: place.id,
          language: language.code,
          usedHook: usedHook,
          outcome: 'success',
          latencyMs: stopwatch.elapsedMilliseconds,
          contentLength: content.text.length,
        ),
      );
    } on AppError catch (e) {
      final errorType = _mapAppError(e.type);
      state = NarrationGenerationState(
        status: NarrationGenerationStatus.error,
        errorType: errorType,
        errorMessage: e.message,
      );
      _emit(
        StoryGenerationReturned(
          generationId: generationId,
          placeId: place.id,
          language: language.code,
          usedHook: usedHook,
          outcome: errorType.wireName,
          latencyMs: stopwatch.elapsedMilliseconds,
          contentLength: 0,
        ),
      );
    }
  }

  /// Resets to the idle state.
  void reset() => state = const NarrationGenerationState();

  NarrationGenerationErrorType _mapAppError(AppErrorType type) {
    if (type is NarrationError) {
      return switch (type) {
        NarrationError.networkError => NarrationGenerationErrorType.network,
        NarrationError.serverError => NarrationGenerationErrorType.server,
        NarrationError.configurationError =>
          NarrationGenerationErrorType.configurationError,
        NarrationError.contentGenerationFailed =>
          NarrationGenerationErrorType.contentGenerationFailed,
        NarrationError.insufficientSource =>
          NarrationGenerationErrorType.insufficientSource,
        NarrationError.freeQuotaExceeded =>
          NarrationGenerationErrorType.quotaExceeded,
        _ => NarrationGenerationErrorType.unknown,
      };
    }

    return NarrationGenerationErrorType.unknown;
  }

  Future<void> _autoSaveToJourney(
    Place place,
    StoryHook? hook,
    NarrationContent content,
    Language language,
  ) async {
    try {
      final entry = JourneyEntry.create(
        id: const Uuid().v4(),
        place: place,
        content: content,
        language: language,
        hook: hook,
        tripId: ref.read(currentTripIdProvider),
      );
      await ref.read(journeyRepositoryProvider).save(entry);
    } catch (_) {
      // Fail silently - don't affect the generation flow.
    }
  }

  void _emit(AnalyticsEvent event) =>
      ref.read(analyticsEmitterProvider).emit(event);
}

extension on NarrationGenerationErrorType {
  String get wireName => switch (this) {
    NarrationGenerationErrorType.network => 'network',
    NarrationGenerationErrorType.server => 'server',
    NarrationGenerationErrorType.configurationError => 'configuration_error',
    NarrationGenerationErrorType.contentGenerationFailed =>
      'content_generation_failed',
    NarrationGenerationErrorType.insufficientSource => 'insufficient_source',
    NarrationGenerationErrorType.quotaExceeded => 'quota_exceeded',
    NarrationGenerationErrorType.unknown => 'unknown',
  };
}
