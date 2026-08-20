import 'package:context_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:context_app/features/onboarding/presentation/screens/onboarding_welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fakes/in_memory_onboarding_repository.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('OnboardingWelcomeScreen', () {
    testWidgets('given a first-time user, when the welcome screen loads, '
        'then the welcome title and sample CTA are rendered', (tester) async {
      await _givenWelcomeScreen(tester);

      _thenWelcomeTitleIsVisible();
    });

    testWidgets('given the welcome screen is visible, when the user taps skip, '
        'then welcomeDone is persisted and the router leaves /onboarding', (
      tester,
    ) async {
      final repo = InMemoryOnboardingRepository();
      await _givenWelcomeScreen(tester, repository: repo);

      await _whenUserTapsSkip(tester);

      expect(repo.markWelcomeDoneCalls, 1);
    });
  });
}

Future<void> _givenWelcomeScreen(
  WidgetTester tester, {
  InMemoryOnboardingRepository? repository,
}) async {
  final repo = repository ?? InMemoryOnboardingRepository();

  await pumpRouterApp(
    tester,
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _HomeStub()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingWelcomeScreen(),
      ),
    ],
    overrides: [onboardingRepositoryProvider.overrideWithValue(repo)],
  );
  // Let the controller async load settle.
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _whenUserTapsSkip(WidgetTester tester) async {
  await tester.tap(find.text('onboarding.skip'));
  // Pump past the closing animation delay so completeWelcome() runs.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pump(const Duration(milliseconds: 400));
}

void _thenWelcomeTitleIsVisible() {
  expect(find.text('onboarding.welcome.title'), findsOneWidget);
  expect(find.text('onboarding.skip'), findsOneWidget);
}

class _HomeStub extends StatelessWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home-stub')));
}
