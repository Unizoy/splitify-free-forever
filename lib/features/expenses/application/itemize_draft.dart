import 'dart:convert';

import 'package:splitify/core/money/itemize.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/scaled_input.dart';

/// The extras of an itemized bill, typed as amounts (never %).
enum ItemExtra { tax, service, tip, discount }

/// Most lines one bill may hold (the saved JSON stays far below the server's 32 KB cap, 0022).
const maxItems = 40;

/// Largest `split_values.itemized` JSON saved (the server refuses `split_values` above 32 KB, 0022).
const maxItemizedJson = 24000;

/// Longest item name kept.
const maxItemName = 60;

/// The `split_values` key that holds the lines of an itemized expense (S-372).
const itemizedKey = 'itemized';

/// One line in the Items editor: an optional name, the typed price and who shares it.
final class ItemDraft {
  const ItemDraft({required this.key, required this.members, this.name = '', this.amountText = ''});

  /// Stable id of the row in this editor session (widget keys).
  final int key;
  final String name;
  final String amountText;

  /// Member ids sharing the line (any order; the money engine uses the fixed member order).
  final Set<String> members;

  ItemDraft _copy({String? name, String? amountText, Set<String>? members}) => ItemDraft(
    key: key,
    name: name ?? this.name,
    amountText: amountText ?? this.amountText,
    members: members ?? this.members,
  );
}

/// The Items split (D-034 A2): lines with prices and people, plus tax, service charge, tip and discount.
/// Saved as an exact split with the lines under `split_values.itemized` (S-372).
final class ItemizeDraft {
  const ItemizeDraft._({
    required this.items,
    required this.extras,
    required this.exponent,
    required this.nextKey,
  });

  /// One empty line shared by [people].
  factory ItemizeDraft.start(List<String> people, int exponent) => ItemizeDraft._(
    items: [ItemDraft(key: 0, members: Set.unmodifiable(people))],
    extras: const {},
    exponent: exponent,
    nextKey: 1,
  );

  /// Lines found on a receipt (minor units), each shared by [people]; extras as amounts.
  factory ItemizeDraft.fromLines(
    List<({String name, int amount})> lines,
    List<String> people,
    int exponent, {
    Map<ItemExtra, int> extras = const {},
  }) {
    final rows = [
      for (final (i, line) in lines.take(maxItems).indexed)
        ItemDraft(
          key: i,
          name: _clip(line.name),
          amountText: ScaledInput.format(line.amount, exponent),
          members: Set.unmodifiable(people),
        ),
    ];
    return ItemizeDraft._(
      items: rows.isEmpty ? [ItemDraft(key: 0, members: Set.unmodifiable(people))] : rows,
      extras: {
        for (final e in extras.entries)
          if (e.value > 0) e.key: ScaledInput.format(e.value, exponent),
      },
      exponent: exponent,
      nextKey: rows.isEmpty ? 1 : rows.length,
    );
  }

  /// Reads a saved expense's `split_values` (a JSON string or map): null when it holds no lines.
  /// People who are no longer in [members] are dropped from the lines.
  static ItemizeDraft? fromStored(Object? splitValues, int exponent, {List<String>? members}) {
    final Object? root = splitValues is String ? _decode(splitValues) : splitValues;
    if (root is! Map) return null;
    final data = root[itemizedKey];
    if (data is! Map || data['items'] is! List) return null;
    final known = members?.toSet();
    final rows = <ItemDraft>[];
    for (final raw in (data['items'] as List).whereType<Map<Object?, Object?>>()) {
      final amount = raw['amount'];
      final people = raw['members'];
      rows.add(
        ItemDraft(
          key: rows.length,
          name: _clip(raw['name'] is String ? raw['name']! as String : ''),
          amountText: amount is int ? ScaledInput.format(amount, exponent) : '',
          members: Set.unmodifiable([
            if (people is List)
              for (final p in people.whereType<String>())
                if (known == null || known.contains(p)) p,
          ]),
        ),
      );
    }
    if (rows.isEmpty) return null;
    final extras = data['extras'];
    return ItemizeDraft._(
      items: rows,
      extras: {
        if (extras is Map)
          for (final e in ItemExtra.values)
            if (extras[e.name] is int && extras[e.name] != 0)
              e: ScaledInput.format(extras[e.name]! as int, exponent),
      },
      exponent: exponent,
      nextKey: rows.length,
    );
  }

  final List<ItemDraft> items;

  /// Typed extras; missing = 0.
  final Map<ItemExtra, String> extras;

  /// Currency exponent of the typed prices.
  final int exponent;
  final int nextKey;

  bool get canAdd => items.length < maxItems;

