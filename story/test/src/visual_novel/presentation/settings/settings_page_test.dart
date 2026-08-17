import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_story/src/visual_novel/presentation/settings/settings_page.dart';
import 'package:lorescape_story/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('調整字級會寫進 SaveStore', (tester) async {
    // 這個 App 只設計給手機直式：預設的桌面型測試視窗（800×600、橫向）跟真機
    // 版面形狀不同，改成直式尺寸（見 pack_page_test.dart 的 pumpPackPage）。
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    late SaveStore store;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            store = ref.watch(saveStoreProvider);
            return const MaterialApp(home: SettingsPage());
          },
        ),
      ),
    );
    await tester.pump();

    expect(store.fontScale(), 1);
    await tester.drag(
      find.byKey(SettingsPage.fontScaleSliderKey),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(store.fontScale(), greaterThan(1));
  });
}
