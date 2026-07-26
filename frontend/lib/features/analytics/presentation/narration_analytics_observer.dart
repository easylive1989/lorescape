import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:context_app/features/analytics/domain/models/abandon_reason.dart';
import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/domain/models/narration_event_source.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:context_app/features/narration/providers.dart';

/// SharedPreferences key tracking whether the user has ever started a
/// narration on this install. Used to populate the
/// `is_first_lifetime_narration` flag of [NarrationStarted].
const String kFirstStartedDoneKey = 'analytics.lifetime.started_done';

/// Narration progress threshold (percent) above which playback is
/// considered "completed" rather than "abandoned" (Story 1 AC3).
const double kNarrationCompletionThresholdPct = 95.0;

/// Progress milestones that emit [NarrationProgress] events.
const List<int> kProgressMilestones = <int>[25, 50, 75];

final Logger _log = Logger('NarrationAnalyticsObserver');

/// Bridges the narration player state stream into analytics events.
///
/// Subscribes to the narration player provider via `ref.listen` and
/// translates state transitions into [NarrationStarted],
/// [NarrationProgress], [NarrationCompleted], and [NarrationAbandoned]
/// events. The observer is intentionally a Riverpod [Notifier] so a
/// single `ref.watch` in `main.dart` keeps it alive for the entire app
/// lifecycle; the notifier itself holds no externalised state (its
/// `build` return type is `void`).
class NarrationAnalyticsObserver extends Notifier<void> {
  NarrationAnalyticsObserver({
    Uuid uuid = const Uuid(),
    SharedPreferences? prefs,
  }) : _uuid = uuid,
       _prefsOverride = prefs;

  final Uuid _uuid;
  final SharedPreferences? _prefsOverride;

  String? _currentNarrationId;
  String? _currentPlaceId;
  int? _currentContentLength;
  final Set<int> _emittedMilestones = <int>{};
  bool _hasEmittedStarted = false;
  bool _hasEmittedCompleted = false;
  int _lastElapsedChars = 0;
  int _lastTotalChars = 0;

  SharedPreferences? _prefs;
  bool? _isFirstLifetimeCache;

  @override
  void build() {
    ref.listen<NarrationState>(playerControllerProvider, (prev, next) {
      _handleTransition(prev, next);
    }, fireImmediately: false);
  }

  void _handleTransition(NarrationState? prev, NarrationState next) {
    final placeId = next.place?.id;
    final contentLength = next.content?.text.length;

    if (placeId == null || contentLength == null || contentLength == 0) {
      return;
    }

    final hasSwitched = _hasSwitchedNarration(placeId, contentLength);
    if (hasSwitched) {
      _emitAbandonedIfNeeded(reason: AbandonReason.switched);
      _resetForNewNarration(placeId, contentLength);
    }

    _maybeEmitStarted(next);
    _maybeEmitProgress(next);
    _maybeEmitCompletion(next);
    _maybeEmitAbandonedOnStop(prev, next);
  }

  bool _hasSwitchedNarration(String placeId, int contentLength) {
    if (_currentPlaceId == null) return false;
    return _currentPlaceId != placeId || _currentContentLength != contentLength;
  }

  void _resetForNewNarration(String placeId, int contentLength) {
    _currentNarrationId = null;
    _currentPlaceId = placeId;
    _currentContentLength = contentLength;
    _emittedMilestones.clear();
    _hasEmittedStarted = false;
    _hasEmittedCompleted = false;
    _lastElapsedChars = 0;
    _lastTotalChars = contentLength;
  }

  void _maybeEmitStarted(NarrationState next) {
    if (_hasEmittedStarted) return;
    if (!next.isPlaying) return;

    _currentNarrationId ??= _uuid.v4();
    _currentPlaceId ??= next.place!.id;
    _currentContentLength ??= next.content!.text.length;
    _lastTotalChars = next.content!.text.length;
    _hasEmittedStarted = true;

    _fireAndLog(_emitStarted(next), 'narration_started');
  }

  Future<void> _emitStarted(NarrationState next) async {
    final isFirstLifetime = await _readAndMarkFirstLifetime();

    final event = NarrationStarted(
      narrationId: _currentNarrationId!,
      placeId: next.place!.id,
      // TODO(story-2): derive real source from router or player state
      // once narration is launched from multiple surfaces.
      source: NarrationEventSource.explore,
      isFirstLifetimeNarration: isFirstLifetime,
    );
    await ref.read(analyticsEmitterProvider).emitAndWait(event);
  }

  void _maybeEmitProgress(NarrationState next) {
    if (!_hasEmittedStarted) return;
    if (_hasEmittedCompleted) return;

    final total = next.content!.text.length;
    final elapsed = next.playerState.currentCharPosition.clamp(0, total);
    _lastElapsedChars = elapsed;
    _lastTotalChars = total;
    if (total == 0) return;
    final progressPct = (elapsed / total) * 100.0;

    for (final milestone in kProgressMilestones) {
      if (progressPct >= milestone && !_emittedMilestones.contains(milestone)) {
        _emittedMilestones.add(milestone);
        _fireAndLog(
          _emitProgressEvent(milestone, elapsed, total),
          'narration_progress',
        );
      }
    }
  }

