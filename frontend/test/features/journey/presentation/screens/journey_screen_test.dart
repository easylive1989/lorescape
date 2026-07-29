import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/presentation/screens/journey_screen.dart';
import 'package:context_app/features/journey/presentation/widgets/trip_bookshelf.dart';
import 'package:context_app/features/journey/providers.dart';
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
      'given a trip on the shelf under a router, when its book is tapped, '
      'then the trip detail route is pushed',
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

    testWidgets(
      'given the by-trip shelf under a router, when the user taps the empty '
      'placeholder book, then the trip-edit route is pushed',
      (tester) async {
        await _givenJourneyScreenWithRouter(tester);

        // 建立旅程的入口只有書架上那本佔位書，頁首不再有 +。
        expect(
          find.descendant(
            of: find.byType(TripBookshelf),
            matching: find.byIcon(Icons.add),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.add), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add));
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

/// 書架上的一本「真書」（旅程），不含末端那本虛線佔位書。
///
/// 書名是直排（逐字換行）的，用 `find.text` 找不到，所以改抓語意上的按鈕；
/// 佔位書同樣是語意按鈕，靠它固定的 label 排除。
Finder _bookFinder() => find.descendant(
  of: find.byType(TripBookshelf),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        widget.properties.label != 'trip.create_action',
  ),
);
