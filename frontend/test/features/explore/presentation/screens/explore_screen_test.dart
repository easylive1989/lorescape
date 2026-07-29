import 'package:context_app/features/daily_story/providers.dart';
import 'package:context_app/features/explore/domain/errors/location_error.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/explore/presentation/screens/explore_screen.dart';
import 'package:context_app/features/explore/presentation/widgets/place_map_pin.dart';
import 'package:context_app/features/explore/providers.dart';
import 'package:context_app/features/saved_locations/providers.dart';
import 'package:context_app/shared/widgets/journal/masthead.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fakes/fake_location_service.dart';
import '../../../../fakes/fake_places_repository.dart';
import '../../../../fakes/in_memory_daily_story_repository.dart';
import '../../../../fakes/in_memory_saved_locations_repository.dart';
import '../../../../helpers/fake_map_style.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_data.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('ExploreScreen', () {
    testWidgets('given no nearby places, when the screen loads, '
        'then the empty-state copy is shown', (tester) async {
      await _givenExploreScreen(tester);

      _thenEmptyStateIsVisible();
    });

    testWidgets(
      'given the overlay header, when the screen loads, then the title and '
      'the search field both sit at the shared masthead inset',
      (tester) async {
        await _givenExploreScreen(tester);

        // 探索頁曾經自己複製一份 masthead，左緣漂移成 16、與故事／歷程兩頁
        // 差 6px。改用共用 Masthead 後由 horizontalInset 統一，這裡鎖住它。
        expect(
          tester.getRect(find.text('explore.title')).left,
          Masthead.horizontalInset,
        );
        // 量搜尋列的藥丸外框，不是內層 TextField——後者還隔著放大鏡與內距。
        final searchPill = find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Container),
            )
            .first;
        expect(tester.getRect(searchPill).left, Masthead.horizontalInset);
      },
    );

    testWidgets('given the map is shown, '
        'when the top icon row is rendered, '
        'then attribution is a corner badge rather than an info button', (
      tester,
    ) async {
      await _givenExploreScreen(tester);

      // 出處是 OpenFreeMap / OSM 的授權義務（見 ADR 0005）。2026-07-30 從
      // 頂部的 ⓘ 改回地圖角標，完整說明搬到設定頁；角標本身不得消失。
      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(
        find.text('OpenFreeMap © OpenMapTiles Data from OpenStreetMap'),
        findsOneWidget,
      );
    });

    testWidgets('given nearby places are returned, when the screen loads, '
        'then a place card is rendered for each place', (tester) async {
      final places = [
        buildPlace(id: 'p1', name: 'Senso-ji'),
        buildPlace(id: 'p2', name: 'Meiji Shrine'),
      ];

      await _givenExploreScreen(tester, places: places);

      _thenPlaceNamesAreVisible(['Senso-ji', 'Meiji Shrine']);
    });

    testWidgets('given a distance filter of 500 m, when the list is filtered, '
        'then only places within range are shown', (tester) async {
      // Place near origin (lat 0, lon 0), one within 500 m, one outside.
      final places = [
        buildPlace(
          id: 'p1',
          name: 'Near',
          latitude: 0.001, // ~111 m
          longitude: 0.0,
        ),
        buildPlace(
          id: 'p2',
          name: 'Far',
          latitude: 0.01, // ~1111 m
          longitude: 0.0,
        ),
      ];

      await _givenExploreScreen(
        tester,
        places: places,
        maxDistance: 500.0,
        userLocation: const PlaceLocation(latitude: 0.0, longitude: 0.0),
      );

      _thenPlaceNamesAreVisible(['Near']);
      _thenPlaceNamesAreHidden(['Far']);
    });

    testWidgets('given the user types in the search box and submits, '
        'when the repository returns search results, '
        'then the result list replaces the nearby places', (tester) async {
      final repo = FakePlacesRepository(
        nearbyPlaces: [buildPlace(id: 'p1', name: 'Nearby Place')],
        searchResults: [buildPlace(id: 's1', name: 'Searched Place')],
      );

      await _givenExploreScreen(tester, repo: repo);

      await tester.enterText(find.byType(TextField), 'searched');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Searched Place'), findsOneWidget);
      expect(find.text('Nearby Place'), findsNothing);
    });

    testWidgets(
      'given a submitted search term, when the user taps the clear icon, '
      'then the controller is cleared and nearby places are restored',
      (tester) async {
        final repo = FakePlacesRepository(
          nearbyPlaces: [buildPlace(id: 'p1', name: 'Nearby Place')],
          searchResults: [buildPlace(id: 's1', name: 'Searched Place')],
        );

        await _givenExploreScreen(tester, repo: repo);

        // The clear icon only appears after the search field is actually
        // used — submit once so the suffix rebuilds into a clear button.
        await tester.enterText(find.byType(TextField), 'xyz');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 20));

        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 20));

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, isEmpty);
        expect(find.text('Nearby Place'), findsOneWidget);
      },
    );

    testWidgets('given places are on screen, when the user taps refresh, '
        'then the nearby-places use case is invoked again', (tester) async {
      final repo = FakePlacesRepository(
        nearbyPlaces: [buildPlace(id: 'p1', name: 'Nearby')],
      );

      await _givenExploreScreen(tester, repo: repo);
      final before = repo.nearbyCallCount;

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      expect(repo.nearbyCallCount, greaterThan(before));
    });

    testWidgets(
      'given the filter is at its default value (10000 m), when the screen '
      'renders, then no active dot is shown',
      (tester) async {
        await _givenExploreScreen(tester, maxDistance: 10000.0);

        // The active dot is an 8x8 BoxDecoration in the filter-button stack.
        // It is hidden whenever maxDistance == kDefaultMaxDistanceMeters.
        expect(_activeDotFinder(), findsNothing);
      },
    );

    testWidgets('given a non-default maxDistance, when the screen renders, '
        'then the active dot is shown', (tester) async {
      await _givenExploreScreen(tester, maxDistance: 500.0);

      expect(_activeDotFinder(), findsOneWidget);
    });

    testWidgets('given the filter button is present, when the user taps it, '
        'then the filter panel bottom sheet is shown', (tester) async {
      await _givenExploreScreen(tester);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('explore.filter.title'), findsOneWidget);
      expect(find.text('explore.filter.max_distance'), findsOneWidget);
      expect(find.text('explore.filter.reset'), findsOneWidget);
    });

    testWidgets(
      'given an unsaved place card, when the user taps the bookmark icon, '
      'then the card shows the filled bookmark and the repo records the save',
      (tester) async {
        final savedRepo = InMemorySavedLocationsRepository();

        await _givenExploreScreen(
          tester,
          places: [buildPlace(id: 'p1', name: 'Senso-ji')],
          savedRepo: savedRepo,
        );

        expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

        await tester.tap(find.byIcon(Icons.bookmark_border));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmark), findsAtLeastNWidgets(1));
        expect(await savedRepo.isSaved('p1'), isTrue);
      },
    );

    testWidgets(
      'given a place card under a router, when the go button is tapped, '
      'then the config route is pushed with the place as extra',
      (tester) async {
        final extras = <Object?>[];

        await _givenExploreScreenWithRouter(
          tester,
          places: [buildPlace(id: 'p1', name: 'Senso-ji')],
          onConfigPush: extras.add,
        );

        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();

        expect(extras.single, isA<Place>());
        expect((extras.single as Place).id, equals('p1'));
      },
    );

    testWidgets(
      'given a place card under a router, when the card body is tapped, '
      'then the map focuses the place instead of navigating away',
      (tester) async {
        final extras = <Object?>[];

        await _givenExploreScreenWithRouter(
          tester,
          places: [buildPlace(id: 'p1', name: 'Senso-ji')],
          onConfigPush: extras.add,
        );

        await tester.tap(find.text('Senso-ji'));
        await tester.pumpAndSettle();

        // 點卡片本體是「把地圖飛到該地點」，不該離開探索頁——導頁只在
        // 箭頭鈕上發生。
        expect(extras, isEmpty);
      },
    );

    testWidgets('given nearby places, when the screen loads, '
        'then one map pin is rendered per place', (tester) async {
      await _givenExploreScreen(
        tester,
        places: [
          buildPlace(id: 'p1', name: 'Senso-ji'),
          buildPlace(id: 'p2', name: 'Meiji Shrine'),
        ],
      );

      expect(find.byType(PlaceMapPin), findsNWidgets(2));
    });

    group('location gate', () {
      testWidgets(
        'given permission is denied, when the screen loads, '
        'then the gate card shows the denied copy and the map cards rail is silent',
        (tester) async {
          await _givenExploreScreen(
            tester,
            locationService: FakeLocationService(
              error: LocationError.permissionDenied,
            ),
          );

          expect(
            find.text('explore.location_gate.permission_denied.title'),
            findsOneWidget,
          );
          // 底部卡片列不再吐原始錯誤字串。
          expect(find.textContaining('common.error_prefix'), findsNothing);
        },
      );

      testWidgets(
        'given permission is denied, when the action button is tapped and '
        'permission is granted, then requestPermission runs and places reload',
        (tester) async {
          final fake = FakeLocationService(
            error: LocationError.permissionDenied,
            grantOnRequest: true,
          );
          await _givenExploreScreen(tester, locationService: fake);

          final before = fake.getCurrentLocationCallCount;
          await tester.tap(
            find.text('explore.location_gate.permission_denied.action'),
          );
          await tester.pump(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));

          expect(fake.requestPermissionCallCount, 1);
          // grant=true 才會觸發 refresh，refresh 內部會再打一次 getCurrentLocation。
          expect(fake.getCurrentLocationCallCount, before + 1);
        },
      );

      testWidgets(
        'given permission is denied, when the action button is tapped and '
        'permission is not granted, then places do not reload',
        (tester) async {
          final fake = FakeLocationService(
            error: LocationError.permissionDenied,
            grantOnRequest: false,
          );
          await _givenExploreScreen(tester, locationService: fake);

          final before = fake.getCurrentLocationCallCount;
          await tester.tap(
            find.text('explore.location_gate.permission_denied.action'),
          );
          await tester.pump(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));

          expect(fake.requestPermissionCallCount, 1);
          // grant=false 時不應觸發 refresh，getCurrentLocation 呼叫次數不應增加。
          expect(fake.getCurrentLocationCallCount, before);
        },
      );

      testWidgets(
        'given permission is denied forever, when the action button is tapped, '
        'then the app settings page is opened',
        (tester) async {
          final fake = FakeLocationService(
            error: LocationError.permissionDeniedForever,
          );
          await _givenExploreScreen(tester, locationService: fake);

          await tester.tap(
            find.text('explore.location_gate.permission_denied_forever.action'),
          );
          await tester.pump(const Duration(milliseconds: 20));

          expect(fake.openAppSettingsCallCount, 1);
        },
      );

      testWidgets(
        'given location services are disabled, when the action button is '
        'tapped, then the location settings page is opened',
        (tester) async {
          final fake = FakeLocationService(
            error: LocationError.serviceDisabled,
          );
          await _givenExploreScreen(tester, locationService: fake);

          await tester.tap(
            find.text('explore.location_gate.service_disabled.action'),
          );
          await tester.pump(const Duration(milliseconds: 20));

          expect(fake.openLocationSettingsCallCount, 1);
        },
      );

      testWidgets('given a non-location error, when the screen loads, '
          'then no gate card is shown', (tester) async {
        await _givenExploreScreen(
          tester,
          locationService: FakeLocationService(error: Exception('boom')),
        );

        expect(
          find.text('explore.location_gate.permission_denied.title'),
          findsNothing,
        );
        expect(
          find.text('explore.location_gate.service_disabled.title'),
          findsNothing,
        );
      });
    });

    group('initial query', () {
      testWidgets('given an initial query, '
          'when the explore screen loads, '
          'then the places repository is searched with that query', (
        tester,
      ) async {
        final repo = FakePlacesRepository();

        await _givenExploreScreen(tester, repo: repo, initialQuery: '京都');

        expect(repo.lastSearchQuery, '京都');
      });
    });

    group('globe back button', () {
      testWidgets('given the explore screen pushed on top of home, '
          'when the user taps the globe button, '
          'then it pops back to the globe home', (tester) async {
        await _givenExploreScreenPushedOnMap(tester);

        // 點擊前先確認探索頁真的在畫面上——首頁的 Scaffold 從頭到尾都
        // 沒被卸載，光看它還在無法證明 pop 真的發生，必須看探索頁消失。
        expect(find.byType(ExploreScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('explore-globe-back')));
        await tester.pumpAndSettle();

        expect(find.byType(ExploreScreen), findsNothing);
        expect(find.byKey(const Key('home-screen')), findsOneWidget);
      });

      testWidgets('given the explore screen reached via go (no back stack), '
          'when the user taps the globe button, '
          'then it navigates to the globe home instead of throwing', (
        tester,
      ) async {
        // trip_empty_state 的「去探索」CTA 用 context.go('/map')，把整個
        // 路由堆疊換成只剩 /map 一頁——這裡重現那個狀態，canPop() 必須是
        // false，跟 _givenExploreScreenPushedOnMap 的 push 情境不同。
        await _givenExploreScreenReplacedHomeWithMap(tester);

        expect(find.byType(ExploreScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('explore-globe-back')));
        await tester.pumpAndSettle();

        expect(find.byType(ExploreScreen), findsNothing);
        expect(find.byKey(const Key('home-screen')), findsOneWidget);
      });
    });
  });
}

