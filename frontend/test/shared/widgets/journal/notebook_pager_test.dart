import 'package:context_app/shared/widgets/journal/notebook_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('JournalPaperPainter', () {
    test(
      'given a paper height, when laying out the ruled lines, '
      'then they start at 33px and repeat every 34px within the page',
      () {
        expect(JournalPaperPainter.ruleOffsets(80), [33.5, 67.5]);
      },
    );

    test(
      'given a paper height, when laying out the binding holes, '
      'then they start 24px down, repeat every 40px and respect the bottom '
      'inset',
      () {
        expect(JournalPaperPainter.holeOffsets(110), [24.0, 64.0]);
      },
    );

    test(
      'given a page shorter than the first rule, when laying out, '
      'then nothing is drawn',
      () {
        expect(JournalPaperPainter.ruleOffsets(20), isEmpty);
        expect(JournalPaperPainter.holeOffsets(20), isEmpty);
      },
    );
  });

  group('NotebookPager', () {
    testWidgets(
      'given a page with no callbacks, when the pager renders, '
      'then no actions are shown and the title appears only in the note',
      (tester) async {
        await _givenPager(tester, pages: [_buildPage()]);

        expect(find.text('trip.add_to_trip'), findsNothing);
        expect(find.text('common.share'), findsNothing);
        expect(find.text('common.delete'), findsNothing);
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
        // 拍立得下方不再放手寫圖說，景點名只出現在筆記標題一處。
        expect(find.text('Kinkaku-ji'), findsOneWidget);
      },
    );

    testWidgets(
      'given a page taller than its content, when the pager renders, '
      'then the photo hugs the header and the slack falls below the note',
      (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await _givenPager(tester, pages: [_buildPage()]);

        final headerBottom = tester
            .getRect(find.text('journey.notebook.entry_no'))
            .bottom;
        final photo = tester.getRect(_emptyPhotoFinder);
        final noteBottom = tester
            .getRect(find.text('A golden pavilion by the pond.'))
            .bottom;
        final footerTop = tester.getRect(find.text('01 / 01')).top;

        // 照片緊接在頁首下方，只留設計稿的間距（含旋轉溢出的餘裕）。
        expect(photo.top - headerBottom, lessThan(60));
        // 多出來的高度全落在筆記與動作列之間。
        expect(footerTop - noteBottom, greaterThan(100));
      },
    );

    testWidgets(
      'given a page with every callback, when the user taps each action, '
      'then replay, add-to-trip, share and delete each fire once',
      (tester) async {
        var replayCount = 0;
        var addCount = 0;
        var shareCount = 0;
        var deleteCount = 0;

        await _givenPager(
          tester,
          pages: [
            _buildPage(
              onReplay: () => replayCount += 1,
              onAddToTrip: () => addCount += 1,
              onShare: () => shareCount += 1,
              onDelete: () => deleteCount += 1,
            ),
          ],
        );
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.tap(find.text('trip.add_to_trip'));
        await tester.tap(find.text('common.share'));
        await tester.tap(find.text('common.delete'));
        await tester.pump();

        expect(replayCount, 1);
        expect(addCount, 1);
        expect(shareCount, 1);
        expect(deleteCount, 1);
      },
    );
  });
}

/// 無照片時的斜紋底，用它的顏色定位拍立得裡那張正方形照片。
final _emptyPhotoFinder = find.byWidgetPredicate(
  (w) => w is ColoredBox && w.color == const Color(0xFFEFE7D6),
);

NotebookPage _buildPage({
  VoidCallback? onReplay,
  VoidCallback? onAddToTrip,
  VoidCallback? onShare,
  VoidCallback? onDelete,
}) => NotebookPage(
  title: 'Kinkaku-ji',
  dateLabel: '2024/05/01 · 10:00',
  text: 'A golden pavilion by the pond.',
  onReplay: onReplay,
  onAddToTrip: onAddToTrip,
  onShare: onShare,
  onDelete: onDelete,
);

Future<void> _givenPager(
  WidgetTester tester, {
  required List<NotebookPage> pages,
}) async {
  await pumpScreen(tester, child: NotebookPager(pages: pages));
}
