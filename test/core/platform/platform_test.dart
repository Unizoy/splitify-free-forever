import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:splitify/core/platform/device_auth.dart';
import 'package:splitify/core/platform/secure_window.dart';

class _MockAuth extends Mock implements LocalAuthentication {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDeviceAuth (X2)', () {
    late _MockAuth auth;
    late LocalDeviceAuth device;

    setUp(() {
      auth = _MockAuth();
      device = LocalDeviceAuth(auth);
    });

    Future<bool> prompt() => auth.authenticate(
      localizedReason: any(named: 'localizedReason'),
      persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
    );

    test('available() follows isDeviceSupported and is false on a platform error', () async {
      when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
      expect(await device.available(), isTrue);
      when(() => auth.isDeviceSupported()).thenThrow(PlatformException(code: 'x'));
      expect(await device.available(), isFalse);
    });

    test('authenticate maps the outcome; device credential stays allowed', () async {
      when(prompt).thenAnswer((_) async => true);
      expect(await device.authenticate('Unlock'), DeviceAuthResult.success);
      verify(() => auth.authenticate(localizedReason: 'Unlock', persistAcrossBackgrounding: true))
          .called(1);

      when(prompt).thenAnswer((_) async => false);
      expect(await device.authenticate('Unlock'), DeviceAuthResult.failed);
    });

    test('no screen lock → unavailable; other errors → failed', () async {
      when(prompt)
          .thenThrow(const LocalAuthException(code: LocalAuthExceptionCode.noCredentialsSet));
      expect(await device.authenticate('Unlock'), DeviceAuthResult.unavailable);
      when(prompt).thenThrow(const LocalAuthException(code: LocalAuthExceptionCode.userCanceled));
      expect(await device.authenticate('Unlock'), DeviceAuthResult.failed);
      when(prompt).thenThrow(PlatformException(code: 'x'));
      expect(await device.authenticate('Unlock'), DeviceAuthResult.failed);
    });
  });

  group('ChannelSecureWindow (X2)', () {
    const channel = MethodChannel('splitify/window');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('sends setSecure / setRecentsHidden with the flag', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      const window = ChannelSecureWindow();
      await window.setSecure(on: true);
      await window.setRecentsHidden(hidden: false);
      expect(calls.map((c) => '${c.method}:${c.arguments}'), [
        'setSecure:true',
        'setRecentsHidden:false',
      ]);
    });

    test('a platform error or a missing channel is ignored', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'old-android');
      });
      await const ChannelSecureWindow().setSecure(on: true);
      messenger.setMockMethodCallHandler(channel, null);
      await const ChannelSecureWindow().setRecentsHidden(hidden: true);
    });
  });
}
