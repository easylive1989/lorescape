// 地球儀是整個書架的鳥瞰：一本書一個釘點，釘的是那本旅程最早那個故事的地
// 點，而不是選中那本書的所有停點。

import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/in_memory_journey_repository.dart';
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

Future<List<dynamic>> _pinsOf(List<JourneyEntry> entries) async {
  final repository = InMemoryJourneyRepository();
  for (final entry in entries) {
    await repository.save(entry);
  }
  final container = ProviderContainer(
    overrides: [journeyRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);

  await container.read(myJourneyProvider.future);
  return container.read(shelfGlobePinsProvider);
}

void main() {
  setUpAll(initTestEnvironment);

  group('shelfGlobePinsProvider', () {
    test(
      'given a trip with several stops, when the pins are built, then only '
      'its first story shows up — one pin per book, not per stop',
      () async {
        final pins = await _pinsOf([
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
        ]);

        expect(pins, hasLength(1));
        expect(pins.single.label, 'first');
        expect(pins.single.id, 't1');
      },
    );

    test(
      'given several books, when the pins are built, then each one gets a pin '
      'including the uncategorised volume',
      () async {
        final pins = await _pinsOf([
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
        ]);

        expect(pins.map((p) => p.id), ['t1', unassignedGlobePinId]);
      },
    );

    test(
      'given the earliest story has no coordinates, when the pins are built, '
      'then the next one that does is used rather than dropping the book',
      () async {
        final pins = await _pinsOf([
          _entry(id: 'a', tripId: 't1', createdAt: DateTime(2026, 1, 1)),
          _entry(
            id: 'b',
            tripId: 't1',
            createdAt: DateTime(2026, 1, 5),
            lat: 2,
            lng: 2,
            name: 'has coords',
          ),
        ]);

        expect(pins.single.label, 'has coords');
      },
    );

    test(
      'given a book whose stories all lack coordinates, when the pins are '
      'built, then it simply has no pin',
      () async {
        final pins = await _pinsOf([
          _entry(id: 'a', tripId: 't1', createdAt: DateTime(2026, 1, 1)),
        ]);

        expect(pins, isEmpty);
      },
    );

    test('given a pin id, when it is mapped back, then the uncategorised '
        'sentinel round-trips to null', () {
      expect(globePinIdForTrip(null), unassignedGlobePinId);
      expect(tripIdForGlobePin(unassignedGlobePinId), isNull);
      expect(tripIdForGlobePin('t1'), 't1');
    });
  });
}
