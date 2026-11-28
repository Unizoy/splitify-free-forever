import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/core/platform/crash_reporting.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/data/sync/background_sync.dart';

class _FakePush implements PushMessaging {
  _FakePush({this.available = true});

  @override
  final bool available;

  final calls = <String>[];
  final refresh = StreamController<String>.broadcast();
  final fg = StreamController<PushMessage>.broadcast();
  final tap = StreamController<PushMessage>.broadcast();

  static const launch = PushMessage(data: {'target_type': 'expense'}, title: 'Hi');

  @override
  Future<PushPermission> permission() async {
    calls.add('permission');
    return PushPermission.granted;
  }

  @override
  Future<PushPermission> requestPermission() async {
    calls.add('requestPermission');
    return PushPermission.notAsked;
  }

  @override
  Future<String?> token() async {
    calls.add('token');
    return 'tok-1';
  }

  @override
  Stream<String> get tokenRefresh => refresh.stream;

  @override
  Future<void> deleteToken() async => calls.add('deleteToken');

  @override
  Stream<PushMessage> get foreground => fg.stream;

  @override
  Stream<PushMessage> get opened => tap.stream;

  @override
  Future<PushMessage?> launchMessage() async {
    calls.add('launchMessage');
    return launch;
  }

  @override
  Future<void> show(PushMessage m) async => calls.add('show ${m.title}');
}

class _FakeBackground implements BackgroundSync {
  final calls = <String>[];

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> syncWhenOnline() async => calls.add('syncWhenOnline');

  @override
  Future<void> stop() async => calls.add('stop');
}

class _FakeCrash implements CrashReporter {
  _FakeCrash({this.available = true});

  @override
  final bool available;

  final calls = <String>[];

  @override
  Future<void> setEnabled(bool on) async => calls.add('setEnabled $on');

  @override
  Future<void> report(Object error, StackTrace? stack, {required bool fatal}) async =>
      calls.add('report $error fatal=$fatal');
}

