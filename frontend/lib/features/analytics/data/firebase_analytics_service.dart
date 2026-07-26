import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logging/logging.dart';

import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/domain/services/analytics_service.dart';

final Logger _log = Logger('FirebaseAnalyticsService');

/// [AnalyticsService] implementation backed by the Firebase Analytics
/// SDK.
///
/// Firebase Analytics imposes the following constraints, which this
/// service satisfies via [firebaseParametersFor]:
///
///   * Parameter values may only be `String` or `num` — `bool` is
///     unsupported and must be coerced to `int` (true → 1, false → 0).
///   * String values are capped at 100 characters.
///   * Each event may carry at most 25 parameters.
///
/// Transport failures are logged but never propagated to the caller;
/// the underlying SDK handles offline queueing, batching, and retry.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this._firebase);

  final FirebaseAnalytics _firebase;

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    try {
      await _firebase.logEvent(
        name: event.type,
        parameters: firebaseParametersFor(event),
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to log analytics event ${event.type}',
        error,
        stackTrace,
      );
    }
  }
}

/// Converts [event] into a `Map<String, Object>` suitable for
/// [FirebaseAnalytics.logEvent].
///
/// [AnalyticsEvent.eventId] and [AnalyticsEvent.occurredAt] are always
/// included, followed by the event family's [AnalyticsEvent.envelope] (e.g.
/// `narration_id`) and the subtype's [AnalyticsEvent.payload]. `bool` values
/// are coerced to `int` and null values dropped, so the result satisfies the
/// Firebase Analytics parameter contract.
///
/// 刻意由 `envelope()` / `payload()` 推導而不是逐型別列欄位：新增事件只要定義
/// 好 payload 就會自動送出，不必記得回來改這裡。
///
/// Exposed as a top-level function so it can be unit-tested without
/// instantiating the Firebase SDK.
Map<String, Object> firebaseParametersFor(AnalyticsEvent event) {
  final Map<String, Object> parameters = {
    'event_id': event.eventId,
    'occurred_at': event.occurredAt.toIso8601String(),
  };

  final wireFields = <String, dynamic>{...event.envelope(), ...event.payload()};
  for (final entry in wireFields.entries) {
    final value = entry.value;
    if (value == null) continue;
    parameters[entry.key] = value is bool ? (value ? 1 : 0) : value as Object;
  }
  return parameters;
}
