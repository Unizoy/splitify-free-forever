// Phase 15 (rule 9, S-160): connectivity_plus → online / offline.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/sync/network_status.dart';

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this.now);

  List<ConnectivityResult> now;
  bool fail = false;
  final changes = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (fail) throw PlatformException(code: 'no-plugin');
    return now;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;
}

void main() {
  test('online when any network is up; airplane mode (none) is offline', () async {
    final c = _FakeConnectivity([ConnectivityResult.wifi]);
    final status = ConnectivityNetworkStatus(c);
    expect(await status.isOnline(), isTrue);
    c.now = [ConnectivityResult.none];
    expect(await status.isOnline(), isFalse);
    expect(
      ConnectivityNetworkStatus.online([ConnectivityResult.mobile, ConnectivityResult.vpn]),
      isTrue,
    );
  });

  test('watch: the current state first, then every change', () async {
    final c = _FakeConnectivity([ConnectivityResult.none]);
    final seen = <bool>[];
    final sub = ConnectivityNetworkStatus(c).watch().listen(seen.add);
    await pumpEventQueue();
    c.changes
      ..add([ConnectivityResult.wifi])
      ..add([ConnectivityResult.none]);
    await pumpEventQueue();
    expect(seen, [false, true, false]);
    await sub.cancel();
    await c.changes.close();
  });

  test('a platform error counts as online (actions then report their own error)', () async {
    final c = _FakeConnectivity([ConnectivityResult.none])..fail = true;
    expect(await ConnectivityNetworkStatus(c).isOnline(), isTrue);
  });

  test('without the plugin: always online, never changes', () async {
    const status = AssumeOnlineNetworkStatus();
    expect(await status.isOnline(), isTrue);
    expect(await status.watch().isEmpty, isTrue);
  });
}