Future<void> _givenExploreScreen(
  WidgetTester tester, {
  List<Place> places = const [],
  FakePlacesRepository? repo,
  InMemorySavedLocationsRepository? savedRepo,
  double maxDistance = 10000.0,
  PlaceLocation? userLocation,
  FakeLocationService? locationService,
  String? initialQuery,
}) async {
  final fakeLocation =
      locationService ??
      FakeLocationService(
        location:
            userLocation ??
            const PlaceLocation(latitude: 25.0, longitude: 121.0),
      );
  await pumpScreen(
    tester,
    child: ExploreScreen(initialQuery: initialQuery),
    overrides: [
      locationServiceProvider.overrideWithValue(fakeLocation),
      placesRepositoryProvider.overrideWithValue(
        repo ?? FakePlacesRepository(nearbyPlaces: places),
      ),
      savedLocationsRepositoryProvider.overrideWithValue(
        savedRepo ?? InMemorySavedLocationsRepository(),
      ),
      maxDistanceProvider.overrideWith((ref) => maxDistance),
      dailyStoryRepositoryProvider.overrideWithValue(
        InMemoryDailyStoryRepository(),
      ),
      ...fakeMapStyleOverrides(),
    ],
  );
  // Let async searchNearby + filtered places provider resolve.
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await settleMapTimers(tester);
}

