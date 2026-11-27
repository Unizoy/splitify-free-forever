import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/amount_expression.dart';
import 'package:splitify/core/money/balances.dart' show Transfer;
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/currency/application/conversion_actions.dart'
    show savedFxOfPayment;
import 'package:splitify/features/currency/domain/conversion.dart' show paymentFxAfterEdit;
import 'package:splitify/features/expenses/application/expense_draft.dart'
    show isoDate, parseIsoDate;
import 'package:splitify/features/groups/application/groups_providers.dart';

/// What Settle up opens: a new payment in [groupId] (optionally [from] → [to] in [currency]), or the
/// saved payment [paymentId] to edit.
typedef SettleArgs = ({
  String groupId,
  String? from,
  String? to,
  String? currency,
  String? paymentId,
});

/// The group or payment is not on this phone.
class SettleNotFound implements Exception {
  const SettleNotFound();
}

/// Longest payment note (server check, 0004).
const maxPaymentNote = 200;

/// The Settle up form (#25).
class SettleDraft {
  const SettleDraft({
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.balances,
    required this.from,
    required this.to,
    required this.currency,
    required this.date,
    this.groupType = 'other',
    this.meId,
    this.amountText = '',
    this.amountEdited = false,
    this.method = 'cash',
    this.note = '',
    this.paymentId,
  });

  final String groupId;
  final String groupName;

  /// `trip`, `home`, `couple`, `direct` or `other` (the group chip's icon).
  final String groupType;

  /// People who can pay or be paid (active members, plus the saved payment's people).
  final List<LocalMember> members;

  /// Group balances without the payment being edited.
  final GroupBalances balances;
  final String? meId;
  final String from;
  final String to;
  final String currency;
  final String amountText;

  /// The person typed an amount: changing people keeps it.
  final bool amountEdited;
  final String method;
  final DateTime date;
  final String note;
  final String? paymentId;

  bool get isEdit => paymentId != null;

  AmountResult get amountResult => AmountExpression.evaluate(amountText, currency);

  /// Minor units, or null while the amount is not valid.
  int? get amount => switch (amountResult) {
    AmountOk(:final minor) => minor,
    _ => null,
  };

  /// What [from] owes [to] in [currency] as the Balances tab shows it (0 = nothing).
  int get owed => balances.owed(from, to, currency);

  String nameOf(String id) => balances.nameOf(id);

  bool get noteTooLong => note.trim().length > maxPaymentNote;

  bool get canSave => amount != null && from != to && !noteTooLong;

  Map<String, Object?> toRow() {
    final a = amount;
    if (a == null || !canSave) throw StateError('payment draft is not valid');
    final n = note.trim();
    return {
      'from_member': from,
      'to_member': to,
      'amount': a,
      'currency': currency,
      'date': isoDate(date),
      'method': method,
      'note': n.isEmpty ? null : n,
    };
  }

  /// The same form in [code] (#14 currency picker).
  SettleDraft withCurrency(String code) => SettleDraft(
    groupId: groupId,
    groupName: groupName,
    groupType: groupType,
    members: members,
    balances: balances,
    meId: meId,
    from: from,
    to: to,
    currency: code,
    amountText: amountText,
    amountEdited: amountEdited,
    method: method,
    date: date,
    note: note,
    paymentId: paymentId,
  );

  SettleDraft copyWith({
    String? from,
    String? to,
    String? amountText,
    bool? amountEdited,
    String? method,
    DateTime? date,
    String? note,
  }) => SettleDraft(
    groupId: groupId,
    groupName: groupName,
    groupType: groupType,
    members: members,
    balances: balances,
    meId: meId,
    from: from ?? this.from,
    to: to ?? this.to,
    currency: currency,
    amountText: amountText ?? this.amountText,
    amountEdited: amountEdited ?? this.amountEdited,
    method: method ?? this.method,
    date: date ?? this.date,
    note: note ?? this.note,
    paymentId: paymentId,
  );
}

