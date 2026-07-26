import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/presentation/widgets/story_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('StoryDeck', () {
    testWidgets(
      'given a deck of stories, when it renders, '
      'then the top card shows its title, subtitle and eyebrow',
      (tester) async {
        await _givenDeck(tester, stories: [_story('a'), _story('b')]);

        expect(find.text('Title a'), findsOneWidget);
        expect(find.text('Sub a'), findsOneWidget);
        expect(find.text('LOCATION A'), findsOneWidget);
      },
    );

    testWidgets(
      'given a deck, when the user taps the top card, '
      'then that story is opened',
      (tester) async {
        final opened = <DailyStory>[];

        await _givenDeck(
          tester,
          stories: [_story('a'), _story('b')],
          onOpen: opened.add,
        );
        await tester.tap(find.text('Title a'));
        await tester.pumpAndSettle();

        expect(opened.single.cardTitle, 'Title a');
      },
    );

    testWidgets(
      'given a deck, when the user swipes the top card right past the '
      'threshold, then the previous story becomes the top card and '
      'nothing opens',
      (tester) async {
        final opened = <DailyStory>[];

        await _givenDeck(
          tester,
          stories: [_story('a'), _story('b'), _story('c')],
          onOpen: opened.add,
        );
        await _whenUserSwipes(tester, dx: 140);

        expect(opened, isEmpty);
        // The queue rotates backwards, so the last card 'c' (the previous
        // one relative to 'a') now owns the deck's top slot.
        expect(find.text('Sub c'), findsOneWidget);
      },
    );

    testWidgets(
      'given a deck, when the user swipes the top card left past the '
      'threshold, then the next story becomes the top card and nothing opens',
      (tester) async {
        final opened = <DailyStory>[];

        await _givenDeck(
          tester,
          stories: [_story('a'), _story('b')],
          onOpen: opened.add,
        );
        await _whenUserSwipes(tester, dx: -140);

        expect(opened, isEmpty);
        // The top card rotates to the back of the queue, so 'b' now
        // owns the deck's top slot.
        expect(tester.widget<StoryDeck>(find.byType(StoryDeck)), isNotNull);
        expect(find.text('Sub b'), findsOneWidget);
      },
    );

    testWidgets(
      'given a deck, when the user drags short of the threshold, '
      'then the card springs back and nothing opens',
      (tester) async {
        final opened = <DailyStory>[];

        await _givenDeck(
          tester,
          stories: [_story('a'), _story('b')],
          onOpen: opened.add,
        );
        await _whenUserSwipes(tester, dx: 40);

        expect(opened, isEmpty);
        expect(find.text('Sub a'), findsOneWidget);
      },
    );

    testWidgets(
      'given more stories than the indicator cap, when the deck renders, '
      'then the progress row shows at most the capped number of dots',
      (tester) async {
        await _givenDeck(
          tester,
          stories: [for (var i = 0; i < 31; i += 1) _story('s$i')],
        );

        // Progress dots are the only AnimatedContainers in the deck.
        expect(find.byType(AnimatedContainer), findsNWidgets(9));
      },
    );
  });
}

DailyStory _story(String id) => DailyStory(
  publishDate: DateTime(2026, 5, 29),
  language: 'zh-TW',
  placeName: 'Place $id',
  placeLocation: 'Somewhere $id',
  era: '70-80 CE',
  story: 'Body $id',
  imageUrl: null,
  imageAttribution: null,
  wikipediaUrl: 'https://example.com/$id',
  cardTitle: 'Title $id',
  cardTitleSub: 'Sub $id',
  cardLocationEn: 'LOCATION ${id.toUpperCase()}',
  cardAnnoRoman: 'I',
);

Future<void> _givenDeck(
  WidgetTester tester, {
  required List<DailyStory> stories,
  ValueChanged<DailyStory>? onOpen,
}) async {
  await pumpScreen(
    tester,
    child: Scaffold(
      body: StoryDeck(stories: stories, onOpen: onOpen ?? (_) {}),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _whenUserSwipes(WidgetTester tester, {required double dx}) async {
  await tester.drag(find.byType(StoryDeck), Offset(dx, 0));
  await tester.pumpAndSettle();
}
