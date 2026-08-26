import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:context_app/features/analytics/domain/models/abandon_reason.dart';
import 'package:context_app/features/analytics/domain/models/hooks_outcome.dart';
import 'package:context_app/features/analytics/domain/models/narration_event_source.dart';

const Uuid _uuid = Uuid();

/// An analytics event captured by the Lorescape client.
///
/// All concrete subtypes carry an [eventId] (UUID v4) and the [occurredAt]
/// timestamp of when the event was created. Use [toJson] to flatten the event
/// into the envelope payload.
///
/// Events come in families ([NarrationAnalyticsEvent],
/// [StoryHookAnalyticsEvent]); each family adds its own shared identifiers via
/// [envelope]. `narration_id` lives on the narration family only——鉤子事件發生
/// 在 narration 產生之前，帶一個空的 narration_id 只會讓報表誤導。
sealed class AnalyticsEvent extends Equatable {
  final String eventId;
  final DateTime occurredAt;

  AnalyticsEvent({String? eventId, DateTime? occurredAt})
    : eventId = eventId ?? _uuid.v4(),
      occurredAt = occurredAt ?? DateTime.now();

  /// Wire-format event name (matches the analytics schema).
  String get type;

  /// Serialise the event into the flat wire payload.
  ///
  /// Includes `event_id`, `event_type`, `occurred_at`, the family's
  /// [envelope] and the subtype-specific [payload]. Keys are snake_case.
  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'event_type': type,
      'occurred_at': occurredAt.toIso8601String(),
      ...envelope(),
      ...payload(),
    };
  }

  /// Identifiers shared by every event in the same family.
  Map<String, dynamic> envelope() => const {};

  /// Subtype-specific payload merged into [toJson].
  Map<String, dynamic> payload();

  @override
  List<Object?> get props => [eventId, occurredAt];
}

/// Events describing one narration playback; all carry its [narrationId].
sealed class NarrationAnalyticsEvent extends AnalyticsEvent {
  final String narrationId;

  NarrationAnalyticsEvent({
    super.eventId,
    required this.narrationId,
    super.occurredAt,
  });

  @override
  Map<String, dynamic> envelope() => {'narration_id': narrationId};

  @override
  List<Object?> get props => [...super.props, narrationId];
}

/// Fired when a narration begins playing.
class NarrationStarted extends NarrationAnalyticsEvent {
  final String placeId;
  final NarrationEventSource source;
  final bool isFirstLifetimeNarration;

  NarrationStarted({
    super.eventId,
    required super.narrationId,
    required this.placeId,
    required this.source,
    required this.isFirstLifetimeNarration,
    super.occurredAt,
  });

  @override
  String get type => 'narration_started';

  @override
  Map<String, dynamic> payload() => {
    'place_id': placeId,
    'source': source.wireName,
    'is_first_lifetime_narration': isFirstLifetimeNarration,
  };

  @override
  List<Object?> get props => [
    ...super.props,
    placeId,
    source,
    isFirstLifetimeNarration,
  ];
}

/// Fired when the listener crosses a 25 / 50 / 75 progress milestone.
///
/// Seek does NOT backfill skipped milestones — each milestone fires at
/// most once per narration.
class NarrationProgress extends NarrationAnalyticsEvent {
  final int milestone;
  final int elapsedMs;
  final int totalDurationMs;

  NarrationProgress({
    super.eventId,
    required super.narrationId,
    required this.milestone,
    required this.elapsedMs,
    required this.totalDurationMs,
    super.occurredAt,
  });

  @override
  String get type => 'narration_progress';

  @override
  Map<String, dynamic> payload() => {
    'milestone': milestone,
    'elapsed_ms': elapsedMs,
    'total_duration_ms': totalDurationMs,
  };

  @override
  List<Object?> get props => [
    ...super.props,
    milestone,
    elapsedMs,
    totalDurationMs,
  ];
}

/// Fired when a narration reaches the completion threshold
/// (Story 1 AC3, default >= 95% of total duration).
class NarrationCompleted extends NarrationAnalyticsEvent {
  final int totalDurationMs;
  final int listenDurationMs;
  final double completionRate;

  NarrationCompleted({
    super.eventId,
    required super.narrationId,
    required this.totalDurationMs,
    required this.listenDurationMs,
    required this.completionRate,
    super.occurredAt,
  });

  @override
  String get type => 'narration_completed';

  @override
  Map<String, dynamic> payload() => {
    'total_duration_ms': totalDurationMs,
    'listen_duration_ms': listenDurationMs,
    'completion_rate': completionRate,
  };

  @override
  List<Object?> get props => [
    ...super.props,
    totalDurationMs,
    listenDurationMs,
    completionRate,
  ];
}

/// Fired when playback ends before the completion threshold.
///
/// [abandonReason] captures the cause; [progressPct] is the percentage
/// listened (0~100) at the time of abandonment.
class NarrationAbandoned extends NarrationAnalyticsEvent {
  final AbandonReason abandonReason;
  final int elapsedMs;
  final double progressPct;

  NarrationAbandoned({
    super.eventId,
    required super.narrationId,
    required this.abandonReason,
    required this.elapsedMs,
    required this.progressPct,
    super.occurredAt,
  });

  @override
  String get type => 'narration_abandoned';

