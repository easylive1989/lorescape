// 同一台裝置換帳號的隔離。
//
// Hive 的兩個 box 是整台裝置共用一份的，登出也不會清。在加上 owner 標記之
// 前，A 登出、B 登入之後 fullSync 會把 A 留在本機的記錄當成「遠端沒有的本
// 機項目」推進 B 的帳號——那是寫入層級的污染，事後只能手動去 DB 清。
//
// 這個檔案走的是真的 Hive box ＋ 真的 SyncEngine ＋ 假的遠端，因為要驗的正
// 是「本機讀取的過濾」與「fullSync 推什麼上去」這兩件事的交界。

import 'dart:io';

import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/sync/data/hive_journey_repository.dart';
import 'package:context_app/features/sync/domain/services/remote_sync_data_source.dart';
import 'package:context_app/features/sync/domain/services/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// 每個 user 一格的假遠端，模擬 RLS：拿得到的只有自己那格。
class _FakeRemote implements RemoteSyncDataSource<JourneyEntry> {
  _FakeRemote(this.rowsByUser, this.currentUserId);

  final Map<String, Map<String, JourneyEntry>> rowsByUser;
  String Function() currentUserId;

  Map<String, JourneyEntry> get _mine =>
      rowsByUser.putIfAbsent(currentUserId(), () => {});

  @override
  Future<List<JourneyEntry>> fetchAll() async => _mine.values.toList();

  @override
  Future<void> upsert(JourneyEntry item) async => _mine[item.id] = item;

  @override
  Future<void> delete(String id) async => _mine.remove(id);
}

JourneyEntry _entry(String id) {
  final at = DateTime(2026, 8, 20, 10);
  return JourneyEntry(
    id: id,
    place: SavedPlace(id: 'wikidata:Q$id', name: 'place-$id', address: ''),
    narrationContent: NarrationContent.create(
      '這是一段夠長的導覽文本，用來滿足 NarrationContent 的長度驗證。',
      language: const Language('zh-TW'),
    ),
    createdAt: at,
    updatedAt: at,
    language: const Language('zh-TW'),
  );
}

void main() {
  late HiveJourneyRepository repo;
  late SyncEngine<JourneyEntry> engine;
  late Map<String, Map<String, JourneyEntry>> remoteRows;
  String? currentUserId;

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync();
    Hive.init(dir.path);
    currentUserId = null;
    remoteRows = {};
    repo = HiveJourneyRepository(currentUserId: () => currentUserId);
    engine = SyncEngine<JourneyEntry>(
      descriptor: SyncEntityDescriptor<JourneyEntry>(
        name: 'journey',
        idOf: (item) => item.id,
        updatedAtOf: (item) => item.updatedAt,
      ),
      remote: _FakeRemote(remoteRows, () => currentUserId!),
      loadLocal: repo.getAll,
      saveLocal: repo.save,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  Future<void> signIn(String userId) async {
    currentUserId = userId;
    await repo.claimUnowned(userId);
    await engine.fullSync();
  }

  test(
    'given account A synced on this device, when account B signs in on the '
    'same device, then B neither sees nor uploads A\'s journeys',
    () async {
      currentUserId = 'user-a';
      await repo.save(_entry('a1'));
      await signIn('user-a');
      expect(remoteRows['user-a']!.keys, ['a1']);

      // 登出不會清本機——這正是污染的前提條件。
      currentUserId = null;
      await signIn('user-b');

      expect(await repo.getAll(), isEmpty, reason: 'B 不該看到 A 的記錄');
      expect(
        remoteRows['user-b'] ?? const {},
        isEmpty,
        reason: 'A 的記錄不該被推進 B 的帳號',
      );
    },
  );

  test(
    'given B took over the device, when A signs back in, then A\'s journeys '
    'are still there — we hide other accounts\' data rather than delete it',
    () async {
      currentUserId = 'user-a';
      await repo.save(_entry('a1'));
      await signIn('user-a');

      currentUserId = null;
      await signIn('user-b');
      await repo.save(_entry('b1'));

      currentUserId = null;
      await signIn('user-a');

      expect((await repo.getAll()).map((e) => e.id), ['a1']);
      expect(
        remoteRows['user-a']!.keys,
        ['a1'],
        reason: 'B 在這台裝置上存的東西不該跟著 A 上去',
      );
    },
  );

  test(
    'given entries saved before signing in, when the first account signs in, '
    'then they are claimed by that account and uploaded once',
    () async {
      await repo.save(_entry('u1'));

      await signIn('user-a');
      expect(remoteRows['user-a']!.keys, ['u1']);

      // 之後換帳號，那批已經有主了，不會再被推給下一個人。
      currentUserId = null;
      await signIn('user-b');

      expect(remoteRows['user-b'] ?? const {}, isEmpty);
    },
  );
}
