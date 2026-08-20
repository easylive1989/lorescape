// App 上傳的欄位必須真的存在於 Supabase 的 schema。
//
// 這條測試是為了一個靜默了好幾個月的 bug 寫的：`_toRow` 一直送
// `story_hook`，但 journey_entries 從建表起就沒有這個欄位。PostgREST 對不存
// 在的欄位是退回整個請求（42703），而 SyncEngine 的 push / fullSync 只寫 log
// 不拋出——於是每一筆上傳都失敗，四張 sync 表長期 0 筆，畫面上完全看不出來。
//
// 走文字剖析而不是連真的資料庫：CI 沒有 Supabase，而這裡要抓的就是「兩份檔
// 案漂移」本身。剖析不到東西時會直接失敗（而不是安靜地通過），因為一個抓不
// 到欄位的守門測試比沒有更糟。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _migrationsDir = Directory('../supabase/migrations');

/// 從所有 migration 收集某張表目前的欄位名。
Set<String> _schemaColumns(String table) {
  final columns = <String>{};
  final files = _migrationsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final sql = file.readAsStringSync().toLowerCase();

    // create table ... public.<table> ( ... );
    final create = RegExp(
      'create table[^;]*?public\\.$table\\s*\\((.*?)\\n\\);',
      dotAll: true,
    ).firstMatch(sql);
    if (create != null) {
      for (final line in create.group(1)!.split(',\n')) {
        final name = RegExp(r'^\s*([a-z_]+)\s').firstMatch(line)?.group(1);
        if (name == null) continue;
        const notColumns = {
          'primary',
          'unique',
          'foreign',
          'constraint',
          'check',
        };
        if (notColumns.contains(name)) continue;
        columns.add(name);
      }
    }

    // alter table public.<table> ... add column [if not exists] <name>
    for (final alter in RegExp(
      'alter table[^;]*?public\\.$table(.*?);',
      dotAll: true,
    ).allMatches(sql)) {
      for (final added in RegExp(
        r'add column\s+(?:if not exists\s+)?([a-z_]+)',
      ).allMatches(alter.group(1)!)) {
        columns.add(added.group(1)!);
      }
      for (final dropped in RegExp(
        r'drop column\s+(?:if exists\s+)?([a-z_]+)',
      ).allMatches(alter.group(1)!)) {
        columns.remove(dropped.group(1)!);
      }
    }
  }
  return columns;
}

/// 從 data source 的 `_toRow` 取出會被送出去的欄位名。
Set<String> _payloadKeys(String dataSourcePath) {
  final source = File(dataSourcePath).readAsStringSync();
  final body = RegExp(
    r'Map<String, dynamic> _toRow\([^)]*\) => \{(.*?)\n  \};',
    dotAll: true,
  ).firstMatch(source);
  expect(
    body,
    isNotNull,
    reason: '$dataSourcePath 的 _toRow 剖析不到——改了寫法就要同步改這條測試，'
        '否則守門會變成空轉',
  );
  return RegExp("'([a-z_]+)':")
      .allMatches(body!.group(1)!)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  group('Supabase 上傳欄位與 schema 一致', () {
    test('given the migrations, when they are parsed, then columns are found — '
        'a guard that parses nothing would pass forever', () {
      expect(_schemaColumns('journey_entries'), contains('place_lat'));
      expect(_schemaColumns('trips'), contains('cover_image_url'));
    });

    test('given journey entries, when one is upserted, then every column in '
        'the payload exists in the table', () {
      final missing =
          _payloadKeys(
            'lib/features/sync/data/supabase_journey_remote_data_source.dart',
          ).difference(_schemaColumns('journey_entries'));

      expect(
        missing,
        isEmpty,
        reason: 'PostgREST 會整筆退回，而 SyncEngine 只寫 log——漏一個欄位就是'
            '整條同步靜默失效',
      );
    });

    test('given trips, when one is upserted, then every column in the payload '
        'exists in the table', () {
      final missing =
          _payloadKeys(
            'lib/features/sync/data/supabase_trip_remote_data_source.dart',
          ).difference(_schemaColumns('trips'));

      expect(missing, isEmpty);
    });
  });
}
