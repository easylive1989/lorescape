import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/presentation/screens/explore_screen.dart';
import 'package:context_app/features/journey/presentation/screens/journey_screen.dart';
import 'package:context_app/features/narration/presentation/screens/select_story_hook_screen.dart';
import 'package:context_app/features/narration/presentation/screens/narration_screen.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:context_app/features/onboarding/presentation/screens/onboarding_welcome_screen.dart';
import 'package:context_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:context_app/features/splash/presentation/splash_screen.dart';
import 'package:context_app/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:context_app/features/trip/presentation/screens/trip_detail_screen.dart';
import 'package:context_app/features/trip/presentation/screens/trip_edit_screen.dart';
import 'package:context_app/features/trip/presentation/screens/trip_list_screen.dart';
import 'package:context_app/shared/widgets/redirect_to_home.dart';

class RouterConfig {
  RouterConfig._();

  static GoRouter createRouter(Ref ref) {
    return GoRouter(
      initialLocation: '/splash',
      // Feeds GA4 screen_view with real screen names; see
      // routeObserversProvider.
      observers: ref.read(routeObserversProvider),
      refreshListenable: _OnboardingListenable(ref),
      redirect: (context, state) {
        // Send first-run users through the welcome carousel. Other flows
        // (deep links via `/player`, etc.) are left untouched
        // so that an authenticated returning user is never interrupted.
        final onboarding = ref.read(onboardingControllerProvider);
        if (!onboarding.hasLoaded) {
          // Trigger the async load (idempotent). `refreshListenable`
          // will re-run this redirect once state is available, so we
          // don't redirect prematurely and flash `/onboarding` at
          // returning users.
          ref.read(onboardingControllerProvider.notifier).ensureLoaded();
          return null;
        }
        final atOnboarding = state.matchedLocation == '/onboarding';
        if (!onboarding.welcomeDone &&
            !atOnboarding &&
            state.matchedLocation == '/') {
          return '/onboarding';
        }
        if (onboarding.welcomeDone && atOnboarding) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/',
          name: 'home',
          // 首頁就是探索地圖。用 NoTransitionPage：首頁幾乎只會是初始路徑
          // 或 redirect 目的地，不需要自己的進場轉場。
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: ExploreScreen(initialQuery: state.uri.queryParameters['q']),
          ),
        ),
        GoRoute(
          path: '/journey',
          name: 'journey',
          builder: (context, state) => const JourneyScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingWelcomeScreen(),
        ),
        GoRoute(
          path: '/config',
          name: 'config',
          redirect: (context, state) {
            final extra = state.extra;
            if (extra == null) return '/';
            if (extra is! Place && extra is! Map<String, dynamic>) return '/';
            if (extra is Map<String, dynamic> && extra['place'] is! Place) {
              return '/';
            }
            return null;
          },
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Place) {
              return SelectStoryHookScreen(place: extra);
            }
            final mapExtra = extra as Map<String, dynamic>;
            final place = mapExtra['place'] as Place;
            final capturedImageBytes =
                mapExtra['capturedImageBytes'] as Uint8List?;
            return SelectStoryHookScreen(
              place: place,
              capturedImageBytes: capturedImageBytes,
            );
          },
        ),
        GoRoute(
          path: '/player',
          name: 'player',
          redirect: (context, state) {
            final extra = state.extra;
            if (extra == null || extra is! Map<String, dynamic>) return '/';
            if (extra['place'] is! Place) return '/';
            if (extra['narrationContent'] is! NarrationContent) return '/';
            return null;
          },
          builder: (context, state) {
            final params = state.extra as Map<String, dynamic>;
            final place = params['place'] as Place;
            final narrationContent =
                params['narrationContent'] as NarrationContent;
            final autoPlay = params['autoPlay'] as bool? ?? false;
            final storyTitle = params['storyTitle'] as String?;
            return NarrationScreen(
              place: place,
              narrationContent: narrationContent,
              storyTitle: storyTitle,
              autoPlay: autoPlay,
            );
          },
        ),
        GoRoute(
          path: '/subscription',
          name: 'subscription',
          builder: (context, state) => const SubscriptionScreen(),
        ),
        GoRoute(
          path: '/trips',
          name: 'trips',
          builder: (context, state) => const TripListScreen(),
        ),
        GoRoute(
          path: '/trip/edit',
          name: 'trip_create',
          builder: (context, state) => const TripEditScreen(),
        ),
        GoRoute(
          path: '/trip/edit/:id',
          name: 'trip_edit',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TripEditScreen(tripId: id);
          },
        ),
        GoRoute(
          path: '/trip/uncategorized',
          name: 'trip_uncategorized',
          builder: (context, state) => const TripDetailScreen(),
        ),
        GoRoute(
          path: '/trip/:id',
          name: 'trip_detail',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TripDetailScreen(tripId: id);
          },
        ),
      ],
      // A URL that matches no route (e.g. a malformed deep link like
      // `/zh/storybook`) redirects home instead of an error page.
      errorBuilder: (context, state) => const RedirectToHome(),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return RouterConfig.createRouter(ref);
});

/// Notifies [GoRouter] to re-evaluate redirects whenever onboarding
/// completes or is reset.
///
/// A ChangeNotifier is the contract GoRouter expects for
/// `refreshListenable`; we forward Riverpod state changes into it.
class _OnboardingListenable extends ChangeNotifier {
  _OnboardingListenable(Ref ref) {
    // Listen to the full state so the router also refreshes when
    // `hasLoaded` flips from false to true on cold start.
    _sub = ref.listen(
      onboardingControllerProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
