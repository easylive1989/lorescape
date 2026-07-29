import 'package:context_app/features/auth/domain/models/auth_user.dart';
import 'package:context_app/features/auth/providers.dart';
import 'package:context_app/features/onboarding/providers.dart';
import 'package:context_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:context_app/features/settings/providers.dart';
import 'package:context_app/features/subscription/domain/models/subscription_status.dart';
import 'package:context_app/features/subscription/providers.dart';
import 'package:context_app/features/usage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fakes/fake_auth_service.dart';
import '../../../../fakes/in_memory_onboarding_repository.dart';
import '../../../../fakes/in_memory_usage_repository.dart';
import '../../../../helpers/pump_app.dart';

const _fakeVersionLabel = 'Version 9.9.9 (Build 42)';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SettingsScreen', () {
    testWidgets('given a free user, when the screen loads, '
        'then preferences and the upgrade CTA are visible and there is no '
        'daily-usage section', (tester) async {
      await _givenSettingsScreen(tester, status: SubscriptionStatus.free);

      _thenPreferencesSectionIsVisible();
      _thenUsageSectionIsHidden();
      _thenUpgradeCtaIsVisible();
    });

    testWidgets('given a premium user, when the screen loads, '
        'then the premium-active tile is shown instead of the upgrade CTA', (
      tester,
    ) async {
      await _givenSettingsScreen(
        tester,
        status: const SubscriptionStatus(isPremium: true),
      );

      _thenPremiumTileIsVisible();
      _thenUpgradeCtaIsHidden();
    });

    testWidgets(
      'given the app version future resolves, when the screen settles, '
      'then the version label is rendered',
      (tester) async {
        await _givenSettingsScreen(tester);

        await _whenVersionFutureResolves(tester);

        _thenVersionLabelIsVisible();
      },
    );

    testWidgets('given no user is signed in, '
        'then sign-in buttons are visible and sync toggle is disabled', (
      tester,
    ) async {
      final auth = FakeAuthService();
      addTearDown(auth.dispose);

      await _givenSettingsScreen(tester, authService: auth);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey('sign_in_google')), findsOneWidget);
      expect(find.byKey(const ValueKey('sign_in_apple')), findsOneWidget);
      final switchFinder = find.byKey(const ValueKey('sync_toggle_switch'));
      expect(switchFinder, findsOneWidget);
      final Switch toggle = tester.widget(switchFinder);
      expect(toggle.onChanged, isNull);
      expect(toggle.value, isFalse);
    });

    testWidgets('given the user taps the Google sign-in button, '
        'then signInWithGoogle is invoked and the user appears as signed in', (
      tester,
    ) async {
      final auth = FakeAuthService();
      addTearDown(auth.dispose);

      await _givenSettingsScreen(tester, authService: auth);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const ValueKey('sign_in_google')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(auth.googleSignInCount, 1);
      // After sign-in, the sign-out button replaces the sign-in buttons.
      expect(find.text('settings.sign_out'), findsOneWidget);
      expect(find.byKey(const ValueKey('sign_in_google')), findsNothing);
    });

    testWidgets('given a signed-in user, '
        'when the sync toggle is flipped on, '
        'then the sync preference is persisted as true', (tester) async {
      final auth = FakeAuthService(
        initialUser: const AuthUser(
          id: 'u1',
          email: 'a@b.com',
          displayName: 'A',
        ),
      );
      addTearDown(auth.dispose);

      await _givenSettingsScreen(tester, authService: auth);
      await tester.pump(const Duration(milliseconds: 50));

      final switchFinder = find.byKey(const ValueKey('sync_toggle_switch'));
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sync_enabled'), isTrue);
    });

    testWidgets('given the settings screen pushed from home, '
        'when the user taps the back button, '
        'then it returns to the previous screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpRouterApp(
        tester,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(key: Key('home-screen')),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
        overrides: _settingsOverrides(),
      );
      final context = tester.element(find.byKey(const Key('home-screen')));
      GoRouter.of(context).push('/settings');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-screen')), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('floating-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-screen')), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
    });
  });
}

List<Override> _settingsOverrides({
  InMemoryUsageRepository? usage,
  SubscriptionStatus status = SubscriptionStatus.free,
  FakeAuthService? authService,
}) {
  final usageRepo = usage ?? InMemoryUsageRepository(usedToday: 0);
  final auth = authService ?? FakeAuthService();

  return [
    authServiceProvider.overrideWithValue(auth),
    usageRepositoryProvider.overrideWithValue(usageRepo),
    usageStatusProvider.overrideWith((ref) async => usageRepo.getUsageStatus()),
    subscriptionStatusProvider.overrideWith(
      (ref) => Stream<SubscriptionStatus>.value(status),
    ),
    appVersionStringProvider.overrideWith((ref) async => _fakeVersionLabel),
    onboardingRepositoryProvider.overrideWithValue(
      InMemoryOnboardingRepository(welcomeDone: true),
    ),
  ];
}

Future<void> _givenSettingsScreen(
  WidgetTester tester, {
  InMemoryUsageRepository? usage,
  SubscriptionStatus status = SubscriptionStatus.free,
  FakeAuthService? authService,
}) async {
  // The settings screen is taller than the default 800x600 test surface
  // after the onboarding section was added. Enlarging the surface lets
  // `find.text` locate tiles below the fold without having to scroll.
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await pumpScreen(
    tester,
    child: const SettingsScreen(),
    overrides: _settingsOverrides(
      usage: usage,
      status: status,
      authService: authService,
    ),
  );
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _whenVersionFutureResolves(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

void _thenPreferencesSectionIsVisible() {
  expect(find.text('SETTINGS.PREFERENCES'), findsOneWidget);
  expect(find.text('settings.change_language'), findsOneWidget);
}

void _thenUsageSectionIsHidden() {
  // The free tier has no daily on-demand quota (full story is subscriber-only,
  // enforced on the backend), so the misleading "daily usage" row was removed.
  expect(find.text('SETTINGS.DAILY_USAGE'), findsNothing);
  expect(find.text('settings.daily_usage'), findsNothing);
}

void _thenUpgradeCtaIsVisible() {
  expect(find.text('subscription.upgrade_banner_title'), findsOneWidget);
}

void _thenPremiumTileIsVisible() {
  expect(find.text('subscription.premium_banner_title'), findsOneWidget);
}

void _thenUpgradeCtaIsHidden() {
  expect(find.text('subscription.upgrade_banner_title'), findsNothing);
}

void _thenVersionLabelIsVisible() {
  expect(find.text(_fakeVersionLabel), findsOneWidget);
}
