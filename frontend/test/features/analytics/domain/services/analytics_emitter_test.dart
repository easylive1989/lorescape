import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/domain/services/analytics_emitter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/recording_analytics_service.dart';

void main() {
  group('AnalyticsEmitter', () {
    test('given consent is enabled, when emitting an event, '
        'then it reaches the analytics service', () async {
      final service = RecordingAnalyticsService();
      final emitter = _emitter(service, consent: true);

      await emitter.emitAndWait(_event());

      expect(service.types, ['hooks_requested']);
    });

    test('given consent is disabled, when emitting an event, '
        'then nothing reaches the analytics service', () async {
      final service = RecordingAnalyticsService();
      final emitter = _emitter(service, consent: false);

      await emitter.emitAndWait(_event());

      expect(service.events, isEmpty);
    });

    test(
      'given the transport throws, when emitting fire-and-forget, '
      'then the caller is not affected and the failure is swallowed',
      () async {
        final service = RecordingAnalyticsService(throwOnLog: true);
        final emitter = _emitter(service, consent: true);

        // 這正是 F13 T1a 的形狀：emit 沒人 await，例外若逸出就會落進
        // unhandled async gap（當年因此兩個月完全沒有資料）。
        emitter.emit(_event());
        await Future<void>.delayed(Duration.zero);

        expect(service.events, hasLength(1));
      },
    );

    test('given the consent lookup itself throws, when emitting, '
        'then the caller still is not affected', () async {
      final service = RecordingAnalyticsService();
      final emitter = AnalyticsEmitter(
        consentEnabled: () async => throw StateError('prefs not ready'),
        service: service,
      );

      emitter.emit(_event());
      await Future<void>.delayed(Duration.zero);

      expect(service.events, isEmpty);
    });
  });
}

AnalyticsEmitter _emitter(
  RecordingAnalyticsService service, {
  required bool consent,
}) {
  return AnalyticsEmitter(
    consentEnabled: () async => consent,
    service: service,
  );
}

AnalyticsEvent _event() =>
    HooksRequested(placeId: 'place-1', language: 'zh-TW');
