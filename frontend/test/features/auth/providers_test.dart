// Auth providers expose the signed-in state to the rest of the app.
// These tests pin the user-observable contract:
//   * a freshly-launched, signed-out container reports isSignedIn=false
//   * a session restored from disk (service.currentUser non-null before
//     the auth stream emits) is reflected immediately, without flicker
//   * signing in via Google or Apple transitions the providers to
//     signed-in and exposes the new user
//   * signing out clears the providers
//   * a failed sign-in propagates AuthFailureException and leaves the
//     providers untouched

import 'package:context_app/features/auth/domain/models/auth_user.dart';
import 'package:context_app/features/auth/domain/services/auth_service.dart';
import 'package:context_app/features/auth/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_service.dart';

void main() {
  group('auth providers — signed-out launch', () {
    test('given no user, when the app reads the providers, '
        'then currentUser is null and isSignedIn is false', () {
      final fake = FakeAuthService();
      addTearDown(fake.dispose);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(currentUserProvider), isNull);
      expect(container.read(isSignedInProvider), isFalse);
    });
  });

  group('auth providers — restored session', () {
    test(
      'given a restored session, when the providers first read before '
      'the auth stream emits, then currentUser falls back to '
      'service.currentUser so the UI does not flicker through signed-out',
      () {
        const restored = AuthUser(
          id: 'user-restored',
          email: 'restored@example.com',
          displayName: 'Restored',
        );
        final fake = FakeAuthService(initialUser: restored);
        addTearDown(fake.dispose);

        final container = ProviderContainer(
          overrides: [authServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        // Subscribe to the stream provider so it starts listening, then
        // read synchronously — the broadcast stream has not delivered any
        // event yet, exercising the fallback path.
        container.listen<AsyncValue<AuthUser?>>(authStateProvider, (_, __) {});

        expect(container.read(currentUserProvider), restored);
        expect(container.read(isSignedInProvider), isTrue);
      },
    );
  });

  group('auth providers — sign-in', () {
    test('given a signed-out user, when signInWithGoogle succeeds, '
        'then currentUser is the new user and isSignedIn is true', () async {
      final fake = FakeAuthService();
      addTearDown(fake.dispose);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      container.listen<AsyncValue<AuthUser?>>(authStateProvider, (_, __) {});

      final user = await container.read(authServiceProvider).signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(user.id, 'fake-google-user');
      expect(fake.googleSignInCount, 1);
      expect(container.read(currentUserProvider)?.id, 'fake-google-user');
      expect(container.read(isSignedInProvider), isTrue);
    });

    test('given a signed-out user, when signInWithApple succeeds, '
        'then currentUser is the new user and isSignedIn is true', () async {
      final fake = FakeAuthService();
      addTearDown(fake.dispose);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      container.listen<AsyncValue<AuthUser?>>(authStateProvider, (_, __) {});

      final user = await container.read(authServiceProvider).signInWithApple();
      await Future<void>.delayed(Duration.zero);

      expect(user.id, 'fake-apple-user');
      expect(fake.appleSignInCount, 1);
      expect(container.read(currentUserProvider)?.id, 'fake-apple-user');
      expect(container.read(isSignedInProvider), isTrue);
    });

    test('given the provider rejects sign-in, when signInWithGoogle is '
        'called, then AuthFailureException propagates and the user '
        'stays signed out', () async {
      final fake = FakeAuthService()..shouldFailSignIn = true;
      addTearDown(fake.dispose);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      container.listen<AsyncValue<AuthUser?>>(authStateProvider, (_, __) {});

      await expectLater(
        container.read(authServiceProvider).signInWithGoogle(),
        throwsA(isA<AuthFailureException>()),
      );

      expect(container.read(currentUserProvider), isNull);
      expect(container.read(isSignedInProvider), isFalse);
    });
  });

  group('auth providers — sign-out', () {
    test('given a signed-in user, when signOut runs, then currentUser '
        'becomes null and isSignedIn is false', () async {
      const restored = AuthUser(id: 'user-1');
      final fake = FakeAuthService(initialUser: restored);
      addTearDown(fake.dispose);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      container.listen<AsyncValue<AuthUser?>>(authStateProvider, (_, __) {});
      expect(container.read(isSignedInProvider), isTrue);

      await container.read(authServiceProvider).signOut();
      await Future<void>.delayed(Duration.zero);

      expect(fake.signOutCount, 1);
      expect(container.read(currentUserProvider), isNull);
      expect(container.read(isSignedInProvider), isFalse);
    });
  });
}
