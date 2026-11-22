import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart' show PlatformException;

/// Whether this phone has a network (rule 9, 04 §1). "Online" means a network is up; the server can still be
/// unreachable, which the sync engine reports as offline on its own.
abstract interface class NetworkStatus {
  /// The current state first, then every change.
  Stream<bool> watch();

  /// Online-only actions ask before they start (rule 9).
  Future<bool> isOnline();
}

/// Without the platform plugin (widget tests, dummy builds): always online, never changes, so online-only
/// actions just try and report their own offline error.
class AssumeOnlineNetworkStatus implements NetworkStatus {
  const AssumeOnlineNetworkStatus();

  @override
  Stream<bool> watch() => const Stream.empty();

  @override
  Future<bool> isOnline() async => true;
}

/// [NetworkStatus] over `connectivity_plus` (airplane mode → `none` → offline).
class ConnectivityNetworkStatus implements NetworkStatus {
  ConnectivityNetworkStatus([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool online(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);

  @override
  Stream<bool> watch() async* {
    yield await isOnline();
    yield* _connectivity.onConnectivityChanged.map(online);
  }

  @override
  Future<bool> isOnline() async {
    try {
      return online(await _connectivity.checkConnectivity());
    } on PlatformException {
      return true;
    }
  }
}
