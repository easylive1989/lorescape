import 'package:context_app/features/journey/domain/globe/world_outline.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/journey/presentation/screens/journey_screen.dart';
import 'package:context_app/features/journey/presentation/widgets/globe_view.dart';
import 'package:context_app/features/journey/presentation/widgets/trip_bookshelf.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/presentation/controllers/current_trip_notifier.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fakes/in_memory_journey_repository.dart';
import '../../../../fakes/in_memory_trip_repository.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_data.dart';

/// 地球儀的輪廓資料在測試裡不必是真的世界地圖，一個方框就夠了——書架頁的
/// 斷言都在釘點上，輪廓只是為了讓 `worldOutlineProvider` 立刻有值。
final _outline = WorldOutline.parse('{"rings":[[0,0,10,0,10,10,0,10]]}');

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('JourneyScreen', () {
    testWidgets('given no trips at all, when the shelf loads, '
        'then the uncategorized volume is still on the shelf', (tester) async {
      await _givenJourneyScreen(tester);

      // 一本都沒有時書架不能整個空掉——未分類永遠有自己的一本。
      expect(find.byType(TripBookshelf), findsOneWidget);
      expect(_bookFinder(), findsOneWidget);
    });

    testWidgets(
      'given saved trips and no loose entries, when the shelf loads, '
      'then one volume per trip is shown and the uncategorized one is hidden',
      (tester) async {
        await _givenJourneyScreen(
          tester,
          seededTrips: [
            buildTrip(id: 't1', name: '京都'),
            buildTrip(id: 't2', name: '大阪'),
          ],
        );

        expect(_bookFinder(), findsNWidgets(2));
      },
    );

    testWidgets('given entries that belong to no trip, when the shelf loads, '
        'then the uncategorized volume appears alongside the trips', (
      tester,
    ) async {
      await _givenJourneyScreen(
        tester,
        seededTrips: [buildTrip(id: 't1', name: '京都')],
        seededJourneys: [buildJourneyEntry(id: 'e1')],
      );

      expect(_bookFinder(), findsNWidgets(2));
    });

    testWidgets(
      'given the only trip on the shelf, which is therefore already selected, '
      'when its book is tapped, then the trip detail route is pushed',
      (tester) async {
        final pushed = <String>[];

        await _givenJourneyScreenWithRouter(
          tester,
          seededTrips: [buildTrip(id: 't1', name: '京都')],
          onTripPush: pushed.add,
        );

        await tester.tap(_bookFinder().last);
        await tester.pumpAndSettle();

        expect(pushed.single, equals('t1'));
      },
    );

    testWidgets('given a selected trip whose entries have coordinates, '
        'when the shelf screen renders, '
        'then the globe pins those stops', (tester) async {
      await _givenJourneyScreen(
        tester,
        seededTrips: [buildTrip(id: 't1', name: '義大利')],
        seededJourneys: [
          journeyEntryWithCoords(tripId: 't1', lat: 40.7497, lng: 14.4869),
          journeyEntryWithCoords(tripId: 't1', lat: 41.9028, lng: 12.4964),
        ],
      );

      final globe = tester.widget<GlobeView>(find.byType(GlobeView));
      expect(globe.pins, hasLength(2));
    });

    testWidgets('given entries without coordinates, '
        'when the shelf screen renders, '
        'then the globe shows no pins instead of pinning zero-zero', (
      tester,
    ) async {
      await _givenJourneyScreen(
        tester,
        seededTrips: [buildTrip(id: 't1', name: '義大利')],
        seededJourneys: [journeyEntryWithoutCoords(tripId: 't1')],
      );

      final globe = tester.widget<GlobeView>(find.byType(GlobeView));
      expect(globe.pins, isEmpty);
    });

    testWidgets('given two trips on the shelf, '
        'when the user taps the book that is not selected, '
        'then the globe repins to that trip and nothing is opened', (
      tester,
    ) async {
      final pushed = <String>[];

      await _givenJourneyScreenWithRouter(
        tester,
        seededTrips: [
          buildTrip(id: 't1', name: '京都', createdAt: DateTime(2024, 2)),
          buildTrip(id: 't2', name: '大阪', createdAt: DateTime(2024, 1)),
        ],
        seededJourneys: [
          journeyEntryWithCoords(
            tripId: 't1',
            lat: 35.0116,
            lng: 135.7681,
            name: '清水寺',
          ),
          journeyEntryWithCoords(
            tripId: 't2',
            lat: 34.6873,
            lng: 135.5259,
            name: '大阪城',
          ),
        ],
        onTripPush: pushed.add,
      );
      expect(
        tester.widget<GlobeView>(find.byType(GlobeView)).pins.single.label,
        '清水寺',
      );

      await tester.tap(_bookNamed('大阪'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<GlobeView>(find.byType(GlobeView)).pins.single.label,
        '大阪城',
      );
      expect(pushed, isEmpty, reason: '第一下只是換選，不該把旅程打開');
    });

    testWidgets('given a book the user has just selected, '
        'when they tap it a second time, '
        'then the trip detail route is pushed', (tester) async {
      final pushed = <String>[];

      await _givenJourneyScreenWithRouter(
        tester,
        seededTrips: [
          buildTrip(id: 't1', name: '京都', createdAt: DateTime(2024, 2)),
          buildTrip(id: 't2', name: '大阪', createdAt: DateTime(2024, 1)),
        ],
        onTripPush: pushed.add,
      );

      await tester.tap(_bookNamed('大阪'));
      await tester.pumpAndSettle();
      await tester.tap(_bookNamed('大阪'));
      await tester.pumpAndSettle();

      expect(pushed.single, equals('t2'));
    });

    testWidgets('given loose entries so the uncategorized volume is selected, '
        'when the user taps it again, '
        'then the uncategorized route is pushed', (tester) async {
      final pushed = <String>[];

      await _givenJourneyScreenWithRouter(
        tester,
        seededJourneys: [journeyEntryWithoutCoords(tripId: null)],
        onTripPush: pushed.add,
      );

      await tester.tap(_bookNamed('trip.uncategorized'));
      await tester.pumpAndSettle();

      expect(pushed.single, equals('uncategorized'));
    });

    testWidgets('given a selected volume, when the shelf loads, '
        'then the hint below the shelf tells the user to tap again', (
      tester,
    ) async {
      await _givenJourneyScreen(
        tester,
        seededTrips: [buildTrip(id: 't1', name: '京都')],
      );

      expect(find.text('journey.shelf_hint'), findsOneWidget);
    });

    testWidgets(
      'given the by-trip shelf under a router, when the user taps the '
      'new-journey pill, then the trip-edit route is pushed',
      (tester) async {
        await _givenJourneyScreenWithRouter(tester);

        // 建立旅程只有書架標頭列那顆 pill 一個入口：頁首沒有 +，架上也不再
        // 有那本虛線佔位書。
        final pill = find.descendant(
          of: find.byType(TripBookshelf),
          matching: find.text('＋ journey.shelf_new'),
        );
        expect(pill, findsOneWidget);
        expect(find.byIcon(Icons.add), findsNothing);

        await tester.tap(pill);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('edit-screen')), findsOneWidget);
      },
    );

    testWidgets('given a current trip is set, when the shelf loads, '
        'then the current-trip banner is shown above the shelf', (
      tester,
    ) async {
      await _givenJourneyScreen(
        tester,
        seededTrips: [buildTrip(id: 't1', name: '京都')],
        currentTripIdInitial: 't1',
      );

      expect(find.text('trip.current_badge'), findsOneWidget);
    });

    testWidgets('given the journey screen pushed from home, '
        'when the user taps the back button, '
        'then it returns to the previous screen', (tester) async {
      final overrides = await _buildJourneyOverrides();

      await pumpRouterApp(
        tester,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(key: Key('home-screen')),
          ),
          GoRoute(path: '/journey', builder: (_, __) => const JourneyScreen()),
        ],
        overrides: overrides,
      );
      final context = tester.element(find.byKey(const Key('home-screen')));
      GoRouter.of(context).push('/journey');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-screen')), findsNothing);
      expect(find.byType(JourneyScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('floating-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-screen')), findsOneWidget);
      expect(find.byType(JourneyScreen), findsNothing);
    });
  });
}

