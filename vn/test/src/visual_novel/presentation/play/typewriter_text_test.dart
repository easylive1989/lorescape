import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/typewriter_text.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('文字逐字浮現，時間到了才全出來', (tester) async {
    await tester.pumpWidget(wrap(TypewriterText(
      text: '天還沒全亮',
      style: const TextStyle(),
      msPerCharacter: 20,
      completed: false,
      onCompleted: () {},
    )));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('天'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('天還沒全亮'), findsOneWidget);
  });

  testWidgets('completed 為 true 時直接顯示全文', (tester) async {
    await tester.pumpWidget(wrap(TypewriterText(
      text: '天還沒全亮',
      style: const TextStyle(),
      msPerCharacter: 200,
      completed: true,
      onCompleted: () {},
    )));
    await tester.pump();
    expect(find.text('天還沒全亮'), findsOneWidget);
  });

  testWidgets('顯示完會呼叫 onCompleted 一次', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrap(TypewriterText(
      text: '天亮',
      style: const TextStyle(),
      msPerCharacter: 10,
      completed: false,
      onCompleted: () => calls++,
    )));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);
  });
}
