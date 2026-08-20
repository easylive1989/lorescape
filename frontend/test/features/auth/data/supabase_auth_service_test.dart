import 'package:context_app/app/config/api_config.dart';
import 'package:context_app/features/auth/data/supabase_auth_service.dart';
import 'package:context_app/features/auth/domain/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class FakeApiConfig extends Fake implements ApiConfig {}

User _user({required bool isAnonymous, String id = 'user-1'}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime(2026).toIso8601String(),
  isAnonymous: isAnonymous,
);

void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late MockGoogleSignIn googleSignIn;
  late SupabaseAuthService service;

  setUpAll(() {
    registerFallbackValue(OAuthProvider.google);
  });

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    googleSignIn = MockGoogleSignIn();
    when(() => client.auth).thenReturn(auth);

    final account = MockGoogleSignInAccount();
    final authentication = MockGoogleSignInAuthentication();
    when(() => googleSignIn.signIn()).thenAnswer((_) async => account);
    when(() => account.authentication).thenAnswer((_) async => authentication);
    when(() => authentication.idToken).thenReturn('google-id-token');
    when(() => authentication.accessToken).thenReturn('google-access-token');

    service = SupabaseAuthService(
      apiConfig: FakeApiConfig(),
      client: client,
      googleSignIn: googleSignIn,
    );
  });

  void stubLink(AuthResponse response) {
    when(
      () => auth.linkIdentityWithIdToken(
        provider: any(named: 'provider'),
        idToken: any(named: 'idToken'),
        accessToken: any(named: 'accessToken'),
        nonce: any(named: 'nonce'),
      ),
    ).thenAnswer((_) async => response);
  }

  void stubLinkThrows(Object error) {
    when(
      () => auth.linkIdentityWithIdToken(
        provider: any(named: 'provider'),
        idToken: any(named: 'idToken'),
        accessToken: any(named: 'accessToken'),
        nonce: any(named: 'nonce'),
      ),
    ).thenThrow(error);
  }

  void stubSignIn(AuthResponse response) {
    when(
      () => auth.signInWithIdToken(
        provider: any(named: 'provider'),
        idToken: any(named: 'idToken'),
        accessToken: any(named: 'accessToken'),
        nonce: any(named: 'nonce'),
      ),
    ).thenAnswer((_) async => response);
  }

  group('signInWithGoogle identity linking', () {
    test('given an anonymous session, '
        'when signing in, then the identity is linked in place', () async {
      when(() => auth.currentUser).thenReturn(_user(isAnonymous: true));
      stubLink(AuthResponse(user: _user(isAnonymous: false, id: 'same-id')));

      final result = await service.signInWithGoogle();

      expect(result.id, 'same-id');
      expect(result.isAnonymous, isFalse);
      verify(
        () => auth.linkIdentityWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
          nonce: any(named: 'nonce'),
        ),
      ).called(1);
      verifyNever(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
          nonce: any(named: 'nonce'),
        ),
      );
    });

    test('given the identity already belongs to another account, '
        'when linking fails with identity_already_exists, '
        'then it falls back to a normal sign-in', () async {
      when(() => auth.currentUser).thenReturn(_user(isAnonymous: true));
      stubLinkThrows(
        const AuthException('exists', code: 'identity_already_exists'),
      );
      stubSignIn(
        AuthResponse(user: _user(isAnonymous: false, id: 'existing-id')),
      );

      final result = await service.signInWithGoogle();

      expect(result.id, 'existing-id');
      verify(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
          nonce: any(named: 'nonce'),
        ),
      ).called(1);
    });

    test(
      'given manual linking is disabled, '
      'when linking fails, then the error is surfaced without silent fallback',
      () async {
        when(() => auth.currentUser).thenReturn(_user(isAnonymous: true));
        stubLinkThrows(
          const AuthException('disabled', code: 'manual_linking_disabled'),
        );

        await expectLater(
          service.signInWithGoogle(),
          throwsA(isA<AuthFailureException>()),
        );
        verifyNever(
          () => auth.signInWithIdToken(
            provider: any(named: 'provider'),
            idToken: any(named: 'idToken'),
            accessToken: any(named: 'accessToken'),
            nonce: any(named: 'nonce'),
          ),
        );
      },
    );

    test('given a non-anonymous current user, '
        'when signing in, then it signs in directly without linking', () async {
      when(() => auth.currentUser).thenReturn(_user(isAnonymous: false));
      stubSignIn(AuthResponse(user: _user(isAnonymous: false, id: 'other')));

      await service.signInWithGoogle();

      verify(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
          nonce: any(named: 'nonce'),
        ),
      ).called(1);
      verifyNever(
        () => auth.linkIdentityWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
          nonce: any(named: 'nonce'),
        ),
      );
    });

    test('given no current session, '
        'when signing in, then it signs in directly without linking', () async {
      when(() => auth.currentUser).thenReturn(null);
      stubSignIn(AuthResponse(user: _user(isAnonymous: false, id: 'fresh')));

      await service.signInWithGoogle();

      verifyNever(
        () => auth.linkIdentityWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
          nonce: any(named: 'nonce'),
        ),
      );
    });
  });
}
