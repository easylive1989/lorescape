import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_story/src/visual_novel/presentation/library/library_page.dart';
import 'package:lorescape_story/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 磁碟上實際有哪些包。**不寫死**——理由同 endings_page_test 的 totalEndings()：
/// 加一個景點包不該讓測試變紅，那是內容變多的正常結果。
List<Map<String, dynamic>> manifestPacks() =>
    ((jsonDecode(File('assets/content/packs.json').readAsStringSync())
                as Map<String, dynamic>)['packs']
            as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

Future<void> pumpLibraryPage(
  WidgetTester tester, {
  Map<String, Object>? prefsValues,
}) async {
  // 手機直式，同 pack_page_test。
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefsValues ?? <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: LibraryPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('列出 packs.json 上的每一個景點包', (tester) async {
    await pumpLibraryPage(tester);
    final packs = manifestPacks();
    expect(packs.length, greaterThanOrEqualTo(2), reason: '至少要有兩個包才驗得到多包');
    for (final pack in packs) {
      expect(
        find.byKey(LibraryPage.packCardKey(pack['id'] as String)),
        findsOneWidget,
        reason: '書架上少了 ${pack['title']}',
      );
      expect(find.text(pack['title'] as String), findsOneWidget);
    }
  });

  testWidgets('每個包顯示自己的篇數', (tester) async {
    await pumpLibraryPage(tester);
    for (final pack in manifestPacks()) {
      expect(
        find.text('${pack['stories']} 篇'),
        findsWidgets,
        reason: '${pack['title']} 的篇數沒顯示',
      );
    }
  });
}
