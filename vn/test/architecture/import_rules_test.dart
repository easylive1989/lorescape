import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 這一包日後要整包搬進另一個 Flutter 專案的 `features/visual_novel/`，屆時
/// 跨 feature 引用只看 `providers.dart`。若 presentation 已經散著直接引用
/// data／domain，搬過去就會拖出一串跨層依賴——那時候才發現就太晚了。
///
/// 用測試守而不是靠註解與 code review：規則要能自己叫。
void main() {
  const String providers = 'package:lorescape_vn/src/visual_novel/providers.dart';
  const String presentation = 'package:lorescape_vn/src/visual_novel/presentation/';

  Iterable<File> dartFilesIn(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  test('presentation 底下只准 import providers.dart', () {
    final RegExp importLine = RegExp("^import '(package:lorescape_vn/[^']+)'");
    final List<String> offenders = <String>[];

    for (final File file in dartFilesIn('lib/src/visual_novel/presentation')) {
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

    expect(offenders, isEmpty,
        reason: 'presentation 只准經 providers.dart 取用 data／domain');
  });

  test('domain 底下零 Flutter 依賴', () {
    final RegExp flutterImport = RegExp("^import 'package:flutter/");
    final List<String> offenders = <String>[];

    for (final File file in dartFilesIn('lib/src/visual_novel/domain')) {
      for (final String line in file.readAsLinesSync()) {
        if (flutterImport.hasMatch(line)) offenders.add('${file.path}: $line');
      }
    }

    expect(offenders, isEmpty, reason: 'domain 要能用 dart test 跑，不得依賴 Flutter');
  });
}
