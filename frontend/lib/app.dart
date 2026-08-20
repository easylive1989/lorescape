import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/app/config/router_config.dart';
import 'package:context_app/app/config/theme_config.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:context_app/features/auth/domain/models/auth_user.dart';
import 'package:context_app/features/auth/providers.dart';
import 'package:context_app/features/onboarding/providers.dart';
import 'package:context_app/features/settings/domain/models/appearance_state.dart';
import 'package:context_app/features/settings/providers.dart';
import 'package:context_app/features/share/providers.dart';
import 'package:context_app/features/subscription/providers.dart';
import 'package:context_app/features/sync/providers.dart';
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the Field Journal [ThemeData] for the given appearance [state].
ThemeData lorescapeThemeFor(AppearanceState state) {
  final tokens = LorescapeTokens.forAppearance(
    accent: state.accent,
    reading: state.reading,
  );
  return buildLorescapeTheme(tokens: tokens, headlineFont: state.headlineFont);
}

/// Main application widget using go_router for navigation.
///
/// This widget sets up the app theme, routing, and global configuration.
class LorescapeApp extends ConsumerWidget {
  const LorescapeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Activate the cross-cutting analytics observer for the whole app
    // lifetime. The Notifier's build() wires up ref.listen on the
    // narration player state, so a single watch here is all that's
    // needed to keep the listener alive (the return value is intentionally
    // discarded).
    ref.watch(narrationAnalyticsObserverProvider);

    // Share intent temporarily disabled — Wikipedia-backed search has too low
    // a hit rate for Google Maps shares. Re-enable along with the platform
    // entries (AndroidManifest intent-filter, iOS ShareExtension activation
    // rule) once a higher-coverage data source is in place.
    // ref.watch(shareIntentInitProvider);

    // Kick off the onboarding state load on app start. The controller
    // itself stays in `initial` until this completes, so the router
    // redirect knows to wait instead of flashing `/onboarding`.
    ref.read(onboardingControllerProvider.notifier).ensureLoaded();

    // journey 與 trip 的同步。session 一有效就跑 full sync，細節（為什麼不是
    // 在這裡用 ref.listen）見 syncBootstrapProvider 的說明。
    ref.watch(syncBootstrapProvider);

    // Keep RevenueCat identified with the current user. When an anonymous
    // user signs in (id changes anonymous → permanent), this re-points the
    // RevenueCat App User ID so purchases and entitlement status attribute
    // to the permanent account.
    ref.listen<AuthUser?>(currentUserProvider, (prev, next) {
      final id = next?.id;
      if (id != null && id != prev?.id) {
        ref.read(subscriptionServiceProvider).logIn(id);
      }
    });

    // 從 Google Maps 分享地點的 listener 已移除：該入口依 ADR 0001 停用，
    // 而它唯一的去處（收藏景點）已在 v3 改版中整組移除。features/share/
    // 的解析程式碼保留，日後要復活需先決定新的落點。

    final pendingShare = ref.watch(shareIntentControllerProvider);
    final appearance = ref.watch(appearanceProvider);
    final theme = lorescapeThemeFor(appearance);

    return MaterialApp.router(
      onGenerateTitle: (context) => 'name'.tr(),
      debugShowCheckedModeBanner: false,
      theme: theme,
      themeMode: ThemeMode.light,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            if (pendingShare != null && pendingShare.isLoading)
              const _ShareLoadingOverlay(),
          ],
        );
      },
    );
  }
}

/// Full-screen loading overlay shown while resolving a shared place.
class _ShareLoadingOverlay extends StatelessWidget {
  const _ShareLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveProgressIndicator(color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'shared_place.loading'.tr(),
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
