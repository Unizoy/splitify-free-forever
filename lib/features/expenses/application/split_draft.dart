import 'dart:convert';

import 'package:splitify/core/money/allocation.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/domain/rules/default_split.dart';
import 'package:splitify/features/expenses/application/itemize_draft.dart';

/// Result of checking the split editor against a total (05 §4).
sealed class SplitCheck {
  const SplitCheck();
}

/// Valid: each participant's share (participants in fixed order; sums to the total).
final class SplitReady extends SplitCheck {
  const SplitReady(this.shares);

  final Map<String, int> shares;
}

/// Not valid yet: a money-engine [code] (`SUM_MISMATCH`, …) or `INVALID_INPUT` for text that is not a
/// number. [amount] is the engine's remaining/over value (minor units, or basis points for percent);
/// negative means over.
final class SplitInvalid extends SplitCheck {
  const SplitInvalid(this.code, [this.amount = 0]);

  static const invalidInput = 'INVALID_INPUT';

  /// The Items split holds more than the server keeps in `split_values` (S-372).
  static const itemsTooLarge = 'ITEMS_TOO_LARGE';

  final String code;
  final int amount;
}

/// Editor state for one split (immutable). [members] are the people shown, in fixed order
/// (`position`, then id). Equal and adjust split between [included]; exact, percent and shares list
/// everyone and read their typed values (S-080).
final class SplitDraft {
  const SplitDraft._({
    required this.kind,
    required this.members,
    required this.included,
    required this.text,
    required this.shareUnits,
    required this.exponent,
    this.items,
  });

  /// Equal between all [members], or [preset] (a group default split that still fits, #35).
  factory SplitDraft.initial(List<String> members, int exponent, {DefaultSplit? preset}) {
    final base = SplitDraft._(
      kind: SplitKind.equal,
      members: List.unmodifiable(members),
      included: Set.unmodifiable(members),
      text: const {},
      shareUnits: const {},
      exponent: exponent,
    );
    if (preset == null) return base;
    return base.withValues(preset.kind, preset.values);
  }

  /// Reopens a saved expense: [kind], its participants (the keys of its stored shares) and its raw
  /// `split_values`. Participants missing from [members] (removed later) are appended.
  factory SplitDraft.stored({
    required List<String> members,
    required int exponent,
    required SplitKind kind,
    required List<String> participants,
    Map<String, int> values = const {},
  }) {
    final all = [...members, ...participants.where((p) => !members.contains(p))];
    final base = SplitDraft._(
      kind: SplitKind.equal,
      members: List.unmodifiable(all),
      included: Set.unmodifiable(participants),
      text: const {},
      shareUnits: const {},
      exponent: exponent,
    );
    return base.withValues(kind, values);
  }

  final SplitKind kind;
  final List<String> members;

  /// Chosen people for equal and adjust.
  final Set<String> included;

  /// Typed values for exact (minor units), percent (e.g. `33.33`) and adjust (signed minor units).
  final Map<String, String> text;

  /// Shares in thousandths (1000 = one share).
  final Map<String, int> shareUnits;

  /// Currency exponent for exact and adjust values.
  final int exponent;

  /// The Items split (D-034 A2): lines with prices and people. Saved as an exact split whose shares the
  /// lines decide; null for the other kinds.
  final ItemizeDraft? items;

  /// The Items split is chosen.
  bool get isItems => items != null;

  /// Same people, [kind] with raw engine [values] (basis points, thousandths or minor units).
  SplitDraft withValues(SplitKind kind, Map<String, int> values) {
    return SplitDraft._(
      kind: kind,
      members: members,
      included: included,
      text: switch (kind) {
        SplitKind.exact || SplitKind.adjust => {
          for (final e in values.entries)
            if (e.value != 0) e.key: ScaledInput.format(e.value, exponent),
        },
        SplitKind.percent => {
          for (final e in values.entries)
            if (e.value != 0) e.key: ScaledInput.format(e.value, 2),
        },
        _ => const {},
      },
      shareUnits: kind == SplitKind.shares ? Map.unmodifiable(values) : const {},
      exponent: exponent,
    );
  }

