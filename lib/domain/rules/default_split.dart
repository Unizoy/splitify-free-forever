import 'dart:convert';

import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/split.dart';

/// A group's default split (#35), stored as `groups.default_split = {kind, values, payer?}` (05 §4). Only
/// amount-free kinds can be defaults: equal (values empty = everyone), percent and shares (S-081). [payer]
/// (W2-X P-10, S-424) is who pays by default; none = whoever adds the expense.
final class DefaultSplit {
  const DefaultSplit(this.kind, [this.values = const {}, this.payer]);

  final SplitKind kind;

  /// Raw editor values by member id (basis points or thousandths of a share).
  final Map<String, int> values;

  /// The default payer's member id (null = whoever adds the expense).
  final String? payer;

  /// Equal between everyone and no default payer: the same as no default at all.
  bool get isPlain => kind == SplitKind.equal && values.isEmpty && payer == null;

  /// Kinds a group may store as its default.
  static const kinds = [SplitKind.equal, SplitKind.percent, SplitKind.shares];

  /// The stored JSON text → split, or null when missing or not understood.
  static DefaultSplit? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final m = jsonDecode(json) as Map<String, Object?>;
      final kind = SplitKind.parse(m['kind']! as String);
      if (!kinds.contains(kind)) return null;
      final raw = (m['values'] as Map<String, Object?>?) ?? const {};
      final payer = m['payer'];
      return DefaultSplit(kind, {
        for (final e in raw.entries) e.key: e.value! as int,
      }, payer is String && payer.isNotEmpty ? payer : null);
    } on Object {
      return null;
    }
  }

  /// Server column value.
  Map<String, Object?> toJson() => {'kind': kind.name, 'values': values, 'payer': ?payer};

  /// The default payer when they are still one of [activeMembers]; else null (= whoever adds it).
  String? payerIn(List<String> activeMembers) =>
      payer != null && activeMembers.contains(payer) ? payer : null;

  /// What a new expense starts from with [activeMembers] (fixed order): this split when it still fits
  /// them, else null (= equal between everyone). It fits when its members are exactly the active
  /// members and the engine accepts its values; equal with no values always fits.
  DefaultSplit? resolve(List<String> activeMembers) {
    if (activeMembers.isEmpty) return null;
    if (kind == SplitKind.equal && values.isEmpty) return this;
    final keys = values.keys.toSet();
    if (keys.length != activeMembers.length || !activeMembers.every(keys.contains)) return null;
    try {
      split(10000, kind, activeMembers, values);
      return this;
    } on MoneyError {
      return null;
    }
  }
}
