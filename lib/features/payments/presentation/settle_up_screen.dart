import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/currency/presentation/currency_picker_sheet.dart'
    show CurrencyChip, pickGroupCurrency;
import 'package:splitify/features/expenses/presentation/editor/editor_fields.dart'
    show AmountField, ToolChip;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;
import 'package:splitify/features/groups/presentation/group_visuals.dart' show confirmAction;
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/features/payments/application/upi_providers.dart';
import 'package:splitify/features/payments/presentation/money_form.dart';
import 'package:splitify/features/payments/presentation/settled_celebration.dart';
import 'package:splitify/features/payments/presentation/upi_pay.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Record a payment (`/settle`, #25; Splitwise-minimal, D-033): one screen in the add-expense layout —
/// "In [group]", payer → receiver avatars (tap to change, the arrow swaps), the amount prefilled with
/// what is owed on the phone's number keyboard with its currency chip, a pill saying how much of the debt
/// it settles, and a toolbar (date, note, method) with the action above the keyboard. When I pay someone
/// with a UPI ID in rupees (#26, rule 13) amber "Pay ₹x via UPI" comes first and the payment is recorded only
/// after "Mark as paid"; otherwise "Record cash payment". Also edits a saved payment (`/payment/:id/edit`).
/// A payment that settles a person completely plays a short Celebration (T6) over the page below.
class SettleUpScreen extends ConsumerStatefulWidget {
  const SettleUpScreen({
    this.groupId = '',
    this.from,
    this.to,
    this.currency,
    this.paymentId,
    super.key,
  });

  final String groupId;
  final String? from;
  final String? to;
  final String? currency;
  final String? paymentId;

  SettleArgs get args =>
      (groupId: groupId, from: from, to: to, currency: currency, paymentId: paymentId);

  @override
  ConsumerState<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends ConsumerState<SettleUpScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode(debugLabel: 'payment amount');
  bool _filled = false;
  bool _saving = false;
  bool _saved = false;

  /// The person changed something: leaving asks first.
  bool _dirty = false;

  /// Show "required" problems (after a Save attempt).
  bool _showErrors = false;

  /// A method was picked in the sheet: Cash / Bank / Other then mean "record", not "pay via UPI" (final QA).
  bool _methodPicked = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  SettleController get _ctrl => ref.read(settleProvider(widget.args).notifier);

  SettleDraft? get _draft => ref.read(settleProvider(widget.args)).value;

  /// A change the person made (marks the form as changed).
  void _edit(void Function(SettleController c) change) {
    _dirty = true;
    change(_ctrl);
  }

