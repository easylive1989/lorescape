import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/providers.dart';
import 'package:context_app/features/explore/providers.dart';
import 'package:context_app/features/home/presentation/screens/globe_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fakes/fake_places_repository.dart';
import '../../../../fakes/in_memory_daily_story_repository.dart';
import '../../../../helpers/pump_app.dart';

DailyStory _story({
  required String date,
  required String place,
  double? latitude,
  double? longitude,
}) => DailyStory(
  publishDate: DateTime.parse(date),
  language: 'zh-TW',
  placeName: place,
  placeLocation: '某地',
  era: '某年',
  story: '內文',
  imageUrl: null,
  wikipediaUrl: 'https://zh.wikipedia.org/wiki/$place',
  latitude: latitude,
  longitude: longitude,
);

late InMemoryDailyStoryRepository _stories;
late FakePlacesRepository _places;

Future<void> _givenHome(
  WidgetTester tester, {
  required List<Object?> pushed,
}) async {
  // 預設 800x600 的測試視窗高度不夠，會把底部卡片列擠出畫面；寬度也要夠讓
  // 三張卡片（不捲動）都落在 ListView 的 cacheExtent 內才會被建出來。
  // 不動 widget 本身的版面，只調測試視窗。
  tester.view.physicalSize = const Size(1100 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const GlobeHomeScreen()),
      GoRoute(
        path: '/map',
        builder: (_, state) {
          pushed.add('/map?q=${state.uri.queryParameters['q'] ?? ''}');
          return const Scaffold(key: Key('map-screen'));
        },
      ),
      GoRoute(
        path: '/journey',
        builder: (_, __) {
          pushed.add('/journey');
          return const Scaffold(key: Key('journey-screen'));
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) {
          pushed.add('/settings');
          return const Scaffold(key: Key('settings-screen'));
        },
      ),
      GoRoute(
        path: '/daily-story/detail',
        builder: (_, state) {
          pushed.add(state.extra);
          return const Scaffold(key: Key('detail-screen'));
        },
      ),
    ],
    overrides: [
      dailyStoryRepositoryProvider.overrideWithValue(_stories),
      placesRepositoryProvider.overrideWithValue(_places),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestEnvironment);

  setUp(() {
    _stories = InMemoryDailyStoryRepository()
      ..seed([
        _story(
          date: '2026-07-28',
          place: '聖伯多祿大殿',
          latitude: 41.9,
          longitude: 12.45,
        ),
        _story(
          date: '2026-07-27',
          place: '四面佛寺',
          latitude: 24.06,
          longitude: 120.54,
        ),
        _story(date: '2026-07-26', place: '沒有座標的地方'),
      ]);
    _places = FakePlacesRepository();
  });

  testWidgets(
    'given seeded daily stories, '
    'when the globe home loads, '
    'then every story appears in the rail and the newest one carries the badge',
    (tester) async {
      await _givenHome(tester, pushed: []);

      expect(find.text('聖伯多祿大殿'), findsWidgets);
      expect(find.text('四面佛寺'), findsOneWidget);
      expect(find.text('沒有座標的地方'), findsOneWidget);
      expect(find.text('home.badge_latest'), findsOneWidget);
    },
  );

  testWidgets(
    'given the globe home, '
    'when the user taps the selected story card, '
    'then the daily story detail is pushed with that story',
    (tester) async {
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.tap(find.byKey(const Key('story-card-2026-07-28')));
      await tester.pumpAndSettle();

      expect(pushed.single, isA<DailyStory>());
      expect((pushed.single as DailyStory).placeName, '聖伯多祿大殿');
    },
  );

  testWidgets(
    'given the globe home, '
    'when the user taps the locate button, '
    'then the map opens with no query',
    (tester) async {
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.tap(find.byKey(const Key('home-locate')));
      await tester.pumpAndSettle();

      expect(pushed, ['/map?q=']);
    },
  );

  testWidgets(
    'given the globe home, '
    'when the user taps the shelf button, '
    'then the journey screen opens',
    (tester) async {
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.tap(find.byKey(const Key('home-open-journey')));
      await tester.pumpAndSettle();

      expect(pushed, ['/journey']);
    },
  );

  testWidgets(
    'given the globe home, '
    'when the user taps the settings button, '
    'then the settings screen opens',
    (tester) async {
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.tap(find.byKey(const Key('home-open-settings')));
      await tester.pumpAndSettle();

      expect(pushed, ['/settings']);
    },
  );

  testWidgets(
    'given suggestions from the places repository, '
    'when the user types and waits out the debounce, '
    'then one request is made and tapping a suggestion opens the map with it',
    (tester) async {
      _places.suggestions = const ['京都市', '京都御所'];
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.enterText(find.byKey(const Key('home-search')), '京');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(const Key('home-search')), '京都');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(_places.suggestCallCount, 1, reason: 'debounce 應該吃掉第一次輸入');
      expect(find.text('京都市'), findsOneWidget);

      await tester.tap(find.text('京都市'));
      await tester.pumpAndSettle();

      expect(pushed, ['/map?q=京都市']);
    },
  );
}
