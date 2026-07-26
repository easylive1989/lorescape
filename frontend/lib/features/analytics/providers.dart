import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:context_app/features/analytics/domain/models/analytics_event.dart';

import 'package:context_app/core/services/firebase_install_id_provider.dart';
import 'package:context_app/core/services/install_id_provider.dart';
import 'package:context_app/features/analytics/data/firebase_analytics_service.dart';
import 'package:context_app/features/analytics/data/shared_prefs_consent_repository.dart';
import 'package:context_app/features/analytics/domain/services/analytics_emitter.dart';
import 'package:context_app/features/analytics/domain/services/analytics_service.dart';
import 'package:context_app/features/analytics/domain/services/consent_repository.dart';
import 'package:context_app/features/analytics/presentation/narration_analytics_observer.dart';

/// Async-resolved [SharedPreferences] singleton, used by consent
/// persistence and the lifetime first-narration flag.
///
/// Override in tests (or in `main.dart` for eager init) with
/// `sharedPreferencesProvider.overrideWith(...)`.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// Exposes the global [FirebaseAnalytics] singleton so it can be
/// overridden with a fake in widget / integration tests.
final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>(
  (ref) => FirebaseAnalytics.instance,
);

/// Entry point for any feature that needs to record an analytics event.
///
/// Default implementation forwards to Firebase Analytics; override in
/// tests by replacing [firebaseAnalyticsProvider] or this provider
/// directly with a fake.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => FirebaseAnalyticsService(ref.read(firebaseAnalyticsProvider)),
);

/// Reads the persisted consent flag, resolving [sharedPreferencesProvider]
/// first.
///
/// **必須先 await prefs 的 future**：[consentRepositoryProvider] 以
/// `requireValue` 取 SharedPreferences，在 `AsyncLoading` 期間會丟
/// `StateError`，而 Riverpod 會快取 build 失敗並在後續讀取重拋——一次過早的
/// 讀取就會讓整個 container 生命週期內的埋點全部失效（BACKLOG F13 T1a）。
/// 這段只留這一份，任何要送事件的地方都走 [analyticsEmitterProvider]。
Future<bool> _consentEnabled(Ref ref) async {
  await ref.read(sharedPreferencesProvider.future);
  final state = await ref.read(consentRepositoryProvider).read();
  return state.enabled;
}

/// Consent-gated emitter every feature should use to record events.
///
/// 取不到底層服務時退化成 no-op 而不是往外丟：`FirebaseAnalytics.instance` 在
/// Firebase 還沒 `initializeApp` 時會丟 `FirebaseException`，而埋點的呼叫點在
/// controller/畫面的主流程上——讓它外溢等於「因為統計壞了所以功能不能用」。
final analyticsEmitterProvider = Provider<AnalyticsEmitter>((ref) {
  AnalyticsService service;
  try {
    service = ref.read(analyticsServiceProvider);
  } catch (error, stackTrace) {
    Logger('analyticsEmitterProvider').warning(
      'Analytics unavailable; events will be dropped',
      error,
      stackTrace,
    );
    service = const _NoopAnalyticsService();
  }
  return AnalyticsEmitter(
    consentEnabled: () => _consentEnabled(ref),
    service: service,
  );
});

/// Swallows events when no analytics backend is reachable.
class _NoopAnalyticsService implements AnalyticsService {
  const _NoopAnalyticsService();

  @override
  Future<void> logEvent(AnalyticsEvent event) async {}
}

/// Navigator observers wired into GoRouter.
///
/// Without a [FirebaseAnalyticsObserver] the app's automatic `screen_view`
/// events reach GA4 with `unifiedScreenName` = `(not set)`, so no in-app
/// funnel can be read. Exposed as a provider so tests (and any surface that
/// must not touch Firebase) can override it with an empty list.
final routeObserversProvider = Provider<List<NavigatorObserver>>((ref) {
  return <NavigatorObserver>[
    FirebaseAnalyticsObserver(analytics: ref.read(firebaseAnalyticsProvider)),
  ];
});

/// Persists and broadcasts the user's analytics consent flag.
///
/// Throws if [sharedPreferencesProvider] has not yet resolved; callers
/// should `await ref.read(sharedPreferencesProvider.future)` once
/// during bootstrap before resolving this provider, or override
/// [sharedPreferencesProvider] with an eagerly-initialised value.
final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  final prefs = ref.read(sharedPreferencesProvider).requireValue;
  final repo = SharedPrefsConsentRepository(prefs);
  ref.onDispose(repo.dispose);
  return repo;
});

/// Returns the stable install id for analytics attribution and
/// (Story 2) feature-flag A/B bucketing.
final installIdProvider = Provider<InstallIdProvider>((ref) {
  final prefs = ref.read(sharedPreferencesProvider).requireValue;
  final analytics = ref.read(firebaseAnalyticsProvider);
  return FirebaseInstallIdProvider(
    fetchAppInstanceId: () => analytics.appInstanceId,
    prefs: prefs,
  );
});

/// Cross-cutting observer that listens to the narration player state
/// and emits analytics events.
///
/// Watch this provider once during app bootstrap (e.g. in `main.dart`
/// or the root widget) so the observer stays alive for the entire
/// session.
final narrationAnalyticsObserverProvider =
    NotifierProvider<NarrationAnalyticsObserver, void>(
      NarrationAnalyticsObserver.new,
    );