Duration? _noRetry(int retryCount, Object error) => null;

/// Reads only the local database: a missing group or payment shows at once (no retry).
final settleProvider = AsyncNotifierProvider.autoDispose
    .family<SettleController, SettleDraft, SettleArgs>(SettleController.new, retry: _noRetry);

/// Settle up / edit payment: prefills person, direction and amount from the balances, saves through
/// the payments repository → outbox (offline-first).
class SettleController extends AsyncNotifier<SettleDraft> {
  SettleController(this.args);

  final SettleArgs args;

  @override
  Future<SettleDraft> build() async {
    final ledgers = ref.read(ledgerRepositoryProvider);
    final id = args.paymentId;
    final saved = id == null ? null : await ledgers.watchPayment(id).first;
    if (id != null && (saved == null || saved.deletedAt != null)) throw const SettleNotFound();
    final ledger = await ledgers.loadGroup(saved?.groupId ?? args.groupId);
    if (ledger == null) throw const SettleNotFound();
    final others = saved == null
        ? ledger
        : GroupLedger(
            group: ledger.group,
            members: ledger.members,
            expenses: ledger.expenses,
            payments: [
              for (final p in ledger.payments)
                if (p.id != saved.id) p,
            ],
          );
    final balances = groupBalancesOf(others, ref.read(currentUserIdProvider));
    final me = balances.meId;
    // Asked-for people must be in the group; the same person twice is no pair (D-033 bug: a link
    // with someone unknown, or the same id twice, opened a form the screen could not show).
    final known = {for (final m in ledger.members) m.id};
    final pair = saved == null && args.from != args.to;
    final askedFrom = pair && known.contains(args.from) ? args.from : null;
    final askedTo = pair && known.contains(args.to) ? args.to : null;
    // Someone who left still shows on the Balances tab while they owe: their row can be settled.
    final members = [
      for (final m in ledger.members)
        if ((m.deletedAt == null && m.status == 'active') ||
            m.id == saved?.fromMember ||
            m.id == saved?.toMember ||
            m.id == askedFrom ||
            m.id == askedTo)
          m,
    ];
    if (members.length < 2) throw const SettleNotFound();
    final today = ref.read(clockProvider).now();
    if (saved != null) {
      return SettleDraft(
        groupId: ledger.group.id,
        groupName: ledger.group.name,
        groupType: ledger.group.type,
        members: members,
        balances: balances,
        meId: me,
        from: saved.fromMember,
        to: saved.toMember,
        currency: saved.currency.trim(),
        amountText: ScaledInput.format(saved.amount, Currencies.exponentOf(saved.currency.trim())),
        amountEdited: true,
        method: saved.method,
        date: parseIsoDate(saved.date),
        note: saved.note ?? '',
        paymentId: saved.id,
      );
    }
    var currency = args.currency ?? balances.mainCurrency;
    var from = askedFrom;
    var to = askedTo;
    if (from == null || to == null) {
      final t = _suggest(balances, me, from ?? to);
      if (t != null) {
        currency = args.currency ?? t.$1;
        from = t.$2.from;
        to = t.$2.to;
      } else {
        from ??= me ?? members.first.id;
        to ??= members.firstWhere((m) => m.id != from).id;
      }
    }
    final draft = SettleDraft(
      groupId: ledger.group.id,
      groupName: ledger.group.name,
      groupType: ledger.group.type,
      members: members,
      balances: balances,
      meId: me,
      from: from,
      to: to,
      currency: currency,
      date: DateTime(today.year, today.month, today.day),
    );
    return draft.copyWith(amountText: _owedText(draft));
  }

  /// The first transfer the Balances tab shows that involves [person] (or me), main currency first.
  static (String, Transfer)? _suggest(GroupBalances b, String? me, String? person) {
    for (final who in [?person, ?me]) {
      for (final c in b.currencies) {
        for (final t in b.shown(c)) {
          if (t.from == who || t.to == who) return (c, t);
        }
      }
    }
    return null;
  }