  /// Equal and adjust show tick boxes; the other kinds a value per person.
  bool get usesInclusion => !isItems && (kind == SplitKind.equal || kind == SplitKind.adjust);

  /// People who take part: chosen ones (equal, adjust) or everyone (exact, percent, shares).
  List<String> get participants => usesInclusion
      ? [
          for (final m in members)
            if (included.contains(m)) m,
        ]
      : members;

  /// People with something to pay in the current editor values (drives "keep chosen members").
  List<String> get chosen {
    if (usesInclusion) return participants;
    final lines = items?.lines;
    if (lines != null) {
      final on = {for (final l in lines) ...l.members};
      final picked = [
        for (final m in members)
          if (on.contains(m)) m,
      ];
      return picked.isEmpty ? members : picked;
    }
    final v = values ?? const <String, int>{};
    final picked = [
      for (final m in members)
        if ((v[m] ?? 0) != 0) m,
    ];
    return picked.isEmpty ? members : picked;
  }

  /// Parsed raw values for the engine, or null when some typed text is not a number.
  Map<String, int>? get values {
    final itemized = items;
    if (itemized != null) {
      try {
        return itemized.shares(members);
      } on FormatException {
        return null;
      } on MoneyError {
        return null;
      }
    }
    switch (kind) {
      case SplitKind.equal:
        return const {};
      case SplitKind.shares:
        return {for (final m in members) m: shareUnits[m] ?? 0};
      case SplitKind.exact || SplitKind.percent || SplitKind.adjust:
        final decimals = kind == SplitKind.percent ? 2 : exponent;
        final out = <String, int>{};
        for (final m in participants) {
          final v = ScaledInput.parse(text[m] ?? '', decimals, signed: kind == SplitKind.adjust);
          if (v == null) return null;
          out[m] = v;
        }
        return out;
    }
  }

  /// Sum of the parsed values (live footer), 0 when some text is invalid. Items: what the lines and
  /// extras come to.
  int get valueSum {
    final itemized = items;
    if (itemized != null) return itemized.total ?? 0;
    return (values ?? const {}).values.fold(0, (a, b) => a + b);
  }

  /// Raw values stored as `split_values` (null for equal; participants only).
  Map<String, int>? get storedValues => kind == SplitKind.equal ? null : values;

  /// The `split_values` column: [storedValues], plus the lines under `itemized` for the Items split (S-372).
  Map<String, Object?>? get storedSplitValues {
    final itemized = items;
    final v = storedValues;
    if (itemized == null) return v;
    return {...?v, itemizedKey: itemized.toJson(members)};
  }

  /// Shares for [total] minor units, or why not.
  SplitCheck check(int? total) {
    if (total == null) return const SplitInvalid('AMOUNT_NOT_POSITIVE');
    final itemized = items;
    if (itemized != null) return _checkItems(itemized, total);
    final v = values;
    if (v == null) return const SplitInvalid(SplitInvalid.invalidInput);
    try {
      return SplitReady(split(total, kind, participants, v));
    } on MoneyError catch (e) {
      return switch (e) {
        SumMismatch(:final remaining) => SplitInvalid(e.code, remaining),
        PercentSumMismatch(:final remainingBps) => SplitInvalid(e.code, remainingBps),
        AdjustmentsExceedTotal(:final over) => SplitInvalid(e.code, -over),
        _ => SplitInvalid(e.code),
      };
    }
  }

  /// Items: the lines' shares when they come to [total]; else what is left (+) or over (−), or why not.
  SplitCheck _checkItems(ItemizeDraft itemized, int total) {
    final Map<String, int> shares;
    try {
      shares = itemized.shares(members);
    } on FormatException {
      return const SplitInvalid(SplitInvalid.invalidInput);
    } on MoneyError catch (e) {
      return SplitInvalid(e.code);
    }
    final sum = shares.values.fold(0, (a, b) => a + b);
    if (sum != total) return SplitInvalid('SUM_MISMATCH', total - sum);
    if (jsonEncode(itemized.toJson(members)).length > maxItemizedJson) {
      return const SplitInvalid(SplitInvalid.itemsTooLarge);
    }
    return SplitReady(shares);
  }

