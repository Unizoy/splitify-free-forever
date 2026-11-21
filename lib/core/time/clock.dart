/// Injectable clock so tests control time.
abstract class Clock {
  DateTime now();
}

/// Real time (UTC).
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