  /// What is owed as field text, money style: "8822.50", not "8822.5" (whole amounts stay "8822"; final QA).
  static String _owedText(SettleDraft d) {
    if (d.owed <= 0) return '';
    final decimals = Currencies.exponentOf(d.currency);
    final text = ScaledInput.format(d.owed, decimals);
    final dot = text.indexOf('.');
    return dot < 0 ? text : text.padRight(dot + 1 + decimals, '0');
  }

  void _set(SettleDraft Function(SettleDraft d) f) {
    final d = state.value;
    if (d != null) state = AsyncData(f(d));
  }

  /// New people: the amount follows what they owe unless it was typed.
  SettleDraft _people(SettleDraft d, String from, String to) {
    final next = d.copyWith(from: from, to: to);
    return d.amountEdited ? next : next.copyWith(amountText: _owedText(next));
  }

  void setFrom(String id) =>
      _set((d) => id == d.to ? _people(d, d.to, d.from) : _people(d, id, d.to));

  void setTo(String id) =>
      _set((d) => id == d.from ? _people(d, d.to, d.from) : _people(d, d.from, id));

  void swap() => _set((d) => _people(d, d.to, d.from));

  /// Another currency: the amount follows what is owed in it unless it was typed.
  /// UPI is for rupees only (rule 13): another currency drops a chosen UPI method back to cash.
  void setCurrency(String code) => _set((d) {
    var next = d.withCurrency(code);
    if (code != 'INR' && next.method == 'upi') next = next.copyWith(method: 'cash');
    return d.amountEdited ? next : next.copyWith(amountText: _owedText(next));
  });

  void setAmountText(String text) => _set((d) => d.copyWith(amountText: text, amountEdited: true));

  /// Fills in exactly what is owed.
  void useOwed() => _set((d) => d.copyWith(amountText: _owedText(d), amountEdited: true));

  void setMethod(String method) => _set((d) => d.copyWith(method: method));

  void setDate(DateTime date) => _set((d) => d.copyWith(date: date));

  void setNote(String note) => _set((d) => d.copyWith(note: note));

  /// Saves (offline-first); returns the payment id, or null when the form is not valid.
  Future<String?> save() async {
    final d = state.value;
    if (d == null || !d.canSave) return null;
    final row = d.toRow();
    if (!d.isEdit) row['created_at'] = ref.read(clockProvider).now().toUtc().toIso8601String();
    if (d.isEdit) {
      // A saved conversion follows the edit (phase 14, S-151).
      final saved = await ref.read(ledgerRepositoryProvider).watchPayment(d.paymentId!).first;
      if (saved != null) {
        row.addAll(
          paymentFxAfterEdit(
            saved: savedFxOfPayment(saved),
            oldCurrency: saved.currency.trim(),
            currency: d.currency,
            amount: row['amount']! as int,
          ),
        );
      }
    }
    return ref.read(paymentsRepositoryProvider).save(d.groupId, row, id: d.paymentId);
  }
}

/// Settle-up choices for a group (D-033, Splitwise's "pick a balance"): what its Balances tab shows, per
/// currency (the group's main currency first); in each currency my balances first, then the others',
/// each biggest first (equal amounts keep the tab order).
List<({String currency, Transfer transfer})> settleSuggestions(GroupBalances b) {
  final me = b.meId;
  bool mine(Transfer t) => me != null && (t.from == me || t.to == me);
  return [
    for (final c in b.currencies)
      for (final t in _biggestFirst([
        ...b.shown(c).where(mine),
      ]).followedBy(_biggestFirst([...b.shown(c).where((t) => !mine(t))])))
        (currency: c, transfer: t),
  ];
}

List<Transfer> _biggestFirst(List<Transfer> list) {
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((x, y) {
    final byAmount = y.$2.amount.compareTo(x.$2.amount);
    return byAmount != 0 ? byAmount : x.$1.compareTo(y.$1);
  });
  return [for (final x in indexed) x.$2];
}
