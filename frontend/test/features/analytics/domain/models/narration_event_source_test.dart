import 'package:context_app/features/analytics/domain/models/narration_event_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NarrationEventSource', () {
    group('wireName', () {
      test('should map each enum value to its snake_case wire id', () {
        expect(NarrationEventSource.explore.wireName, 'explore');
        expect(NarrationEventSource.journey.wireName, 'journey');
        expect(NarrationEventSource.onboarding.wireName, 'onboarding');
      });

      test('should cover every enum value (exhaustive)', () {
        for (final source in NarrationEventSource.values) {
          expect(
            source.wireName,
            isNotEmpty,
            reason: 'No wireName mapping for $source',
          );
        }
      });
    });
  });
}
