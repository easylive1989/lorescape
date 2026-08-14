import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/typewriter_text.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('文字逐字浮現，時間到了才全出來', (tester) async {
    await tester.pumpWidget(
      wrap(
        TypewriterText(
          text: '天還沒全亮',
          style: const TextStyle(),
          msPerCharacter: 20,
          completed: false,
          onCompleted: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('天'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('天還沒全亮'), findsOneWidget);
  });

  testWidgets('completed 為 true 時直接顯示全文', (tester) async {
    await tester.pumpWidget(
      wrap(
        TypewriterText(
          text: '天還沒全亮',
          style: const TextStyle(),
          msPerCharacter: 200,
          completed: true,
          onCompleted: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('天還沒全亮'), findsOneWidget);
  });

  testWidgets('顯示完會呼叫 onCompleted 一次', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      wrap(
        TypewriterText(
          text: '天亮',
          style: const TextStyle(),
          msPerCharacter: 10,
          completed: false,
          onCompleted: () => calls++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);
  });

  testWidgets('自然打完之後父層把 completed 翻成 true，不得再通知一次', (tester) async {
    // 實際會走到的路徑：打完 → 父層 _typingDone 翻 true → rebuild 時新 widget
    // 的 completed 是 true、舊的是 false → didUpdateWidget 的「外部強制補完」
    // 分支被觸發。沒有 _notified 旗標的話 onCompleted 會被打第二次。
    var calls = 0;
    Widget build(bool completed) => wrap(
      TypewriterText(
        text: '天亮',
        style: const TextStyle(),
        msPerCharacter: 10,
        completed: completed,
        onCompleted: () => calls++,
      ),
    );
    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(calls, 1);

    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(calls, 1, reason: '同一段文字只能通知一次');
  });

  testWidgets('一開始就是 completed 也要通知，否則已讀節點要多點一次', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      wrap(
        TypewriterText(
          text: '天亮',
          style: const TextStyle(),
          msPerCharacter: 200,
          completed: true,
          onCompleted: () => calls++,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('天亮'), findsOneWidget);
    expect(calls, 1);
  });
}
