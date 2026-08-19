import 'package:context_app/features/daily_story/providers.dart';
import 'package:context_app/features/explore/domain/errors/location_error.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/explore/presentation/screens/explore_screen.dart';
import 'package:context_app/features/explore/presentation/widgets/place_map_pin.dart';
import 'package:context_app/features/explore/providers.dart';
import 'package:context_app/shared/widgets/journal/masthead.dart';
import 'package:context_app/shared/widgets/journal/search_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fakes/fake_location_service.dart';
import '../../../../fakes/fake_places_repository.dart';
import '../../../../fakes/in_memory_daily_story_repository.dart';
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

    testWidgets('given place cards are shown, '
        'when the attribution badge is rendered, '
        'then the badge sits below the card rail and clear of the cards', (
      tester,
    ) async {
      await _givenExploreScreen(
        tester,
        places: [buildPlace(id: 'p1', name: 'Senso-ji')],
      );

      // 角標放卡片列下方的縫隙（見 explore_screen.dart 的幾何註解）。這裡
      // 驗實際幾何：卡片的下緣必須在角標上緣之上——署名被蓋掉等同沒有署名
      // （見 ADR 0005）。
      final badgeTop = tester
          .getRect(
            find.text('OpenFreeMap © OpenMapTiles Data from OpenStreetMap'),
          )
          .top;
      final card = find
          .ancestor(
            of: _cardText('Senso-ji'),
            matching: find.byType(Container),
          )
          .first;
      expect(badgeTop, greaterThanOrEqualTo(tester.getRect(card).bottom));
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

      expect(_cardText('Searched Place'), findsOneWidget);
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
        expect(_cardText('Nearby Place'), findsOneWidget);
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

    testWidgets('given the map is showing an area, '
        'when the user taps refresh, '
        'then the search is centred on the map and its radius is clamped into '
        'the allowed band', (tester) async {
      final repo = FakePlacesRepository(
        nearbyPlaces: [buildPlace(id: 'p1', name: 'Nearby')],
      );

      await _givenExploreScreen(tester, repo: repo);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      // 距離篩選已移除：改成以地圖中心 ＋ 可視範圍搜尋。半徑一定落在
      // [下限, Wikipedia geosearch 的 API 上限] 之間。
      expect(repo.lastNearbyCenter, isNotNull);
      expect(
        repo.lastNearbyRadius,
        inInclusiveRange(kMinSearchRadiusMeters, kMaxSearchRadiusMeters),
      );
    });

    testWidgets('given the explore screen is shown, '
        'when looking at the top bar, '
        'then the shelf, settings and refresh buttons are all present',
        (tester) async {
      await _givenExploreScreen(tester);

      expect(find.byKey(const Key('explore-open-shelf')), findsOneWidget);
      expect(find.byKey(const Key('explore-open-settings')), findsOneWidget);
      expect(find.byKey(const Key('explore-refresh')), findsOneWidget);
    });

    testWidgets('given location permission is denied, '
        'when the user taps refresh, '
        'then the area search still runs so the gate card is not a dead end', (
      tester,
    ) async {
      final repo = FakePlacesRepository(
        nearbyPlaces: [buildPlace(id: 'p1', name: 'Nearby')],
      );

      await _givenExploreScreen(
        tester,
        repo: repo,
        locationService: FakeLocationService(
          location: const PlaceLocation(latitude: 25.0, longitude: 121.0),
          error: LocationError.permissionDenied,
        ),
      );
      final before = repo.nearbyCallCount;

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      // searchArea 用地圖中心、不問 LocationService，所以沒有定位權限也
      // 走得下去——location gate 因此只是提示，不是死路。
      expect(repo.nearbyCallCount, greaterThan(before));
      expect(repo.lastNearbyCenter, isNotNull);
    });

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

        await tester.tap(_cardText('Senso-ji'));
        await tester.pumpAndSettle();

        // 點卡片本體是「把地圖飛到該地點」，不該離開探索頁——導頁只在
        // 箭頭鈕上發生。
        expect(extras, isEmpty);
      },
    );

    testWidgets('given nearby places, when the screen loads, '
        'then one map pin is rendered per place, '
        'each with its name chip shown without needing focus', (tester) async {
      await _givenExploreScreen(
        tester,
        places: [
          buildPlace(id: 'p1', name: 'Senso-ji'),
          buildPlace(id: 'p2', name: 'Meiji Shrine'),
        ],
      );

      expect(find.byType(PlaceMapPin), findsNWidgets(2));
      expect(_markerLabel('Senso-ji'), findsOneWidget);
      expect(_markerLabel('Meiji Shrine'), findsOneWidget);
    });

    testWidgets(
      'given a map pin under a router, when its name chip is tapped, '
      'then the config route is pushed with the place as extra',
      (tester) async {
        final extras = <Object?>[];

        await _givenExploreScreenWithRouter(
          tester,
          places: [buildPlace(id: 'p1', name: 'Senso-ji')],
          onConfigPush: extras.add,
        );

        await tester.tap(_markerLabel('Senso-ji'));
        await tester.pumpAndSettle();

        expect(extras.single, isA<Place>());
        expect((extras.single as Place).id, equals('p1'));
      },
    );

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

    group('search loader', () {
      testWidgets(
        'given a slow search, when the user submits a query, '
        'then the centred loader shows the searching copy with the query, '
        'and disappears once results arrive',
        (tester) async {
          final repo = FakePlacesRepository(
            nearbyPlaces: [buildPlace(id: 'p1', name: 'Nearby Place')],
            searchResults: [buildPlace(id: 's1', name: 'Searched Place')],
          );
          await _givenExploreScreen(tester, repo: repo);
          repo.delay = const Duration(milliseconds: 400);

          await tester.enterText(find.byType(TextField), '京都');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pump(const Duration(milliseconds: 20));

          expect(find.byType(SearchLoader), findsOneWidget);
          expect(find.text('explore.searching'), findsOneWidget);
          expect(
            tester
                .widget<Text>(find.byKey(const Key('search-loader-name')))
                .data,
            '京都',
          );

          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(SearchLoader), findsNothing);
          expect(_cardText('Searched Place'), findsOneWidget);
        },
      );

      testWidgets(
        'given a slow nearby lookup, when the screen is still loading, '
        'then the loader shows the locating copy without a place name',
        (tester) async {
          final repo = FakePlacesRepository(
            nearbyPlaces: [buildPlace(id: 'p1', name: 'Nearby Place')],
          )..delay = const Duration(milliseconds: 400);

          // 不走 _givenExploreScreen：它會把載入整段 pump 完，看不到
          // 載入中的畫面。
          await pumpScreen(
            tester,
            child: const ExploreScreen(),
            overrides: [
              locationServiceProvider.overrideWithValue(
                FakeLocationService(
                  location: const PlaceLocation(
                    latitude: 25.0,
                    longitude: 121.0,
                  ),
                ),
              ),
              placesRepositoryProvider.overrideWithValue(repo),
              dailyStoryRepositoryProvider.overrideWithValue(
                InMemoryDailyStoryRepository(),
              ),
              ...fakeMapStyleOverrides(),
            ],
          );
          await tester.pump(const Duration(milliseconds: 20));

          expect(find.byType(SearchLoader), findsOneWidget);
          expect(find.textContaining('explore.locating'), findsOneWidget);
          expect(find.byKey(const Key('search-loader-name')), findsNothing);

          // 把延遲與地圖排程的 timer 跑完，避免 tear-down 抱怨 Timer 未結束。
          await tester.pump(const Duration(milliseconds: 500));
          await settleMapTimers(tester);
        },
      );

      testWidgets(
        'given places on screen, when the user taps refresh, '
        'then the loader shows the searching copy while the area search runs',
        (tester) async {
          final repo = FakePlacesRepository(
            nearbyPlaces: [buildPlace(id: 'p1', name: 'Nearby')],
          );
          await _givenExploreScreen(tester, repo: repo);
          repo.delay = const Duration(milliseconds: 400);

          await tester.tap(find.byIcon(Icons.refresh));
          await tester.pump(const Duration(milliseconds: 20));

          // 以可視範圍重搜不是定位，所以是「搜尋地點中」而不是「定位中」，
          // 而且沒有關鍵字可以顯示。
          expect(find.byType(SearchLoader), findsOneWidget);
          expect(find.textContaining('explore.searching'), findsOneWidget);
          expect(find.byKey(const Key('search-loader-name')), findsNothing);

          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(SearchLoader), findsNothing);
        },
      );
    });

  });
}

