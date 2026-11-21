/// Local vs server balance checks (05 §5 "Server vs phone", rule 3, TC-15-04): both sides are
/// reduced to a canonical text and an FNV-1a checksum; a difference means a bug and is logged.
library;

import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/utils/stable_hash.dart';

/// Canonical text of a group's balances: per currency (alphabetical) the non-zero nets by member id,
/// the original pairs and the simplified transfers, both sorted by (from, to).
String balancesFingerprint(Map<String, Balances> byCurrency) {
  final b = StringBuffer();
  for (final code in byCurrency.keys.toList()..sort()) {
    final x = byCurrency[code]!;
    final nets = x.nets.entries.where((e) => e.value != 0).toList()
      ..sort((a, c) => a.key.compareTo(c.key));
    b
      ..write(code)
      ..write('|n:')
      ..write(nets.map((e) => '${e.key}=${e.value}').join(','))
      ..write('|p:')
      ..write(_transfers(x.pairs))
      ..write('|s:')
      ..write(_transfers(x.simplified))
      ..write(';');
  }
  return b.toString();
}

String _transfers(List<Transfer> ts) {
  final sorted = [...ts]
    ..sort((a, c) {
      final f = a.from.compareTo(c.from);
      return f != 0 ? f : a.to.compareTo(c.to);
    });
  return sorted.map((t) => '${t.from}>${t.to}=${t.amount}').join(',');
}

/// Checksum of [balancesFingerprint].
int balancesChecksum(Map<String, Balances> byCurrency) =>
    stableHash(balancesFingerprint(byCurrency));

/// Canonical text of my balance per group (group id → currency → non-zero net).
String overviewFingerprint(Map<String, Map<String, int>> byGroup) {
  final b = StringBuffer();
  for (final g in byGroup.keys.toList()..sort()) {
    final nets = byGroup[g]!.entries.where((e) => e.value != 0).toList()
      ..sort((a, c) => a.key.compareTo(c.key));
    if (nets.isEmpty) continue;
    b
      ..write(g)
      ..write(':')
      ..write(nets.map((e) => '${e.key}=${e.value}').join(','))
      ..write(';');
  }
  return b.toString();
}

/// Group ids whose balances differ between [local] and [server] (sorted).
List<String> overviewDifferences(
  Map<String, Map<String, int>> local,
  Map<String, Map<String, int>> server,
) {
  String one(Map<String, Map<String, int>> m, String g) =>
      overviewFingerprint({if (m.containsKey(g)) g: m[g]!});
  final ids = {...local.keys, ...server.keys}.toList()..sort();
  return [
    for (final g in ids)
      if (one(local, g) != one(server, g)) g,
  ];
}

/// `0x1a2b3c4d` style text of a checksum for logs.
String checksumText(int checksum) => '0x${checksum.toRadixString(16).padLeft(8, '0')}';
