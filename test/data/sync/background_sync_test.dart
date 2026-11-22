// Phase 15: foreground answer port for WorkManager runs in the same process (04 §8, S-160).
import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/sync/background_sync.dart';

void main() {
  tearDown(() => IsolateNameServer.removePortNameMapping(foregroundSyncPortName));

  test('no signed-in app in the process: the worker syncs on its own', () async {
    expect(await askForegroundToSync(), isFalse);
  });

  test('the foreground app runs the sync and the worker gets true', () async {
    var ran = 0;
    final port = ForegroundSyncPort(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      ran++;
    });
    addTearDown(port.close);
    expect(await askForegroundToSync(), isTrue);
    expect(ran, 1);
  });

  test('a failing foreground sync still ends the worker wait', () async {
    final port = ForegroundSyncPort(() async => throw StateError('boom'));
    addTearDown(port.close);
    expect(await askForegroundToSync(), isTrue);
  });

  test('a stale mapping (port closed, no answer) is dropped and the worker syncs itself', () async {
    final dead = ReceivePort();
    IsolateNameServer.registerPortWithName(dead.sendPort, foregroundSyncPortName);
    dead.close();
    expect(await askForegroundToSync(answer: const Duration(milliseconds: 100)), isFalse);
    expect(IsolateNameServer.lookupPortByName(foregroundSyncPortName), isNull);
  });

  test('close removes the mapping only when it is still this port', () async {
    final first = ForegroundSyncPort(() async {});
    final second = ForegroundSyncPort(() async {});
    first.close();
    expect(IsolateNameServer.lookupPortByName(foregroundSyncPortName), isNotNull);
    second.close();
    expect(IsolateNameServer.lookupPortByName(foregroundSyncPortName), isNull);
  });

  test('NoBackgroundSync does nothing and never throws', () async {
    const b = NoBackgroundSync();
    await b.start();
    await b.syncWhenOnline();
    await b.stop();
  });
}
