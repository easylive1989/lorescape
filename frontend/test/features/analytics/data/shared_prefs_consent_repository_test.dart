import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:context_app/features/analytics/data/shared_prefs_consent_repository.dart';
import 'package:context_app/features/analytics/domain/models/consent_state.dart';

void main() {
  group('SharedPrefsConsentRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('given_no_existing_pref_when_read_then_returns_default_on_'
        'consent_state', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsConsentRepository(prefs);

      final state = await repository.read();

      expect(state.enabled, isTrue);
      expect(state.updatedAt, isA<DateTime>());
      await repository.dispose();
    });

    test('given_existing_pref_disabled_when_read_then_returns_disabled_'
        'state_with_persisted_timestamp', () async {
      final timestamp = DateTime(2026, 3, 15, 12);
      SharedPreferences.setMockInitialValues(<String, Object>{
        kConsentEnabledKey: false,
        kConsentUpdatedAtKey: timestamp.millisecondsSinceEpoch,
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsConsentRepository(prefs);

      final state = await repository.read();

      expect(state.enabled, isFalse);
      expect(
        state.updatedAt.millisecondsSinceEpoch,
        timestamp.millisecondsSinceEpoch,
      );
      await repository.dispose();
    });

    test('given_consent_state_when_write_then_persists_enabled_and_'
        'updated_at_to_shared_prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsConsentRepository(prefs);
      final timestamp = DateTime.utc(2026, 5, 1);
      final newState = ConsentState(enabled: false, updatedAt: timestamp);

      await repository.write(newState);

      expect(prefs.getBool(kConsentEnabledKey), isFalse);
      expect(
        prefs.getInt(kConsentUpdatedAtKey),
        timestamp.millisecondsSinceEpoch,
      );
      await repository.dispose();
    });

    test('given_repository_when_watch_called_then_first_emission_is_'
        'current_state', () async {
      final timestamp = DateTime(2026, 2, 2);
      SharedPreferences.setMockInitialValues(<String, Object>{
        kConsentEnabledKey: false,
        kConsentUpdatedAtKey: timestamp.millisecondsSinceEpoch,
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsConsentRepository(prefs);

      final first = await repository.watch().first;

      expect(first.enabled, isFalse);
      expect(
        first.updatedAt.millisecondsSinceEpoch,
        timestamp.millisecondsSinceEpoch,
      );
      await repository.dispose();
    });

    test(
      'given_watcher_subscribed_when_write_called_then_emits_new_state',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repository = SharedPrefsConsentRepository(prefs);
        final emissions = <ConsentState>[];
        final subscription = repository.watch().listen(emissions.add);

        // Allow first (current) emission to fire.
        await Future<void>.delayed(Duration.zero);
        final newState = ConsentState(
          enabled: false,
          updatedAt: DateTime.utc(2026, 6, 1),
        );
        await repository.write(newState);
        await Future<void>.delayed(Duration.zero);

        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.last, newState);
        await subscription.cancel();
        await repository.dispose();
      },
    );

    test(
      'given_two_watchers_when_write_called_then_both_receive_new_state',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repository = SharedPrefsConsentRepository(prefs);
        final firstEmissions = <ConsentState>[];
        final secondEmissions = <ConsentState>[];
        final sub1 = repository.watch().listen(firstEmissions.add);
        final sub2 = repository.watch().listen(secondEmissions.add);

        await Future<void>.delayed(Duration.zero);
        final newState = ConsentState(
          enabled: false,
          updatedAt: DateTime.utc(2026, 7, 1),
        );
        await repository.write(newState);
        await Future<void>.delayed(Duration.zero);

        expect(firstEmissions.last, newState);
        expect(secondEmissions.last, newState);
        await sub1.cancel();
        await sub2.cancel();
        await repository.dispose();
      },
    );
  });
}
