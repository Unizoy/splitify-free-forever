import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/theme/app_motion.dart';

void main() {
  const normal = AppMotion(reduced: false);
  const reduced = AppMotion(reduced: true);

  Duration ms(int v) => Duration(milliseconds: v);

  group('AppMotion tokens', () {
    test('S-451/S-452 tokens have their documented values', () {
      expect(normal.expand, ms(220));
      expect(normal.insert, ms(240));
      expect(normal.swap, ms(180));
      expect(normal.success, ms(280));
      expect(normal.successHold, ms(420));
    });

    test('select is fast and sheet is slow', () {
      expect(normal.select, ms(150));
      expect(normal.select, normal.fast);
      expect(normal.sheet, ms(300));
      expect(normal.sheet, normal.slow);
    });

    test('transition tokens stay within 90-350 ms', () {
      final all = {
        'press': normal.press,
        'release': normal.release,
        'fast': normal.fast,
        'base': normal.base,
        'slow': normal.slow,
        'showcase': normal.showcase,
        'route': normal.route,
        'routeBack': normal.routeBack,
        'tab': normal.tab,
        'count': normal.count,
        'entrance': normal.entrance,
        'intro': normal.intro,
        'expand': normal.expand,
        'insert': normal.insert,
        'swap': normal.swap,
        'success': normal.success,
        'select': normal.select,
        'sheet': normal.sheet,
      };
      for (final e in all.entries) {
        expect(e.value, greaterThanOrEqualTo(ms(90)), reason: e.key);
        expect(e.value, lessThanOrEqualTo(ms(350)), reason: e.key);
      }
      expect(normal.sheet, lessThanOrEqualTo(ms(350)));
    });

    test('every duration is zero when motion is reduced (shimmer and float excepted)', () {
      final zeroed = {
        'press': reduced.press,
        'release': reduced.release,
        'fast': reduced.fast,
        'base': reduced.base,
        'slow': reduced.slow,
        'showcase': reduced.showcase,
        'route': reduced.route,
        'routeBack': reduced.routeBack,
        'tab': reduced.tab,
        'count': reduced.count,
        'entrance': reduced.entrance,
        'stagger': reduced.stagger,
        'intro': reduced.intro,
        'expand': reduced.expand,
        'insert': reduced.insert,
        'swap': reduced.swap,
        'success': reduced.success,
        'successHold': reduced.successHold,
        'select': reduced.select,
        'sheet': reduced.sheet,
      };
      for (final e in zeroed.entries) {
        expect(e.value, Duration.zero, reason: e.key);
      }
      // Documented exceptions: callers never start these when reduced.
      expect(reduced.shimmer, normal.shimmer);
      expect(reduced.float, normal.float);
    });
  });
}