Future<void> _givenJourneyScreen(
  WidgetTester tester, {
  List<JourneyEntry> seededJourneys = const [],
  List<Trip> seededTrips = const [],
  String? currentTripIdInitial,
}) async {
  final overrides = await _buildJourneyOverrides(
    seededJourneys: seededJourneys,
    seededTrips: seededTrips,
    currentTripIdInitial: currentTripIdInitial,
  );

  await pumpScreen(tester, child: const JourneyScreen(), overrides: overrides);
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _givenJourneyScreenWithRouter(
  WidgetTester tester, {
  List<JourneyEntry> seededJourneys = const [],
  List<Trip> seededTrips = const [],
  void Function(String tripId)? onTripPush,
}) async {
  final overrides = await _buildJourneyOverrides(
    seededJourneys: seededJourneys,
    seededTrips: seededTrips,
  );

  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const JourneyScreen()),
      GoRoute(
        path: '/trip/edit',
        builder: (_, __) =>
            const Scaffold(key: ValueKey('edit-screen'), body: Text('edit')),
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (_, state) {
          onTripPush?.call(state.pathParameters['id']!);
          return const Scaffold(
            key: ValueKey('trip-screen'),
            body: SizedBox.shrink(),
          );
        },
      ),
    ],
    overrides: overrides,
  );
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

