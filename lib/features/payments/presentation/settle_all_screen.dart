import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/core/upi/upi_link.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/currency/presentation/currency_picker_sheet.dart'
    show CurrencyChip;
import 'package:splitify/features/expenses/presentation/editor/editor_fields.dart' show AmountField;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/friends/presentation/friend_widgets.dart' show groupTypeIcon;
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;
import 'package:splitify/features/groups/presentation/group_visuals.dart' show confirmAction;
import 'package:splitify/features/payments/application/settle_all_controller.dart';
import 'package:splitify/features/payments/application/settle_controller.dart' show maxPaymentNote;
import 'package:splitify/features/payments/application/upi_providers.dart';
import 'package:splitify/features/payments/presentation/money_form.dart';
import 'package:splitify/features/payments/presentation/settle_up_screen.dart';
import 'package:splitify/features/payments/presentation/settled_celebration.dart';
import 'package:splitify/features/payments/presentation/upi_pay.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Pay via UPI" for a batch (rule 13): rupees, I pay on balance, the friend has a UPI ID.
bool canPayAllByUpi(SettleAllDraft d, String? vpa) =>
    vpa != null && d.currency == UpiLinkBuilder.currency && !d.friendPays;

/// Record a payment for everything with one friend in one currency (`/settle/all`, D-034 B1): the same one
/// screen as Record a payment — "With Asha · Across 2 groups" (tap for the breakdown), payer → receiver, the
/// amount prefilled with the whole balance, the summary pill, date / note / method and the action above the
/// keyboard. Saving writes one payment per group (biggest balance first for part of it); more than the whole
/// balance is an inline error. When I pay in rupees and the friend has a UPI ID, one "Pay ₹x via UPI" link
/// carries the total and "Mark as paid" records every payment.
class SettleAllScreen extends ConsumerStatefulWidget {
  const SettleAllScreen({required this.friendKey, required this.currency, super.key});

  final String friendKey;
  final String currency;

  SettleAllArgs get args => (friendKey: friendKey, currency: currency);

  @override
  ConsumerState<SettleAllScreen> createState() => _SettleAllScreenState();
}

