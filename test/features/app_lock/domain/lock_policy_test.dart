import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/app_lock/domain/lock_policy.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 22, 10);

  group('LockTimeout.fromMinutes', () {
    test('known values', () {
      expect(LockTimeout.fromMinutes(1), LockTimeout.min1);
      expect(LockTimeout.fromMinutes(5), LockTimeout.min5);
      expect(LockTimeout.fromMinutes(15), LockTimeout.min15);
    });

    test('null and unknown values fall back to 1 minute', () {
      expect(LockTimeout.fromMinutes(null), LockTimeout.min1);
      expect(LockTimeout.fromMinutes(0), LockTimeout.min1);
      expect(LockTimeout.fromMinutes(7), LockTimeout.min1);
      expect(LockTimeout.fromMinutes(-5), LockTimeout.min1);
    });

    test('duration matches minutes', () {
      expect(LockTimeout.min5.duration, const Duration(minutes: 5));
    });
  });

  group('TC-X2-01', () {
    bool lock(
      LockTimeout timeout,
      Duration away, {
      bool enabled = true,
      bool backgrounded = true,
    }) => shouldLockOnResume(
      enabled: enabled,
      backgroundedAt: backgrounded ? t0 : null,
      now: t0.add(away),
      timeout: timeout,
    );

    for (final timeout in LockTimeout.values) {
      group('timeout ${timeout.minutes} min', () {
        // TC-X2-01
        test('disabled never locks', () {
          expect(lock(timeout, const Duration(hours: 5), enabled: false), isFalse);
        });

        // TC-X2-01
        test('never backgrounded never locks', () {
          expect(lock(timeout, const Duration(hours: 5), backgrounded: false), isFalse);
        });

        // TC-X2-01
        test('just under the timeout does not lock', () {
          expect(lock(timeout, timeout.duration - const Duration(milliseconds: 1)), isFalse);
          expect(lock(timeout, Duration.zero), isFalse);
        });

        // TC-X2-01
        test('exactly the timeout locks', () {
          expect(lock(timeout, timeout.duration), isTrue);
        });

        // TC-X2-01
        test('over the timeout locks', () {
          expect(lock(timeout, timeout.duration + const Duration(seconds: 1)), isTrue);
        });

        // TC-X2-01
        test('a clock moved backwards locks', () {
          expect(lock(timeout, const Duration(seconds: -1)), isTrue);
        });
      });
    }
  });
}
