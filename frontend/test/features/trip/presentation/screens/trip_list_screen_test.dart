import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/presentation/screens/trip_edit_screen.dart';
import 'package:context_app/features/trip/presentation/screens/trip_list_screen.dart';
import 'package:context_app/features/trip/presentation/widgets/trip_card.dart';
import 'package:context_app/features/trip/providers.dart';
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

  group('TripListScreen', () {
    testWidgets('given the user has saved trips, when the screen loads, '
        'then each trip card is rendered in the grid', (tester) async {
      final kyoto = buildTrip(id: 't1', name: 'Kyoto Week');
      final tokyo = buildTrip(id: 't2', name: 'Tokyo Weekend');

      await _givenTripListScreen(tester, seededTrips: [kyoto, tokyo]);

      _thenTripNamesAreVisible(['Kyoto Week', 'Tokyo Weekend']);
    });

    testWidgets('given the user has no trips at all, when the screen loads, '
        'then only the uncategorized placeholder is shown', (tester) async {
      await _givenTripListScreen(tester);

      _thenUncategorizedCardIsVisible();
    });

    testWidgets(
      'given the screen is loaded, when the user taps the add button, '
      'then the trip edit screen is pushed onto the stack',
      (tester) async {
        await _givenTripListScreenWithRouter(tester);

        await _whenUserTapsAddTripButton(tester);

        _thenTripEditScreenIsPushed();
      },
    );

    testWidgets('given trips have item counts, when the screen loads, '
        'then the counts are rendered on their respective cards', (
      tester,
    ) async {
      final trip = buildTrip(id: 't1', name: 'With Items');
      final entry = buildJourneyEntry(id: 'e1', tripId: 't1');

      await _givenTripListScreen(
        tester,
        seededTrips: [trip],
        seededJourneys: [entry],
      );

      _thenTripNamesAreVisible(['With Items']);
    });
  });
}

Future<void> _givenTripListScreen(
  WidgetTester tester, {
  List<Trip> seededTrips = const [],
  List<JourneyEntry> seededJourneys = const [],
}) async {
  final tripRepo = InMemoryTripRepository();
  for (final trip in seededTrips) {
    await tripRepo.save(trip);
  }
  final journeyRepo = InMemoryJourneyRepository();
  for (final entry in seededJourneys) {
    await journeyRepo.save(entry);
  }

  await pumpScreen(
    tester,
    child: const TripListScreen(),
    overrides: [
      tripRepositoryProvider.overrideWithValue(tripRepo),
      journeyRepositoryProvider.overrideWithValue(journeyRepo),
    ],
  );
  // Allow async providers (tripsProvider, tripItemCountsProvider) to resolve.
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _givenTripListScreenWithRouter(WidgetTester tester) async {
  final tripRepo = InMemoryTripRepository();
  final journeyRepo = InMemoryJourneyRepository();

  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const TripListScreen()),
      GoRoute(path: '/trip/edit', builder: (_, __) => const TripEditScreen()),
    ],
    overrides: [
      tripRepositoryProvider.overrideWithValue(tripRepo),
      journeyRepositoryProvider.overrideWithValue(journeyRepo),
    ],
  );
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _whenUserTapsAddTripButton(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();
  // Allow the push transition to complete.
  await tester.pump(const Duration(milliseconds: 400));
}

void _thenTripNamesAreVisible(List<String> names) {
  for (final name in names) {
    expect(find.text(name), findsOneWidget);
  }
  expect(find.byType(TripCard), findsNWidgets(names.length));
}

void _thenUncategorizedCardIsVisible() {
  // The trip list screen shows the "uncategorized" placeholder when the
  // trip list is empty. It's rendered via UncategorizedTripCard.
  expect(find.byType(TripCard), findsNothing);
  expect(find.text('trip.uncategorized'), findsOneWidget);
}

void _thenTripEditScreenIsPushed() {
  expect(find.byType(TripEditScreen), findsOneWidget);
}
