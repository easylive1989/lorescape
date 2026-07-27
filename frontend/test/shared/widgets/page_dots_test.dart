import 'package:context_app/shared/widgets/page_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('PageDots', () {
    testWidgets(
      'given fewer pages than the cap, when the row renders, '
      'then every page gets its own dot',
      (tester) async {
        await _givenPageDots(tester, count: 4, index: 0);

        expect(_dotSizes(tester).length, 4);
      },
    );

    testWidgets(
      'given more pages than the cap, when the row renders, '
      'then the row never grows beyond the capped number of dots',
      (tester) async {
        await _givenPageDots(tester, count: 31, index: 0);

        expect(_dotSizes(tester).length, PageDots.maxDots);
      },
    );

    testWidgets(
      'given a page in the middle of a long run, when the row renders, '
      'then both window edges shrink to hint at the pages beyond them',
      (tester) async {
        await _givenPageDots(tester, count: 20, index: 10);

        final sizes = _dotSizes(tester);
        expect(sizes.first, _hintDot);
        expect(sizes.last, _hintDot);
        // 中間那顆是目前頁，其餘維持一般大小。
        expect(sizes.where((s) => s == _activeDot).length, 1);
        expect(sizes.where((s) => s == _plainDot).length, 3);
      },
    );

    testWidgets(
      'given the first page of a long run, when the row renders, '
      'then only the trailing edge hints at more pages',
      (tester) async {
        await _givenPageDots(tester, count: 20, index: 0);

        final sizes = _dotSizes(tester);
        expect(sizes.first, _activeDot);
        expect(sizes.last, _hintDot);
        expect(sizes.where((s) => s == _hintDot).length, 1);
      },
    );

    testWidgets(
      'given the last page of a long run, when the row renders, '
      'then only the leading edge hints at more pages',
      (tester) async {
        await _givenPageDots(tester, count: 20, index: 19);

        final sizes = _dotSizes(tester);
        expect(sizes.first, _hintDot);
        expect(sizes.last, _activeDot);
        expect(sizes.where((s) => s == _hintDot).length, 1);
      },
    );

    testWidgets(
      'given an onSelect callback, when a dot is tapped, '
      'then it reports the page that dot stands for',
      (tester) async {
        final selected = <int>[];

        await _givenPageDots(
          tester,
          count: 20,
          index: 0,
          onSelect: selected.add,
        );
        await tester.tap(_dotTaps.at(2));

        // 視窗從第 0 頁起算，所以第三顆點就是第 2 頁。
        expect(selected, [2]);
      },
    );

    testWidgets(
      'given no onSelect callback, when the row renders, '
      'then the dots carry no tap handler',
      (tester) async {
        await _givenPageDots(tester, count: 4, index: 0);

        expect(_dotTaps, findsNothing);
      },
    );
  });
}

const Size _activeDot = Size(20, 6);
const Size _plainDot = Size(6, 6);
const Size _hintDot = Size(4, 4);

Future<void> _givenPageDots(
  WidgetTester tester, {
  required int count,
  required int index,
  ValueChanged<int>? onSelect,
}) async {
  await pumpScreen(
    tester,
    child: Scaffold(
      body: PageDots(
        count: count,
        index: index,
        padding: EdgeInsets.zero,
        onSelect: onSelect,
      ),
    ),
  );
}

Finder get _dotTaps => find.descendant(
  of: find.byType(PageDots),
  matching: find.byType(GestureDetector),
);

List<Size> _dotSizes(WidgetTester tester) => tester
    .widgetList<AnimatedContainer>(
      find.descendant(
        of: find.byType(PageDots),
        matching: find.byType(AnimatedContainer),
      ),
    )
    .map((dot) => Size(dot.constraints!.maxWidth, dot.constraints!.maxHeight))
    .toList();