void main() {
  group('DeferredPushMessaging', () {
    test('available is false before complete and follows the real push after', () async {
      final yes = DeferredPushMessaging();
      expect(yes.available, isFalse);
      yes.complete(_FakePush());
      expect(yes.available, isTrue);

      final no = DeferredPushMessaging();
      no.complete(_FakePush(available: false));
      expect(no.available, isFalse);
    });

    test('complete is once only', () async {
      final d = DeferredPushMessaging();
      final first = _FakePush();
      d.complete(first);
      d.complete(_FakePush(available: false));
      expect(d.available, isTrue);
      expect(await d.token(), 'tok-1');
      expect(first.calls, ['token']);
    });

    test('permission, token and launchMessage wait for completion', () async {
      final d = DeferredPushMessaging();
      final real = _FakePush();
      String? token;
      PushPermission? permission;
      PushMessage? launch;
      var tokenDone = false;
      unawaited(
        d.token().then((v) {
          token = v;
          tokenDone = true;
        }),
      );
      unawaited(d.permission().then((v) => permission = v));
      unawaited(d.launchMessage().then((v) => launch = v));
      await pumpEventQueue();
      expect(tokenDone, isFalse);
      expect(permission, isNull);
      expect(launch, isNull);
      expect(real.calls, isEmpty);

      d.complete(real);
      await pumpEventQueue();
      expect(token, 'tok-1');
      expect(permission, PushPermission.granted);
      expect(launch, same(_FakePush.launch));
      expect(real.calls, containsAll(['token', 'permission', 'launchMessage']));
    });

    test('requestPermission, deleteToken and show forward after completion', () async {
      final d = DeferredPushMessaging();
      final real = _FakePush();
      final results = Future.wait<Object?>([
        d.requestPermission(),
        d.deleteToken(),
        d.show(const PushMessage(data: {}, title: 'T')),
      ]);
      d.complete(real);
      final out = await results;
      expect(out.first, PushPermission.notAsked);
      expect(real.calls, ['requestPermission', 'deleteToken', 'show T']);
    });

    test('tokenRefresh, foreground and opened forward events emitted after completion', () async {
      final d = DeferredPushMessaging();
      final real = _FakePush();
      final tokens = <String>[];
      final fgs = <String?>[];
      final taps = <String?>[];
      final subs = [
        d.tokenRefresh.listen(tokens.add),
        d.foreground.listen((m) => fgs.add(m.title)),
        d.opened.listen((m) => taps.add(m.title)),
      ];
      await pumpEventQueue();
      d.complete(real);
      await pumpEventQueue();

      real.refresh.add('tok-2');
      real.fg.add(const PushMessage(data: {}, title: 'fg'));
      real.tap.add(const PushMessage(data: {}, title: 'tap'));
      await pumpEventQueue();
      expect(tokens, ['tok-2']);
      expect(fgs, ['fg']);
      expect(taps, ['tap']);

      for (final s in subs) {
        await s.cancel();
      }
    });

    test('whenPushReady waits for the deferred push', () async {
      final d = DeferredPushMessaging();
      var ready = false;
      unawaited(whenPushReady(d).then((_) => ready = true));
      await pumpEventQueue();
      expect(ready, isFalse);
      d.complete(const DisabledPushMessaging());
      await pumpEventQueue();
      expect(ready, isTrue);
    });

    test('whenPushReady is immediate for any other push', () async {
      var ready = false;
      unawaited(whenPushReady(const DisabledPushMessaging()).then((_) => ready = true));
      await pumpEventQueue();
      expect(ready, isTrue);

      ready = false;
      unawaited(whenPushReady(_FakePush()).then((_) => ready = true));
      await pumpEventQueue();
      expect(ready, isTrue);
    });
  });

  group('DeferredBackgroundSync', () {
    test('calls made before complete run once completed, in order', () async {
      final d = DeferredBackgroundSync();
      final real = _FakeBackground();
      final all = Future.wait([d.start(), d.syncWhenOnline(), d.stop()]);
      await pumpEventQueue();
      expect(real.calls, isEmpty);
      d.complete(real);
      await all;
      expect(real.calls, ['start', 'syncWhenOnline', 'stop']);
    });

    test('forwards calls after complete and ignores a second complete', () async {
      final d = DeferredBackgroundSync();
      final real = _FakeBackground();
      final other = _FakeBackground();
      d.complete(real);
      d.complete(other);
      await d.start();
      await d.stop();
      expect(real.calls, ['start', 'stop']);
      expect(other.calls, isEmpty);
    });
  });

  group('DeferredCrashReporter', () {
    test('available is false before complete and follows the real reporter after', () {
      final d = DeferredCrashReporter();
      expect(d.available, isFalse);
      d.complete(_FakeCrash());
      expect(d.available, isTrue);

      final off = DeferredCrashReporter();
      off.complete(_FakeCrash(available: false));
      expect(off.available, isFalse);
    });

    test('a report and a switch made before complete run once completed', () async {
      final d = DeferredCrashReporter();
      final real = _FakeCrash();
      final pending = Future.wait([
        d.setEnabled(true),
        d.report('boom', StackTrace.empty, fatal: true),
      ]);
      await pumpEventQueue();
      expect(real.calls, isEmpty);
      d.complete(real);
      await pending;
      expect(real.calls, ['setEnabled true', 'report boom fatal=true']);
    });

    test('forwards after complete; a second complete is ignored', () async {
      final d = DeferredCrashReporter();
      final real = _FakeCrash();
      final other = _FakeCrash();
      d.complete(real);
      d.complete(other);
      await d.report('e', null, fatal: false);
      expect(real.calls, ['report e fatal=false']);
      expect(other.calls, isEmpty);
    });
  });

  group('startDeferredServices', () {
    late SharedPreferences prefs;
    late DeferredPushMessaging push;
    late DeferredCrashReporter crash;
    late DeferredBackgroundSync background;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      push = DeferredPushMessaging();
      crash = DeferredCrashReporter();
      background = DeferredBackgroundSync();
    });

    test('completes all three with the injected services', () async {
      final realPush = _FakePush();
      final realCrash = _FakeCrash();
      final realBackground = _FakeBackground();
      SharedPreferences? seenPrefs;

      await startDeferredServices(
        prefs,
        push: push,
        crash: crash,
        background: background,
        initPush: () async => realPush,
        initCrash: (p) async {
          seenPrefs = p;
          return realCrash;
        },
        initBackground: () async => realBackground,
      );

      expect(seenPrefs, same(prefs));
      await push.ready;
      expect(push.available, isTrue);
      expect(crash.available, isTrue);
      await push.requestPermission();
      await crash.report('x', null, fatal: false);
      await background.start();
      expect(realPush.calls, ['requestPermission']);
      expect(realCrash.calls, ['report x fatal=false']);
      expect(realBackground.calls, ['start']);
    });

    test(
      'an init that throws leaves each service disabled, and later calls do not throw',
      () async {
        await startDeferredServices(
          prefs,
          push: push,
          crash: crash,
          background: background,
          initPush: () async => throw StateError('no firebase'),
          initCrash: (_) async => throw StateError('no crashlytics'),
          initBackground: () async => throw StateError('no workmanager'),
        );

        await push.ready;
        expect(push.available, isFalse);
        expect(await push.permission(), PushPermission.denied);
        expect(await push.token(), isNull);
        expect(await push.launchMessage(), isNull);
        await push.deleteToken();
        expect(crash.available, isFalse);
        await crash.setEnabled(true);
        await crash.report('x', StackTrace.empty, fatal: true);
        await background.start();
        await background.syncWhenOnline();
        await background.stop();
      },
    );

    test('one failing init does not stop the others', () async {
      final realBackground = _FakeBackground();
      final realCrash = _FakeCrash();
      await startDeferredServices(
        prefs,
        push: push,
        crash: crash,
        background: background,
        initPush: () async => throw StateError('no firebase'),
        initCrash: (_) async => realCrash,
        initBackground: () async => realBackground,
      );
      expect(push.available, isFalse);
      expect(crash.available, isTrue);
      await background.stop();
      expect(realBackground.calls, ['stop']);
    });

    test('a disabled deferred push shows nothing and emits nothing', () async {
      await startDeferredServices(
        prefs,
        push: push,
        crash: crash,
        background: background,
        initPush: () async => throw StateError('x'),
        initCrash: (_) async => _FakeCrash(),
        initBackground: () async => _FakeBackground(),
      );
      await push.show(const PushMessage(data: {}));
      expect(await push.foreground.toList(), isEmpty);
      expect(await push.opened.toList(), isEmpty);
      expect(await push.tokenRefresh.toList(), isEmpty);
    });
  });
}
