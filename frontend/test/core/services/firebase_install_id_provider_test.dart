import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:context_app/core/services/firebase_install_id_provider.dart';

void main() {
  group('FirebaseInstallIdProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('given_firebase_returns_valid_id_when_get_called_then_returns_'
        'firebase_id', () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = FirebaseInstallIdProvider(
        fetchAppInstanceId: () async => 'firebase-install-id-abc',
        prefs: prefs,
      );

      final id = await provider.get();

      expect(id, 'firebase-install-id-abc');
    });

    test('given_firebase_returns_null_when_get_called_then_falls_back_to_'
        'shared_prefs', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kInstallIdFallbackKey: 'persisted-fallback-id',
      });
      final prefs = await SharedPreferences.getInstance();
      final provider = FirebaseInstallIdProvider(
        fetchAppInstanceId: () async => null,
        prefs: prefs,
      );

      final id = await provider.get();

      expect(id, 'persisted-fallback-id');
    });

    test('given_firebase_returns_null_and_no_existing_fallback_when_get_'
        'called_then_generates_and_persists_uuid', () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = FirebaseInstallIdProvider(
        fetchAppInstanceId: () async => null,
        prefs: prefs,
      );

      final id = await provider.get();

      expect(id, isNotEmpty);
      expect(id.length, greaterThanOrEqualTo(32));
      expect(prefs.getString(kInstallIdFallbackKey), id);
    });

    test('given_get_called_multiple_times_when_firebase_returns_valid_id_'
        'then_firebase_called_only_once', () async {
      final prefs = await SharedPreferences.getInstance();
      var fetchCount = 0;
      final provider = FirebaseInstallIdProvider(
        fetchAppInstanceId: () async {
          fetchCount += 1;
          return 'firebase-install-id-xyz';
        },
        prefs: prefs,
      );

      final first = await provider.get();
      final second = await provider.get();
      final third = await provider.get();

      expect(first, 'firebase-install-id-xyz');
      expect(second, first);
      expect(third, first);
      expect(fetchCount, 1);
    });

    test('given_firebase_returns_empty_string_when_get_called_then_falls_'
        'back_to_uuid_generation', () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = FirebaseInstallIdProvider(
        fetchAppInstanceId: () async => '',
        prefs: prefs,
      );

      final id = await provider.get();

      expect(id, isNotEmpty);
      expect(prefs.getString(kInstallIdFallbackKey), id);
    });
  });
}
