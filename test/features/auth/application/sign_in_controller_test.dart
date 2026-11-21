import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/auth/application/sign_in_controller.dart';
import 'package:splitify/l10n/app_localizations.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRemote remote;
  late FakeClock clock;
  late ProviderContainer c;
  late SharedPreferences prefs;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    prefs = await SharedPreferences.getInstance();
    auth = FakeAuthRepository();
    remote = FakeProfileRemote(sampleProfile);
    clock = FakeClock(DateTime.utc(2026, 11, 21, 10));
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(auth),
        profileRemoteProvider.overrideWithValue(remote),
        clockProvider.overrideWithValue(clock),
        e2ePasswordProvider.overrideWithValue('pw'),
      ],
    );
    addTearDown(c.dispose);
  });

  SignInController ctl() => c.read(signInControllerProvider.notifier);
  SignInState st() => c.read(signInControllerProvider);

  test('send code validates the email and starts the 60 s resend timer', () async {
    expect(await ctl().sendCode('nope'), isFalse);
    expect(st().failure, AuthFailureCode.invalidEmail);
    expect(ctl().resendSecondsLeft(), 0);
    expect(await ctl().sendCode(' asha@splitify.test '), isTrue);
    expect(auth.calls, ['send:asha@splitify.test']);
    expect(st().email, 'asha@splitify.test');
    expect(ctl().resendSecondsLeft(), 60);
    clock.advance(const Duration(seconds: 59, milliseconds: 500));
    expect(ctl().resendSecondsLeft(), 1);
    clock.advance(const Duration(seconds: 1));
    expect(ctl().resendSecondsLeft(), 0);
    expect(await ctl().resend(), isTrue);
    expect(auth.calls.last, 'send:asha@splitify.test');
  });

  test('wrong codes count up to 5 tries, then "request a new code"', () async {
    await ctl().sendCode('asha@splitify.test');
    for (var i = 1; i <= 4; i++) {
      expect(await ctl().verify('000000'), isFalse);
      expect(st().failure, AuthFailureCode.invalidCode);
      expect(st().wrongTries, i);
    }
    expect(await ctl().verify('000000'), isFalse);
    expect(st().failure, AuthFailureCode.tooManyTries);
    expect(await ctl().verify('123456'), isFalse, reason: 'blocked until a new code');
    expect(auth.calls.where((x) => x.startsWith('verify')).length, 5);
    await ctl().resend();
    expect(st().wrongTries, 0);
    expect(await ctl().verify('123456'), isTrue);
    expect(auth.currentUser?.email, 'asha@splitify.test');
  });

  test('expired code and offline keep their own failure', () async {
    await ctl().sendCode('asha@splitify.test');
    auth.fail = const AuthFailure(AuthFailureCode.expiredCode);
    expect(await ctl().verify('123456'), isFalse);
    expect(st().failure, AuthFailureCode.expiredCode);
    expect(st().wrongTries, 0);
    auth.fail = const AuthFailure(AuthFailureCode.offline);
    expect(await ctl().sendCode('asha@splitify.test'), isFalse);
    expect(st().failure, AuthFailureCode.offline);
    ctl().clearFailure();
    expect(st().failure, isNull);
  });

  test('Google: cancel is quiet, success signs in; dev sign-in uses the e2e user', () async {
    auth.fail = const AuthFailure(AuthFailureCode.cancelled);
    expect(await ctl().google(), isFalse);
    expect(st().failure, isNull);
    expect(await ctl().google(), isTrue);
    expect(await ctl().devSignIn('e2e-a'), isTrue);
    expect(auth.calls.last, 'password:e2e-a@splitify.test');
  });

  test('TC-B1-02 every failure maps to friendly copy', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final texts = {for (final code in AuthFailureCode.values) code: authFailureText(l, code)};
    expect(texts[AuthFailureCode.tooManyTries], 'Too many tries, request a new code');
    expect(texts[AuthFailureCode.offline], contains('offline'));
    expect(texts.values.toSet().length, AuthFailureCode.values.length);
    expect(texts.values.every((t) => t.isNotEmpty), isTrue);
  });

  test('profile: null when signed out, loads after sign-in, save updates state', () async {
    expect(await c.read(profileProvider.future), isNull);
    await auth.signInWithPassword(email: 'a@splitify.test', password: 'pw');
    c.invalidate(profileProvider);
    expect(await c.read(profileProvider.future), sampleProfile);
    final saved = await c
        .read(profileProvider.notifier)
        .save(sampleProfile.copyWith(upiId: 'asha@ybl'), photo: Uint8List(2));
    expect(saved.upiId, 'asha@ybl');
    expect(saved.avatarPath, isNotNull);
    expect(c.read(profileProvider).value, saved);
    remote.fail = const ProfileFailure(ProfileFailureCode.unknown);
    c.invalidate(profileProvider);
    expect(await c.read(profileProvider.future), saved, reason: 'falls back to cache');
  });

  test('T8 sign out and delete account wipe the phone but keep the theme', () async {
    await auth.signInWithPassword(email: 'a@splitify.test', password: 'pw');
    await prefs.setString(ProfileRepository.cacheKey, '{}');
    await c.read(accountActionsProvider).signOut();
    expect(auth.currentUser, isNull);
    expect(prefs.getKeys(), {'theme_mode'});

    await auth.signInWithPassword(email: 'a@splitify.test', password: 'pw');
    await prefs.setString('x', 'y');
    await c.read(accountActionsProvider).deleteAccount();
    expect(auth.calls.last, 'delete');
    expect(prefs.getKeys(), {'theme_mode'});

    auth.fail = const AuthFailure(AuthFailureCode.offline);
    await expectLater(c.read(accountActionsProvider).deleteAccount(), throwsA(isA<AuthFailure>()));
  });

  test('default providers: not configured, no Google, no dev login', () async {
    final d = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(d.dispose);
    expect(d.read(authRepositoryProvider), isA<UnconfiguredAuthRepository>());
    expect(d.read(googleConfiguredProvider), isFalse);
    expect(d.read(devLoginProvider), isFalse);
    expect(d.read(e2ePasswordProvider), isEmpty);
    expect(d.read(clockProvider).now().isUtc, isTrue);
    // Riverpod 3 pauses unlistened providers, so listen before reading.
    final sub = d.listen(authUserProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    expect(d.read(authUserProvider).value, isNull);
  });
}
