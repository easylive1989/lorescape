import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/sync/data/syncing_journey_repository.dart';
import 'package:context_app/features/sync/domain/services/remote_sync_data_source.dart';
import 'package:context_app/features/sync/domain/services/sync_engine.dart';
import 'package:context_app/features/sync/domain/services/sync_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/in_memory_journey_repository.dart';
import '../../helpers/test_data.dart';

class _FakeRemote implements RemoteSyncDataSource<JourneyEntry> {
  final List<JourneyEntry> upserts = [];
  final List<String> deletes = [];
  List<JourneyEntry> seeded = const [];

  @override
  Future<List<JourneyEntry>> fetchAll() async => seeded;

  @override
  Future<void> upsert(JourneyEntry item) async {
    upserts.add(item);
  }

  @override
  Future<void> delete(String id) async {
    deletes.add(id);
  }
}

SyncingJourneyRepository _build({
  required SyncSession Function() session,
  required InMemoryJourneyRepository local,
  required _FakeRemote remote,
}) {
  final engine = SyncEngine<JourneyEntry>(
    descriptor: SyncEntityDescriptor<JourneyEntry>(
      name: 'journey_entry',
      idOf: (e) => e.id,
      updatedAtOf: (e) => e.updatedAt,
    ),
    remote: remote,
    loadLocal: local.getAll,
    saveLocal: local.save,
  );
  return SyncingJourneyRepository(
    local: local,
    engine: engine,
    session: session,
  );
}

void main() {
  group('SyncingJourneyRepository', () {
    test('given sync inactive, save does not push to remote', () async {
      final local = InMemoryJourneyRepository();
      final remote = _FakeRemote();
      final repo = _build(
        local: local,
        remote: remote,
        session: () => const SyncSession.disabled(),
      );

      await repo.save(buildJourneyEntry(id: 'e1'));

      expect(await local.getAll(), hasLength(1));
      expect(remote.upserts, isEmpty);
    });

    test('given sync active, save also pushes to remote', () async {
      final local = InMemoryJourneyRepository();
      final remote = _FakeRemote();
      final repo = _build(
        local: local,
        remote: remote,
        session: () => const SyncSession(enabled: true, userId: 'u1'),
      );

      final entry = buildJourneyEntry(id: 'e1');
      await repo.save(entry);

      expect(remote.upserts, [entry]);
    });

    test('given sync active, delete cascades to remote', () async {
      final local = InMemoryJourneyRepository();
      final remote = _FakeRemote();
      final repo = _build(
        local: local,
        remote: remote,
        session: () => const SyncSession(enabled: true, userId: 'u1'),
      );

      await repo.save(buildJourneyEntry(id: 'e1'));
      await repo.delete('e1');

      expect(remote.deletes, ['e1']);
    });

    test('given sync inactive, delete only affects local', () async {
      final local = InMemoryJourneyRepository();
      final remote = _FakeRemote();
      final repo = _build(
        local: local,
        remote: remote,
        session: () => const SyncSession.disabled(),
      );

      await repo.save(buildJourneyEntry(id: 'e1'));
      await repo.delete('e1');

      expect(await local.getAll(), isEmpty);
      expect(remote.deletes, isEmpty);
    });

    test(
      'engine.fullSync writes newer remote items locally and pushes newer locals',
      () async {
        final local = InMemoryJourneyRepository();
        final remote = _FakeRemote();
        final repo = _build(
          local: local,
          remote: remote,
          session: () => const SyncSession(enabled: true, userId: 'u1'),
        );

        // Local has an older copy of "shared" and a unique "localOnly".
        await repo.save(
          buildJourneyEntry(
            id: 'shared',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );
        await repo.save(
          buildJourneyEntry(
            id: 'localOnly',
            createdAt: DateTime(2026, 2, 1),
            updatedAt: DateTime(2026, 2, 1),
          ),
        );

        // Remote has a newer copy of "shared" and a unique "remoteOnly".
        remote.seeded = [
          buildJourneyEntry(
            id: 'shared',
            createdAt: DateTime(2026, 6, 1),
            updatedAt: DateTime(2026, 6, 1),
          ),
          buildJourneyEntry(
            id: 'remoteOnly',
            createdAt: DateTime(2026, 7, 1),
            updatedAt: DateTime(2026, 7, 1),
          ),
        ];

        // Clear out the upserts captured during the warm-up saves so the
        // assertions below only see what fullSync pushed.
        remote.upserts.clear();

        final engine = SyncEngine<JourneyEntry>(
          descriptor: SyncEntityDescriptor<JourneyEntry>(
            name: 'journey_entry',
            idOf: (e) => e.id,
            updatedAtOf: (e) => e.updatedAt,
          ),
          remote: remote,
          loadLocal: local.getAll,
          saveLocal: local.save,
        );
        await engine.fullSync();

        final localIds = (await local.getAll()).map((e) => e.id).toSet();
        expect(localIds, {'shared', 'localOnly', 'remoteOnly'});

        final pushedIds = remote.upserts.map((e) => e.id).toList();
        expect(pushedIds, contains('localOnly'));
        expect(pushedIds, isNot(contains('shared')));
      },
    );
  });
}
