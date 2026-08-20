import 'dart:io';

import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/sync/data/hive_journey_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const _hook = StoryHook(
  id: 'hook-1',
  title: 'A test hook',
  teaser: 'Something happened...',
);

JourneyEntry _makeEntry({String id = 'e1', DateTime? createdAt}) {
  const place = SavedPlace(
    id: 'p1',
    name: 'Test Place',
    address: 'Test Address',
  );

  final content = NarrationContent.create(
    'Narration text',
    language: const Language('zh-TW'),
  );

  final resolvedCreatedAt = createdAt ?? DateTime.now();
  return JourneyEntry(
    id: id,
    place: place,
    narrationContent: content,
    storyHook: _hook,
    createdAt: resolvedCreatedAt,
    updatedAt: resolvedCreatedAt,
    language: const Language('zh-TW'),
  );
}

void main() {
  late HiveJourneyRepository repo;
  // box 是整台裝置共用的，所以「現在是誰」是這個 repository 的輸入之一。
  String? currentUserId;

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync();
    Hive.init(dir.path);
    currentUserId = null;
    repo = HiveJourneyRepository(currentUserId: () => currentUserId);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('given data saved by another account, getAll hides it — a shared '
      'device must not show one account the other one\'s journeys', () async {
    currentUserId = 'user-a';
    await repo.save(_makeEntry(id: 'a1'));

    currentUserId = 'user-b';
    expect(await repo.getAll(), isEmpty);

    currentUserId = 'user-a';
    expect((await repo.getAll()).single.id, 'a1');
  });

  test('given data saved while signed out, getAll shows it to everyone until '
      'someone claims it', () async {
    await repo.save(_makeEntry(id: 'u1'));

    currentUserId = 'user-a';
    expect((await repo.getAll()).single.id, 'u1', reason: '無主資料人人看得到');
  });

  test('given unowned data, claimUnowned stamps it and it stops being '
      'visible to other accounts', () async {
    await repo.save(_makeEntry(id: 'u1'));

    currentUserId = 'user-a';
    expect(await repo.claimUnowned('user-a'), 1);

    currentUserId = 'user-b';
    expect(await repo.getAll(), isEmpty, reason: '認領後就只屬於 user-a');
  });

  test('given data already owned, claimUnowned leaves it alone', () async {
    currentUserId = 'user-a';
    await repo.save(_makeEntry(id: 'a1'));

    expect(await repo.claimUnowned('user-b'), 0);

    currentUserId = 'user-a';
    expect((await repo.getAll()).single.id, 'a1');
  });

  test('given entries from several accounts, clearAll wipes the device',
      () async {
    currentUserId = 'user-a';
    await repo.save(_makeEntry(id: 'a1'));
    currentUserId = 'user-b';
    await repo.save(_makeEntry(id: 'b1'));

    await repo.clearAll();

    currentUserId = 'user-a';
    expect(await repo.getAll(), isEmpty);
    currentUserId = 'user-b';
    expect(await repo.getAll(), isEmpty);
  });

  test('getAll returns empty list when no entries saved', () async {
    final result = await repo.getAll();
    expect(result, isEmpty);
  });

  test('save then getAll returns the saved entry', () async {
    final entry = _makeEntry(id: 'abc');
    await repo.save(entry);

    final result = await repo.getAll();
    expect(result.length, 1);
    expect(result.first.id, 'abc');
    expect(result.first.place.name, 'Test Place');
  });

  test('getAll returns entries sorted newest first', () async {
    final old = _makeEntry(id: 'old', createdAt: DateTime(2026, 1, 1));
    final recent = _makeEntry(id: 'recent', createdAt: DateTime(2026, 3, 1));

    await repo.save(old);
    await repo.save(recent);

    final result = await repo.getAll();
    expect(result.first.id, 'recent');
    expect(result.last.id, 'old');
  });

  test('delete removes the entry', () async {
    final entry = _makeEntry(id: 'del');
    await repo.save(entry);
    await repo.delete('del');

    final result = await repo.getAll();
    expect(result, isEmpty);
  });

  test('delete non-existent id does nothing', () async {
    await repo.save(_makeEntry(id: 'keep'));
    await repo.delete('nope');

    final result = await repo.getAll();
    expect(result.length, 1);
  });

  test('save preserves all fields through JSON round-trip', () async {
    final original = _makeEntry(id: 'rt');
    await repo.save(original);

    final result = await repo.getAll();
    final restored = result.first;

    expect(restored.id, original.id);
    expect(restored.place.id, original.place.id);
    expect(restored.place.name, original.place.name);
    expect(restored.place.address, original.place.address);
    expect(restored.narrationContent.text, original.narrationContent.text);
    expect(restored.storyHook, original.storyHook);
    expect(restored.language.code, original.language.code);
  });
}
