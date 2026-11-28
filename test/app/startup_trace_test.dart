import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/app/startup_trace.dart';

void main() {
  group('StartupTrace (S-450)', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('r3b-proc'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('is off unless the build asks for it', () {
      expect(StartupTrace.on, isFalse);
      // Off: start/runApp do nothing (no binding needed, nothing printed).
      StartupTrace.start();
      StartupTrace.runApp();
    });

    test('process age = uptime − start time (10 ms ticks), command names with spaces too', () {
      final stat = File('${dir.path}/stat')
        ..writeAsStringSync(
          // pid (comm) state … field 22 (starttime) = 12345 ticks.
          '4242 (ify.splitify qa) S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 12345 19 20',
        );
      final uptime = File('${dir.path}/uptime')..writeAsStringSync('125.50 300.00\n');
      expect(StartupTrace.processAgeMs(stat: stat.path, uptime: uptime.path), 125500 - 123450);
    });

    test('null when /proc is not there', () {
      expect(
        StartupTrace.processAgeMs(stat: '${dir.path}/missing', uptime: '${dir.path}/missing'),
        isNull,
      );
    });
  });
}
