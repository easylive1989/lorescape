import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:context_app/features/analytics/domain/models/abandon_reason.dart';
import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/domain/models/consent_state.dart';
import 'package:context_app/features/analytics/domain/services/analytics_service.dart';
import 'package:context_app/features/analytics/domain/services/consent_repository.dart';
import 'package:context_app/features/analytics/presentation/narration_analytics_observer.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/presentation/controllers/playback_state.dart';
import 'package:context_app/features/narration/presentation/controllers/player_controller.dart';
import 'package:context_app/features/narration/presentation/controllers/player_state.dart';
import 'package:context_app/features/narration/providers.dart';
import 'package:context_app/features/settings/domain/models/language.dart';

class _FakeAnalyticsService implements AnalyticsService {
  final List<AnalyticsEvent> recorded = <AnalyticsEvent>[];

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    recorded.add(event);
  }
}

class _FakeConsentRepository implements ConsentRepository {
  _FakeConsentRepository({this.enabled = true});

  bool enabled;

  @override
  Future<ConsentState> read() async {
    return ConsentState(enabled: enabled, updatedAt: DateTime(2026));
  }

  @override
  Future<void> write(ConsentState state) async {
    enabled = state.enabled;
  }

  @override
  Stream<ConsentState> watch() async* {
    yield await read();
  }
}

/// Test double for [PlayerController] that exposes [setState] so tests
/// can simulate narration player transitions directly.
class _StubPlayerController extends PlayerController {
  @override
  NarrationState build() {
    ref.onDispose(() {});
    return NarrationState.initial();
  }

  void setState(NarrationState next) {
    state = next;
  }
}

Place _place(String id) {
  return Place(
    id: id,
    name: 'Place $id',
    address: 'addr',
    location: const PlaceLocation(latitude: 0, longitude: 0),
    tags: const [],
    photos: const [],
    category: PlaceCategory.historicalCultural,
  );
}

NarrationContent _content({int sentenceCount = 10}) {
  // Each sentence is 10 chars so total length = sentenceCount * 10.
  final buffer = StringBuffer();
  for (var i = 0; i < sentenceCount; i++) {
    buffer.write('abcdefghi.');
  }
  return NarrationContent.create(buffer.toString(), language: Language.english);
}

NarrationState _stateWith({
  required Place place,
  required NarrationContent content,
  required PlaybackState state,
  required int charPosition,
}) {
  return NarrationState(
    place: place,
    content: content,
    playerState: PlayerState(state: state, currentCharPosition: charPosition),
  );
}

ProviderContainer _makeContainer({
  required _FakeAnalyticsService analytics,
  required _FakeConsentRepository consent,
  required SharedPreferences prefs,
  required _StubPlayerController controller,
}) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) async => prefs),
      analyticsServiceProvider.overrideWithValue(analytics),
      consentRepositoryProvider.overrideWithValue(consent),
      playerControllerProvider.overrideWith(() => controller),
      narrationAnalyticsObserverProvider.overrideWith(
        () => NarrationAnalyticsObserver(prefs: prefs),
      ),
    ],
  );
}

/// Container wired the way `main.dart` wires production: only
/// [sharedPreferencesProvider] is overridden, so [consentRepositoryProvider]
/// resolves through the real [SharedPrefsConsentRepository]. Regression cover
/// for the analytics blackout — every other test fakes the consent repository
/// and therefore never exercises this path.
ProviderContainer _makeProductionLikeContainer({
  required _FakeAnalyticsService analytics,
  required SharedPreferences prefs,
  required _StubPlayerController controller,
}) {
  return ProviderContainer(
    overrides: [
      // Same shape as main.dart: an async override, resolved eagerly outside.
      sharedPreferencesProvider.overrideWith((ref) async => prefs),
      analyticsServiceProvider.overrideWithValue(analytics),
      playerControllerProvider.overrideWith(() => controller),
      narrationAnalyticsObserverProvider.overrideWith(
        () => NarrationAnalyticsObserver(prefs: prefs),
      ),
    ],
  );
}

