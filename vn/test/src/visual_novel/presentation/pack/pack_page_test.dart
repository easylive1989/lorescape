import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/pack/pack_page.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpPackPage(
  WidgetTester tester, {
  Map<String, Object>? prefsValues,
}) async {
  // 這個 App 只設計給手機直式：預設的桌面型測試視窗（800×600、橫向）跟真機
  // 版面形狀不同，改成直式尺寸（見 play_page_test.dart 的 pumpPlayPage）。
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefsValues ?? <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: PackPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('列出 8 篇，依 order 排序並顯示副標與分鐘數', (tester) async {
    await pumpPackPage(tester);
    expect(
      find.byKey(PackPage.storyCardKey('pompeii_01_harbour_stranger')),
      findsOneWidget,
    );
    expect(find.text('港口的外地人'), findsOneWidget);
    expect(find.text('爆發前一日'), findsOneWidget);
    expect(find.textContaining('12 分鐘'), findsWidgets);
    expect(find.text('普特奧利的新房子'), findsOneWidget);
  });

  testWidgets('顯示每篇的結局進度', (tester) async {
    await pumpPackPage(
      tester,
      prefsValues: <String, Object>{
        'vn.endingsSeen': <String>[
          'pompeii_01_harbour_stranger#A',
          'pompeii_01_harbour_stranger#B',
        ],
      },
    );
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('0 / 3'), findsNWidgets(7));
  });
}
