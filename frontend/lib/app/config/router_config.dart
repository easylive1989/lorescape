import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:context_app/app/shell/main_screen.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/narration/presentation/screens/select_story_hook_screen.dart';
import 'package:context_app/features/narration/presentation/screens/narration_screen.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:context_app/features/onboarding/presentation/screens/onboarding_welcome_screen.dart';
import 'package:context_app/features/splash/presentation/splash_screen.dart';
import 'package:context_app/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:context_app/features/trip/presentation/screens/trip_detail_screen.dart';
import 'package:context_app/features/trip/presentation/screens/trip_edit_screen.dart';
import 'package:context_app/features/trip/presentation/screens/trip_list_screen.dart';
import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/presentation/screens/daily_story_detail_screen.dart';
import 'package:context_app/features/daily_story/presentation/screens/story_deep_link_screen.dart';
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
          builder: (context, state) {
            final tab = state.uri.queryParameters['tab'];
            final index = switch (tab) {
              'explore' => 1,
              'journey' => 2,
              _ => 0,
            };
            // GoRouter 的 pageKey 只看路徑（見 go_router 原始碼
            // match.dart 的 `ValueKey<String>(newMatchedPath)`），同樣是
            // `/` 但 tab 參數不同時會重用同一個 Page，MainScreen 的
            // State 也就跟著留用——但 initialIndex 只在 initState 讀一次，
            // 新的 tab 進不去。這裡用 tab 值當 widget key，逼 tab 改變時
            // 強制重建 State，讓新的 initialIndex 生效。
            return MainScreen(
              key: ValueKey('main-screen-${tab ?? 'default'}'),
              initialIndex: index,
            );
          },
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
          path: '/daily-story/detail',
          name: 'daily_story_detail',
          builder: (context, state) {
            final story = state.extra as DailyStory;
            return DailyStoryDetailScreen(story: story);
          },
        ),
        GoRoute(
          path: '/:locale/story/:date',
          name: 'story_deep_link',
          builder: (context, state) => StoryDeepLinkScreen(
            locale: state.pathParameters['locale']!,
            date: state.pathParameters['date']!,
          ),
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
