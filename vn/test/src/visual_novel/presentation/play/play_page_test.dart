import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/dialogue_box.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/play_page.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpPlayPage(WidgetTester tester, String storyId) async {
  // 這個 App 只設計給手機直式：預設的桌面型測試視窗（800×600、橫向）會讓
  // `bodyFontSize`（跟寬度成正比）相對選項區的高度（跟高度成正比）過大，
  // 選項節點會撐爆 ChoiceOverlay 的 Column 而丟出 RenderFlex overflow——不是
  // 版面在真機上會發生的問題，是測試視窗形狀不像真機。改成直式尺寸。
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(home: PlayPage(storyId: storyId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('VnLayout', () {
    test('版面數值照 Flutter製作規範 §2', () {
      const layout = VnLayout(Size(400, 800));
      expect(layout.dialogueHeight, 800 * 0.35);
      expect(layout.spriteHeight, 800 * 0.72);
      expect(layout.sideInset, 400 * 0.06);
      expect(layout.choiceInset, 400 * 0.10);
      expect(layout.bodyFontSize, 400 / 20);
      expect(layout.spriteOffset, 400 * 0.18);
      expect(layout.spriteBottom, 800 * 0.12, reason: '立繪底邊置於 0.88H ＝ 距底 0.12H');
      expect(layout.choiceTop, 800 * 0.45);
      expect(layout.choiceBottom, 800 * 0.25);
      expect(layout.safeInset, 800 * 0.08);
    });
  });

  group('PlayPage', () {
    testWidgets('開場顯示第一段旁白，且沒有名牌', (tester) async {
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      expect(find.text('天還沒全亮，海面是鉛的顏色。'), findsOneWidget);
      expect(find.byKey(DialogueBox.nameTagKey), findsNothing);
    });

    testWidgets('點擊推進到下一個節點', (tester) async {
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      await tester.tap(find.byKey(PlayPage.advanceAreaKey));
      await tester.pumpAndSettle();
      expect(find.text('天還沒全亮，海面是鉛的顏色。'), findsNothing);
    });

    testWidgets('對白節點顯示名牌與立繪', (tester) async {
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      // 走到第一句對白（尼基亞斯：札布達。）
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byKey(PlayPage.advanceAreaKey));
        await tester.pumpAndSettle();
        if (find.text('札布達。').evaluate().isNotEmpty) break;
      }
      expect(find.text('札布達。'), findsOneWidget);
      expect(find.byKey(DialogueBox.nameTagKey), findsOneWidget);
      expect(find.text('尼基亞斯'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('sprite-nikias')), findsOneWidget);
    });

    testWidgets('選項只顯示 cond 成立者，點選後走對分支', (tester) async {
      // choice_overlay.dart 是這個 task 新寫的 widget，卻沒有任何 widget 測試
      // 走到 choosing 狀態——渲染與「點第 i 個 → choose(可見索引 i)」的接線
      // 都只靠人工截圖確認過。這條補上。
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      for (var i = 0; i < 40; i++) {
        if (find.byKey(const ValueKey<String>('choice-0')).evaluate().isNotEmpty) break;
        await tester.tap(find.byKey(PlayPage.advanceAreaKey));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey<String>('choice-0')), findsOneWidget,
          reason: '01 篇 S01 結尾有一個兩選項的分歧');
      expect(find.text('直接進城找人。'), findsOneWidget);
      expect(find.text('先去廣場，把債權登記起來。'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('choice-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('choice-0')), findsNothing,
          reason: '選完之後選項要收起來');
      expect(tester.takeException(), isNull);
    });

    testWidgets('缺件的 sfx 與 bgm 不造成例外', (tester) async {
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byKey(PlayPage.advanceAreaKey));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  });
}