Future<List<Override>> _buildJourneyOverrides({
  List<JourneyEntry> seededJourneys = const [],
  List<Trip> seededTrips = const [],
  String? currentTripIdInitial,
}) async {
  final journeyRepo = InMemoryJourneyRepository();
  for (final entry in seededJourneys) {
    await journeyRepo.save(entry);
  }
  final tripRepo = InMemoryTripRepository();
  for (final trip in seededTrips) {
    await tripRepo.save(trip);
  }

  return [
    journeyRepositoryProvider.overrideWithValue(journeyRepo),
    tripRepositoryProvider.overrideWithValue(tripRepo),
    // 同步給值，地球儀第一幀就畫得出來（真的 provider 要讀 asset）。
    worldOutlineProvider.overrideWith((ref) => _outline),
    if (currentTripIdInitial != null)
      currentTripIdProvider.overrideWith(
        () => _StaticCurrentTripIdNotifier(currentTripIdInitial),
      ),
  ];
}

class _StaticCurrentTripIdNotifier extends CurrentTripIdNotifier {
  _StaticCurrentTripIdNotifier(this._initial);

  final String? _initial;

  @override
  String? build() => _initial;
}

/// 有座標的停點記錄。
///
/// id 與地點名沒給就從座標推，讓「只給經緯度」的呼叫也不會在 in-memory
/// repository（用 id 當 key）裡互相覆蓋。
JourneyEntry journeyEntryWithCoords({
  required String? tripId,
  required double lat,
  required double lng,
  String? name,
}) {
  final label = name ?? '$lat,$lng';
  final createdAt = DateTime(2024, 1, 2, 10);
  return JourneyEntry(
    id: 'entry-$label',
    place: SavedPlace(
      id: 'place-$label',
      name: label,
      address: '$label 的地址',
      latitude: lat,
      longitude: lng,
    ),
    narrationContent: buildNarrationContent(),
    createdAt: createdAt,
    updatedAt: createdAt,
    language: Language.english,
    tripId: tripId,
  );
}

/// 沒座標的舊記錄（20260819000000 migration 之前存的那些）。
JourneyEntry journeyEntryWithoutCoords({
  required String? tripId,
  String id = 'entry-legacy',
}) => buildJourneyEntry(id: id, tripId: tripId);

/// 書架上的一本「真書」（旅程），不含末端那本虛線佔位書與標頭列的新增按鈕。
///
/// 書名是直排（逐字換行）的，用 `find.text` 找不到，所以改抓語意上的按鈕；
/// 只有真書的 label 是「書名｜篇數」，靠那個分隔號認。
Finder _bookFinder() => _bookWhere((label) => label.contains('｜'));

/// 架上書名為 [title] 的那一本。
Finder _bookNamed(String title) => _bookWhere(
  (label) => label.startsWith('$title｜'),
);

Finder _bookWhere(bool Function(String label) matches) => find.descendant(
  of: find.byType(TripBookshelf),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        matches(widget.properties.label ?? ''),
  ),
);
