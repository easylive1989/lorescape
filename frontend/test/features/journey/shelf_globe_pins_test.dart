// 地球儀是整個書架的鳥瞰：一本書一個釘點，釘在那趟旅程所有地點的平均位置，
// 標籤是旅程名稱，而不是某一個停點的地名。

import 'package:context_app/features/journey/domain/models/globe_pin.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/in_memory_journey_repository.dart';
import '../../fakes/in_memory_trip_repository.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_data.dart';

JourneyEntry _entry({
  required String id,
  required String? tripId,
  required DateTime createdAt,
  double? lat,
  double? lng,
  String name = 'place',
}) {
  final base = buildJourneyEntry(id: id);
  return JourneyEntry(
    id: id,
    place: SavedPlace(
      id: 'wikidata:Q$id',
      name: name,
      address: '',
      latitude: lat,
      longitude: lng,
    ),
    narrationContent: base.narrationContent,
    createdAt: createdAt,
    updatedAt: createdAt,
    language: const Language('zh-TW'),
    tripId: tripId,
  );
}

Future<List<GlobePin>> _pinsOf(
  List<JourneyEntry> entries, {
  List<Trip> trips = const [],
}) async {
  final journeyRepository = InMemoryJourneyRepository();
  for (final entry in entries) {
    await journeyRepository.save(entry);
  }
  final tripRepository = InMemoryTripRepository();
  for (final trip in trips) {
    await tripRepository.save(trip);
  }
  final container = ProviderContainer(
    overrides: [
      journeyRepositoryProvider.overrideWithValue(journeyRepository),
      tripRepositoryProvider.overrideWithValue(tripRepository),
    ],
  );
  addTearDown(container.dispose);

  await container.read(myJourneyProvider.future);
  await container.read(tripsProvider.future);
  return container.read(shelfGlobePinsProvider);
}

void main() {
  setUpAll(initTestEnvironment);

  group('shelfGlobePinsProvider', () {
    test('given a trip with several stops, when the pins are built, then it '
        'gets a single pin labelled with the trip name — one pin per book, '
        'not per stop', () async {
      final pins = await _pinsOf(
        [
          _entry(
            id: 'a',
            tripId: 't1',
            createdAt: DateTime(2026, 1, 1),
            lat: 1,
            lng: 1,
            name: 'first',
          ),
          _entry(
            id: 'b',
            tripId: 't1',
            createdAt: DateTime(2026, 1, 5),
            lat: 2,
            lng: 2,
            name: 'later',
          ),
        ],
        trips: [buildTrip(id: 't1', name: '2026 奧捷')],
      );

      expect(pins, hasLength(1));
      expect(pins.single.id, 't1');
      expect(pins.single.label, '2026 奧捷');
    });

    test('given a trip whose stops are spread out, when the pin is built, '
        'then it sits at their average position, not at any one stop', () async {
      final pins = await _pinsOf(
        [
          _entry(
            id: 'a',
            tripId: 't1',
            createdAt: DateTime(2026, 1, 1),
            lat: 0,
            lng: 10,
          ),
          _entry(
            id: 'b',
            tripId: 't1',
            createdAt: DateTime(2026, 1, 5),
            lat: 0,
            lng: 20,
          ),
        ],
        trips: [buildTrip(id: 't1')],
      );

      expect(pins.single.coordinate.latitude, closeTo(0, 1e-6));
      expect(pins.single.coordinate.longitude, closeTo(15, 1e-6));
    });

    test('given stops on both sides of the antimeridian, when the pin is '
        'built, then it stays between them instead of flipping to the far '
        'side of the globe', () async {
      final pins = await _pinsOf(
        [
          _entry(
            id: 'a',
            tripId: 't1',
            createdAt: DateTime(2026, 1, 1),
            lat: 0,
            lng: 179,
          ),
          _entry(
            id: 'b',
            tripId: 't1',
            createdAt: DateTime(2026, 1, 5),
            lat: 0,
            lng: -179,
          ),
        ],
        trips: [buildTrip(id: 't1')],
      );

      expect(pins.single.coordinate.longitude.abs(), closeTo(180, 1e-6));
    });

    test(
      'given the uncategorised volume, when the pins are built, then it is '
      'left off the globe — it is not a journey, its stops are unrelated',
      () async {
        final pins = await _pinsOf(
          [
            _entry(
              id: 'a',
              tripId: 't1',
              createdAt: DateTime(2026, 1, 1),
              lat: 1,
              lng: 1,
            ),
            _entry(
              id: 'b',
              tripId: null,
              createdAt: DateTime(2026, 2, 1),
              lat: 2,
              lng: 2,
            ),
          ],
          trips: [buildTrip(id: 't1')],
        );

        expect(pins.map((p) => p.id), ['t1']);
      },
    );

    test(
      'given some stories have no coordinates, when the pin is built, then '
      'only the located ones are averaged rather than dropping the book',
      () async {
        final pins = await _pinsOf(
          [
            _entry(id: 'a', tripId: 't1', createdAt: DateTime(2026, 1, 1)),
            _entry(
              id: 'b',
              tripId: 't1',
              createdAt: DateTime(2026, 1, 5),
              lat: 2,
              lng: 2,
            ),
          ],
          trips: [buildTrip(id: 't1')],
        );

        expect(pins.single.coordinate.latitude, closeTo(2, 1e-6));
        expect(pins.single.coordinate.longitude, closeTo(2, 1e-6));
      },
    );

    test('given a book whose stories all lack coordinates, when the pins are '
        'built, then it simply has no pin', () async {
      final pins = await _pinsOf(
        [_entry(id: 'a', tripId: 't1', createdAt: DateTime(2026, 1, 1))],
        trips: [buildTrip(id: 't1')],
      );

      expect(pins, isEmpty);
    });

    test('given a trip that no longer exists, when the pins are built, then '
        'its entries get no pin — there is no name to show', () async {
      final pins = await _pinsOf([
        _entry(
          id: 'a',
          tripId: 'deleted',
          createdAt: DateTime(2026, 1, 1),
          lat: 1,
          lng: 1,
        ),
      ]);

      expect(pins, isEmpty);
    });

    test('given several trips, when the pins are built, then they come in '
        'trip start order, matching the shelf', () async {
      final pins = await _pinsOf(
        [
          _entry(
            id: 'a',
            tripId: 't-late',
            createdAt: DateTime(2026, 5, 1),
            lat: 1,
            lng: 1,
          ),
          _entry(
            id: 'b',
            tripId: 't-early',
            createdAt: DateTime(2026, 1, 1),
            lat: 2,
            lng: 2,
          ),
        ],
        trips: [buildTrip(id: 't-late'), buildTrip(id: 't-early')],
      );

      expect(pins.map((p) => p.id), ['t-early', 't-late']);
    });
  });
}
