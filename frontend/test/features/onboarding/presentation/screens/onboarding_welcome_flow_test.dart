// Sequence-level tests for the onboarding welcome flow.
//
// Pins down the wires that the loaded-state screen test does not:
// - tapping the dock "next" button advances the PageView between steps
// - the shared `_finish()` path (used by both skip and the final button)
//   plays the closing animation, persists welcomeDone and lands on `/`
// - the resetAll controller method drops welcomeDone

import 'package:context_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:context_app/features/onboarding/presentation/screens/onboarding_welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fakes/in_memory_onboarding_repository.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('Onboarding welcome flow', () {
    testWidgets('given the welcome step, when the user taps next, '
        'then the PageView advances to the value step', (tester) async {
      await _pumpOnboardingFlow(tester);

      expect(find.text('onboarding.welcome.title'), findsOneWidget);

      await tester.tap(find.text('onboarding.next_welcome'));
      await tester.pumpAndSettle();

      expect(find.text('onboarding.value.title'), findsOneWidget);
    });

    testWidgets('given the welcome screen is visible, when the user taps Skip, '
        'then the closing animation runs, welcomeDone is persisted '
        'and the router lands on /', (tester) async {
      // Skip and the final button share the `_finish()` path, so tapping
      // Skip exercises the same completion wiring without driving the
      // PageView through every step.
      final repo = InMemoryOnboardingRepository();
      await _pumpOnboardingFlow(tester, repo: repo);

      await tester.tap(find.text('onboarding.skip'));
      await _settleFinish(tester);

      expect(repo.markWelcomeDoneCalls, 1);
      expect(find.text('home-stub'), findsOneWidget);
    });

    testWidgets('given welcomeDone has been set, when resetAll runs, '
        'then the repository is reset and the controller drops welcomeDone', (
      tester,
    ) async {
      final repo = InMemoryOnboardingRepository(welcomeDone: true);
      await _pumpOnboardingFlow(tester, repo: repo);

      final element = tester.element(find.byType(OnboardingWelcomeScreen));
      final scope = ProviderScope.containerOf(element, listen: false);
      await scope.read(onboardingControllerProvider.notifier).resetAll();
      await tester.pump();

      expect(repo.resetCalls, 1);
      expect(scope.read(onboardingControllerProvider).welcomeDone, isFalse);
    });
  });
}

Future<void> _pumpOnboardingFlow(
  WidgetTester tester, {
  InMemoryOnboardingRepository? repo,
}) async {
  final resolved = repo ?? InMemoryOnboardingRepository();
  await pumpRouterApp(
    tester,
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _HomeStub()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingWelcomeScreen(),
      ),
    ],
    overrides: [onboardingRepositoryProvider.overrideWithValue(resolved)],
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// Pumps past the closing animation delay and the subsequent navigation
/// without using pumpAndSettle (the finish overlay's spinner never settles).
Future<void> _settleFinish(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pump(const Duration(milliseconds: 400));
}

class _HomeStub extends StatelessWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home-stub')));
}
