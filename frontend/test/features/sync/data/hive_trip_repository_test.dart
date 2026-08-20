import 'dart:io';

import 'package:context_app/features/sync/data/hive_trip_repository.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Trip _makeTrip({String id = 't1', DateTime? createdAt}) {
  final resolved = createdAt ?? DateTime(2026, 4, 17);
  return Trip(
    id: id,
    name: 'Trip $id',
    createdAt: resolved,
    updatedAt: resolved,
  );
}

void main() {
  late HiveTripRepository repo;
  String? currentUserId;

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync();
    Hive.init(dir.path);
    currentUserId = null;
    repo = HiveTripRepository(currentUserId: () => currentUserId);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test(
    'given a trip saved by another account, both getAll and getById hide '
    'it — getById is reachable by deep link and stale currentTripId',
    () async {
      currentUserId = 'user-a';
      await repo.save(_makeTrip(id: 'a1'));

      currentUserId = 'user-b';
      expect(await repo.getAll(), isEmpty);
      expect(await repo.getById('a1'), isNull);

      currentUserId = 'user-a';
      expect((await repo.getById('a1'))?.id, 'a1');
    },
  );

  test(
    'given unowned trips, claimUnowned stamps them for that account',
    () async {
      await repo.save(_makeTrip(id: 'u1'));

      expect(await repo.claimUnowned('user-a'), 1);

      currentUserId = 'user-b';
      expect(await repo.getAll(), isEmpty);
    },
  );

  test('clearAll wipes trips from every account on the device', () async {
    currentUserId = 'user-a';
    await repo.save(_makeTrip(id: 'a1'));

    await repo.clearAll();

    expect(await repo.getAll(), isEmpty);
  });

  test('getAll returns empty list when no trips saved', () async {
    expect(await repo.getAll(), isEmpty);
  });

  test('save then getAll returns the saved trip', () async {
    await repo.save(_makeTrip(id: 'abc'));

    final result = await repo.getAll();
    expect(result.length, 1);
    expect(result.first.id, 'abc');
  });

  test('getAll returns trips sorted newest first', () async {
    await repo.save(_makeTrip(id: 'old', createdAt: DateTime(2026, 1, 1)));
    await repo.save(_makeTrip(id: 'recent', createdAt: DateTime(2026, 3, 1)));

    final result = await repo.getAll();
    expect(result.first.id, 'recent');
    expect(result.last.id, 'old');
  });

  test('getById returns the matching trip', () async {
    await repo.save(_makeTrip(id: 'find-me'));

    final trip = await repo.getById('find-me');
    expect(trip, isNotNull);
    expect(trip!.id, 'find-me');
  });

  test('getById returns null when trip does not exist', () async {
    expect(await repo.getById('missing'), isNull);
  });

  test('delete removes the trip', () async {
    await repo.save(_makeTrip(id: 'del'));
    await repo.delete('del');

    expect(await repo.getAll(), isEmpty);
  });

  test('save overwrites an existing trip with the same id', () async {
    await repo.save(_makeTrip(id: 'dup'));
    await repo.save(
      Trip(
        id: 'dup',
        name: 'Renamed',
        createdAt: DateTime(2026, 4, 17),
        updatedAt: DateTime(2026, 4, 17),
      ),
    );

    final result = await repo.getAll();
    expect(result.length, 1);
    expect(result.first.name, 'Renamed');
  });
}