  void _fill(SettleDraft d) {
    if (_filled) return;
    _filled = true;
    _amount.text = d.amountText;
    _note.text = d.note;
    if (!d.isEdit && d.amountText.isEmpty) {
      // Nothing owed to prefill: the amount gets the focus (number keyboard up).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }
  }

  Future<void> _pickCurrency(SettleDraft d) async {
    final code = await pickGroupCurrency(context, ref, groupId: d.groupId, selected: d.currency);
    if (code != null && code != d.currency) _edit((c) => c.setCurrency(code));
  }

  Future<void> _pickDate(SettleDraft d) async {
    final picked = await pickDay(context, value: d.date, today: ref.read(clockProvider).today());
    if (picked != null && !DateUtils.isSameDay(picked, d.date)) _edit((c) => c.setDate(picked));
  }

  Future<void> _openNote() {
    final l = AppLocalizations.of(context);
    return showTextSheet(
      context,
      title: l.settleNote,
      fieldKey: const Key('settle-note'),
      label: l.settleNote,
      hint: l.settleNoteHint,
      controller: _note,
      max: maxPaymentNote,
      tooLong: l.settleNoteTooLong(maxPaymentNote),
      onChanged: (t) => _edit((c) => c.setNote(t)),
    );
  }

  Future<void> _pickMethod(SettleDraft d) async {
    final l = AppLocalizations.of(context);
    final picked = await showAppSheet<String>(
      context,
      title: l.settleMethodTitle,
      builder: (sheet) => PaymentMethodOptions(
        currency: d.currency,
        selected: d.method,
        onPicked: (m) => Navigator.of(sheet).pop(m),
      ),
    );
    if (picked == null) return;
    setState(() => _methodPicked = true);
    if (picked != d.method) _edit((c) => c.setMethod(picked));
  }

  /// Leaving with changes asks first (an app sheet, never a system alert).
  Future<void> _back() async {
    final d = _draft;
    if (_dirty && !_saved && d != null) {
      final l = AppLocalizations.of(context);
      FocusManager.instance.primaryFocus?.unfocus();
      final discard = await confirmAction(
        context,
        title: d.isEdit ? l.expDiscardEditTitle : l.settleDiscardTitle,
        body: d.isEdit ? l.settleDiscardEditBody : l.settleDiscardBody,
        confirm: l.discardLabel,
        icon: AppIcons.trash,
      );
      if (!discard || !mounted) return;
    }
    _close(d?.groupId ?? widget.groupId);
  }

  /// Leaves the form. `pop` ignores the PopScope that asks before discarding.
  void _close(String groupId) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(groupId.isEmpty ? '/groups' : '/groups/$groupId');
    }
  }

  /// What stops saving, shown inline: the amount field gets the focus, a long note opens its sheet.
  bool _check(SettleDraft d) {
    if (d.canSave) return true;
    setState(() => _showErrors = true);
    unawaited(HapticFeedback.lightImpact());
    if (d.amount == null) {
      _amountFocus.requestFocus();
    } else if (d.noteTooLong) {
      unawaited(_openNote());
    }
    return false;
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    final d = _draft;
    if (d == null || !_check(d)) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final root = Navigator.of(context, rootNavigator: true);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final id = await _ctrl.save();
    if (!mounted) return;
    if (id == null) {
      setState(() => _saving = false);
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _saving = false;
      _saved = true;
    });
    final other = settledWith(d);
    _close(d.groupId);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(d.isEdit ? l.settleSaved : l.settleRecorded)));
    // Over the page below (the form is already closed): short, and a tap or Back skips it. After the
    // next frame, so it sits on the page the router shows then (a dialog pushed on top of a page that is
    // being replaced would go with it).
    if (other != null) {
      final name = personName(l, d.balances, other, start: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (root.mounted) unawaited(showSettledCelebration(root.context, name: name));
      });
    }
  }

  Future<void> _payByUpi(String vpa, String payeeName) async {
    if (_saving || _saved) return;
    final d = _draft;
    if (d == null || !_check(d)) return;
    final l = AppLocalizations.of(context);
    final link = upiLinkFor(d, vpa: vpa, name: payeeName, note: l.upiNote(d.groupName));
    if (link == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final paid = await payViaUpi(context, ref, link, payeeName: payeeName, amountMinor: d.amount!);
    if (!paid || !mounted) return;
    // Recorded only after "Mark as paid" (rule 13).
    _edit((c) => c.setMethod('upi'));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Changing the people or the currency re-derives the amount from what is owed: keep the field in step.
    ref.listen(settleProvider(widget.args), (_, next) {
      final text = next.value?.amountText;
      if (_filled && text != null && _amount.text != text) _amount.text = text;
    });
    final async = ref.watch(settleProvider(widget.args));
    final offline = ref.watch(syncOfflineProvider).value ?? false;
    final d = async.value;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(widget.paymentId == null ? l.settleRecordTitle : l.settleEditTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: async.isLoading
                ? DotsPulse(color: context.colors.primary, semanticLabel: l.loading)
                : EmptyState(
                    icon: AppIcons.settle,
                    title: l.settleNotFoundTitle,
                    message: l.settleNotFoundBody,
                  ),
          ),
        ),
      );
    }
    _fill(d);
    final payee = d.members.firstWhere((m) => m.id == d.to);
    final vpa = payee.userId == null ? null : ref.watch(upiIdProvider(payee.userId!)).value;
    final payeeName = personName(l, d.balances, d.to, start: false);
    // Pay via UPI comes first until another method is picked (rule 13: rupees, a payee with a UPI ID).
    final upi = canPayByUpi(d, vpa) && (!_methodPicked || d.method == 'upi');
    final amountError =
        l.amountError(d.amountResult, d.currency) ??
        (_showErrors && d.amount == null ? l.expAmountMissing : null);
    final today = ref.read(clockProvider).today();
    final record = PillButton(
      key: const Key('settle-save'),
      label: d.isEdit ? l.settleSave : recordLabel(l, d.method),
      icon: upi ? null : AppIcons.check,
      variant: upi ? PillVariant.ghost : PillVariant.money,
      size: upi ? PillSize.medium : PillSize.large,
      loading: _saving && !upi,
      onPressed: () => unawaited(_save()),
    );
    return PopScope(
      canPop: _saved || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => unawaited(_back()),
          ),
          title: Text(d.isEdit ? l.settleEditTitle : l.settleRecordTitle),
        ),
        body: PageBody(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: const Key('settle-form'),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.s3,
                    AppSpacing.screen,
                    AppSpacing.s6,
                  ),
                  children: [
                    GroupLine(name: d.groupName, type: d.groupType, offline: offline),
                    const SizedBox(height: AppSpacing.s6),
                    _People(draft: d, onEdit: _edit),
                    const SizedBox(height: AppSpacing.s6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.s4,
                            end: AppSpacing.s3,
                          ),
                          child: CurrencyChip(
                            key: const Key('settle-currency'),
                            code: d.currency,
                            onTap: () => unawaited(_pickCurrency(d)),
                          ),
                        ),
                        Expanded(
                          child: AmountField(
                            key: const Key('settle-amount'),
                            controller: _amount,
                            focusNode: _amountFocus,
                            currency: d.currency,
                            errorText: amountError,
                            onChanged: (t) => _edit((c) => c.setAmountText(t)),
                            onSubmitted: (_) => _amountFocus.unfocus(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    OwedSummaryPill(owed: d.owed, amount: d.amount, currency: d.currency),
                    if (d.owed > 0 && d.amount != d.owed) ...[
                      const SizedBox(height: AppSpacing.s3),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconChip(
                          key: const Key('settle-use-owed'),
                          label: l.settleUseOwed(listMoney(d.owed, d.currency)),
                          icon: AppIcons.checkCircle,
                          onTap: () => _edit((c) => c.useOwed()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // In the body (not bottomNavigationBar): the Scaffold lifts it above the keyboard.
              if (!_saved)
                StickyActionBar(
                  summary: SettleToolbar(
                    date: d.date,
                    note: d.note,
                    method: d.method,
                    today: today,
                    onDate: () => unawaited(_pickDate(d)),
                    onNote: () => unawaited(_openNote()),
                    onMethod: () => unawaited(_pickMethod(d)),
                  ),
                  primary: !upi
                      ? record
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PillButton(
                              key: const Key('settle-upi'),
                              label: d.amount == null
                                  ? l.settlePayUpi
                                  : l.upiPay(listMoney(d.amount!, d.currency)),
                              icon: AppIcons.qr,
                              variant: PillVariant.money,
                              loading: _saving,
                              onPressed: () => unawaited(_payByUpi(vpa!, payeeName)),
                            ),
                            const SizedBox(height: AppSpacing.s1),
                            record,
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String methodLabel(AppLocalizations l, String method) => switch (method) {
  'upi' => l.methodUpi,
  'bank' => l.methodBank,
  'other' => l.methodOther,
  _ => l.methodCash,
};

IconData methodIcon(String method) => switch (method) {
  'upi' => AppIcons.qr,
  'bank' => AppIcons.bank,
  'other' => AppIcons.methodOther,
  _ => AppIcons.cash,
};

/// The method sheet's choices: Cash, UPI (rupees only, rule 13), Bank, Other.
class PaymentMethodOptions extends StatelessWidget {
  const PaymentMethodOptions({
    required this.currency,
    required this.selected,
    required this.onPicked,
    super.key,
  });

  final String currency;
  final String selected;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      key: const Key('settle-methods'),
      children: [
        for (final m in paymentMethods)
          if (m != 'upi' || currency == 'INR') ...[
            OptionTile(
              key: Key('method-$m'),
              label: methodLabel(l, m),
              selected: selected == m,
              leading: Icon(methodIcon(m), color: context.colors.primary),
              onTap: () => onPicked(m),
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
      ],
    );
  }
}

/// "Record cash payment" / "Record UPI payment" / "Record bank payment" / "Record payment".
String recordLabel(AppLocalizations l, String method) => switch (method) {
  'cash' => l.settleRecordCash,
  'upi' => l.settleRecordUpi,
  'bank' => l.settleRecordBank,
  _ => l.settleRecord,
};

/// Payer → receiver: two avatars with names and the arrow between them (it swaps who paid), the sentence
/// "You paid Asha" underneath. Tapping a person picks someone else.
class _People extends StatelessWidget {
  const _People({required this.draft, required this.onEdit});

  final SettleDraft draft;
  final void Function(void Function(SettleController c) change) onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final d = draft;
    String name(String id, {bool start = true}) => personName(l, d.balances, id, start: start);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SettlePerson(
                key: const Key('settle-from'),
                member: d.members.firstWhere((m) => m.id == d.from),
                name: name(d.from),
                tooltip: l.settleChangePerson(name(d.from)),
                onTap: () => unawaited(
                  _pick(context, l.settleWhoPaid, d.from, (id) => onEdit((x) => x.setFrom(id))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: IconButton.filled(
                key: const Key('settle-swap'),
                tooltip: l.settleSwap,
                style: IconButton.styleFrom(
                  backgroundColor: c.ink,
                  foregroundColor: c.onInk,
                  minimumSize: const Size.square(AppSpacing.minTouch),
                ),
                onPressed: () => onEdit((x) => x.swap()),
                icon: const Icon(AppIcons.arrowRight, size: 20),
              ),
            ),
            Expanded(
              child: SettlePerson(
                key: const Key('settle-to'),
                member: d.members.firstWhere((m) => m.id == d.to),
                name: name(d.to),
                tooltip: l.settleChangePerson(name(d.to)),
                onTap: () => unawaited(
                  _pick(context, l.settleWhoReceived, d.to, (id) => onEdit((x) => x.setTo(id))),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          l.settlePaidSentence(name(d.from), name(d.to, start: false)),
          key: const Key('settle-sentence'),
          textAlign: TextAlign.center,
          style: context.text.title.w(600),
        ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    String title,
    String current,
    ValueChanged<String> onPicked,
  ) async {
    final l = AppLocalizations.of(context);
    final picked = await showAppSheet<String>(
      context,
      title: title,
      builder: (sheet) => Column(
        children: [
          for (final m in draft.members) ...[
            OptionTile(
              key: Key('pick-person-${m.id}'),
              label: personName(l, draft.balances, m.id),
              selected: m.id == current,
              leading: Avatar(name: m.displayName, seed: m.id, tint: m.tint),
              onTap: () => Navigator.of(sheet).pop(m.id),
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
        ],
      ),
    );
    if (picked != null && picked != current) onPicked(picked);
  }
}

/// One side of a payment: the avatar with a ring and the name under it. Tapping picks someone else; without
/// [onTap] (the batch form) it is read-only.
class SettlePerson extends StatelessWidget {
  const SettlePerson({
    required this.member,
    required this.name,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final LocalMember member;
  final String name;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final face = Padding(
      padding: const EdgeInsets.all(AppSpacing.s2),
      child: Column(
        children: [
          Avatar(
            name: member.displayName,
            seed: member.id,
            tint: member.tint,
            size: AvatarSize.s56,
            ring: true,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.body.w(600),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return Semantics(label: name, excludeSemantics: true, child: face);
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      onTap: tap,
      child: Pressable(onTap: tap, borderRadius: AppRadii.all16, child: face),
    );
  }
}

/// How much of the debt this payment settles: "Settles all of ₹300", "Part of the ₹300 owed · ₹150 left
/// after this", "More than the ₹300 owed · ₹200 more than owed", or "Nothing owed right now". With
/// [overIsError] (the batch form, D-034) paying more is an error: red edge, no extra line.
class OwedSummaryPill extends StatelessWidget {
  const OwedSummaryPill({
    required this.owed,
    required this.amount,
    required this.currency,
    this.overIsError = false,
    super.key,
  });

  final int owed;
  final int? amount;
  final String currency;
  final bool overIsError;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String money(int v) => listMoney(v, currency);
    final (IconData icon, String title, String? sub) = switch (amount) {
      _ when owed <= 0 => (AppIcons.info, l.settleNothingOwed, l.settleNothingOwedSub),
      null => (AppIcons.settle, l.settleSummaryOwed(money(owed)), null),
      final a when a == owed => (AppIcons.checkCircle, l.settleSummaryAll(money(owed)), null),
      final a when a < owed => (
        AppIcons.settle,
        l.settleSummaryPart(money(owed)),
        l.settleSummaryLeft(money(owed - a)),
      ),
      final a => (
        AppIcons.warning,
        l.settleSummaryOver(money(owed)),
        overIsError ? null : l.settleSummaryExtra(money(a - owed)),
      ),
    };
    final error = overIsError && (amount ?? 0) > owed && owed > 0;
    return FormPill(
      key: const Key('settle-summary'),
      icon: icon,
      title: title,
      subtitle: sub,
      error: error,
    );
  }
}

/// The bottom toolbar: date, note and method chips; a chip is filled once it differs from the default.
class SettleToolbar extends StatelessWidget {
  const SettleToolbar({
    required this.date,
    required this.note,
    required this.method,
    required this.today,
    required this.onDate,
    required this.onNote,
    required this.onMethod,
    super.key,
  });

  final DateTime date;
  final String note;
  final String method;
  final DateTime today;
  final VoidCallback onDate;
  final VoidCallback onNote;
  final VoidCallback onMethod;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasNote = note.trim().isNotEmpty;
    return SingleChildScrollView(
      key: const Key('settle-toolbar'),
      scrollDirection: Axis.horizontal,
      // Chips scroll on to the screen edge instead of being cut at the 20 dp margin (R3-A, S-446).
      clipBehavior: Clip.none,
      child: Row(
        children: [
          ToolChip(
            key: const Key('settle-date'),
            icon: AppIcons.calendar,
            label: dayLabel(context, date, today),
            semanticLabel: l.expToolDate(shortDate(context, date)),
            active: !DateUtils.isSameDay(date, today),
            onTap: onDate,
          ),
          const SizedBox(width: AppSpacing.s2),
          ToolChip(
            key: const Key('settle-note-chip'),
            icon: AppIcons.notes,
            label: l.settleNote,
            semanticLabel: hasNote ? l.settleToolNoteAdded : l.settleNote,
            active: hasNote,
            onTap: onNote,
          ),
          const SizedBox(width: AppSpacing.s2),
          ToolChip(
            key: const Key('settle-method'),
            icon: methodIcon(method),
            label: methodLabel(l, method),
            semanticLabel: l.settleToolMethod(methodLabel(l, method)),
            active: method != 'cash',
            onTap: onMethod,
          ),
        ],
      ),
    );
  }
}

/// The person a new payment by or to me settles completely — nothing is owed either way between us in
/// any currency of the group afterwards — or null (T6: only then the Celebration plays).
String? settledWith(SettleDraft d) {
  final me = d.meId;
  if (me == null || d.isEdit || d.owed <= 0 || d.amount != d.owed) return null;
  final other = d.from == me ? d.to : (d.to == me ? d.from : null);
  if (other == null) return null;
  final b = d.balances;
  for (final c in b.currencies) {
    if (c == d.currency) continue;
    if (b.owed(me, other, c) != 0 || b.owed(other, me, c) != 0) return null;
  }
  return other;
}
