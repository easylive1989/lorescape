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
      'then the footer shows no actions',
      (tester) async {
        await _givenPager(tester, pages: [_buildPage()]);

        expect(find.text('trip.add_to_trip'), findsNothing);
        expect(find.text('common.share'), findsNothing);
        expect(find.text('common.delete'), findsNothing);
      },
    );

    testWidgets(
      'given a page with every callback, when the user taps each action, '
      'then add-to-trip, share and delete each fire once',
      (tester) async {
        var addCount = 0;
        var shareCount = 0;
        var deleteCount = 0;

        await _givenPager(
          tester,
          pages: [
            _buildPage(
              onAddToTrip: () => addCount += 1,
              onShare: () => shareCount += 1,
              onDelete: () => deleteCount += 1,
            ),
          ],
        );
        await tester.tap(find.text('trip.add_to_trip'));
        await tester.tap(find.text('common.share'));
        await tester.tap(find.text('common.delete'));
        await tester.pump();

        expect(addCount, 1);
        expect(shareCount, 1);
        expect(deleteCount, 1);
      },
    );
  });
}

NotebookPage _buildPage({
  VoidCallback? onAddToTrip,
  VoidCallback? onShare,
  VoidCallback? onDelete,
}) => NotebookPage(
  title: 'Kinkaku-ji',
  dateLabel: '2024/05/01 · 10:00',
  text: 'A golden pavilion by the pond.',
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
