import 'package:context_app/features/analytics/domain/models/abandon_reason.dart';
import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/domain/models/hooks_outcome.dart';
import 'package:context_app/features/analytics/domain/models/narration_event_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsEvent', () {
    group('NarrationStarted', () {
      test('should auto-generate a UUID v4 eventId when none supplied', () {
        final event = NarrationStarted(
          narrationId: 'n1',
          placeId: 'p1',
          source: NarrationEventSource.explore,
          isFirstLifetimeNarration: true,
        );

        // UUID v4: 36 chars, version digit in the 15th position.
        expect(event.eventId, hasLength(36));
        expect(event.eventId[14], '4');
      });

      test('should stamp occurredAt with a current timestamp by default', () {
        final before = DateTime.now();
        final event = NarrationStarted(
          narrationId: 'n1',
          placeId: 'p1',
          source: NarrationEventSource.explore,
          isFirstLifetimeNarration: false,
        );
        final after = DateTime.now();

        expect(
          event.occurredAt.isBefore(
            before.subtract(const Duration(seconds: 1)),
          ),
          isFalse,
        );
        expect(
          event.occurredAt.isAfter(after.add(const Duration(seconds: 1))),
          isFalse,
        );
      });

      test('should expose narration_started as its wire type', () {
        final event = NarrationStarted(
          narrationId: 'n1',
          placeId: 'p1',
          source: NarrationEventSource.journey,
          isFirstLifetimeNarration: false,
        );

        expect(event.type, 'narration_started');
      });

      test('should serialise envelope + subtype fields with snake_case', () {
        final event = NarrationStarted(
          eventId: 'fixed-id',
          narrationId: 'n1',
          placeId: 'p1',
          source: NarrationEventSource.dailyStory,
          isFirstLifetimeNarration: true,
          occurredAt: DateTime.utc(2026, 1, 1),
        );

        expect(event.toJson(), {
          'event_id': 'fixed-id',
          'event_type': 'narration_started',
          'narration_id': 'n1',
          'occurred_at': '2026-01-01T00:00:00.000Z',
          'place_id': 'p1',
          'source': 'daily_story',
          'is_first_lifetime_narration': true,
        });
      });

      test('should treat two events with identical fields as equal', () {
        final timestamp = DateTime.utc(2026, 1, 1);
        final a = NarrationStarted(
          eventId: 'e1',
          narrationId: 'n1',
          placeId: 'p1',
          source: NarrationEventSource.explore,
          isFirstLifetimeNarration: true,
          occurredAt: timestamp,
        );
        final b = NarrationStarted(
          eventId: 'e1',
          narrationId: 'n1',
          placeId: 'p1',
          source: NarrationEventSource.explore,
          isFirstLifetimeNarration: true,
          occurredAt: timestamp,
        );

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });
    });

    group('NarrationProgress', () {
      test('should serialise milestone, elapsed and total duration', () {
        final event = NarrationProgress(
          eventId: 'e2',
          narrationId: 'n1',
          milestone: 50,
          elapsedMs: 60000,
          totalDurationMs: 120000,
          occurredAt: DateTime.utc(2026, 1, 1),
        );

        expect(event.toJson(), {
          'event_id': 'e2',
          'event_type': 'narration_progress',
          'narration_id': 'n1',
          'occurred_at': '2026-01-01T00:00:00.000Z',
          'milestone': 50,
          'elapsed_ms': 60000,
          'total_duration_ms': 120000,
        });
      });
    });

    group('NarrationCompleted', () {
      test('should serialise listen / total durations and completion %', () {
        final event = NarrationCompleted(
          eventId: 'e3',
          narrationId: 'n1',
          totalDurationMs: 100000,
          listenDurationMs: 96000,
          completionRate: 96.0,
          occurredAt: DateTime.utc(2026, 1, 1),
        );

        expect(event.type, 'narration_completed');
        expect(event.toJson(), {
          'event_id': 'e3',
          'event_type': 'narration_completed',
          'narration_id': 'n1',
          'occurred_at': '2026-01-01T00:00:00.000Z',
          'total_duration_ms': 100000,
          'listen_duration_ms': 96000,
          'completion_rate': 96.0,
        });
      });
    });

    group('NarrationAbandoned', () {
      test('should serialise reason, elapsed and progress percentage', () {
        final event = NarrationAbandoned(
          eventId: 'e4',
          narrationId: 'n1',
          abandonReason: AbandonReason.backgrounded,
          elapsedMs: 30000,
          progressPct: 42.5,
          occurredAt: DateTime.utc(2026, 1, 1),
        );

        expect(event.type, 'narration_abandoned');
        expect(event.toJson(), {
          'event_id': 'e4',
          'event_type': 'narration_abandoned',
          'narration_id': 'n1',
          'occurred_at': '2026-01-01T00:00:00.000Z',
          'abandon_reason': 'backgrounded',
          'elapsed_ms': 30000,
          'progress_pct': 42.5,
        });
      });
    });

    group('sealed exhaustiveness', () {
      test('should let callers pattern-match every subtype', () {
        final events = <NarrationAnalyticsEvent>[
          NarrationStarted(
            narrationId: 'n',
            placeId: 'p',
            source: NarrationEventSource.explore,
            isFirstLifetimeNarration: false,
          ),
          NarrationProgress(
            narrationId: 'n',
            milestone: 25,
            elapsedMs: 1,
            totalDurationMs: 2,
          ),
          NarrationCompleted(
            narrationId: 'n',
            totalDurationMs: 1,
            listenDurationMs: 1,
            completionRate: 100,
          ),
          NarrationAbandoned(
            narrationId: 'n',
            abandonReason: AbandonReason.userStop,
            elapsedMs: 1,
            progressPct: 1,
          ),
        ];

        final types = events
            .map(
              (e) => switch (e) {
                NarrationStarted() => 'started',
                NarrationProgress() => 'progress',
                NarrationCompleted() => 'completed',
                NarrationAbandoned() => 'abandoned',
              },
            )
            .toList();

        expect(types, ['started', 'progress', 'completed', 'abandoned']);
      });

      test('should let callers pattern-match every story-hook subtype', () {
        final events = <StoryHookAnalyticsEvent>[
          HooksRequested(placeId: 'p', language: 'zh-TW'),
          HooksReturned(
            placeId: 'p',
            language: 'zh-TW',
            outcome: HooksOutcome.success,
            hookCount: 3,
          ),
          HookSelected(
            placeId: 'p',
            language: 'zh-TW',
            hookIndex: 1,
            hookCount: 3,
          ),
        ];

        final types = events
            .map(
              (e) => switch (e) {
                HooksRequested() => 'requested',
                HooksReturned() => 'returned',
                HookSelected() => 'selected',
              },
            )
            .toList();

        expect(types, ['requested', 'returned', 'selected']);
      });
    });

    group('story hook events', () {
      test(
        'given three hooks were returned, when serialising, then the place, '
        'language, outcome and count are on the wire without a narration id',
        () {
          final event = HooksReturned(
            eventId: 'e1',
            placeId: 'place-1',
            language: 'zh-TW',
            outcome: HooksOutcome.success,
            hookCount: 3,
            occurredAt: DateTime.utc(2026, 7, 26, 12),
          );

          expect(event.type, 'hooks_returned');
          expect(event.toJson(), {
            'event_id': 'e1',
            'event_type': 'hooks_returned',
            'occurred_at': '2026-07-26T12:00:00.000Z',
            'place_id': 'place-1',
            'language': 'zh-TW',
            'outcome': 'success',
            'hook_count': 3,
          });
          // 鉤子發生在 narration 產生之前，帶 narration_id 只會誤導報表。
          expect(event.toJson().containsKey('narration_id'), isFalse);
        },
      );

      test(
        'given the user picked the second hook, when serialising, then the '
        'index is kept and selected_default is false',
        () {
          final event = HookSelected(
            placeId: 'place-1',
            language: 'en-US',
            hookIndex: 1,
            hookCount: 3,
          );

          expect(event.type, 'hook_selected');
          expect(event.payload(), {
            'hook_index': 1,
            'hook_count': 3,
            'selected_default': false,
          });
        },
      );

      test(
        'given the user listened without picking a hook, when serialising, '
        'then the index is null and selected_default is true',
        () {
          final event = HookSelected(
            placeId: 'place-1',
            language: 'en-US',
            hookIndex: null,
            hookCount: 0,
          );

          expect(event.payload(), {
            'hook_index': null,
            'hook_count': 0,
            'selected_default': true,
          });
        },
      );
    });
  });
}
