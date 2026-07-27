import 'package:context_app/features/journey/presentation/widgets/trip_bookshelf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(initTestEnvironment);

  group('TripBookshelf', () {
    testWidgets(
      'given more books than fit the shelf width, when the shelf is rendered, '
      'then the extra books wrap onto further rows instead of scrolling '
      'sideways, and every row starts at the same left edge',
      (tester) async {
        await _givenBookshelf(tester, bookCount: 9);

        final rows = _thenBooksGroupedByRow(tester, bookCount: 9);

        expect(rows.length, greaterThan(1));
        expect(
          rows.values.map((row) => row.first.dx).toSet(),
          hasLength(1),
          reason: '每一層書架都應該從同一個左邊界開始排',
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.right,
          ),
          findsNothing,
          reason: '書架本身不再橫向捲動，改由外層的頁面上下捲',
        );
      },
    );

    testWidgets('given fewer books than fit the shelf width, when the shelf is '
        'rendered, then they all stay on a single row', (tester) async {
      await _givenBookshelf(tester, bookCount: 3);

      expect(_thenBooksGroupedByRow(tester, bookCount: 3), hasLength(1));
    });

    testWidgets(
      'given a caption, when the shelf is rendered, then the caption is shown '
      'above the books',
      (tester) async {
        await _givenBookshelf(tester, bookCount: 3);

        expect(find.text('旅程書架 · 3 本'), findsOneWidget);
      },
    );

    testWidgets(
      'given any shelf, when it is rendered, then an empty placeholder book '
      'sits after the real books',
      (tester) async {
        await _givenBookshelf(tester, bookCount: 3);

        expect(find.byIcon(Icons.add), findsOneWidget);
        // 佔位書排在最後一本真書的右邊，而不是插在書堆前面。
        expect(
          tester.getTopLeft(find.byIcon(Icons.add)).dx,
          greaterThan(tester.getTopLeft(find.text('#2')).dx),
        );
      },
    );

    testWidgets(
      'given the placeholder book, when the user taps it, '
      'then the shelf reports the request to add a trip',
      (tester) async {
        var addTaps = 0;

        await _givenBookshelf(tester, bookCount: 3, onAddTrip: () => addTaps++);
        await tester.tap(find.byIcon(Icons.add));

        expect(addTaps, 1);
      },
    );

    testWidgets(
      'given a shelf whose last row is exactly full, when it is rendered, '
      'then the placeholder wraps onto the next row instead of overflowing',
      (tester) async {
        // 390 寬一層剛好放 4 本；第 4 本填滿該層，佔位書必須換行。
        await _givenBookshelf(tester, bookCount: 4);

        final lastBook = tester.getTopLeft(find.text('#3'));
        final placeholder = tester.getTopLeft(find.byIcon(Icons.add));

        expect(placeholder.dy, greaterThan(lastBook.dy));
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// 固定 390 邏輯寬度，讓「一層放得下幾本」在測試裡是確定的。
Future<void> _givenBookshelf(
  WidgetTester tester, {
  required int bookCount,
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
          caption: '旅程書架 · $bookCount 本',
          onAddTrip: onAddTrip ?? () {},
          books: [
            for (var i = 0; i < bookCount; i++)
              ShelfBook(
                title: '旅程$i',
                subtitle: '#$i',
                hasEntries: false,
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
/// 同一層的書是靠底部對齊的（書高刻意不齊），所以 subtitle 的 y 相同即同層。
Map<double, List<Offset>> _thenBooksGroupedByRow(
  WidgetTester tester, {
  required int bookCount,
}) {
  final rows = <double, List<Offset>>{};
  for (var i = 0; i < bookCount; i++) {
    final offset = tester.getTopLeft(find.text('#$i'));
    rows.putIfAbsent(offset.dy, () => []).add(offset);
  }
  return rows;
}
