import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 這一包日後要整包搬進另一個 Flutter 專案的 `features/visual_novel/`，屆時
/// 跨 feature 引用只看 `providers.dart`。若 presentation 已經散著直接引用
/// data／domain，搬過去就會拖出一串跨層依賴——那時候才發現就太晚了。
///
/// 用測試守而不是靠註解與 code review：規則要能自己叫。
void main() {
  const String providers =
      'package:lorescape_story/src/visual_novel/providers.dart';
  const String presentation =
      'package:lorescape_story/src/visual_novel/presentation/';

  Iterable<File> dartFilesIn(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  test('presentation 底下只准 import providers.dart', () {
    // 連 export 一起擋：presentation 若把 domain 型別重新掛出去，跨層依賴
    // 一樣成立，只是換了個字。
    final RegExp importLine = RegExp(
      "^(?:import|export) '(package:lorescape_story/[^']+)'",
    );
    final List<String> offenders = <String>[];
    final List<File> scanned = dartFilesIn(
      'lib/src/visual_novel/presentation',
    ).toList();
    // 沒有這一條的話，掃描根目錄一改名這條測試就變成永遠通過。
    expect(scanned, isNotEmpty, reason: 'presentation 掃不到任何檔案');

    for (final File file in scanned) {
      for (final String line in file.readAsLinesSync()) {
        final RegExpMatch? match = importLine.firstMatch(line);
        if (match == null) continue;
        final String target = match.group(1)!;
        // 同一層內部互相引用沒問題，那不算跨層。
        if (target.startsWith(presentation)) continue;
        if (target == providers) continue;
        offenders.add('${file.path} → $target');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'presentation 只准經 providers.dart 取用 data／domain',
    );
  });

  test('domain 只准 import dart: 與自己', () {
    // 用白名單而不是黑名單。只擋 `package:flutter/` 是查代理指標不是查性質——
    // domain 若 import `package:flutter_riverpod/…`（傳遞相依整個 Flutter）
    // 或 `.../data/pack_repository.dart`（那個檔 import flutter/services.dart），
    // 規則實質已破而黑名單照樣綠。`dart:ui` 也只是同一個問題的特例。
    final RegExp anyImport = RegExp("^(?:import|export) '([^']+)'");
    const String domain = 'package:lorescape_story/src/visual_novel/domain/';
    final List<String> offenders = <String>[];
    final List<File> scanned = dartFilesIn(
      'lib/src/visual_novel/domain',
    ).toList();
    expect(scanned, isNotEmpty, reason: 'domain 掃不到任何檔案');

    for (final File file in scanned) {
      for (final String line in file.readAsLinesSync()) {
        final RegExpMatch? match = anyImport.firstMatch(line);
        if (match == null) continue;
        final String target = match.group(1)!;
        if (target.startsWith('dart:') && target != 'dart:ui') continue;
        if (target.startsWith(domain)) continue;
        offenders.add('${file.path} → $target');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'domain 要能用 dart test 跑，只准 import dart: 與 domain 自己',
    );
  });

  test('data 不得 import presentation', () {
    final RegExp anyImport = RegExp("^(?:import|export) '([^']+)'");
    const String presentation =
        'package:lorescape_story/src/visual_novel/presentation/';
    final List<String> offenders = <String>[];
    final List<File> scanned = dartFilesIn(
      'lib/src/visual_novel/data',
    ).toList();
    expect(scanned, isNotEmpty, reason: 'data 掃不到任何檔案');

    for (final File file in scanned) {
      for (final String line in file.readAsLinesSync()) {
        final RegExpMatch? match = anyImport.firstMatch(line);
        if (match == null) continue;
        if (match.group(1)!.startsWith(presentation)) {
          offenders.add('${file.path} → ${match.group(1)}');
        }
      }
    }

    expect(offenders, isEmpty, reason: 'data 是 presentation 的下游，不得反向依賴');
  });
}
