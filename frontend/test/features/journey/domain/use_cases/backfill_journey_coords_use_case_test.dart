import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/journey/domain/services/place_coords_resolver.dart';
import 'package:context_app/features/journey/domain/use_cases/backfill_journey_coords_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/in_memory_journey_repository.dart';
import '../../../../helpers/test_data.dart';

/// 記下被查過哪些 qid，讓「沒有待補記錄時不打網路」這條斷言驗得到。
class _FakeResolver implements PlaceCoordsResolver {
  _FakeResolver(this.coords);

  final Map<String, PlaceLocation> coords;
  final List<Set<String>> calls = [];

  @override
  Future<Map<String, PlaceLocation>> resolve(Set<String> qids) async {
    calls.add(qids);
    return {
      for (final qid in qids)
        if (coords[qid] case final location?) qid: location,
    };
  }
}

JourneyEntry _entry({
  required String id,
  required String placeId,
  double? latitude,
  double? longitude,
}) {
  final base = buildJourneyEntry(id: id);
  return JourneyEntry(
    id: base.id,
    place: SavedPlace(
      id: placeId,
      name: 'place-$id',
      address: '',
      latitude: latitude,
      longitude: longitude,
    ),
    narrationContent: base.narrationContent,
    createdAt: base.createdAt,
    updatedAt: base.updatedAt,
    language: base.language,
  );
}

void main() {
  group('BackfillJourneyCoordsUseCase', () {
    test(
      'given an old entry with no coordinates, when the backfill runs, '
      'then the coordinates resolved from its Wikidata id are saved',
      () async {
        final repository = InMemoryJourneyRepository();
        await repository.save(_entry(id: 'e1', placeId: 'wikidata:Q42'));
        final resolver = _FakeResolver({
          'Q42': const PlaceLocation(latitude: 35.5, longitude: 139.5),
        });

        final filled = await BackfillJourneyCoordsUseCase(
          repository: repository,
          resolver: resolver,
        )();

        expect(filled, 1);
        final saved = (await repository.getAll()).single;
        expect(saved.place.latitude, 35.5);
        expect(saved.place.longitude, 139.5);
      },
    );

    test(
      'given the saved entry, when the backfill writes it back, then '
      'updatedAt is bumped so sync does not overwrite it with the old row',
      () async {
        final repository = InMemoryJourneyRepository();
        final before = _entry(id: 'e1', placeId: 'wikidata:Q42');
        await repository.save(before);

        await BackfillJourneyCoordsUseCase(
          repository: repository,
          resolver: _FakeResolver({
            'Q42': const PlaceLocation(latitude: 1, longitude: 2),
          }),
        )();

        final saved = (await repository.getAll()).single;
        expect(saved.updatedAt.isAfter(before.updatedAt), isTrue);
        expect(saved.createdAt, before.createdAt, reason: '建立時間不該被動到');
      },
    );

    test(
      'given entries that already carry coordinates, when the backfill runs, '
      'then they are neither queried nor rewritten',
      () async {
        final repository = InMemoryJourneyRepository();
        await repository.save(
          _entry(
            id: 'e1',
            placeId: 'wikidata:Q42',
            latitude: 10,
            longitude: 20,
          ),
        );
        final resolver = _FakeResolver({
          'Q42': const PlaceLocation(latitude: 99, longitude: 99),
        });

        final filled = await BackfillJourneyCoordsUseCase(
          repository: repository,
          resolver: resolver,
        )();

        expect(filled, 0);
        expect(resolver.calls, isEmpty, reason: '沒有待補的記錄就不該打網路');
        final saved = (await repository.getAll()).single;
        expect(saved.place.latitude, 10, reason: '既有座標不能被覆蓋');
      },
    );

    test(
      'given a pre-Wikidata entry whose place id is a Google Places id, '
      'when the backfill runs, then it is skipped instead of queried',
      () async {
        final repository = InMemoryJourneyRepository();
        await repository.save(_entry(id: 'e1', placeId: 'ChIJN1t_tDeuEmsRUs'));
        final resolver = _FakeResolver(const {});

        final filled = await BackfillJourneyCoordsUseCase(
          repository: repository,
          resolver: resolver,
        )();

        expect(filled, 0);
        expect(resolver.calls, isEmpty);
        expect((await repository.getAll()).single.place.latitude, isNull);
      },
    );

    test(
      'given the resolver finds coordinates for only some entries, when the '
      'backfill runs, then the rest are left untouched rather than zeroed',
      () async {
        final repository = InMemoryJourneyRepository();
        await repository.save(_entry(id: 'e1', placeId: 'wikidata:Q1'));
        await repository.save(_entry(id: 'e2', placeId: 'wikidata:Q2'));

        final filled = await BackfillJourneyCoordsUseCase(
          repository: repository,
          resolver: _FakeResolver({
            'Q1': const PlaceLocation(latitude: 1, longitude: 1),
          }),
        )();

        expect(filled, 1);
        final entries = {
          for (final entry in await repository.getAll()) entry.id: entry,
        };
        expect(entries['e1']!.place.latitude, 1);
        expect(
          entries['e2']!.place.latitude,
          isNull,
          reason: '查不到就維持 null——補 (0,0) 會在幾內亞灣長出假的點',
        );
      },
    );

    test(
      'given the resolver comes back empty because the device is offline, '
      'when the backfill runs, then nothing is written and no error escapes',
      () async {
        final repository = InMemoryJourneyRepository();
        await repository.save(_entry(id: 'e1', placeId: 'wikidata:Q42'));

        final filled = await BackfillJourneyCoordsUseCase(
          repository: repository,
          resolver: _FakeResolver(const {}),
        )();

        expect(filled, 0);
        expect((await repository.getAll()).single.place.latitude, isNull);
      },
    );
  });
}
