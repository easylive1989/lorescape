import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/endings/endings_page.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpEndingsPage(WidgetTester tester, Map<String, Object> prefsValues) async {
  // 這個 App 只設計給手機直式：預設的桌面型測試視窗（800×600、橫向）跟真機
  // 版面形狀不同，改成直式尺寸（見 pack_page_test.dart 的 pumpPackPage）。
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: EndingsPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('未達成的結局只顯示鎖頭，不顯示標題', (tester) async {
    await pumpEndingsPage(tester, <String, Object>{});
    // 注意：不能用 find.text('天上那棵樹') 判斷——那也是第 4 篇（天上那棵樹）
    // 的故事標題，故事標題本身不是劇透、本來就會顯示。這裡把 finder 限定在
    // 結局的 ListTile 底下，只驗證「結局 A 的標題」沒有洩漏。
    expect(
      find.widgetWithText(ListTile, '天上那棵樹'),
      findsNothing,
      reason: '結局 A 的標題不得劇透',
    );
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(24));
  });

  testWidgets('達成過的結局顯示標題', (tester) async {
    await pumpEndingsPage(tester, <String, Object>{
      'vn.endingsSeen': <String>['pompeii_01_harbour_stranger#A'],
    });
    expect(find.widgetWithText(ListTile, '天上那棵樹'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(23));
  });
}
