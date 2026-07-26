import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/presentation/controllers/current_trip_notifier.dart';
import 'package:context_app/features/trip/presentation/screens/trip_detail_screen.dart';
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
    testWidgets(
      'given a trip with entries, when the detail screen loads, '
      'then the trip name and each timeline entry are rendered',
      (tester) async {
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

        await tester.tap(find.text('common.replay'));
        await tester.pumpAndSettle();

        final extra = playerExtras.single as Map<String, dynamic>;
        expect((extra['place'] as Place).name, 'Kinkaku-ji');
        expect((extra['place'] as Place).address, '1 Kinkakujicho');
        expect(extra['narrationContent'], entry.narrationContent);
        // 按下「重聽」本身就是要聽，不該再多按一次播放鍵。
        expect(extra['autoPlay'], isTrue);
      },
    );

    testWidgets(
      'given a trip with no entries, when the detail screen loads, '
      'then the empty state is rendered',
      (tester) async {
        final trip = buildTrip(id: 'empty', name: 'Empty Trip');

        await _givenTripDetailScreen(
          tester,
          tripId: 'empty',
          seededTrips: [trip],
        );

        _thenEmptyStateIsVisible();
      },
    );

    testWidgets(
      'given the uncategorized bucket, when the screen loads, '
      'then the uncategorized title and checklist action are shown',
      (tester) async {
        final orphan = buildJourneyEntry(id: 'o1');

        await _givenTripDetailScreen(
          tester,
          tripId: null,
          seededJourneys: [orphan],
        );

        _thenUncategorizedTitleIsVisible();
        _thenSelectionModeIsAvailable();
      },
    );

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

    testWidgets(
      'given selection mode, when the user taps an entry, '
      'then that entry is marked with a check icon',
      (tester) async {
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
      },
    );

    testWidgets(
      'given selection mode, when the user taps Select all, '
      'then every entry becomes selected',
      (tester) async {
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
      },
    );

    testWidgets(
      'given selection mode, when the user taps the close icon, '
      'then the screen returns to the default app bar',
      (tester) async {
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
      },
    );

    testWidgets(
      'given a trip with start and end dates, when the screen loads, '
      'then the meta header shows a formatted date range',
      (tester) async {
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
      },
    );

    testWidgets(
      'given a named trip, when the user opens the menu, '
      'then all trip actions are listed',
      (tester) async {
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
      },
    );

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

    testWidgets(
      'given the trip menu is open, when the user taps Delete, '
      'then the delete-confirmation dialog appears',
      (tester) async {
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
      },
    );

    testWidgets(
      'given the delete dialog is open, when the user cancels, '
      'then the trip remains in the repository',
      (tester) async {
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
      },
    );

    testWidgets(
      'given the trip menu is open under a router, '
      'when the user confirms delete, '
      'then the trip is removed and the screen pops',
      (tester) async {
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
      },
    );

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
        builder: (_, __) => Scaffold(
          key: const ValueKey('home-screen'),
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => context.push('/detail'),
              child: const Text('to-detail'),
            ),
          ),
        ),
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
  expect(find.text('trip.no_items'), findsOneWidget);
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