  /// For an adjust split of [total] whose result is `NEGATIVE_SHARE`: the first participant (fixed
  /// order) whose share would go below 0, so the error can name them. Null otherwise.
  String? negativeMember(int total) {
    final v = values;
    if (kind != SplitKind.adjust || v == null) return null;
    final people = participants;
    final rest = total - v.values.fold<int>(0, (a, b) => a + b);
    if (people.isEmpty || rest < 0) return null;
    final base = allocateEqual(rest, people.length);
    for (var i = 0; i < people.length; i++) {
      if (base[i] + (v[people[i]] ?? 0) < 0) return people[i];
    }
    return null;
  }

  /// Switches to [next], keeping the chosen people; values reset sensibly (05 §4, #5–9): exact gets the
  /// equal amounts of [total], percent equal percentages, shares one each, adjust no adjustments.
  SplitDraft switchTo(SplitKind next, {int? total}) {
    if (next == kind && !isItems) return this;
    // Items → exact amounts: start from what the lines give each person.
    if (isItems && next == SplitKind.exact) {
      final shares = this.values;
      return SplitDraft._(
        kind: SplitKind.exact,
        members: members,
        included: Set.unmodifiable(members),
        text: const {},
        shareUnits: const {},
        exponent: exponent,
      ).withValues(SplitKind.exact, shares ?? const {});
    }
    final people = chosen;
    final kept = SplitDraft._(
      kind: kind,
      members: members,
      included: Set.unmodifiable(people),
      text: const {},
      shareUnits: const {},
      exponent: exponent,
    );
    List<int> equal(int amount) => allocateEqual(amount, people.length);
    final values = switch (next) {
      SplitKind.equal || SplitKind.adjust => const <String, int>{},
      SplitKind.exact =>
        total == null || total <= 0
            ? const <String, int>{}
            : Map.fromIterables(people, equal(total)),
      SplitKind.percent => Map.fromIterables(people, equal(10000)),
      SplitKind.shares => {for (final p in people) p: 1000},
    };
    return kept.withValues(next, values);
  }

  /// Switches to Items (D-034 A2): one empty line shared by the chosen people. Kept when already there.
  SplitDraft switchToItems() {
    if (isItems) return this;
    return SplitDraft._(
      kind: SplitKind.exact,
      members: members,
      included: Set.unmodifiable(members),
      text: const {},
      shareUnits: const {},
      exponent: exponent,
      items: ItemizeDraft.start(chosen, exponent),
    );
  }

  /// The Items split with [next] lines (an edit in the Items editor, or lines from a scanned receipt).
  SplitDraft withItems(ItemizeDraft next) => SplitDraft._(
    kind: SplitKind.exact,
    members: members,
    included: Set.unmodifiable(members),
    text: const {},
    shareUnits: const {},
    exponent: exponent,
    items: next,
  );

  /// The same split for a currency with [exponent] decimals (the typed values are kept as text and are
  /// checked again against the new exponent).
  SplitDraft withExponent(int exponent) => SplitDraft._(
    kind: kind,
    members: members,
    included: included,
    text: text,
    shareUnits: shareUnits,
    exponent: exponent,
    items: items?.withExponent(exponent),
  );

  /// Ticks or unticks [member] (equal, adjust).
  SplitDraft toggle(String member) {
    final next = {...included};
    if (!next.remove(member)) next.add(member);
    return _copy(included: Set.unmodifiable(next));
  }

  /// Typed value for [member] (exact, percent, adjust).
  SplitDraft setText(String member, String value) =>
      _copy(text: Map.unmodifiable({...text, member: value}));

  /// Shares of [member] in thousandths (shares).
  SplitDraft setShareUnits(String member, int units) =>
      _copy(shareUnits: Map.unmodifiable({...shareUnits, member: units < 0 ? 0 : units}));

  SplitDraft _copy({
    Set<String>? included,
    Map<String, String>? text,
    Map<String, int>? shareUnits,
  }) => SplitDraft._(
    kind: kind,
    members: members,
    included: included ?? this.included,
    text: text ?? this.text,
    shareUnits: shareUnits ?? this.shareUnits,
    exponent: exponent,
    items: items,
  );
}