class _SettleAllScreenState extends ConsumerState<SettleAllScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode(debugLabel: 'batch payment amount');
  bool _filled = false;
  bool _saving = false;
  bool _saved = false;
  bool _dirty = false;
  bool _showErrors = false;
  bool _methodPicked = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  SettleAllController get _ctrl => ref.read(settleAllProvider(widget.args).notifier);

  SettleAllDraft? get _draft => ref.read(settleAllProvider(widget.args)).value;

  void _edit(void Function(SettleAllController c) change) {
    _dirty = true;
    change(_ctrl);
  }

  void _fill(SettleAllDraft d) {
    if (_filled) return;
    _filled = true;
    _amount.text = d.amountText;
    _note.text = d.note;
  }

  Future<void> _pickDate(SettleAllDraft d) async {
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

  Future<void> _pickMethod(SettleAllDraft d) async {
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

  Future<void> _back() async {
    final d = _draft;
    if (_dirty && !_saved && d != null) {
      final l = AppLocalizations.of(context);
      FocusManager.instance.primaryFocus?.unfocus();
      final discard = await confirmAction(
        context,
        title: l.settleDiscardTitle,
        body: l.settleDiscardBody,
        confirm: l.discardLabel,
        icon: AppIcons.trash,
      );
      if (!discard || !mounted) return;
    }
    _close();
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/friends');
    }
  }

  bool _check(SettleAllDraft d) {
    if (d.canSave) return true;
    setState(() => _showErrors = true);
    unawaited(HapticFeedback.lightImpact());
    if (d.amount == null || d.over) {
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
    final ids = await _ctrl.save();
    if (!mounted) return;
    if (ids == null) {
      setState(() => _saving = false);
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _saving = false;
      _saved = true;
    });
    _close();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.settle2Recorded(ids.length))));
    if (d.settlesEverything) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (root.mounted) unawaited(showSettledCelebration(root.context, name: d.friendName));
      });
    }
  }

  Future<void> _payByUpi(String vpa) async {
    if (_saving || _saved) return;
    final d = _draft;
    if (d == null || !_check(d)) return;
    final l = AppLocalizations.of(context);
    final UpiLink link;
    try {
      link = const UpiLinkBuilder().build(
        vpa: vpa,
        name: d.friendName,
        amountMinor: d.amount!,
        currencyCode: d.currency,
        note: l.settle2UpiNote,
      );
    } on UpiLinkError {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final paid = await payViaUpi(
      context,
      ref,
      link,
      payeeName: d.friendName,
      amountMinor: d.amount!,
    );
    if (!paid || !mounted) return;
    // Recorded only after "Mark as paid" (rule 13): every payment of the batch, method UPI.
    _edit((c) => c.setMethod('upi'));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(settleAllProvider(widget.args));
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
          title: Text(l.settleRecordTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: async.isLoading
                ? DotsPulse(color: context.colors.primary, semanticLabel: l.loading)
                : EmptyState(
                    icon: AppIcons.settle,
                    title: l.settleNotFoundTitle,
                    message: l.settle2NotFoundBody,
                  ),
          ),
        ),
      );
    }
    _fill(d);
    final userId = d.friendUserId;
    final vpa = userId == null ? null : ref.watch(upiIdProvider(userId)).value;
    final upi = canPayAllByUpi(d, vpa) && (!_methodPicked || d.method == 'upi');
    final money = listMoney(d.total, d.currency);
    final amountError =
        l.amountError(d.amountResult, d.currency) ??
        (d.over ? l.settle2OverHint : null) ??
        (_showErrors && d.amount == null ? l.expAmountMissing : null);
    final today = ref.read(clockProvider).today();
    final record = PillButton(
      key: const Key('settle-save'),
      label: recordLabel(l, d.method),
      icon: upi ? null : AppIcons.check,
      variant: upi ? PillVariant.ghost : PillVariant.money,
      size: upi ? PillSize.medium : PillSize.large,
      loading: _saving && !upi,
      onPressed: () => unawaited(_save()),
    );
    String name(bool friend, {bool start = true}) =>
        friend ? d.friendName : (start ? l.you : l.youLower);
    final fromFriend = d.friendPays;
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
          title: Text(l.settleRecordTitle),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                key: const Key('settle-all-form'),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.s3,
                  AppSpacing.screen,
                  AppSpacing.s6,
                ),
                children: [
                  _FriendLine(
                    draft: d,
                    offline: offline,
                    onBreakdown: () => unawaited(showSettleAllBreakdown(context, d)),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SettlePerson(
                          key: const Key('settle-from'),
                          member: fromFriend ? d.friend : d.me,
                          name: name(fromFriend),
                          tooltip: name(fromFriend),
                          onTap: null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s6),
                        child: Icon(AppIcons.arrowRight, size: 20, color: context.colors.ink),
                      ),
                      Expanded(
                        child: SettlePerson(
                          key: const Key('settle-to'),
                          member: fromFriend ? d.me : d.friend,
                          name: name(!fromFriend),
                          tooltip: name(!fromFriend),
                          onTap: null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    l.settlePaidSentence(name(fromFriend), name(!fromFriend, start: false)),
                    key: const Key('settle-sentence'),
                    textAlign: TextAlign.center,
                    style: context.text.title.w(600),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: AppSpacing.s4,
                          end: AppSpacing.s3,
                        ),
                        // One currency per batch (rule 4): the chip only names it.
                        child: CurrencyChip(
                          key: const Key('settle-currency'),
                          code: d.currency,
                          onTap: null,
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
                  OwedSummaryPill(
                    owed: d.total,
                    amount: d.amount,
                    currency: d.currency,
                    overIsError: true,
                  ),
                  if (d.amount != d.total) ...[
                    const SizedBox(height: AppSpacing.s3),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconChip(
                        key: const Key('settle-use-owed'),
                        label: l.settleUseOwed(money),
                        icon: AppIcons.checkCircle,
                        onTap: () {
                          _edit((c) => c.useTotal());
                          _amount.text = _draft?.amountText ?? _amount.text;
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
                            onPressed: () => unawaited(_payByUpi(vpa!)),
                          ),
                          const SizedBox(height: AppSpacing.s1),
                          record,
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "With [Asha]  [Across 2 groups ›]": who the batch is with and the chip that opens the breakdown. Offline, the
/// "Not synced yet" marker sits next to it.
class _FriendLine extends StatelessWidget {
  const _FriendLine({required this.draft, required this.offline, required this.onBreakdown});

  final SettleAllDraft draft;
  final bool offline;
  final VoidCallback onBreakdown;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final d = draft;
    final across = l.settle2Across(d.groups.length);
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.settle2WithLabel, style: context.text.body.copyWith(color: c.textSecondary)),
        Semantics(
          container: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.s1,
              AppSpacing.s1,
              AppSpacing.s4,
              AppSpacing.s1,
            ),
            decoration: ShapeDecoration(
              color: c.surface,
              shape: StadiumBorder(side: BorderSide(color: c.border, width: 1.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Avatar(
                  name: d.friend.displayName,
                  seed: d.friend.id,
                  tint: d.friend.tint,
                  size: AvatarSize.s32,
                ),
                const SizedBox(width: AppSpacing.s2),
                Flexible(child: Text(d.friendName, style: context.text.body.w(600))),
              ],
            ),
          ),
        ),
        Semantics(
          button: true,
          label: across,
          hint: l.settle2AcrossHint,
          excludeSemantics: true,
          onTap: onBreakdown,
          child: Pressable(
            key: const Key('settle-all-across'),
            onTap: onBreakdown,
            borderRadius: AppRadii.allPill,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.groups, size: 18, color: c.primary),
                    const SizedBox(width: AppSpacing.s1),
                    Text(across, style: context.text.bodySmall.w(700).copyWith(color: c.primary)),
                    Icon(AppIcons.chevronRight, size: 18, color: c.primary),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (offline) const SyncMarker(key: Key('money-offline')),
      ],
    );
  }
}

/// The read-only breakdown: each group, what it shows between us and what this payment pays there.
Future<void> showSettleAllBreakdown(BuildContext context, SettleAllDraft draft) =>
    showAppSheet<void>(
      context,
      title: AppLocalizations.of(context).settle2Across(draft.groups.length),
      builder: (sheet) => SettleAllBreakdown(draft: draft),
    );

class SettleAllBreakdown extends StatelessWidget {
  const SettleAllBreakdown({required this.draft, super.key});

  final SettleAllDraft draft;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final d = draft;
    // Biggest first, like the payment pays them.
    final groups = [...d.groups]
      ..sort((a, b) {
        final byAmount = b.owed.abs().compareTo(a.owed.abs());
        return byAmount != 0 ? byAmount : a.groupId.compareTo(b.groupId);
      });
    return Column(
      key: const Key('settle-all-breakdown'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          _BreakdownRow(group: groups[i], part: d.partIn(groups[i].groupId), currency: d.currency),
          if (i < groups.length - 1) const DashedDivider(),
        ],
        const SizedBox(height: AppSpacing.s4),
        Text(
          l.settle2BreakdownOrder,
          style: context.text.bodySmall.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s2),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.group, required this.part, required this.currency});

  final SettleAllGroup group;
  final int part;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final g = group;
    final amount = listMoney(g.owed.abs(), currency);
    final (line, color) = g.owed > 0
        ? (l.settlePickOwesYou(amount), c.owedText)
        : (l.settlePickYouOwe(amount), c.oweText);
    final name = g.type == 'direct' ? l.friendDirectGroup : g.name;
    final paid = part > 0 ? l.settle2ThisPayment(listMoney(part, currency)) : l.settle2NotInPayment;
    return MergeSemantics(
      child: Padding(
        key: Key('settle-all-group-${g.groupId}'),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
        child: Row(
          children: [
            TintedIcon(icon: groupTypeIcon(g.type), color: c.primary, size: 40),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.text.body.w(600)),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: context.text.bodySmall
                        .w(600)
                        .copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paid,
                    key: Key('settle-all-part-${g.groupId}'),
                    style: context.text.bodySmall.copyWith(
                      color: part > 0 ? c.textPrimary : c.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
