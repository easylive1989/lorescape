import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/presentation/controllers/current_trip_notifier.dart';
import 'package:context_app/features/trip/presentation/screens/trip_detail_screen.dart';
import 'package:context_app/features/trip/presentation/widgets/trip_empty_state.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:context_app/shared/widgets/journal/notebook_pager.dart';
import 'package:flutter/material.dart';
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

  group('TripDetailScreen', () {
    testWidgets('given a trip with entries, when the detail screen loads, '
        'then the trip name and each timeline entry are rendered', (
      tester,
    ) async {
      final trip = buildTrip(id: 'kyoto', name: 'Kyoto Temples');
      final entry = buildJourneyEntry(id: 'e1', tripId: 'kyoto');

      await _givenTripDetailScreen(
        tester,
        tripId: 'kyoto',
        seededTrips: [trip],
        seededJourneys: [entry],
      );

      _thenTripNameIsVisible('Kyoto Temples');
      _thenNotebookPagerIsShown();
      // 手記本身帶三顆動作；重聽鍵是筆記標題右側的 icon 圓鈕。
      expect(find.text('trip.add_to_trip'), findsOneWidget);
      expect(find.text('common.share'), findsOneWidget);
      expect(find.text('common.delete'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets(
      'given a trip entry in reading mode, when the user taps add-to-trip, '
      'then the move-to-trip sheet opens',
      (tester) async {
        final trip = buildTrip(id: 'kyoto', name: 'Kyoto Temples');
        final entry = buildJourneyEntry(id: 'e1', tripId: 'kyoto');
        final tripRepo = InMemoryTripRepository();
        final journeyRepo = InMemoryJourneyRepository();
        await tripRepo.save(trip);
        await journeyRepo.save(entry);

        await _givenTripDetailScreenWithRouter(
          tester,
          tripId: 'kyoto',
          tripRepo: tripRepo,
          journeyRepo: journeyRepo,
        );

        await tester.tap(find.text('trip.add_to_trip'));
        await tester.pumpAndSettle();

        expect(find.text('trip.uncategorized'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'given a trip entry in reading mode, when the user confirms delete, '
      'then the entry is removed from the repository',
      (tester) async {
        final trip = buildTrip(id: 'kyoto', name: 'Kyoto Temples');
        final entry = buildJourneyEntry(id: 'e1', tripId: 'kyoto');
        final tripRepo = InMemoryTripRepository();
        final journeyRepo = InMemoryJourneyRepository();
        await tripRepo.save(trip);
        await journeyRepo.save(entry);

        await _givenTripDetailScreenWithRouter(
          tester,
          tripId: 'kyoto',
          tripRepo: tripRepo,
          journeyRepo: journeyRepo,
        );

        await tester.tap(find.text('common.delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('journey.delete_confirm'));
        await tester.pumpAndSettle();

        expect(await journeyRepo.getAll(), isEmpty);
      },
    );

    testWidgets(
      'given a trip entry in reading mode, when the user taps replay, '
      'then the player route receives that entry place, narration and autoplay',
      (tester) async {
        final trip = buildTrip(id: 'kyoto', name: 'Kyoto Temples');
        final entry = buildJourneyEntry(
          id: 'e1',
          tripId: 'kyoto',
          place: buildPlace(name: 'Kinkaku-ji', address: '1 Kinkakujicho'),
        );
        final tripRepo = InMemoryTripRepository();
        final journeyRepo = InMemoryJourneyRepository();
        await tripRepo.save(trip);
        await journeyRepo.save(entry);
        final playerExtras = <Object?>[];

        await _givenTripDetailScreenWithRouter(
          tester,
          tripId: 'kyoto',
          tripRepo: tripRepo,
          journeyRepo: journeyRepo,
          playerExtras: playerExtras,
        );

        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pumpAndSettle();

        final extra = playerExtras.single as Map<String, dynamic>;
        expect((extra['place'] as Place).name, 'Kinkaku-ji');
        expect((extra['place'] as Place).address, '1 Kinkakujicho');
        expect(extra['narrationContent'], entry.narrationContent);
        // 按下「重聽」本身就是要聽，不該再多按一次播放鍵。
        expect(extra['autoPlay'], isTrue);
      },
    );

    testWidgets('given a trip with no entries, when the detail screen loads, '
        'then the empty state is rendered', (tester) async {
      final trip = buildTrip(id: 'empty', name: 'Empty Trip');

      await _givenTripDetailScreen(
        tester,
        tripId: 'empty',
        seededTrips: [trip],
      );

      _thenEmptyStateIsVisible();
    });

    testWidgets(
      'given a trip pushed from home with no entries, when the user taps '
      'the explore CTA, then the app lands on the explore tab and the trip '
      'is not left on the back stack',
      (tester) async {
        final trip = buildTrip(id: 'empty', name: 'Empty Trip');
        final tripRepo = InMemoryTripRepository();
        final journeyRepo = InMemoryJourneyRepository();
        await tripRepo.save(trip);
        final visitedLocations = <String>[];

        await _givenTripDetailScreenWithRouter(
          tester,
          tripId: 'empty',
          tripRepo: tripRepo,
          journeyRepo: journeyRepo,
          visitedLocations: visitedLocations,
        );

        final before = visitedLocations.length;

        await tester.tap(find.text('trip.empty_cta'));
        await tester.pumpAndSettle();

        // 落點是首頁（探索地圖）：初始渲染已經記過一次 '/'，這裡確認 CTA
        // 之後又重新落在 '/' 一次，不是原本那次殘留的記錄。
        expect(visitedLocations.length, greaterThan(before));
        expect(visitedLocations.last, '/');
        // 用 go 而非 push：確認旅程路由被取代，返回堆疊裡沒留下它——若退回
        // push，這裡會變成能 pop。
        final homeContext = tester.element(
          find.byKey(const ValueKey('home-screen')),
        );
        expect(Navigator.canPop(homeContext), isFalse);
      },
    );

    testWidgets('given the uncategorized bucket, when the screen loads, '
        'then the uncategorized title and checklist action are shown', (
      tester,
    ) async {
      final orphan = buildJourneyEntry(id: 'o1');

      await _givenTripDetailScreen(
        tester,
        tripId: null,
        seededJourneys: [orphan],
      );

      _thenUncategorizedTitleIsVisible();
      _thenSelectionModeIsAvailable();
    });

    testWidgets(
      'given uncategorized entries, when the user enters selection mode, '
      'then the selection header replaces the default app bar',
      (tester) async {
        final orphan = buildJourneyEntry(id: 'o1');

        await _givenTripDetailScreen(
          tester,
          tripId: null,
          seededJourneys: [orphan],
        );
        await _whenUserEntersSelectionMode(tester);

        _thenSelectionHeaderIsVisible();
      },
    );

    testWidgets('given selection mode, when the user taps an entry, '
        'then that entry is marked with a check icon', (tester) async {
      final a = buildJourneyEntry(id: 'a');
      final b = buildJourneyEntry(id: 'b');

      await _givenTripDetailScreen(
        tester,
        tripId: null,
        seededJourneys: [a, b],
      );
      await _whenUserEntersSelectionMode(tester);

      await tester.tap(find.byKey(const ValueKey('a')));
      await tester.pump();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('given selection mode, when the user taps Select all, '
        'then every entry becomes selected', (tester) async {
      final a = buildJourneyEntry(id: 'a');
      final b = buildJourneyEntry(id: 'b');

      await _givenTripDetailScreen(
        tester,
        tripId: null,
        seededJourneys: [a, b],
      );
      await _whenUserEntersSelectionMode(tester);

      await tester.tap(find.text('trip.select_all'));
      await tester.pump();

      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });

    testWidgets('given selection mode, when the user taps the close icon, '
        'then the screen returns to the default app bar', (tester) async {
      final orphan = buildJourneyEntry(id: 'o1');

      await _givenTripDetailScreen(
        tester,
        tripId: null,
        seededJourneys: [orphan],
      );
      await _whenUserEntersSelectionMode(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('trip.selected_count'), findsNothing);
      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });

    testWidgets('given a trip with start and end dates, when the screen loads, '
        'then the meta header shows a formatted date range', (tester) async {
      final trip = buildTrip(
        id: 'kyoto',
        name: 'Kyoto Temples',
        startDate: DateTime(2024, 5, 1),
        endDate: DateTime(2024, 5, 3),
      );

      await _givenTripDetailScreen(
        tester,
        tripId: 'kyoto',
        seededTrips: [trip],
      );

      expect(find.byIcon(Icons.event), findsOneWidget);
      // Contains an en-dash between two formatted dates.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains(' – ') ?? false),
        ),
        findsOneWidget,
      );
    });

    testWidgets('given a named trip, when the user opens the menu, '
        'then all trip actions are listed', (tester) async {
      final trip = buildTrip(id: 'kyoto', name: 'Kyoto');

      await _givenTripDetailScreen(
        tester,
        tripId: 'kyoto',
        seededTrips: [trip],
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('trip.set_as_current'), findsOneWidget);
      expect(find.text('trip.edit_action'), findsOneWidget);
      expect(find.text('export.menu_item'), findsOneWidget);
      expect(find.text('trip.delete_action'), findsOneWidget);
    });

    testWidgets(
      'given this trip is the current trip, when the user opens the menu, '
      'then the set-current action is labelled as end-current',
      (tester) async {
        final trip = buildTrip(id: 'kyoto', name: 'Kyoto');

        await _givenTripDetailScreen(
          tester,
          tripId: 'kyoto',
          seededTrips: [trip],
          currentTripIdInitial: 'kyoto',
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('trip.end_current'), findsOneWidget);
        expect(find.text('trip.set_as_current'), findsNothing);
      },
    );

    testWidgets('given the trip menu is open, when the user taps Delete, '
        'then the delete-confirmation dialog appears', (tester) async {
      final trip = buildTrip(id: 'kyoto', name: 'Kyoto');

      await _givenTripDetailScreen(
        tester,
        tripId: 'kyoto',
        seededTrips: [trip],
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('trip.delete_action'));
      await tester.pumpAndSettle();

      expect(find.text('trip.delete_title'), findsOneWidget);
      expect(find.text('trip.delete_message'), findsOneWidget);
      expect(find.text('trip.delete_confirm'), findsOneWidget);
      expect(find.text('trip.cancel'), findsOneWidget);
    });

    testWidgets('given the delete dialog is open, when the user cancels, '
        'then the trip remains in the repository', (tester) async {
      final trip = buildTrip(id: 'kyoto', name: 'Kyoto');
      final tripRepo = InMemoryTripRepository();
      await tripRepo.save(trip);

      await _givenTripDetailScreenWithRepos(
        tester,
        tripId: 'kyoto',
        tripRepo: tripRepo,
        journeyRepo: InMemoryJourneyRepository(),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('trip.delete_action'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('trip.cancel'));
      await tester.pumpAndSettle();

      expect(await tripRepo.getById('kyoto'), isNotNull);
    });

    testWidgets('given the trip menu is open under a router, '
        'when the user confirms delete, '
        'then the trip is removed and the screen pops', (tester) async {
      final trip = buildTrip(id: 'kyoto', name: 'Kyoto');
      final entry = buildJourneyEntry(id: 'e1', tripId: 'kyoto');
      final tripRepo = InMemoryTripRepository();
      final journeyRepo = InMemoryJourneyRepository();
      await tripRepo.save(trip);
      await journeyRepo.save(entry);

      await _givenTripDetailScreenWithRouter(
        tester,
        tripId: 'kyoto',
        tripRepo: tripRepo,
        journeyRepo: journeyRepo,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('trip.delete_action'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('trip.delete_confirm'));
      await tester.pumpAndSettle();

      expect(await tripRepo.getById('kyoto'), isNull);
      // Orphaned journey entry's tripId is cleared to null.
      final remaining = await journeyRepo.getAll();
      expect(remaining.single.tripId, isNull);
      // The screen popped back to the home route placeholder.
      expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    });

    testWidgets(
      'given the trip is not current, when the user taps set-as-current, '
      'then the menu label flips to end-current on next open',
      (tester) async {
        final trip = buildTrip(id: 'kyoto', name: 'Kyoto');

        await _givenTripDetailScreen(
          tester,
          tripId: 'kyoto',
          seededTrips: [trip],
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('trip.set_as_current'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('trip.end_current'), findsOneWidget);
        expect(find.text('trip.set_as_current'), findsNothing);
      },
    );

    testWidgets(
      'given selection mode is active, when the user taps move selected, '
      'then the move-to-trip sheet is shown',
      (tester) async {
        final orphan = buildJourneyEntry(id: 'o1');

        await _givenTripDetailScreenWithRouter(
          tester,
          tripId: null,
          tripRepo: InMemoryTripRepository(),
          journeyRepo: (() {
            final r = InMemoryJourneyRepository();
            r.save(orphan);
            return r;
          })(),
        );

        await tester.tap(find.byIcon(Icons.checklist));
        await tester.pumpAndSettle();
        await tester.tap(find.text('trip.select_all'));
        await tester.pump();
        await tester.tap(find.text('trip.move_selected'));
        await tester.pumpAndSettle();

        // The sheet shows the uncategorized option (always the first entry).
        expect(find.text('trip.uncategorized'), findsAtLeastNWidgets(1));
        expect(find.text('trip.create_action'), findsOneWidget);
      },
    );
  });
}

Future<void> _givenTripDetailScreen(
  WidgetTester tester, {
  required String? tripId,
  List<Trip> seededTrips = const [],
  List<JourneyEntry> seededJourneys = const [],
  String? currentTripIdInitial,
}) async {
  final tripRepo = InMemoryTripRepository();
  for (final trip in seededTrips) {
    await tripRepo.save(trip);
  }
  final journeyRepo = InMemoryJourneyRepository();
  for (final entry in seededJourneys) {
    await journeyRepo.save(entry);
  }

  await _givenTripDetailScreenWithRepos(
    tester,
    tripId: tripId,
    tripRepo: tripRepo,
    journeyRepo: journeyRepo,
    currentTripIdInitial: currentTripIdInitial,
  );
}

Future<void> _givenTripDetailScreenWithRepos(
  WidgetTester tester, {
  required String? tripId,
  required InMemoryTripRepository tripRepo,
  required InMemoryJourneyRepository journeyRepo,
  String? currentTripIdInitial,
}) async {
  await pumpScreen(
    tester,
    child: TripDetailScreen(tripId: tripId),
    overrides: [
      tripRepositoryProvider.overrideWithValue(tripRepo),
      journeyRepositoryProvider.overrideWithValue(journeyRepo),
      if (currentTripIdInitial != null)
        currentTripIdProvider.overrideWith(
          () => _StaticCurrentTripIdNotifier(currentTripIdInitial),
        ),
    ],
  );
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _givenTripDetailScreenWithRouter(
  WidgetTester tester, {
  required String? tripId,
  required InMemoryTripRepository tripRepo,
  required InMemoryJourneyRepository journeyRepo,
  List<Object?>? playerExtras,
  List<String>? visitedLocations,
}) async {
  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(
        name: 'player',
        path: '/player',
        builder: (_, state) {
          playerExtras?.add(state.extra);
          return const Scaffold(key: ValueKey('player-screen'));
        },
      ),
      GoRoute(
        path: '/',
        builder: (_, state) {
          // 只在呼叫方要驗證落點時記錄，其餘測試不受影響。
          visitedLocations?.add(state.uri.toString());
          return Scaffold(
            key: const ValueKey('home-screen'),
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => context.push('/detail'),
                child: const Text('to-detail'),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/detail',
        builder: (_, __) => TripDetailScreen(tripId: tripId),
      ),
    ],
    overrides: [
      tripRepositoryProvider.overrideWithValue(tripRepo),
      journeyRepositoryProvider.overrideWithValue(journeyRepo),
    ],
  );
  await tester.tap(find.text('to-detail'));
  await tester.pumpAndSettle();
}

Future<void> _whenUserEntersSelectionMode(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.checklist));
  await tester.pump(const Duration(milliseconds: 10));
}

void _thenTripNameIsVisible(String name) {
  expect(find.text(name), findsOneWidget);
}

/// 一般閱讀模式現在是手記翻頁器；`TimelineEntry` 只在多選模式下才出現。
void _thenNotebookPagerIsShown() {
  expect(find.byType(NotebookPager), findsOneWidget);
}

void _thenEmptyStateIsVisible() {
  expect(find.byType(TripEmptyState), findsOneWidget);
  expect(find.text('trip.no_items'), findsOneWidget);
  expect(find.text('trip.empty_hint'), findsOneWidget);
  expect(find.text('trip.empty_cta'), findsOneWidget);
}

void _thenUncategorizedTitleIsVisible() {
  expect(find.text('trip.uncategorized'), findsOneWidget);
}

void _thenSelectionModeIsAvailable() {
  expect(find.byIcon(Icons.checklist), findsOneWidget);
}

void _thenSelectionHeaderIsVisible() {
  expect(find.text('trip.selected_count'), findsOneWidget);
  expect(find.text('trip.select_all'), findsOneWidget);
}

class _StaticCurrentTripIdNotifier extends CurrentTripIdNotifier {
  _StaticCurrentTripIdNotifier(this._initial);

  final String? _initial;

  @override
  String? build() => _initial;
}
