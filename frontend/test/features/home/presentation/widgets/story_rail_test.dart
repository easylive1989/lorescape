import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/home/presentation/widgets/story_rail.dart';
import 'package:context_app/shared/widgets/page_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

DailyStory _story(int i) => DailyStory(
  publishDate: DateTime(2026, 7, 28).subtract(Duration(days: i)),
  language: 'zh-TW',
  placeName: '地點$i',
  placeLocation: '某地',
  era: '某年',
  story: '內文',
  imageUrl: null,
  wikipediaUrl: 'https://zh.wikipedia.org/wiki/地點$i',
  latitude: 30 + i.toDouble(),
  longitude: 100 + i.toDouble(),
);

Future<void> _givenRail(
  WidgetTester tester, {
  required int count,
  int activeIndex = 0,
  bool isError = false,
  VoidCallback? onRetry,
}) async {
  await pumpScreen(
    tester,
    child: Scaffold(
      body: StoryRail(
        stories: [for (var i = 0; i < count; i++) _story(i)],
        isError: isError,
        onRetry: onRetry ?? () {},
        activeIndex: activeIndex,
        onActiveChanged: (_) {},
        onOpen: (_) {},
      ),
    ),
  );
}

void main() {
  setUpAll(initTestEnvironment);

  testWidgets('given a loading-failure state, '
      'when the rail renders, '
      'then it shows an error message and a retry button instead of cards', (
    tester,
  ) async {
    var retried = false;
    await _givenRail(
      tester,
      count: 0,
      isError: true,
      onRetry: () => retried = true,
    );

    expect(find.text('home.load_error'), findsOneWidget);
    expect(find.byKey(const Key('home-stories-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-stories-retry')));

    expect(retried, isTrue);
  });

  testWidgets(
    'given a page indicator, '
    'when the rail renders with several stories, '
    'then the dot count matches the story count and the active dot is highlighted',
    (tester) async {
      await _givenRail(tester, count: 4, activeIndex: 2);

      final dots = tester.widget<PageDots>(find.byType(PageDots));
      expect(dots.count, 4);
      expect(dots.index, 2);
    },
  );

  testWidgets(
    'given the story rail, '
    'when the user flings across it, '
    'then it settles exactly on a card boundary instead of stopping mid-card',
    (tester) async {
      await _givenRail(tester, count: 8);

      await tester.fling(find.byType(ListView), const Offset(-500, 0), 800);
      await tester.pumpAndSettle();

      final offset = tester
          .widget<ListView>(find.byType(ListView))
          .controller!
          .offset;
      final remainder = offset % StoryRail.stride;
      final distanceToBoundary = remainder < StoryRail.stride / 2
          ? remainder
          : StoryRail.stride - remainder;

      expect(
        distanceToBoundary,
        lessThan(1.0),
        reason:
            '甩動後的捲動位置應該落在卡片邊界（stride 的整數倍）附近，'
            '不是停在兩張卡中間',
      );
    },
  );

  testWidgets(
    'given the story rail at the first card, '
    'when the user flicks quickly but drags less than half a card, '
    'then it still advances to the next card instead of springing back',
    (tester) async {
      await _givenRail(tester, count: 8);

      // 拖動距離只有 80px（遠小於半張卡的 162px），靠甩動速度換卡。
      await tester.fling(find.byType(ListView), const Offset(-80, 0), 1200);
      await tester.pumpAndSettle();

      final offset = tester
          .widget<ListView>(find.byType(ListView))
          .controller!
          .offset;

      expect(
        offset,
        closeTo(StoryRail.stride, 1.0),
        reason: '輕甩就該前進一張卡，不必實際拖超過半張卡的距離',
      );
    },
  );
}