Future<void> _givenExploreScreenWithRouter(
  WidgetTester tester, {
  List<Place> places = const [],
  required void Function(Object? extra) onConfigPush,
}) async {
  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ExploreScreen()),
      GoRoute(
        name: 'config',
        path: '/config',
        builder: (_, state) {
          onConfigPush(state.extra);
          return const Scaffold(
            key: Key('config-screen'),
            body: SizedBox.shrink(),
          );
        },
      ),
    ],
    overrides: [
      locationServiceProvider.overrideWithValue(FakeLocationService()),
      placesRepositoryProvider.overrideWithValue(
        FakePlacesRepository(nearbyPlaces: places),
      ),
      savedLocationsRepositoryProvider.overrideWithValue(
        InMemorySavedLocationsRepository(),
      ),
      dailyStoryRepositoryProvider.overrideWithValue(
        InMemoryDailyStoryRepository(),
      ),
      ...fakeMapStyleOverrides(),
    ],
  );
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await settleMapTimers(tester);
}

/// 從首頁 push 到 `/map` 上的探索頁——地球儀返回鈕測試要有東西可以 pop
/// 回去，不能像其他測試一樣把 [ExploreScreen] 直接當成初始路由。
Future<void> _givenExploreScreenPushedOnMap(WidgetTester tester) async {
  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(key: Key('home-screen')),
      ),
      GoRoute(path: '/map', builder: (_, __) => const ExploreScreen()),
    ],
    overrides: [
      locationServiceProvider.overrideWithValue(FakeLocationService()),
      placesRepositoryProvider.overrideWithValue(FakePlacesRepository()),
      savedLocationsRepositoryProvider.overrideWithValue(
        InMemorySavedLocationsRepository(),
      ),
      dailyStoryRepositoryProvider.overrideWithValue(
        InMemoryDailyStoryRepository(),
      ),
      ...fakeMapStyleOverrides(),
    ],
  );

  final context = tester.element(find.byKey(const Key('home-screen')));
  GoRouter.of(context).push('/map');
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await settleMapTimers(tester);
}

