import 'package:context_app/features/trip/presentation/screens/trip_edit_screen.dart';
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

  group('TripEditScreen', () {
    testWidgets('given the create mode, when the screen loads, '
        'then the form fields and create action are visible', (tester) async {
      await _givenCreateScreen(tester);

      _thenCreateTitleIsVisible();
      _thenSaveActionUsesCreateLabel();
    });

    testWidgets('given create mode, when the user submits an empty name, '
        'then the required-field error is shown', (tester) async {
      await _givenCreateScreen(tester);

      await _whenUserTapsSave(tester);

      _thenRequiredFieldErrorIsVisible();
    });

    testWidgets('given create mode, when the user saves a valid trip, '
        'then the trip is persisted and the screen pops', (tester) async {
      final tripRepo = InMemoryTripRepository();

      await _givenCreateScreenWithRouter(tester, tripRepo);

      await _whenUserEntersTripName(tester, 'Osaka Foodie Tour');
      await _whenUserTapsSave(tester);

      await _thenTripIsPersistedWithName(tripRepo, 'Osaka Foodie Tour');
      _thenEditScreenIsDismissed();
    });

    testWidgets('given edit mode with an existing trip, when the screen loads, '
        'then the existing trip name prefills the form', (tester) async {
      final tripRepo = InMemoryTripRepository();
      await tripRepo.save(buildTrip(id: 'existing', name: 'Prefilled Trip'));

      await _givenEditScreen(tester, tripRepo: tripRepo, tripId: 'existing');

      _thenTripNameFieldHasText('Prefilled Trip');
    });
  });
}

Future<void> _givenCreateScreen(
  WidgetTester tester, {
  InMemoryTripRepository? repo,
}) async {
  final tripRepo = repo ?? InMemoryTripRepository();
  await pumpScreen(
    tester,
    child: const TripEditScreen(),
    overrides: [tripRepositoryProvider.overrideWithValue(tripRepo)],
  );
}

Future<void> _givenEditScreen(
  WidgetTester tester, {
  required InMemoryTripRepository tripRepo,
  required String tripId,
}) async {
  await pumpScreen(
    tester,
    child: TripEditScreen(tripId: tripId),
    overrides: [tripRepositoryProvider.overrideWithValue(tripRepo)],
  );
  // Let _loadExistingTrip async resolve.
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _givenCreateScreenWithRouter(
  WidgetTester tester,
  InMemoryTripRepository tripRepo,
) async {
  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _Host()),
      GoRoute(path: '/trip/edit', builder: (_, __) => const TripEditScreen()),
    ],
    overrides: [tripRepositoryProvider.overrideWithValue(tripRepo)],
  );
  await tester.pump(const Duration(milliseconds: 10));
  final context = tester.element(find.byType(_Host));
  GoRouter.of(context).push('/trip/edit');
  // Allow the push transition to complete.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _whenUserEntersTripName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextFormField), name);
  await tester.pump();
}

Future<void> _whenUserTapsSave(WidgetTester tester) async {
  await tester.tap(find.text('trip.create_action'));
  await tester.pumpAndSettle();
}

void _thenCreateTitleIsVisible() {
  expect(find.text('trip.create_title'), findsOneWidget);
}

void _thenSaveActionUsesCreateLabel() {
  expect(find.text('trip.create_action'), findsOneWidget);
}

void _thenRequiredFieldErrorIsVisible() {
  expect(find.text('trip.name_required'), findsOneWidget);
}

Future<void> _thenTripIsPersistedWithName(
  InMemoryTripRepository repo,
  String expectedName,
) async {
  final trips = await repo.getAll();
  final names = trips.map((t) => t.name).toList();
  expect(names, contains(expectedName));
}

void _thenEditScreenIsDismissed() {
  expect(find.byType(TripEditScreen), findsNothing);
}

void _thenTripNameFieldHasText(String expected) {
  final textField = find.byType(TextFormField);
  expect(textField, findsOneWidget);
  final widget = find.text(expected);
  expect(widget, findsOneWidget);
}

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('host')));
}