  @override
  Map<String, dynamic> payload() => {
    'abandon_reason': abandonReason.wireName,
    'elapsed_ms': elapsedMs,
    'progress_pct': progressPct,
  };

  @override
  List<Object?> get props => [
    ...super.props,
    abandonReason,
    elapsedMs,
    progressPct,
  ];
}

/// Events describing the story-hook step, which runs *before* any narration
/// exists — hence no `narration_id`.
///
/// 這一段過去完全沒有埋點：GA4 上從 `screen_view` 到 `narration_started`
/// 之間是斷的，「產生了角度但沒人想聽」看不出來。
sealed class StoryHookAnalyticsEvent extends AnalyticsEvent {
  final String placeId;

  /// 語言標籤（如 `zh-TW`）——鉤子是按語言分別生成與快取的。
  final String language;

  StoryHookAnalyticsEvent({
    super.eventId,
    required this.placeId,
    required this.language,
    super.occurredAt,
  });

  @override
  Map<String, dynamic> envelope() => {
    'place_id': placeId,
    'language': language,
  };

  @override
  List<Object?> get props => [...super.props, placeId, language];
}

/// Fired when the app asks the backend for a place's story hooks.
///
/// 這是漏斗的分母；與 [HooksReturned] 分開是因為請求可能永遠不回來。
class HooksRequested extends StoryHookAnalyticsEvent {
  HooksRequested({
    super.eventId,
    required super.placeId,
    required super.language,
    super.occurredAt,
  });

  @override
  String get type => 'hooks_requested';

  @override
  Map<String, dynamic> payload() => const {};
}

/// Fired when a hook request settles, successfully or not.
class HooksReturned extends StoryHookAnalyticsEvent {
  final HooksOutcome outcome;

  /// 回傳的角度數量；非 [HooksOutcome.success] 時為 0。
  final int hookCount;

  HooksReturned({
    super.eventId,
    required super.placeId,
    required super.language,
    required this.outcome,
    required this.hookCount,
    super.occurredAt,
  });

  @override
  String get type => 'hooks_returned';

  @override
  Map<String, dynamic> payload() => {
    'outcome': outcome.wireName,
    'hook_count': hookCount,
  };

  @override
  List<Object?> get props => [...super.props, outcome, hookCount];
}

/// Fired when the user commits to listening from this screen.
///
/// [hookIndex] 為 null 代表走「直接聽故事」（沒挑角度，或後端沒給角度）——
/// 用 `selected_default` 在 GA4 上直接分流，不必自己判斷 null。
class HookSelected extends StoryHookAnalyticsEvent {
  final int? hookIndex;
  final int hookCount;

  HookSelected({
    super.eventId,
    required super.placeId,
    required super.language,
    required this.hookIndex,
    required this.hookCount,
    super.occurredAt,
  });

  @override
  String get type => 'hook_selected';

  @override
  Map<String, dynamic> payload() => {
    'hook_index': hookIndex,
    'hook_count': hookCount,
    'selected_default': hookIndex == null,
  };

  @override
  List<Object?> get props => [...super.props, hookIndex, hookCount];
}

/// Events for expanding a selected hook into the full playable story.
///
/// [generationId] joins the request and result, including retries for the
/// same place. This closes the analytics gap between `hook_selected` and
/// `narration_started` without pretending a failed generation was a listen.
sealed class StoryGenerationAnalyticsEvent extends AnalyticsEvent {
  final String generationId;
  final String placeId;
  final String language;
  final bool usedHook;

  StoryGenerationAnalyticsEvent({
    super.eventId,
    required this.generationId,
    required this.placeId,
    required this.language,
    required this.usedHook,
    super.occurredAt,
  });

  @override
  Map<String, dynamic> envelope() => {
    'generation_id': generationId,
    'place_id': placeId,
    'language': language,
    'used_hook': usedHook,
  };

  @override
  List<Object?> get props => [
    ...super.props,
    generationId,
    placeId,
    language,
    usedHook,
  ];
}

/// Fired immediately before full-story generation starts.
class StoryGenerationRequested extends StoryGenerationAnalyticsEvent {
  StoryGenerationRequested({
    super.eventId,
    required super.generationId,
    required super.placeId,
    required super.language,
    required super.usedHook,
    super.occurredAt,
  });

  @override
  String get type => 'story_generation_requested';

  @override
  Map<String, dynamic> payload() => const {};
}

/// Fired when full-story generation succeeds or fails.
///
/// [outcome] is `success` or the stable wire name of the mapped generation
/// error. Keeping the failure category on the result makes quota, network,
/// source-quality and backend failures separable in the first-value funnel.
class StoryGenerationReturned extends StoryGenerationAnalyticsEvent {
  final String outcome;
  final int latencyMs;
  final int contentLength;

  StoryGenerationReturned({
    super.eventId,
    required super.generationId,
    required super.placeId,
    required super.language,
    required super.usedHook,
    required this.outcome,
    required this.latencyMs,
    required this.contentLength,
    super.occurredAt,
  });

  @override
  String get type => 'story_generation_returned';

  @override
  Map<String, dynamic> payload() => {
    'outcome': outcome,
    'latency_ms': latencyMs,
    'content_length': contentLength,
  };

  @override
  List<Object?> get props => [
    ...super.props,
    outcome,
    latencyMs,
    contentLength,
  ];
}