  Future<void> _emitProgressEvent(
    int milestone,
    int elapsedChars,
    int totalChars,
  ) async {
    // TODO(story-2): swap char count for real elapsed/total ms once
    // TtsService exposes playback duration in milliseconds.
    final event = NarrationProgress(
      narrationId: _currentNarrationId!,
      milestone: milestone,
      elapsedMs: elapsedChars,
      totalDurationMs: totalChars,
    );
    await ref.read(analyticsEmitterProvider).emitAndWait(event);
  }

  void _maybeEmitCompletion(NarrationState next) {
    if (!_hasEmittedStarted) return;
    if (_hasEmittedCompleted) return;
    if (!next.isCompleted) return;

    final total = next.content!.text.length;
    if (total == 0) return;
    final elapsed = next.playerState.currentCharPosition.clamp(0, total);
    final progressPct = (elapsed / total) * 100.0;
    if (progressPct < kNarrationCompletionThresholdPct) return;

    _hasEmittedCompleted = true;
    _fireAndLog(
      _emitCompletedEvent(elapsed, total, progressPct),
      'narration_completed',
    );
  }

  Future<void> _emitCompletedEvent(
    int elapsedChars,
    int totalChars,
    double progressPct,
  ) async {
    // TODO(story-2): swap char counts for real durations in ms.
    final event = NarrationCompleted(
      narrationId: _currentNarrationId!,
      totalDurationMs: totalChars,
      listenDurationMs: elapsedChars,
      completionRate: progressPct,
    );
    await ref.read(analyticsEmitterProvider).emitAndWait(event);
  }

  void _maybeEmitAbandonedOnStop(NarrationState? prev, NarrationState next) {
    if (!_hasEmittedStarted) return;
    if (_hasEmittedCompleted) return;
    final wasPlaying = prev?.isPlaying ?? false;
    if (!wasPlaying) return;
    final stoppedPlaying = !next.isPlaying && !next.isPaused;
    if (!stoppedPlaying) return;
    // If state moved to completed but threshold wasn't reached, treat
    // as user_stop; if hasError, also user_stop semantically.
    _emitAbandonedIfNeeded(
      // TODO(story-2): differentiate user_stop / route_change /
      // backgrounded once the player state carries the cause.
      reason: AbandonReason.userStop,
    );
  }

  void _emitAbandonedIfNeeded({required AbandonReason reason}) {
    if (!_hasEmittedStarted) return;
    if (_hasEmittedCompleted) return;
    final total = _lastTotalChars;
    if (total == 0) return;
    final elapsed = _lastElapsedChars.clamp(0, total);
    final progressPct = (elapsed / total) * 100.0;
    if (progressPct >= kNarrationCompletionThresholdPct) {
      // Reached completion threshold but the dedicated completion
      // emission didn't fire — guard against duplicate categorisation.
      return;
    }
    // Mark as completed to prevent re-emission on subsequent
    // transitions for the same narration.
    _hasEmittedCompleted = true;
    _fireAndLog(
      _emitAbandonedEvent(reason, elapsed, progressPct),
      'narration_abandoned',
    );
  }

  Future<void> _emitAbandonedEvent(
    AbandonReason reason,
    int elapsedChars,
    double progressPct,
  ) async {
    final event = NarrationAbandoned(
      narrationId: _currentNarrationId!,
      abandonReason: reason,
      // TODO(story-2): swap char count for real elapsed ms.
      elapsedMs: elapsedChars,
      progressPct: progressPct,
    );
    await ref.read(analyticsEmitterProvider).emitAndWait(event);
  }

  /// Emitting is fire-and-forget by design (state transitions must not block
  /// on analytics), which means a thrown error would otherwise vanish into an
  /// unhandled async gap. A silent failure here blacked out every narration
  /// event for two months, so failures are logged rather than dropped.
  void _fireAndLog(Future<void> emit, String what) {
    emit.catchError((Object error, StackTrace stackTrace) {
      _log.warning('Failed to emit $what', error, stackTrace);
    });
  }

  Future<SharedPreferences> _resolvePrefs() async {
    return _prefsOverride ??
        _prefs ??
        (_prefs = await SharedPreferences.getInstance());
  }

  Future<bool> _readAndMarkFirstLifetime() async {
    final cached = _isFirstLifetimeCache;
    if (cached != null) return cached;
    final prefs = await _resolvePrefs();
    final alreadyDone = prefs.getBool(kFirstStartedDoneKey) ?? false;
    final isFirst = !alreadyDone;
    if (isFirst) {
      await prefs.setBool(kFirstStartedDoneKey, true);
    }
    _isFirstLifetimeCache = false;
    return isFirst;
  }
}
