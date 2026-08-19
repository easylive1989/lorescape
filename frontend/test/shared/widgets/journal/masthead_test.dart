import 'package:context_app/shared/widgets/journal/masthead.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('Masthead', () {
    testWidgets(
      'given a title and actions, when the masthead renders, '
      'then both sit at the shared inset with the rule drawn below',
      (tester) async {
        await _givenMasthead(
          tester,
          actions: const Icon(Icons.add, key: Key('actions')),
        );

        _thenTitleStartsAtSharedInset(tester);
        expect(find.byKey(const Key('actions')), findsOneWidget);
        expect(_ruleFinder, findsOneWidget);
      },
    );

    testWidgets(
      'given showRule is false, when the masthead renders, '
      'then the rule is gone but the title keeps the shared inset',
      (tester) async {
        await _givenMasthead(tester, showRule: false);

        // 探索頁浮在地圖上時關掉分隔線，位置仍必須與其他分頁對齊。
        expect(_ruleFinder, findsNothing);
        _thenTitleStartsAtSharedInset(tester);
      },
    );

    testWidgets('given a masthead, '
        'when it renders, '
        'then only the title is shown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Masthead(title: '探索')),
        ),
      );

      expect(find.text('探索'), findsOneWidget);
    });
  });
}

/// 標題下的細分隔線：唯一高度為 1 的 SizedBox。
final _ruleFinder = find.byWidgetPredicate(
  (w) => w is SizedBox && w.height == 1,
);

Future<void> _givenMasthead(
  WidgetTester tester, {
  Widget? actions,
  bool showRule = true,
}) async {
  await pumpScreen(
    tester,
    child: Scaffold(
      body: SafeArea(
        child: Masthead(title: '探索', actions: actions, showRule: showRule),
      ),
    ),
  );
}

void _thenTitleStartsAtSharedInset(WidgetTester tester) {
  expect(tester.getRect(find.text('探索')).left, Masthead.horizontalInset);
}
