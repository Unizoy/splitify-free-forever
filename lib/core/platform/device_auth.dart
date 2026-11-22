import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Outcome of asking the phone's owner to confirm it's them (X2).
enum DeviceAuthResult {
  /// Fingerprint, face or screen lock accepted.
  success,

  /// Cancelled, wrong too often or interrupted: try again.
  failed,

  /// The phone has no screen lock at all (nothing to check against).
  unavailable,
}

/// The phone's own lock (biometric or PIN/pattern/password) — a seam over `local_auth` for tests.
abstract interface class DeviceAuth {
  /// True when the phone has a screen lock or enrolled biometrics.
  Future<bool> available();

  /// Shows the system prompt with [reason]; device credential is always offered as the fallback,
  /// so removing a fingerprint never locks anyone out.
  Future<DeviceAuthResult> authenticate(String reason);
}

class LocalDeviceAuth implements DeviceAuth {
  LocalDeviceAuth([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return ok ? DeviceAuthResult.success : DeviceAuthResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet => DeviceAuthResult.unavailable,
        _ => DeviceAuthResult.failed,
      };
    } on PlatformException {
      return DeviceAuthResult.failed;
    }
  }
}
