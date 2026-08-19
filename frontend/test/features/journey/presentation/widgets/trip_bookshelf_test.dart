import 'package:context_app/features/journey/presentation/widgets/trip_bookshelf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(initTestEnvironment);

  group('TripBookshelf', () {
    testWidgets(
      'given more books than fit the shelf width, when the shelf is rendered, '
      'then they stay on one row that scrolls sideways',
      (tester) async {
        await _givenBookshelf(tester, bookCount: 9);

        final rows = _thenBooksGroupedByRow(tester, bookCount: 9);
        expect(
          rows,
          hasLength(1),
          reason: 'v3 的書架只有一層，放不下就橫捲，不再往下長第二層',
        );
        expect(
          rows.values.single,
          hasLength(9),
          reason: '九本都要在那一層上——少了幾本同樣只會量到一個 dy，'
              '不把本數釘住的話「只有一層」這個斷言就形同虛設',
        );
        expect(_horizontalScrollable(), findsOneWidget);
      },
    );

    testWidgets(
      'given more books than fit the shelf width, when the user scrolls the '
      'shelf sideways, then the books that were off the right edge come in',
      (tester) async {
        await _givenBookshelf(tester, bookCount: 9);
        final viewport = tester.getRect(_horizontalScrollable());
        final before = tester.getTopLeft(find.text('#8')).dx;
        expect(before, greaterThan(viewport.right), reason: '第 9 本原本在畫面外');

        await tester.drag(_horizontalScrollable(), const Offset(-400, 0));
        await tester.pumpAndSettle();

        final after = tester.getTopLeft(find.text('#8')).dx;
        expect(after, lessThan(before));
        expect(after, lessThan(viewport.right));
      },
    );

    testWidgets(
      'given a caption, when the shelf is rendered, then the caption is shown '
      'above the books',
      (tester) async {
        await _givenBookshelf(tester, bookCount: 3);

        expect(find.text('3 本旅程'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('3 本旅程')).dy,
          lessThan(tester.getTopLeft(find.text('#0')).dy),
        );
      },
    );

    testWidgets(
      'given the header row, when the user taps the new-journey pill, '
      'then the shelf reports the request to add a trip',
      (tester) async {
        var addTaps = 0;

        await _givenBookshelf(tester, bookCount: 3, onAddTrip: () => addTaps++);
        await tester.tap(find.text('＋ journey.shelf_new'));

        expect(addTaps, 1);
      },
    );

    testWidgets(
      'given any shelf, when it is rendered, then the only way to add a trip '
      'is the header pill',
      (tester) async {
        await _givenBookshelf(tester, bookCount: 3);

        expect(find.text('＋ journey.shelf_new'), findsOneWidget);
        // v3 拿掉了書架末端那本虛線佔位書：同一個動作不留兩個入口。
        expect(find.byIcon(Icons.add), findsNothing);
      },
    );

    testWidgets(
      'given a selected book, when the lift animation settles, '
      'then only that book is raised above the others',
      (tester) async {
        await _givenBookshelf(tester, bookCount: 3, selectedIndex: 1);
        await tester.pumpAndSettle();

        // 書是靠底部對齊的，被抽出來的那本底緣才會高於同排其他本。
        final raised = tester.getBottomLeft(find.text('#1')).dy;
        expect(raised, lessThan(tester.getBottomLeft(find.text('#0')).dy));
        expect(raised, lessThan(tester.getBottomLeft(find.text('#2')).dy));
      },
    );

    testWidgets(
      'given the tallest book is the selected one, when it is lifted, '
      'then its head is not clipped by the scrolling shelf',
      (tester) async {
        // 高度循環是 148/158/168，第 3 本（index 2）最高。
        await _givenBookshelf(tester, bookCount: 3, selectedIndex: 2);
        await tester.pumpAndSettle();

        final shelfTop = tester.getRect(_horizontalScrollable()).top;
        expect(_spineRect(tester, '#2').top, greaterThanOrEqualTo(shelfTop));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'given no books at all, when the shelf is rendered, '
      'then it stands empty without collapsing',
      (tester) async {
        await _givenBookshelf(tester, bookCount: 0);

        // 一本書都沒有時凹槽仍撐在最小高度上，而不是塌成一條線。
        expect(
          tester.getRect(_horizontalScrollable()).height,
          greaterThanOrEqualTo(172),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Finder _horizontalScrollable() => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.right,
);

/// 書背本身（畫書皮的那層）畫出來的位置。
///
/// 抽高與傾斜是 Transform 系的效果，只改繪製位置不改版面，所以要量書背裡面
/// 的節點才看得到；量外層的 Semantics 拿到的還是沒抽出來的原位。
Rect _spineRect(WidgetTester tester, String subtitle) => tester.getRect(
  find
      .ancestor(of: find.text(subtitle), matching: find.byType(CustomPaint))
      .first,
);

/// 固定 390 邏輯寬度，讓「一排放得下幾本」在測試裡是確定的。
Future<void> _givenBookshelf(
  WidgetTester tester, {
  required int bookCount,
  int? selectedIndex,
  VoidCallback? onAddTrip,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await pumpScreen(
    tester,
    child: Scaffold(
      body: SingleChildScrollView(
        child: TripBookshelf(
          caption: '$bookCount 本旅程',
          onAddTrip: onAddTrip ?? () {},
          books: [
            for (var i = 0; i < bookCount; i++)
              ShelfBook(
                title: '旅程$i',
                subtitle: '#$i',
                hasEntries: false,
                isSelected: i == selectedIndex,
                onTap: () {},
              ),
          ],
        ),
      ),
    ),
  );
}

/// 用每本書底部的 subtitle 當定位點，依 y 座標把書分層。
///
/// 同一排的書是靠底部對齊的（書高刻意不齊），所以 subtitle 的 y 相同即同排。
Map<double, List<Offset>> _thenBooksGroupedByRow(
  WidgetTester tester, {
  required int bookCount,
}) {
  final rows = <double, List<Offset>>{};
  for (var i = 0; i < bookCount; i++) {
    final finder = find.text('#$i');
    // 捲出畫面外的書仍在 widget tree 裡（Row 一次全建），位置照樣量得到。
    if (finder.evaluate().isEmpty) continue;
    final offset = tester.getTopLeft(finder);
    rows.putIfAbsent(offset.dy, () => []).add(offset);
  }
  return rows;
}
