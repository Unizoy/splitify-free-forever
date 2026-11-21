import 'dart:async';

/// Why a sign-in step failed; the UI maps each code to ARB copy (TC-B1-02).
enum AuthFailureCode {
  /// Wrong or mistyped 6-digit code.
  invalidCode,

  /// Code older than 10 minutes.
  expiredCode,

  /// Too many wrong tries or requests: ask for a new code later.
  tooManyTries,

  /// Not an email address.
  invalidEmail,

  /// No connection to the server.
  offline,

  /// The person closed the Google sheet; stay on the screen quietly.
  cancelled,

  /// The backend (or Google) is not set up in this build (D-020).
  notConfigured,

  /// Developer sign-in: wrong password.
  invalidCredentials,

  /// Anything else.
  unknown,
}

/// A failed auth call with a mapped [code].
class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthFailureCode code;

  @override
  String toString() => 'AuthFailure(${code.name})';
}

/// The signed-in account (only what the app needs).
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

/// Sign-in, session and account removal (B1). Implemented over Supabase Auth
/// in `data/remote`; tests and screenshots use fakes.
abstract interface class AuthRepository {
  /// The current session's user, or null when signed out.
  AuthUser? get currentUser;

  /// Emits on every sign-in / sign-out / token change.
  Stream<AuthUser?> authStateChanges();

  /// Google via Credential Manager → `signInWithIdToken`.
  Future<void> signInWithGoogle();

  /// Sends a 6-digit code to [email].
  Future<void> sendEmailCode(String email);

  /// Checks the 6-digit [code] sent to [email] and signs in.
  Future<void> verifyEmailCode({required String email, required String code});

  /// Debug builds only: email + password, creating the test user if missing.
  Future<void> signInWithPassword({required String email, required String password});

  Future<void> signOut();

  /// Calls the `delete-account` Edge Function, then signs out locally.
  Future<void> deleteAccount();
}

/// Stand-in when Supabase is not configured (widget tests, screenshots):
/// always signed out, every call fails with [AuthFailureCode.notConfigured].
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();

  static const _failure = AuthFailure(AuthFailureCode.notConfigured);

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => Stream<AuthUser?>.value(null);

  @override
  Future<void> signInWithGoogle() => Future.error(_failure);

  @override
  Future<void> sendEmailCode(String email) => Future.error(_failure);

  @override
  Future<void> verifyEmailCode({required String email, required String code}) =>
      Future.error(_failure);

  @override
  Future<void> signInWithPassword({required String email, required String password}) =>
      Future.error(_failure);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() => Future.error(_failure);
}