  /// Some extra holds an amount (the extras rows open by themselves).
  bool get hasExtras => extras.values.any((t) => (ScaledInput.parse(t, exponent) ?? 1) != 0);

  ItemizeDraft addItem(Iterable<String> people) => !canAdd
      ? this
      : _copy(
          items: [
            ...items,
            ItemDraft(key: nextKey, members: Set.unmodifiable(people)),
          ],
          nextKey: nextKey + 1,
        );

  ItemizeDraft removeItem(int key) => _copy(
    items: [
      for (final i in items)
        if (i.key != key) i,
    ],
  );

  ItemizeDraft setName(int key, String name) => _update(key, (i) => i._copy(name: name));

  ItemizeDraft setAmount(int key, String text) => _update(key, (i) => i._copy(amountText: text));

  /// Ticks or unticks [member] on line [key].
  ItemizeDraft toggleMember(int key, String member) => _update(key, (i) {
    final next = {...i.members};
    if (!next.remove(member)) next.add(member);
    return i._copy(members: Set.unmodifiable(next));
  });

  ItemizeDraft setExtra(ItemExtra extra, String text) =>
      _copy(extras: Map.unmodifiable({...extras, extra: text}));

  /// The same lines for a currency with [exponent] decimals (texts are checked again).
  ItemizeDraft withExponent(int exponent) =>
      ItemizeDraft._(items: items, extras: extras, exponent: exponent, nextKey: nextKey);

  /// Lines that count (a line with nothing typed is ignored), in minor units; null when some price is
  /// not an amount.
  List<ItemLine>? get lines {
    final out = <ItemLine>[];
    for (final i in items) {
      final v = ScaledInput.parse(i.amountText, exponent);
      if (v == null) return null;
      if (v == 0 && i.members.isEmpty) continue;
      out.add((amount: v, members: i.members.toList()));
    }
    return out;
  }

  /// Parsed extras; null when some text is not an amount.
  ItemExtras? get parsedExtras {
    int? v(ItemExtra e) => ScaledInput.parse(extras[e] ?? '', exponent);
    final tax = v(ItemExtra.tax);
    final service = v(ItemExtra.service);
    final tip = v(ItemExtra.tip);
    final discount = v(ItemExtra.discount);
    if (tax == null || service == null || tip == null || discount == null) return null;
    return (tax: tax, service: service, tip: tip, discount: discount);
  }

  /// What the lines and extras come to (live footer, "Use items total"); null while some text is invalid.
  int? get total {
    final l = lines;
    final e = parsedExtras;
    if (l == null || e == null) return null;
    try {
      return itemizedTotal(l, e);
    } on MoneyError {
      return null;
    }
  }

  /// Each person's share (every id of [order]); throws [FormatException] for text that is not an amount
  /// and a [MoneyError] from [itemize].
  Map<String, int> shares(List<String> order) {
    final l = lines;
    final e = parsedExtras;
    if (l == null || e == null) throw const FormatException('item amount');
    return itemize(order, l, e);
  }

  /// The `split_values.itemized` object: amounts in minor units, members in [order] (fixed member order).
  Map<String, Object?> toJson(List<String> order) {
    final l = lines ?? const <ItemLine>[];
    final e = parsedExtras ?? noExtras;
    final rank = {for (final (i, id) in order.indexed) id: i};
    final named = [
      for (final i in items)
        if ((ScaledInput.parse(i.amountText, exponent) ?? 0) != 0 || i.members.isNotEmpty) i,
    ];
    return {
      'v': 1,
      'items': [
        for (final (n, line) in l.indexed)
          {
            if (n < named.length && named[n].name.trim().isNotEmpty) 'name': named[n].name.trim(),
            'amount': line.amount,
            'members': [...line.members]
              ..sort((a, b) => (rank[a] ?? order.length).compareTo(rank[b] ?? order.length)),
          },
      ],
      'extras': {'tax': e.tax, 'service': e.service, 'tip': e.tip, 'discount': e.discount},
    };
  }

  ItemizeDraft _update(int key, ItemDraft Function(ItemDraft i) change) =>
      _copy(items: [for (final i in items) i.key == key ? change(i) : i]);

  ItemizeDraft _copy({List<ItemDraft>? items, Map<ItemExtra, String>? extras, int? nextKey}) =>
      ItemizeDraft._(
        items: List.unmodifiable(items ?? this.items),
        extras: extras ?? this.extras,
        exponent: exponent,
        nextKey: nextKey ?? this.nextKey,
      );

  static String _clip(String s) {
    final t = s.trim();
    return t.length > maxItemName ? t.substring(0, maxItemName).trim() : t;
  }

  static Object? _decode(String s) {
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }
}
