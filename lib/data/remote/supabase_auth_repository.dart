import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:logging/logging.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final _log = Logger('auth');

/// Gets a Google ID token from Credential Manager; null when cancelled.
/// Other failures throw an [AuthFailure].
abstract interface class GoogleIdTokenSource {
  Future<String?> idToken();

  /// Forgets the chosen account (Credential Manager `clearCredentialState`).
  Future<void> signOut();
}

/// `google_sign_in` 7.x (research 04): initialize once with the web client
/// id, then `authenticate()` -> `authentication.idToken`. On Android that is
/// Credential Manager's "Sign in with Google" sheet (`GetSignInWithGoogleOption`,
/// web client id as server client id, every account on the phone, no nonce:
/// Supabase "Skip nonce checks" is on; S-230).
class GoogleSignInIdTokenSource implements GoogleIdTokenSource {
  GoogleSignInIdTokenSource(this.serverClientId);

  final String serverClientId;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _ready = true;
  }

  @override
  Future<String?> idToken() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      final code = googleFailure(e.code);
      if (code == null) return null;
      _log.warning('Google sign-in failed: ${e.code.name} ${e.description ?? ''}');
      throw AuthFailure(code);
    }
  }

  @override
  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
  }
}

/// Credential Manager errors -> [AuthFailureCode]; null = the person closed the sheet (S-231).
AuthFailureCode? googleFailure(GoogleSignInExceptionCode code) => switch (code) {
  GoogleSignInExceptionCode.canceled => null,
  GoogleSignInExceptionCode.clientConfigurationError ||
  GoogleSignInExceptionCode.providerConfigurationError => AuthFailureCode.notConfigured,
  _ => AuthFailureCode.unknown,
};

/// [AuthRepository] over Supabase Auth + the `delete-account` Edge Function.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({required this.auth, required this.functions, this.google});

  final sb.GoTrueClient auth;
  final sb.FunctionsClient functions;

  /// Null when no Google client id is configured (D-020).
  final GoogleIdTokenSource? google;

  static AuthUser? _user(sb.User? u) => u == null ? null : AuthUser(id: u.id, email: u.email);

  @override
  AuthUser? get currentUser => _user(auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() => auth.onAuthStateChange.map((s) => _user(s.session?.user));

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    final g = google;
    if (g == null) throw const AuthFailure(AuthFailureCode.notConfigured);
    final token = await g.idToken();
    if (token == null) throw const AuthFailure(AuthFailureCode.cancelled);
    await auth.signInWithIdToken(provider: sb.OAuthProvider.google, idToken: token);
  });

  @override
  Future<void> sendEmailCode(String email) =>
      _guard(() => auth.signInWithOtp(email: email.trim(), shouldCreateUser: true));

  @override
  Future<void> verifyEmailCode({required String email, required String code}) =>
      _guard(() => auth.verifyOTP(type: sb.OtpType.email, email: email.trim(), token: code.trim()));

  @override
  Future<void> signInWithPassword({required String email, required String password}) =>
      _guard(() async {
        try {
          await auth.signInWithPassword(email: email, password: password);
        } on sb.AuthException catch (e) {
          if (mapAuthError(e) != AuthFailureCode.invalidCredentials) rethrow;
          // Test users are created on first use (T4 harness).
          final r = await auth.signUp(email: email, password: password);
          if (r.session == null) throw const AuthFailure(AuthFailureCode.invalidCredentials);
        }
      });

  @override
  Future<void> signOut() => _guard(() async {
    await auth.signOut(scope: sb.SignOutScope.local);
    try {
      await google?.signOut();
    } on Object catch (e) {
      // Best effort: the Supabase session is what signs the person out.
      _log.info('Google sign-out failed: $e');
    }
  });

  @override
  Future<void> deleteAccount() => _guard(() async {
    final r = await functions.invoke('delete-account', method: sb.HttpMethod.post);
    if (r.status != 200) throw const AuthFailure(AuthFailureCode.unknown);
    await auth.signOut(scope: sb.SignOutScope.local);
  });

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on AuthFailure {
      rethrow;
    } on sb.AuthRetryableFetchException {
      throw const AuthFailure(AuthFailureCode.offline);
    } on sb.AuthException catch (e) {
      throw AuthFailure(mapAuthError(e));
    } on SocketException {
      throw const AuthFailure(AuthFailureCode.offline);
    } on TimeoutException {
      throw const AuthFailure(AuthFailureCode.offline);
    } on sb.FunctionException {
      throw const AuthFailure(AuthFailureCode.unknown);
    }
  }
}

/// Supabase Auth error codes -> [AuthFailureCode].
AuthFailureCode mapAuthError(sb.AuthException e) {
  switch (e.code) {
    // Supabase answers 403 `otp_expired` ("Token has expired or is invalid") for a mistyped, a used and an
    // expired code alike (seen live 2026-11-22), so it counts as a wrong try (S-233).
    case 'otp_expired':
      return AuthFailureCode.invalidCode;
    case 'otp_disabled' || 'email_provider_disabled' || 'provider_disabled':
      return AuthFailureCode.notConfigured;
    case 'over_request_rate_limit' || 'over_email_send_rate_limit':
      return AuthFailureCode.tooManyTries;
    case 'email_address_invalid' || 'validation_failed':
      return AuthFailureCode.invalidEmail;
    case 'invalid_credentials':
      return AuthFailureCode.invalidCredentials;
  }
  if (e.statusCode == '429') return AuthFailureCode.tooManyTries;
  final m = e.message.toLowerCase();
  if (m.contains('expired') || m.contains('invalid') && m.contains('token')) {
    return AuthFailureCode.invalidCode;
  }
  return AuthFailureCode.unknown;
}
