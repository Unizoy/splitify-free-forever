// Phase 15: foreground answer port for WorkManager runs in the same process (04 §8, S-160).
import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/sync/background_sync.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  wmTests();
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

/// Records every WorkManager call; [fail] makes them throw.
class _FakeWorkmanager implements Workmanager {
  final calls = <String>[];
  bool fail = false;

  @override
  dynamic noSuchMethod(Invocation i) {
    calls.add(i.memberName.toString().replaceAll('Symbol("', '').replaceAll('")', ''));
    if (fail) return Future<void>.error(StateError('no plugin'));
    return Future<void>.value();
  }
}

void wmTests() {
  group('WorkmanagerBackgroundSync', () {
    test('periodic keep, one-off replace, cancel all on stop', () async {
      final wm = _FakeWorkmanager();
      final bg = WorkmanagerBackgroundSync(wm);
      await bg.start();
      await bg.syncWhenOnline();
      await bg.stop();
      expect(wm.calls, ['registerPeriodicTask', 'registerOneOffTask', 'cancelAll']);
    });

    test('plugin errors are logged, never thrown', () async {
      final wm = _FakeWorkmanager()..fail = true;
      final bg = WorkmanagerBackgroundSync(wm);
      await expectLater(bg.start(), completes);
      await expectLater(bg.syncWhenOnline(), completes);
      await expectLater(bg.stop(), completes);
      expect(wm.calls, hasLength(3));
    });

    test('NoBackgroundSync does nothing', () async {
      const bg = NoBackgroundSync();
      await bg.start();
      await bg.syncWhenOnline();
      await bg.stop();
    });
  });
}