Future<void> _flush() async {
  // Allow the observer's async event logging to settle.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  test('given_player_starts_playing_first_time_when_observer_attached_'
      'then_emits_narration_started_with_is_first_lifetime_true', () async {
    final analytics = _FakeAnalyticsService();
    final consent = _FakeConsentRepository();
    final controller = _StubPlayerController();
    final container = _makeContainer(
      analytics: analytics,
      consent: consent,
      prefs: prefs,
      controller: controller,
    );
    addTearDown(container.dispose);

    container.read(narrationAnalyticsObserverProvider);
    controller.setState(
      _stateWith(
        place: _place('place-1'),
        content: _content(),
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();

    final started = analytics.recorded.whereType<NarrationStarted>();
    expect(started, hasLength(1));
    expect(started.single.placeId, 'place-1');
    expect(started.single.isFirstLifetimeNarration, isTrue);
    expect(prefs.getBool(kFirstStartedDoneKey), isTrue);
  });

  test('given_started_already_emitted_when_player_stays_playing_then_'
      'does_not_emit_duplicate_started', () async {
    final analytics = _FakeAnalyticsService();
    final consent = _FakeConsentRepository();
    final controller = _StubPlayerController();
    final container = _makeContainer(
      analytics: analytics,
      consent: consent,
      prefs: prefs,
      controller: controller,
    );
    addTearDown(container.dispose);
    container.read(narrationAnalyticsObserverProvider);
    final place = _place('place-1');
    final content = _content();

    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: 5,
      ),
    );
    await _flush();

    expect(analytics.recorded.whereType<NarrationStarted>(), hasLength(1));
  });

  test('given_player_progresses_to_30pct_when_observer_updates_then_'
      'emits_progress_milestone_25_exactly_once', () async {
    final analytics = _FakeAnalyticsService();
    final consent = _FakeConsentRepository();
    final controller = _StubPlayerController();
    final container = _makeContainer(
      analytics: analytics,
      consent: consent,
      prefs: prefs,
      controller: controller,
    );
    addTearDown(container.dispose);
    container.read(narrationAnalyticsObserverProvider);
    final place = _place('place-1');
    final content = _content();
    final totalChars = content.text.length;

    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: (totalChars * 0.30).round(),
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: (totalChars * 0.35).round(),
      ),
    );
    await _flush();

    final progress = analytics.recorded.whereType<NarrationProgress>();
    expect(progress, hasLength(1));
    expect(progress.single.milestone, 25);
  });

  test('given_player_seeks_back_from_60_to_30pct_when_milestone_25_'
      'already_emitted_then_does_not_re_emit', () async {
    final analytics = _FakeAnalyticsService();
    final consent = _FakeConsentRepository();
    final controller = _StubPlayerController();
    final container = _makeContainer(
      analytics: analytics,
      consent: consent,
      prefs: prefs,
      controller: controller,
    );
    addTearDown(container.dispose);
    container.read(narrationAnalyticsObserverProvider);
    final place = _place('place-1');
    final content = _content();
    final totalChars = content.text.length;

    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: (totalChars * 0.60).round(),
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: (totalChars * 0.30).round(),
      ),
    );
    await _flush();

    final progressEvents = analytics.recorded
        .whereType<NarrationProgress>()
        .toList();
    // 25 and 50 should fire exactly once on the jump to 60%.
    final milestones = progressEvents.map((e) => e.milestone).toSet();
    expect(milestones, {25, 50});
    expect(progressEvents.length, 2);
  });

  test('given_player_reaches_95pct_and_completes_when_observer_updates_'
      'then_emits_narration_completed', () async {
    final analytics = _FakeAnalyticsService();
    final consent = _FakeConsentRepository();
    final controller = _StubPlayerController();
    final container = _makeContainer(
      analytics: analytics,
      consent: consent,
      prefs: prefs,
      controller: controller,
    );
    addTearDown(container.dispose);
    container.read(narrationAnalyticsObserverProvider);
    final place = _place('place-1');
    final content = _content();
    final totalChars = content.text.length;

    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.completed,
        charPosition: totalChars,
      ),
    );
    await _flush();

    final completed = analytics.recorded
        .whereType<NarrationCompleted>()
        .toList();
    expect(completed, hasLength(1));
    expect(completed.single.completionRate, 100.0);
    expect(completed.single.listenDurationMs, totalChars);
    expect(completed.single.totalDurationMs, totalChars);
    // Once completed, no abandoned should fire.
    expect(analytics.recorded.whereType<NarrationAbandoned>(), isEmpty);
  });

  test('given_player_at_60pct_when_user_stops_then_emits_narration_'
      'abandoned_with_progress_pct_60', () async {
    final analytics = _FakeAnalyticsService();
    final consent = _FakeConsentRepository();
    final controller = _StubPlayerController();
    final container = _makeContainer(
      analytics: analytics,
      consent: consent,
      prefs: prefs,
      controller: controller,
    );
    addTearDown(container.dispose);
    container.read(narrationAnalyticsObserverProvider);
    final place = _place('place-1');
    final content = _content();
    final totalChars = content.text.length;

    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: (totalChars * 0.60).round(),
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.ready,
        charPosition: (totalChars * 0.60).round(),
      ),
    );
    await _flush();

    final abandoned = analytics.recorded
        .whereType<NarrationAbandoned>()
        .toList();
    expect(abandoned, hasLength(1));
    expect(abandoned.single.abandonReason, AbandonReason.userStop);
    expect(abandoned.single.progressPct, closeTo(60.0, 0.5));
  });

  test('given_consent_disabled_when_player_state_changes_then_no_events_'
      'emitted', () async {
    final analytics = _FakeAnalyticsService();
    final consent = _FakeConsentRepository(enabled: false);
    final controller = _StubPlayerController();
    final container = _makeContainer(
      analytics: analytics,
      consent: consent,
      prefs: prefs,
      controller: controller,
    );
    addTearDown(container.dispose);
    container.read(narrationAnalyticsObserverProvider);
    final place = _place('place-1');
    final content = _content();
    final totalChars = content.text.length;

    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: place,
        content: content,
        state: PlaybackState.completed,
        charPosition: totalChars,
      ),
    );
    await _flush();

    expect(analytics.recorded, isEmpty);
  });

  test('given_user_completed_one_narration_when_starts_another_then_'
      'is_first_lifetime_narration_is_false', () async {
    final analytics = _FakeAnalyticsService();
    final consent = _FakeConsentRepository();
    final controller = _StubPlayerController();
    final container = _makeContainer(
      analytics: analytics,
      consent: consent,
      prefs: prefs,
      controller: controller,
    );
    addTearDown(container.dispose);
    container.read(narrationAnalyticsObserverProvider);
    final firstPlace = _place('place-1');
    final firstContent = _content();
    final totalChars = firstContent.text.length;

    controller.setState(
      _stateWith(
        place: firstPlace,
        content: firstContent,
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: firstPlace,
        content: firstContent,
        state: PlaybackState.completed,
        charPosition: totalChars,
      ),
    );
    await _flush();

    // Second narration on a different place.
    final secondPlace = _place('place-2');
    final secondContent = _content(sentenceCount: 8);
    controller.setState(
      _stateWith(
        place: secondPlace,
        content: secondContent,
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();

    final startedEvents = analytics.recorded
        .whereType<NarrationStarted>()
        .toList();
    expect(startedEvents, hasLength(2));
    expect(startedEvents.first.isFirstLifetimeNarration, isTrue);
    expect(startedEvents.last.isFirstLifetimeNarration, isFalse);
  });

  test('given_user_switches_narration_mid_play_when_new_narration_starts_'
      'then_emits_abandoned_for_previous_narration', () async {
    final analytics = _FakeAnalyticsService();
    final consent = _FakeConsentRepository();
    final controller = _StubPlayerController();
    final container = _makeContainer(
      analytics: analytics,
      consent: consent,
      prefs: prefs,
      controller: controller,
    );
    addTearDown(container.dispose);
    container.read(narrationAnalyticsObserverProvider);
    final firstPlace = _place('place-1');
    final firstContent = _content();
    final firstTotal = firstContent.text.length;

    controller.setState(
      _stateWith(
        place: firstPlace,
        content: firstContent,
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();
    controller.setState(
      _stateWith(
        place: firstPlace,
        content: firstContent,
        state: PlaybackState.playing,
        charPosition: (firstTotal * 0.40).round(),
      ),
    );
    await _flush();

    final secondPlace = _place('place-2');
    final secondContent = _content(sentenceCount: 8);
    controller.setState(
      _stateWith(
        place: secondPlace,
        content: secondContent,
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();

    final abandoned = analytics.recorded
        .whereType<NarrationAbandoned>()
        .toList();
    expect(abandoned, hasLength(1));
    expect(abandoned.single.abandonReason, AbandonReason.switched);
    expect(abandoned.single.progressPct, closeTo(40.0, 1.0));
  });

  test('given_real_consent_repository_when_player_starts_playing_'
      'then_still_emits_narration_started', () async {
    final analytics = _FakeAnalyticsService();
    final controller = _StubPlayerController();
    final container = _makeProductionLikeContainer(
      analytics: analytics,
      prefs: prefs,
      controller: controller,
    );
    addTearDown(container.dispose);

    container.read(narrationAnalyticsObserverProvider);
    controller.setState(
      _stateWith(
        place: _place('place-1'),
        content: _content(),
        state: PlaybackState.playing,
        charPosition: 0,
      ),
    );
    await _flush();

    expect(
      analytics.recorded.whereType<NarrationStarted>(),
      hasLength(1),
      reason:
          'consent gate must not swallow the event on the first read of '
          'sharedPreferencesProvider',
    );
  });
}
