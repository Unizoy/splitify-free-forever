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

/// The phone's calendar day (08: an expense date is a local date, "today in the device time zone").
/// `DateTime(now.year, now.month, now.day)` on the UTC clock gave yesterday in India between 00:00 and
/// 05:30 (final QA: a friend expense saved at 00:08 IST got the previous day).
extension LocalToday on Clock {
  DateTime today() {
    final local = now().toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
