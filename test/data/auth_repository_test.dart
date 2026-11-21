import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:splitify/data/remote/supabase_auth_repository.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _Auth extends Mock implements sb.GoTrueClient {}

class _Functions extends Mock implements sb.FunctionsClient {}

class _Google implements GoogleIdTokenSource {
  _Google(this.token);

  final String? token;

  @override
  Future<String?> idToken() async => token;
}

final _user = sb.User(
  id: 'u1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-11-21T00:00:00Z',
  email: 'a@splitify.test',
);
final _session = sb.Session(accessToken: 'a', tokenType: 'bearer', user: _user);

Future<AuthFailureCode?> _code(Future<void> f) async {
  try {
    await f;
    return null;
  } on AuthFailure catch (e) {
    return e.code;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(sb.OAuthProvider.google);
    registerFallbackValue(sb.OtpType.email);
    registerFallbackValue(sb.SignOutScope.local);
    registerFallbackValue(sb.HttpMethod.post);
  });

  late _Auth auth;
  late _Functions functions;
  late SupabaseAuthRepository repo;

  setUp(() {
    auth = _Auth();
    functions = _Functions();
    repo = SupabaseAuthRepository(auth: auth, functions: functions, google: _Google('id-token'));
    when(() => auth.signOut(scope: any(named: 'scope'))).thenAnswer((_) async {});
  });

  test('session user and auth state stream', () async {
    when(() => auth.currentUser).thenReturn(_user);
    when(() => auth.onAuthStateChange).thenAnswer(
      (_) => Stream.fromIterable([
        sb.AuthState(sb.AuthChangeEvent.signedIn, _session),
        const sb.AuthState(sb.AuthChangeEvent.signedOut, null),
      ]),
    );
    expect(repo.currentUser?.id, 'u1');
    expect(repo.currentUser?.email, 'a@splitify.test');
    expect(await repo.authStateChanges().map((u) => u?.id).toList(), ['u1', null]);
  });

  test('Google: id token goes to signInWithIdToken; cancel and missing config fail', () async {
    when(
      () => auth.signInWithIdToken(
        provider: any(named: 'provider'),
        idToken: any(named: 'idToken'),
      ),
    ).thenAnswer((_) async => sb.AuthResponse(session: _session));
    await repo.signInWithGoogle();
    verify(() => auth.signInWithIdToken(provider: sb.OAuthProvider.google, idToken: 'id-token'))
        .called(1);
    final cancelled = SupabaseAuthRepository(
      auth: auth,
      functions: functions,
      google: _Google(null),
    );
    expect(await _code(cancelled.signInWithGoogle()), AuthFailureCode.cancelled);
    final none = SupabaseAuthRepository(auth: auth, functions: functions);
    expect(await _code(none.signInWithGoogle()), AuthFailureCode.notConfigured);
  });

  test('email code: send and verify', () async {
    when(
      () => auth.signInWithOtp(
        email: any(named: 'email'),
        shouldCreateUser: any(named: 'shouldCreateUser'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => auth.verifyOTP(
        type: any(named: 'type'),
        email: any(named: 'email'),
        token: any(named: 'token'),
      ),
    ).thenAnswer((_) async => sb.AuthResponse(session: _session));
    await repo.sendEmailCode(' a@splitify.test ');
    await repo.verifyEmailCode(email: 'a@splitify.test', code: ' 123456 ');
    verify(() => auth.signInWithOtp(email: 'a@splitify.test', shouldCreateUser: true)).called(1);
    verify(() => auth.verifyOTP(type: sb.OtpType.email, email: 'a@splitify.test', token: '123456'))
        .called(1);
  });

  test('errors map to failure codes', () async {
    Future<AuthFailureCode?> send(Object error) {
      when(
        () => auth.signInWithOtp(
          email: any(named: 'email'),
          shouldCreateUser: any(named: 'shouldCreateUser'),
        ),
      ).thenAnswer((_) async => throw error);
      return _code(repo.sendEmailCode('a@b.co'));
    }

    expect(await send(sb.AuthRetryableFetchException()), AuthFailureCode.offline);
    expect(await send(const SocketException('x')), AuthFailureCode.offline);
    expect(await send(TimeoutException('x')), AuthFailureCode.offline);
    expect(
      await send(const sb.AuthException('m', code: 'over_email_send_rate_limit')),
      AuthFailureCode.tooManyTries,
    );
    expect(
      await send(const sb.AuthException('m', code: 'otp_expired')),
      AuthFailureCode.expiredCode,
    );
  });

  test('mapAuthError covers the Supabase codes', () {
    AuthFailureCode m(String msg, {String? code, String? status}) =>
        mapAuthError(sb.AuthException(msg, code: code, statusCode: status));
    expect(m('x', code: 'otp_disabled'), AuthFailureCode.notConfigured);
    expect(m('x', code: 'email_address_invalid'), AuthFailureCode.invalidEmail);
    expect(m('x', code: 'invalid_credentials'), AuthFailureCode.invalidCredentials);
    expect(m('x', status: '429'), AuthFailureCode.tooManyTries);
    expect(m('Token has expired or is invalid'), AuthFailureCode.invalidCode);
    expect(m('boom'), AuthFailureCode.unknown);
  });

  test('developer sign-in creates the test user when missing (T4)', () async {
    when(
      () => auth.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const sb.AuthException('bad', code: 'invalid_credentials'));
    when(
      () => auth.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => sb.AuthResponse(session: _session));
    await repo.signInWithPassword(email: 'e2e-a@splitify.test', password: 'pw');
    verify(() => auth.signUp(email: 'e2e-a@splitify.test', password: 'pw')).called(1);

    when(
      () => auth.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => sb.AuthResponse());
    expect(
      await _code(repo.signInWithPassword(email: 'e', password: 'p')),
      AuthFailureCode.invalidCredentials,
    );

    when(
      () => auth.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const sb.AuthException('slow', code: 'over_request_rate_limit'));
    expect(
      await _code(repo.signInWithPassword(email: 'e', password: 'p')),
      AuthFailureCode.tooManyTries,
    );
  });

  test('sign out is local; delete account calls the Edge Function then signs out', () async {
    await repo.signOut();
    verify(() => auth.signOut(scope: sb.SignOutScope.local)).called(1);

    when(() => functions.invoke(any(), method: any(named: 'method')))
        .thenAnswer((_) async => sb.FunctionResponse(status: 200, data: {'deleted': true}));
    await repo.deleteAccount();
    verify(() => functions.invoke('delete-account', method: sb.HttpMethod.post)).called(1);
    verify(() => auth.signOut(scope: sb.SignOutScope.local)).called(1);

    when(() => functions.invoke(any(), method: any(named: 'method')))
        .thenAnswer((_) async => sb.FunctionResponse(status: 202));
    expect(await _code(repo.deleteAccount()), AuthFailureCode.unknown);

    when(() => functions.invoke(any(), method: any(named: 'method')))
        .thenThrow(const sb.FunctionException(status: 500));
    expect(await _code(repo.deleteAccount()), AuthFailureCode.unknown);
  });

  test('UnconfiguredAuthRepository is signed out and reports notConfigured', () async {
    const r = UnconfiguredAuthRepository();
    expect(r.currentUser, isNull);
    expect(await r.authStateChanges().first, isNull);
    await r.signOut();
    for (final f in [
      r.signInWithGoogle(),
      r.sendEmailCode('a'),
      r.verifyEmailCode(email: 'a', code: '1'),
      r.signInWithPassword(email: 'a', password: 'b'),
      r.deleteAccount(),
    ]) {
      expect(await _code(f), AuthFailureCode.notConfigured);
    }
    expect(const AuthFailure(AuthFailureCode.offline).toString(), contains('offline'));
  });
}
