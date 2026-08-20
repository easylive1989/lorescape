import 'package:context_app/features/narration/domain/models/narration_segment.dart';
import 'package:context_app/features/narration/presentation/widgets/transcript_segment_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('TranscriptSegmentItem', () {
    testWidgets(
      'given isLede is true, when rendered, then a drop cap is shown',
      (tester) async {
        await pumpScreen(
          tester,
          child: TranscriptSegmentItem(
            segment: const NarrationSegment(
              text: '五○六年四月，羅馬的春風吹拂著梵蒂岡山丘。',
              startPosition: 0,
              endPosition: 20,
            ),
            isActive: false,
            scrollController: AutoScrollController(),
            index: 1,
            isLede: true,
          ),
        );

        expect(find.byKey(const Key('reader-lede-dropcap')), findsOneWidget);
        // 設計稿 `.reader__lede .dropcap`：64px、line-height .84。
        final dropcap = tester.widget<Text>(
          find.byKey(const Key('reader-lede-dropcap')),
        );
        expect(dropcap.style?.fontSize, 64);
        expect(dropcap.style?.height, 0.84);
      },
    );

    testWidgets(
      'given isLede is false, when rendered, then no drop cap is shown',
      (tester) async {
        await pumpScreen(
          tester,
          child: TranscriptSegmentItem(
            segment: const NarrationSegment(
              text: '對儒略二世而言，這座教堂是象徵。',
              startPosition: 0,
              endPosition: 16,
            ),
            isActive: false,
            scrollController: AutoScrollController(),
            index: 2,
          ),
        );

        expect(find.byKey(const Key('reader-lede-dropcap')), findsNothing);
      },
    );
  });
}
