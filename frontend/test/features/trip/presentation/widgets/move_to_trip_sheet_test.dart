import 'package:context_app/features/trip/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fakes/in_memory_trip_repository.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_data.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  setUp(() {
    _Host.popped = false;
    _Host.lastSelection = null;
  });

  group('MoveToTripSheet', () {
    testWidgets('given no trips, when the sheet opens, '
        'then only the uncategorized option and create action are shown', (
      tester,
    ) async {
      await _openSheet(tester, repo: InMemoryTripRepository());

      expect(find.text('trip.uncategorized'), findsOneWidget);
      expect(find.text('trip.create_action'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
    });

    testWidgets('given two trips, when the sheet opens, '
        'then a flag tile is rendered for each trip', (tester) async {
      final repo = InMemoryTripRepository();
      await repo.save(
        buildTrip(id: 't1', name: 'Kyoto', createdAt: DateTime(2024, 2, 1)),
      );
      await repo.save(
        buildTrip(id: 't2', name: 'Tokyo', createdAt: DateTime(2024, 1, 1)),
      );

      await _openSheet(tester, repo: repo);

      expect(find.text('Kyoto'), findsOneWidget);
      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsNWidgets(2));
    });

    testWidgets('given the sheet shows uncategorized, when the user taps it, '
        'then the sheet pops with a null TripSelection', (tester) async {
      await _openSheet(tester, repo: InMemoryTripRepository());

      await tester.tap(find.text('trip.uncategorized'));
      await tester.pumpAndSettle();

      expect(_Host.popped, isTrue);
      expect(_Host.lastSelection, isNotNull);
      expect(_Host.lastSelection!.tripId, isNull);
    });

    testWidgets('given the sheet lists trips, when the user taps one, '
        'then the sheet pops with the matching trip id', (tester) async {
      final repo = InMemoryTripRepository();
      await repo.save(buildTrip(id: 't1', name: 'Kyoto'));

      await _openSheet(tester, repo: repo);

      await tester.tap(find.text('Kyoto'));
      await tester.pumpAndSettle();

      expect(_Host.lastSelection?.tripId, equals('t1'));
    });

    testWidgets('given itemCount is greater than one, when the sheet opens, '
        'then the batch title is shown', (tester) async {
      await _openSheet(tester, repo: InMemoryTripRepository(), itemCount: 3);

      expect(find.text('trip.move_title_batch'), findsOneWidget);
      expect(find.text('trip.move_title'), findsNothing);
    });

    testWidgets(
      'given a currentTripId matches a listed trip, when the sheet opens, '
      'then that option shows the selected check icon',
      (tester) async {
        final repo = InMemoryTripRepository();
        await repo.save(buildTrip(id: 't1', name: 'Kyoto'));
        await repo.save(buildTrip(id: 't2', name: 'Tokyo'));

        await _openSheet(tester, repo: repo, currentTripId: 't2');

        expect(find.byIcon(Icons.check), findsOneWidget);
        // Pull the ListTile that owns the check to confirm it's Tokyo's row.
        final selectedTileFinder = find.ancestor(
          of: find.byIcon(Icons.check),
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(of: selectedTileFinder, matching: find.text('Tokyo')),
          findsOneWidget,
        );
      },
    );

    testWidgets('given no currentTripId, when the sheet opens, '
        'then the uncategorized option is marked selected', (tester) async {
      await _openSheet(tester, repo: InMemoryTripRepository());

      final selectedTileFinder = find.ancestor(
        of: find.byIcon(Icons.check),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(
          of: selectedTileFinder,
          matching: find.text('trip.uncategorized'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('given the create-trip action, when the user taps it, '
        'then the sheet pops and the router navigates to /trip/edit', (
      tester,
    ) async {
      await _openSheet(tester, repo: InMemoryTripRepository());

      await tester.tap(find.text('trip.create_action'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('edit-screen')), findsOneWidget);
    });
  });
}

Future<void> _openSheet(
  WidgetTester tester, {
  required InMemoryTripRepository repo,
  String? currentTripId,
  int itemCount = 1,
}) async {
  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            _Host(currentTripId: currentTripId, itemCount: itemCount),
      ),
      GoRoute(
        path: '/trip/edit',
        builder: (_, __) =>
            const Scaffold(key: ValueKey('edit-screen'), body: Text('edit')),
      ),
    ],
    overrides: [tripRepositoryProvider.overrideWithValue(repo)],
  );

  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

class _Host extends StatefulWidget {
  final String? currentTripId;
  final int itemCount;

  const _Host({this.currentTripId, this.itemCount = 1});

  static TripSelection? lastSelection;
  static bool popped = false;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final selection = await showMoveToTripSheet(
              context: context,
              currentTripId: widget.currentTripId,
              itemCount: widget.itemCount,
            );
            _Host.popped = true;
            _Host.lastSelection = selection;
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}
