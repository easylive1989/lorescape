import 'package:context_app/shared/widgets/journal/notebook_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('NotebookPager', () {
    testWidgets(
      'given a page without onPlay, when the pager renders, '
      'then no replay action is shown',
      (tester) async {
        await _givenPager(tester, pages: [_buildPage()]);

        expect(find.text('common.replay'), findsNothing);
      },
    );

    testWidgets(
      'given a page with onPlay, when the user taps the replay action, '
      'then the callback fires once',
      (tester) async {
        var playCount = 0;

        await _givenPager(
          tester,
          pages: [_buildPage(onPlay: () => playCount += 1)],
        );
        await tester.tap(find.text('common.replay'));
        await tester.pump();

        expect(playCount, 1);
      },
    );
  });
}

NotebookPage _buildPage({VoidCallback? onPlay}) => NotebookPage(
  title: 'Kinkaku-ji',
  dateLabel: '2024/05/01 · 10:00',
  text: 'A golden pavilion by the pond.',
  onPlay: onPlay,
);

Future<void> _givenPager(
  WidgetTester tester, {
  required List<NotebookPage> pages,
}) async {
  await pumpScreen(tester, child: NotebookPager(pages: pages));
}
