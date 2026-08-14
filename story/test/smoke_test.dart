import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_story/main.dart';
import 'package:lorescape_story/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('啟動時顯示景點包名稱', (tester) async {
    // App 只設計給手機直式，見 pack_page_test.dart 的 pumpPackPage。
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 首頁換成 go_router 導覽的 PackPage 後，啟動要先載入景點包（asset）——
    // 得覆寫 sharedPreferencesProvider，再等一輪 pump 讓非同步載入完成。
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const VnApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('龐貝 79'), findsOneWidget);
  });
}
