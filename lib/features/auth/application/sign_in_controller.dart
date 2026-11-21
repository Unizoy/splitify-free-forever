import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';

/// State of the email-code sign-in (B1).
class SignInState {
  const SignInState({
    this.email = '',
    this.busy = false,
    this.failure,
    this.wrongTries = 0,
    this.codeSentAt,
  });

  final String email;
  final bool busy;
  final AuthFailureCode? failure;
  final int wrongTries;
  final DateTime? codeSentAt;

  SignInState copyWith({
    String? email,
    bool? busy,
    AuthFailureCode? failure,
    bool clearFailure = false,
    int? wrongTries,
    DateTime? codeSentAt,
  }) => SignInState(
    email: email ?? this.email,
    busy: busy ?? this.busy,
    failure: clearFailure ? null : failure ?? this.failure,
    wrongTries: wrongTries ?? this.wrongTries,
    codeSentAt: codeSentAt ?? this.codeSentAt,
  );
}

final signInControllerProvider = NotifierProvider<SignInController, SignInState>(
  SignInController.new,
);

/// Drives sign-in: Google, email code (resend after 60 s, 5 wrong tries) and
/// the debug developer sign-in.
class SignInController extends Notifier<SignInState> {
  static const resendAfter = Duration(seconds: 60);
  static const maxTries = 5;
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  SignInState build() => const SignInState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Seconds until "Resend code" is enabled (0 = now).
  int resendSecondsLeft() {
    final sent = state.codeSentAt;
    if (sent == null) return 0;
    final left = resendAfter - ref.read(clockProvider).now().difference(sent);
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  /// Sends a code; true when the code screen should open.
  Future<bool> sendCode(String email) async {
    final e = email.trim();
    if (!_email.hasMatch(e)) {
      state = state.copyWith(email: e, failure: AuthFailureCode.invalidEmail);
      return false;
    }
    return _run(() async {
      await _repo.sendEmailCode(e);
      state = state.copyWith(email: e, wrongTries: 0, codeSentAt: ref.read(clockProvider).now());
    });
  }

  /// Sends a new code to the same email.
  Future<bool> resend() => sendCode(state.email);

  /// Checks the code; true when signed in.
  Future<bool> verify(String code) async {
    if (state.wrongTries >= maxTries) {
      state = state.copyWith(failure: AuthFailureCode.tooManyTries);
      return false;
    }
    final ok = await _run(() => _repo.verifyEmailCode(email: state.email, code: code));
    if (!ok && state.failure == AuthFailureCode.invalidCode) {
      final tries = state.wrongTries + 1;
      state = state.copyWith(
        wrongTries: tries,
        failure: tries >= maxTries ? AuthFailureCode.tooManyTries : AuthFailureCode.invalidCode,
      );
    }
    return ok;
  }

  /// Google sign-in; a cancelled sheet is not an error.
  Future<bool> google() async {
    final ok = await _run(_repo.signInWithGoogle);
    if (!ok && state.failure == AuthFailureCode.cancelled) {
      state = state.copyWith(clearFailure: true);
    }
    return ok;
  }

  /// Debug-only developer sign-in for `<user>@splitify.test`.
  Future<bool> devSignIn(String user) => _run(
    () => _repo.signInWithPassword(
      email: '$user@splitify.test',
      password: ref.read(e2ePasswordProvider),
    ),
  );

  void clearFailure() => state = state.copyWith(clearFailure: true);

  Future<bool> _run(Future<void> Function() body) async {
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      await body();
      state = state.copyWith(busy: false);
      return true;
    } on AuthFailure catch (e) {
      state = state.copyWith(busy: false, failure: e.code);
      return false;
    }
  }
}

/// Friendly copy for each failure (TC-B1-02).
String authFailureText(AppLocalizations l, AuthFailureCode code) => switch (code) {
  AuthFailureCode.invalidCode => l.authErrorInvalidCode,
  AuthFailureCode.expiredCode => l.authErrorExpiredCode,
  AuthFailureCode.tooManyTries => l.authErrorTooManyTries,
  AuthFailureCode.invalidEmail => l.authErrorInvalidEmail,
  AuthFailureCode.offline => l.authErrorOffline,
  AuthFailureCode.cancelled => l.authErrorCancelled,
  AuthFailureCode.notConfigured => l.authErrorNotConfigured,
  AuthFailureCode.invalidCredentials => l.authErrorInvalidCredentials,
  AuthFailureCode.unknown => l.authErrorUnknown,
};