/// 用 `go('/map')` 把首頁換掉，模擬 `trip_empty_state` 的「去探索」CTA——
/// 換完之後路由堆疊只剩 `/map`，沒有東西可以 pop 回去。
Future<void> _givenExploreScreenReplacedHomeWithMap(WidgetTester tester) async {
  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(key: Key('home-screen')),
      ),
      GoRoute(path: '/map', builder: (_, __) => const ExploreScreen()),
    ],
    overrides: [
      locationServiceProvider.overrideWithValue(FakeLocationService()),
      placesRepositoryProvider.overrideWithValue(FakePlacesRepository()),
      savedLocationsRepositoryProvider.overrideWithValue(
        InMemorySavedLocationsRepository(),
      ),
      dailyStoryRepositoryProvider.overrideWithValue(
        InMemoryDailyStoryRepository(),
      ),
      ...fakeMapStyleOverrides(),
    ],
  );

  final context = tester.element(find.byKey(const Key('home-screen')));
  GoRouter.of(context).go('/map');
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await settleMapTimers(tester);
}

void _thenEmptyStateIsVisible() {
  expect(find.text('explore.empty'), findsOneWidget);
}

void _thenPlaceNamesAreVisible(List<String> names) {
  for (final name in names) {
    expect(find.text(name), findsOneWidget);
  }
}

void _thenPlaceNamesAreHidden(List<String> names) {
  for (final name in names) {
    expect(find.text(name), findsNothing);
  }
}

/// 用 Key 找篩選鈕上的小圓點。
///
/// 不要用「畫面上任何有顏色的圓形 Container」當條件——地圖 pin 與卡片上的
/// 前往鈕都符合，會讓「沒有小圓點」的測試假性通過。
Finder _activeDotFinder() => find.byKey(const Key('explore-filter-active-dot'));
