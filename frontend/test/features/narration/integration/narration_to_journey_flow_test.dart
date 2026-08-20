// Verifies the cross-feature contract that generating a narration also
// saves a JourneyEntry — including correctly inheriting the current
// trip id when one is active. The end-to-end UI for this lives in
// SelectStoryHookScreen + NarrationScreen, but the entry-creation wiring
// belongs to NarrationGenerationController and is what regressions tend
// to hit, so we test it at the controller level via a real
// ProviderContainer.

import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/narration/domain/errors/narration_error.dart';
import 'package:context_app/features/narration/providers.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes/fake_narration_service.dart';
import '../../../fakes/in_memory_journey_repository.dart';
import '../../../fakes/in_memory_trip_repository.dart';

const _place = Place(
  id: 'kiyomizu',
  name: 'Kiyomizu-dera',
  address: '1-294 Kiyomizu, Higashiyama Ward, Kyoto',
  location: PlaceLocation(latitude: 34.9949, longitude: 135.7850),
  tags: [],
  photos: [],
  category: PlaceCategory.historicalCultural,
);

void main() {
  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Narration → Journey wiring', () {
    test('given no active trip, when narration is generated, '
        'then a journey entry is saved with a null tripId', () async {
      final journey = InMemoryJourneyRepository();
      final container = _buildContainer(journey: journey);
      addTearDown(container.dispose);

      await container
          .read(narrationGenerationControllerProvider.notifier)
          .generate(place: _place, language: Language.english);

      final saved = await journey.getAll();
      expect(saved, hasLength(1));
      expect(saved.single.place.id, _place.id);
      expect(saved.single.tripId, isNull);
    });

    test('given an active current trip, when narration is generated, '
        'then the saved journey entry inherits that trip id', () async {
      final journey = InMemoryJourneyRepository();
      final container = _buildContainer(journey: journey);
      addTearDown(container.dispose);

      // Pre-load the controller so its build() runs before we mutate.
      container.read(currentTripIdProvider);
      await container
          .read(currentTripIdProvider.notifier)
          .setCurrentTripId('trip-kyoto-2025');

      await container
          .read(narrationGenerationControllerProvider.notifier)
          .generate(place: _place, language: Language.english);

      final saved = await journey.getAll();
      expect(saved, hasLength(1));
      expect(saved.single.tripId, 'trip-kyoto-2025');
    });

    test(
      'given the narration service fails, when generation runs, '
      'then no journey entry is saved and the controller exposes the error',
      () async {
        final journey = InMemoryJourneyRepository();
        final container = _buildContainer(
          journey: journey,
          narration: FakeNarrationService(
            error: const AppError(
              type: NarrationError.networkError,
              message: 'boom',
            ),
          ),
        );
        addTearDown(container.dispose);

        await container
            .read(narrationGenerationControllerProvider.notifier)
            .generate(place: _place, language: Language.english);

        final saved = await journey.getAll();
        expect(saved, isEmpty);
        expect(
          container.read(narrationGenerationControllerProvider).hasError,
          isTrue,
        );
      },
    );
  });
}

ProviderContainer _buildContainer({
  required InMemoryJourneyRepository journey,
  FakeNarrationService? narration,
}) {
  return ProviderContainer(
    overrides: [
      journeyRepositoryProvider.overrideWithValue(journey),
      narrationServiceProvider.overrideWithValue(
        narration ?? FakeNarrationService(),
      ),
      tripRepositoryProvider.overrideWithValue(InMemoryTripRepository()),
    ],
  );
}
