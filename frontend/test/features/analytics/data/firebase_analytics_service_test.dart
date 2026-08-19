import 'package:flutter_test/flutter_test.dart';

import 'package:context_app/features/analytics/data/firebase_analytics_service.dart';
import 'package:context_app/features/analytics/domain/models/abandon_reason.dart';
import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/domain/models/narration_event_source.dart';

void main() {
  group('firebaseParametersFor', () {
    test(
      'given_narration_started_with_first_lifetime_true_'
      'when_to_firebase_params_then_bool_converted_to_int_one',
      () {
        final event = NarrationStarted(
          eventId: 'e1',
          narrationId: 'n1',
          placeId: 'p1',
          source: NarrationEventSource.explore,
          isFirstLifetimeNarration: true,
          occurredAt: DateTime.utc(2026, 1, 1),
        );

        final params = firebaseParametersFor(event);

        expect(params['is_first_lifetime_narration'], 1);
        expect(params['is_first_lifetime_narration'], isA<int>());
      },
    );

    test(
      'given_narration_started_when_to_firebase_params_then_includes_'
      'event_id_narration_id_occurred_at_place_id_source_and_'
      'first_lifetime_flag_as_int',
      () {
        final event = NarrationStarted(
          eventId: 'e1',
          narrationId: 'n1',
          placeId: 'p1',
          source: NarrationEventSource.journey,
          isFirstLifetimeNarration: false,
          occurredAt: DateTime.utc(2026, 1, 1),
        );

        final params = firebaseParametersFor(event);

        expect(params, {
          'event_id': 'e1',
          'narration_id': 'n1',
          'occurred_at': '2026-01-01T00:00:00.000Z',
          'place_id': 'p1',
          'source': 'journey',
          'is_first_lifetime_narration': 0,
        });
      },
    );

    test(
      'given_narration_progress_when_to_firebase_params_then_includes_'
      'milestone_elapsed_total_duration',
      () {
        final event = NarrationProgress(
          eventId: 'e2',
          narrationId: 'n1',
          milestone: 50,
          elapsedMs: 60000,
          totalDurationMs: 120000,
          occurredAt: DateTime.utc(2026, 1, 1),
        );

        final params = firebaseParametersFor(event);

        expect(params, {
          'event_id': 'e2',
          'narration_id': 'n1',
          'occurred_at': '2026-01-01T00:00:00.000Z',
          'milestone': 50,
          'elapsed_ms': 60000,
          'total_duration_ms': 120000,
        });
      },
    );

    test(
      'given_narration_completed_when_to_firebase_params_then_includes_'
      'durations_and_completion_rate',
      () {
        final event = NarrationCompleted(
          eventId: 'e3',
          narrationId: 'n1',
          totalDurationMs: 100000,
          listenDurationMs: 96000,
          completionRate: 96.0,
          occurredAt: DateTime.utc(2026, 1, 1),
        );

        final params = firebaseParametersFor(event);

        expect(params, {
          'event_id': 'e3',
          'narration_id': 'n1',
          'occurred_at': '2026-01-01T00:00:00.000Z',
          'total_duration_ms': 100000,
          'listen_duration_ms': 96000,
          'completion_rate': 96.0,
        });
      },
    );

    test(
      'given_narration_abandoned_when_to_firebase_params_then_'
      'abandon_reason_serialised_as_wire_name',
      () {
        final event = NarrationAbandoned(
          eventId: 'e4',
          narrationId: 'n1',
          abandonReason: AbandonReason.routeChange,
          elapsedMs: 30000,
          progressPct: 42.5,
          occurredAt: DateTime.utc(2026, 1, 1),
        );

        final params = firebaseParametersFor(event);

        expect(params['abandon_reason'], 'route_change');
        expect(params['elapsed_ms'], 30000);
        expect(params['progress_pct'], 42.5);
      },
    );

    test(
      'given_any_event_when_to_firebase_params_then_no_value_is_bool_'
      'and_all_string_values_are_under_100_chars',
      () {
        final events = <AnalyticsEvent>[
          NarrationStarted(
            narrationId: 'n1',
            placeId: 'p1',
            source: NarrationEventSource.explore,
            isFirstLifetimeNarration: true,
          ),
          NarrationProgress(
            narrationId: 'n1',
            milestone: 25,
            elapsedMs: 1,
            totalDurationMs: 2,
          ),
          NarrationCompleted(
            narrationId: 'n1',
            totalDurationMs: 1,
            listenDurationMs: 1,
            completionRate: 100,
          ),
          NarrationAbandoned(
            narrationId: 'n1',
            abandonReason: AbandonReason.userStop,
            elapsedMs: 1,
            progressPct: 1,
          ),
        ];

        for (final event in events) {
          final params = firebaseParametersFor(event);
          for (final entry in params.entries) {
            expect(
              entry.value,
              isNot(isA<bool>()),
              reason: '${event.type}.${entry.key} must not be bool',
            );
            if (entry.value is String) {
              expect(
                (entry.value as String).length,
                lessThanOrEqualTo(100),
                reason: '${event.type}.${entry.key} string > 100 chars',
              );
            }
          }
        }
      },
    );

    test(
      'given_any_event_when_to_firebase_params_then_param_count_is_'
      'within_25',
      () {
        final events = <AnalyticsEvent>[
          NarrationStarted(
            narrationId: 'n1',
            placeId: 'p1',
            source: NarrationEventSource.explore,
            isFirstLifetimeNarration: false,
          ),
          NarrationProgress(
            narrationId: 'n1',
            milestone: 75,
            elapsedMs: 10,
            totalDurationMs: 20,
          ),
          NarrationCompleted(
            narrationId: 'n1',
            totalDurationMs: 1,
            listenDurationMs: 1,
            completionRate: 100,
          ),
          NarrationAbandoned(
            narrationId: 'n1',
            abandonReason: AbandonReason.killed,
            elapsedMs: 1,
            progressPct: 1,
          ),
        ];

        for (final event in events) {
          final params = firebaseParametersFor(event);
          expect(
            params.length,
            lessThanOrEqualTo(25),
            reason: '${event.type} param count exceeds Firebase limit',
          );
        }
      },
    );
  });
}
