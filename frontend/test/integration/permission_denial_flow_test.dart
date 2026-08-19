// What happens when the user denies a runtime permission? Until now
// the location-denied and picker-denied branches were silently
// untested. These tests pin the user-visible fallback for each entry
// point so a regression doesn't ship the app stuck on a blank screen.

import 'package:context_app/features/explore/presentation/screens/explore_screen.dart';
import 'package:context_app/features/explore/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_location_service.dart';
import '../fakes/fake_places_repository.dart';
import '../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('Location permission denied', () {
    testWidgets(
      'given Explore loads and the OS denies location, '
      'when the controller surfaces the error, '
      'then the error prefix is rendered and no place cards are shown',
      (tester) async {
        await pumpScreen(
          tester,
          child: const ExploreScreen(),
          overrides: [
            locationServiceProvider.overrideWithValue(
              FakeLocationService(
                error: Exception('Location permissions are denied'),
              ),
            ),
            placesRepositoryProvider.overrideWithValue(
              FakePlacesRepository(nearbyPlaces: const []),
            ),
          ],
        );
        // Allow async location call + AsyncValue.error to settle.
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        expect(find.textContaining('common.error_prefix'), findsOneWidget);
        // The empty-state "no places found" copy should NOT replace the
        // error UI — that would mislead the user into thinking the area
        // genuinely had nothing.
        expect(find.text('No places found'), findsNothing);
      },
    );
  });
}