Future<void> _givenExploreScreen(
  WidgetTester tester, {
  List<Place> places = const [],
  FakePlacesRepository? repo,
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
      dailyStoryRepositoryProvider.overrideWithValue(
        InMemoryDailyStoryRepository(),
      ),
      ...fakeMapStyleOverrides(),
    ],
  );
  // Let the async nearby search resolve.
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

void _thenEmptyStateIsVisible() {
  expect(find.text('explore.empty'), findsOneWidget);
}

/// 地名同時出現在底部卡片與地圖 marker 的地名 chip 上；這裡限定在卡片列
/// （唯一的 ListView）底下找，才不會誤數到 marker 的標籤。
Finder _cardText(String name) =>
    find.descendant(of: find.byType(ListView), matching: find.text(name));

/// 地圖 marker 地名 chip 上的文字。
Finder _markerLabel(String name) => find.descendant(
  of: find.byType(LabeledPlaceMapPin),
  matching: find.text(name),
);

void _thenPlaceNamesAreVisible(List<String> names) {
  for (final name in names) {
    expect(_cardText(name), findsOneWidget);
  }
}

/// 用 Key 找篩選鈕上的小圓點。
///
/// 不要用「畫面上任何有顏色的圓形 Container」當條件——地圖 pin 與卡片上的
/// 前往鈕都符合，會讓「沒有小圓點」的測試假性通過。
