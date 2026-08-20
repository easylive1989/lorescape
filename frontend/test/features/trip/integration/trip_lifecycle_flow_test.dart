// Trip lifecycle test gaps that existing per-screen tests left open:
// (1) edit-mode save mutates the existing trip in place — does not
// create a second one and does not lose the original id / createdAt;
// (2) the "set as current / end current" menu actions actually update
// the CurrentTripIdNotifier state, not just the menu label.

import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/trip/presentation/screens/trip_detail_screen.dart';
import 'package:context_app/features/trip/presentation/screens/trip_edit_screen.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fakes/in_memory_journey_repository.dart';
import '../../../fakes/in_memory_trip_repository.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_data.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  // CurrentTripIdNotifier persists via SharedPreferences, so test 2
  // would leak its 'kyoto' value into test 3 and skew the menu state.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Trip edit save', () {
    testWidgets(
      'given an existing trip, when the user changes the name and saves, '
      'then the trip is mutated in place — id and createdAt unchanged '
      'and no new trip row appears',
      (tester) async {
        final repo = InMemoryTripRepository();
        final original = buildTrip(
          id: 'kyoto',
          name: 'Kyoto Original',
          createdAt: DateTime(2024, 1, 1),
        );
        await repo.save(original);

        await _pumpTripEdit(tester, tripId: 'kyoto', tripRepo: repo);

        await tester.enterText(find.byType(TextFormField), 'Kyoto Renamed');
        await tester.pump();
        await tester.tap(find.text('trip.save_changes'));
        await tester.pumpAndSettle();

        final all = await repo.getAll();
        expect(all, hasLength(1), reason: 'must not create a duplicate trip');
        final updated = all.single;
        expect(updated.id, 'kyoto');
        expect(updated.name, 'Kyoto Renamed');
        expect(
          updated.createdAt,
          original.createdAt,
          reason: 'createdAt should survive an edit',
        );
      },
    );
  });

  group('Trip current-id wiring', () {
    testWidgets('given a non-current trip, when set-as-current is invoked, '
        'then currentTripIdProvider exposes that trip id', (tester) async {
      final tripRepo = InMemoryTripRepository();
      final trip = buildTrip(id: 'kyoto', name: 'Kyoto');
      await tripRepo.save(trip);

      await _pumpTripDetail(tester, tripId: 'kyoto', tripRepo: tripRepo);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('trip.set_as_current'));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(TripDetailScreen));
      final scope = ProviderScope.containerOf(element, listen: false);
      expect(scope.read(currentTripIdProvider), 'kyoto');
    });

    testWidgets('given an already-current trip, when end-current is invoked, '
        'then currentTripIdProvider falls back to null', (tester) async {
      final tripRepo = InMemoryTripRepository();
      final trip = buildTrip(id: 'kyoto', name: 'Kyoto');
      await tripRepo.save(trip);

      await _pumpTripDetail(tester, tripId: 'kyoto', tripRepo: tripRepo);

      // First set it as current.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('trip.set_as_current'));
      await tester.pumpAndSettle();

      // Then end it.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('trip.end_current'));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(TripDetailScreen));
      final scope = ProviderScope.containerOf(element, listen: false);
      expect(scope.read(currentTripIdProvider), isNull);
    });
  });
}

Future<void> _pumpTripEdit(
  WidgetTester tester, {
  required String tripId,
  required InMemoryTripRepository tripRepo,
}) async {
  // TripEditScreen calls context.pop() after save. Start at `/`
  // and push onto the stack so pop has somewhere to go — the
  // existing trip-edit test follows the same pattern.
  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home-stub')),
      ),
      GoRoute(
        path: '/trip/edit/:id',
        builder: (_, state) =>
            TripEditScreen(tripId: state.pathParameters['id']!),
      ),
    ],
    overrides: [tripRepositoryProvider.overrideWithValue(tripRepo)],
  );
  await tester.pump();
  final context = tester.element(find.text('home-stub'));
  GoRouter.of(context).push('/trip/edit/$tripId');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpTripDetail(
  WidgetTester tester, {
  required String tripId,
  required InMemoryTripRepository tripRepo,
}) async {
  await pumpRouterApp(
    tester,
    initialLocation: '/trip/$tripId',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home-stub')),
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (_, state) =>
            TripDetailScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trip/edit/:id',
        builder: (_, __) => const Scaffold(body: Text('edit-stub')),
      ),
    ],
    overrides: [
      tripRepositoryProvider.overrideWithValue(tripRepo),
      journeyRepositoryProvider.overrideWithValue(InMemoryJourneyRepository()),
    ],
  );
  for (var i = 0; i < 3; i += 1) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}
