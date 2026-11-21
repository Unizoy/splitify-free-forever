import 'dart:collection';

/// Keeps the last [capacity] log lines in memory for "Export debug log".
class LogBuffer {
  LogBuffer({this.capacity = 2000});

  final int capacity;
  final Queue<String> _lines = Queue<String>();

  void add(String line) {
    _lines.addLast(line);
    while (_lines.length > capacity) {
      _lines.removeFirst();
    }
  }

  List<String> get lines => List.unmodifiable(_lines);

  String export() => _lines.join('\n');

  void clear() => _lines.clear();
}
