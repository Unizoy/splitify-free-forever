// Coverage floors (gate G2). Run after `flutter test --coverage`.
// Floors: planning/09-testing-strategy.md section 4.
// ignore_for_file: avoid_print
import 'dart:io';

/// Ordered most specific first; the first matching prefix wins.
const _floors = <(String, String, double)>[
  ('lib/core/money/', 'money', 100),
  ('lib/data/sync/', 'sync', 95),
  ('lib/core/', 'core', 90),
  ('lib/domain/', 'domain', 90),
  ('lib/data/', 'data', 85),
];
const _overall = 80.0;
const _presentation = 60.0;

bool _excluded(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.startsWith('lib/l10n/') ||
    p == 'lib/main.dart';

bool _isController(String p) => p.contains('/application/');
bool _isPresentation(String p) =>
    p.contains('/presentation/') || p.startsWith('lib/ui/') || p.startsWith('lib/app/');

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('coverage/lcov.info not found. Run flutter test --coverage first.');
    exit(1);
  }
  final found = <String, int>{};
  final hit = <String, int>{};
  String? current;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll('\\', '/');
      found[current] = 0;
      hit[current] = 0;
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      found[current] = found[current]! + 1;
      if (int.parse(parts[1]) > 0) hit[current] = hit[current]! + 1;
    }
  }

  final groups = <String, List<int>>{}; // name -> [found, hit, floor*10]
  var totalFound = 0;
  var totalHit = 0;
  void add(String name, double floor, String p) {
    final g = groups.putIfAbsent(name, () => [0, 0, (floor * 10).round()]);
    g[0] += found[p]!;
    g[1] += hit[p]!;
  }

  for (final p in found.keys) {
    if (_excluded(p)) continue;
    totalFound += found[p]!;
    totalHit += hit[p]!;
    if (_isController(p)) {
      add('application', 85, p);
      continue;
    }
    if (_isPresentation(p)) {
      add('presentation', _presentation, p);
      continue;
    }
    for (final (prefix, name, floor) in _floors) {
      if (p.startsWith(prefix)) {
        add(name, floor, p);
        break;
      }
    }
  }

  var failed = false;
  double pct(int h, int f) => f == 0 ? 100 : h * 100 / f;
  for (final e in groups.entries) {
    final p = pct(e.value[1], e.value[0]);
    final floor = e.value[2] / 10;
    final ok = p >= floor;
    if (!ok) failed = true;
    print(
      '${ok ? 'PASS' : 'FAIL'} ${e.key.padRight(13)} '
      '${p.toStringAsFixed(1)}% (floor $floor%)',
    );
  }
  final o = pct(totalHit, totalFound);
  final okAll = o >= _overall;
  if (!okAll) failed = true;
  print(
    '${okAll ? 'PASS' : 'FAIL'} ${'overall'.padRight(13)} '
    '${o.toStringAsFixed(1)}% (floor $_overall%)',
  );
  if (failed) exit(1);
}
