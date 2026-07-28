import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/providers.dart';
import 'package:context_app/features/explore/providers.dart';
import 'package:context_app/features/home/domain/globe/world_outline.dart';
import 'package:context_app/features/home/presentation/screens/globe_home_screen.dart';
import 'package:context_app/features/home/presentation/widgets/globe_view.dart';
import 'package:context_app/features/home/providers.dart';
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

/// 從 2026-07-28 往回數 [daysAgo] 天的日期字串，用來鋪多篇故事時避免手key
/// 一長串日期。
String _dateAt(int daysAgo) {
  final date = DateTime(2026, 7, 28).subtract(Duration(days: daysAgo));
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

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
      // WorldOutline.load 用 compute() 開真正的背景 isolate，testWidgets
      // 預設跑在 FakeAsync zone 下等不到真實 isolate 的回應，會讓
      // GlobeView 永遠不出現在畫面上（見 world_outline_test.dart 對同一個
      // 坑的說明）。這裡直接把 provider 換成同步可解的假輪廓，測試才能
      // 檢查 GlobeView 本身收到的 pins / focus。
      worldOutlineProvider.overrideWith(
        (ref) async => WorldOutline.parse('{"rings":[]}'),
      ),
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

  testWidgets(
    'given the globe home, '
    'when the user taps a story card that is not the selected one, '
    'then it only scrolls that card into view and does not open the story',
    (tester) async {
      // 6 篇夠讓卡片列超出視窗寬度，點擊才會真的觸發捲動（見 _givenHome
      // 的視窗尺寸註解）。
      _stories.seed([
        for (var i = 0; i < 6; i++)
          _story(
            date: _dateAt(i),
            place: '地點$i',
            latitude: 30 + i.toDouble(),
            longitude: 100 + i.toDouble(),
          ),
      ]);
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.tap(find.byKey(Key('story-card-${_dateAt(1)}')));
      await tester.pumpAndSettle();

      expect(pushed, isEmpty, reason: '第一次點非選中卡片只是把它捲到中間，不該開故事');

      // 上面那次點擊觸發捲動、把第 1 張捲成選中卡；再點一次同一張，這次
      // 才該真的打開故事。
      await tester.tap(find.byKey(Key('story-card-${_dateAt(1)}')));
      await tester.pumpAndSettle();

      expect(pushed.single, isA<DailyStory>());
      expect((pushed.single as DailyStory).placeName, '地點1');
    },
  );

  testWidgets(
    'given a story without coordinates, '
    'when it becomes the selected card, '
    'then the globe renders with no focus pin instead of crashing',
    (tester) async {
      _stories.seed([
        for (var i = 0; i < 6; i++)
          _story(
            date: _dateAt(i),
            place: '地點$i',
            latitude: i == 2 ? null : 30 + i.toDouble(),
            longitude: i == 2 ? null : 100 + i.toDouble(),
          ),
      ]);
      await _givenHome(tester, pushed: []);

      await tester.tap(find.byKey(Key('story-card-${_dateAt(2)}')));
      await tester.pumpAndSettle();

      final globe = tester.widget<GlobeView>(find.byType(GlobeView));
      expect(globe.focus, isNull);
    },
  );

  testWidgets(
    'given more daily stories than the pin cap, '
    'when the globe home loads, '
    'then only the most recent pinnedStoryCount stories are pinned '
    'but scrolling to an older one still focuses it',
    (tester) async {
      // 12 篇：確保捲到第 8、9 篇（index 7、8）時，目標捲動位置落在
      // maxScrollExtent 之內，不會被 clamp 到別的索引。
      _stories.seed([
        for (var i = 0; i < 12; i++)
          _story(
            date: _dateAt(i),
            place: '地點$i',
            latitude: 30 + i.toDouble(),
            longitude: 100 + i.toDouble(),
          ),
      ]);
      await _givenHome(tester, pushed: []);

      expect(
        tester.widget<GlobeView>(find.byType(GlobeView)).pins.length,
        GlobeHomeScreen.pinnedStoryCount,
        reason: '地球儀最多只釘最近 7 篇故事',
      );

      // StoryRail.stride 是每張卡的橫向間距；直接拖曳捲軸到第 8 篇
      // （index 7）的位置——用拖曳而不是點卡片，因為卡片離起點太遠，
      // 一開始還沒被 ListView 懶建出來，點不到。
      await tester.drag(find.byType(ListView), const Offset(-7 * 324, 0));
      await tester.pumpAndSettle();

      expect(
        tester.widget<GlobeView>(find.byType(GlobeView)).focus?.label,
        '地點7',
        reason: '第 8 篇雖然不在 7 篇的釘點上限內，選中時仍要出現 focus pin',
      );

      await tester.drag(find.byType(ListView), const Offset(-324, 0));
      await tester.pumpAndSettle();

      expect(
        tester.widget<GlobeView>(find.byType(GlobeView)).focus?.label,
        '地點8',
        reason: '第 9 篇同理',
      );
    },
  );
}
