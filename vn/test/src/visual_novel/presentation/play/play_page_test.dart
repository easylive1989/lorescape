import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/dialogue_box.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/play_page.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpPlayPage(WidgetTester tester, String storyId) async {
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
