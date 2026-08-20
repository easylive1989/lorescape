// Verifies that the post-error retry cycle actually recovers — not
// just that the error state renders. The pre-existing tests stopped at
// "error UI is shown" or "controller reset restores idle"; this file
// drives the full failure → reset → retry-succeeds → success path
// that real users hit when the network blips.

import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/narration/domain/errors/narration_error.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/narration/domain/services/narration_service.dart';
import 'package:context_app/features/narration/providers.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes/in_memory_journey_repository.dart';
import '../../../fakes/in_memory_trip_repository.dart';

const _place = Place(
  id: 'p',
  name: 'Test Place',
  address: 'Addr',
  location: PlaceLocation(latitude: 0, longitude: 0),
  tags: [],
  photos: [],
  category: PlaceCategory.modernUrban,
);

void main() {
  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Narration generation error → retry flow', () {
    test(
      'given a transient network error, when the user retries after reset, '
      'then the second attempt produces content and the journey is saved',
      () async {
        final narration = _SequencedNarrationService([
          const AppError(
            type: NarrationError.networkError,
            message: 'Temporary network blip',
          ),
          'recovery text',
        ]);
        final journey = InMemoryJourneyRepository();
        final container = _buildContainer(
          narration: narration,
          journey: journey,
        );
        addTearDown(container.dispose);

        final controller = container.read(
          narrationGenerationControllerProvider.notifier,
        );

        await controller.generate(place: _place, language: Language.english);
        expect(
          container.read(narrationGenerationControllerProvider).hasError,
          isTrue,
        );
        expect(await journey.getAll(), isEmpty);

        controller.reset();
        expect(
          container.read(narrationGenerationControllerProvider).isIdle,
          isTrue,
        );

        await controller.generate(place: _place, language: Language.english);

        final state = container.read(narrationGenerationControllerProvider);
        expect(state.isSuccess, isTrue);
        expect(state.content?.text, contains('recovery text'));
        expect(
          await journey.getAll(),
          hasLength(1),
          reason: 'a successful retry should persist the journey entry',
        );
      },
    );

    test(
      'given a non-retryable error, when the controller still allows reset, '
      'then the retry path is available — gating retry UI is the screen\'s job',
      () async {
        final narration = _SequencedNarrationService([
          const AppError(
            type: NarrationError.configurationError,
            message: 'Missing API key',
          ),
          'recovery text',
        ]);
        final container = _buildContainer(narration: narration);
        addTearDown(container.dispose);

        final controller = container.read(
          narrationGenerationControllerProvider.notifier,
        );

        await controller.generate(place: _place, language: Language.english);
        final errorState = container.read(
          narrationGenerationControllerProvider,
        );
        expect(errorState.hasError, isTrue);
        expect(errorState.errorType?.isRetryable, isFalse);

        // Even though the screen would hide the retry CTA, the controller
        // itself does not lock — manual reset is always allowed.
        controller.reset();
        await controller.generate(place: _place, language: Language.english);

        expect(
          container.read(narrationGenerationControllerProvider).isSuccess,
          isTrue,
        );
      },
    );
  });
}

ProviderContainer _buildContainer({
  required _SequencedNarrationService narration,
  InMemoryJourneyRepository? journey,
}) {
  return ProviderContainer(
    overrides: [
      narrationServiceProvider.overrideWithValue(narration),
      journeyRepositoryProvider.overrideWithValue(
        journey ?? InMemoryJourneyRepository(),
      ),
      tripRepositoryProvider.overrideWithValue(InMemoryTripRepository()),
    ],
  );
}

/// Returns each item in [outcomes] on successive calls — either throws an
/// [AppError] or returns the string as narration text. Used to script
/// "first call fails, second call succeeds" scenarios.
class _SequencedNarrationService implements NarrationService {
  _SequencedNarrationService(List<Object> outcomes)
    : _queue = List.of(outcomes);

  final List<Object> _queue;

  @override
  Future<NarrationGenerationResult> generateNarration({
    required Place place,
    required Language language,
    StoryHook? hook,
  }) async {
    if (_queue.isEmpty) {
      throw StateError('no outcomes left to dispense');
    }
    final next = _queue.removeAt(0);
    if (next is AppError) throw next;
    if (next is String) {
      return (text: next, grounding: null);
    }
    throw StateError('unsupported outcome: ${next.runtimeType}');
  }
}
