import 'package:splitify/core/time/clock.dart';

/// Clock that only moves when the test says so.
class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}
