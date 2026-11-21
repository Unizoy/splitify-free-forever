import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/expenses/presentation/editor/details_step.dart' show DateChips;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart'
    show PageTitle, SectionLabel;
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Settle up (`/settle`, #25, 712 + 646): who paid whom (avatars with a swap button), the amount
/// prefilled with what is owed, an [ArcGauge] of how much of the debt it settles, method chips, date
/// and note; amber "Record payment" in the sticky bar. Also edits a saved payment (`/payment/:id/edit`).
/// UPI ("Pay via UPI") arrives in phase 11.
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
  bool _filled = false;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  SettleController get _ctrl => ref.read(settleProvider(widget.args).notifier);

  void _fill(SettleDraft d) {
    if (_filled) return;
    _filled = true;
    _amount.text = d.amountText;
    _note.text = d.note;
  }

  Future<void> _save(SettleDraft d) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final id = await _ctrl.save();
    if (!mounted) return;
    setState(() => _saving = false);
    if (id == null) return;
    unawaited(HapticFeedback.mediumImpact());
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      router.go('/groups/${d.groupId}');
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(d.isEdit ? l.settleSaved : l.settleRecorded)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Changing the people re-derives the amount from what is owed: keep the visible field in step.
    ref.listen(settleProvider(widget.args), (_, next) {
      final text = next.value?.amountText;
      if (_filled && text != null && _amount.text != text) _amount.text = text;
    });
    final async = ref.watch(settleProvider(widget.args));
    final d = async.value;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
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
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s2,
            AppSpacing.screen,
            AppSpacing.s8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  tooltip: l.back,
                  icon: const Icon(AppIcons.back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              PageTitle(title: d.isEdit ? l.settleEditTitle : l.settleUp, subtitle: d.groupName),
              const SizedBox(height: AppSpacing.s6),
              _People(draft: d, controller: _ctrl),
              const SizedBox(height: AppSpacing.s8),
              SectionLabel(l.settleAmount),
              const SizedBox(height: AppSpacing.s2),
              _AmountField(draft: d, controller: _amount, onChanged: _ctrl.setAmountText),
              if (d.owed > 0 && d.amount != d.owed) ...[
                const SizedBox(height: AppSpacing.s3),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconChip(
                    key: const Key('settle-use-owed'),
                    label: l.settleUseOwed(listMoney(d.owed, d.currency)),
                    icon: AppIcons.checkCircle,
                    onTap: () {
                      _ctrl.useOwed();
                      _amount.text = ref.read(settleProvider(widget.args)).value!.amountText;
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s6),
              _Gauge(draft: d),
              const SizedBox(height: AppSpacing.s8),
              SectionLabel(l.settleMethod),
              const SizedBox(height: AppSpacing.s3),
              Wrap(
                spacing: AppSpacing.s2,
                runSpacing: AppSpacing.s2,
                children: [
                  for (final m in paymentMethods)
                    IconChip(
                      key: Key('method-$m'),
                      label: methodLabel(l, m),
                      icon: methodIcon(m),
                      selected: d.method == m,
                      onTap: () => _ctrl.setMethod(m),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              SectionLabel(l.settleDate),
              const SizedBox(height: AppSpacing.s3),
              DateChips(value: d.date, today: _today(), onChanged: _ctrl.setDate),
              const SizedBox(height: AppSpacing.s8),
              UnderlineField(
                key: const Key('settle-note'),
                label: l.settleNote,
                hint: l.settleNoteHint,
                controller: _note,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                errorText: d.noteTooLong ? l.settleNoteTooLong(maxPaymentNote) : null,
                onChanged: _ctrl.setNote,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: StickyActionBar(
        primary: PillButton(
          key: const Key('settle-save'),
          label: d.isEdit ? l.settleSave : l.settleRecord,
          icon: AppIcons.check,
          variant: PillVariant.money,
          loading: _saving,
          onPressed: d.canSave && !_saving ? () => unawaited(_save(d)) : null,
        ),
      ),
    );
  }

  DateTime _today() {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month, now.day);
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

/// Payer → receiver: two big avatars with names, a swap button between them, and the sentence
/// "You paid Asha" underneath. Tapping a person picks someone else.
class _People extends StatelessWidget {
  const _People({required this.draft, required this.controller});

  final SettleDraft draft;
  final SettleController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final d = draft;
    String name(String id, {bool start = true}) => personName(l, d.balances, id, start: start);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s5,
        AppSpacing.s4,
        AppSpacing.s5,
      ),
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all28),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Person(
                  key: const Key('settle-from'),
                  member: d.members.firstWhere((m) => m.id == d.from),
                  name: name(d.from),
                  tooltip: l.settleChangePerson(name(d.from)),
                  onTap: () =>
                      unawaited(_pick(context, l.settleWhoPaid, d.from, controller.setFrom)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s2),
                child: IconButton.filled(
                  key: const Key('settle-swap'),
                  tooltip: l.settleSwap,
                  style: IconButton.styleFrom(
                    backgroundColor: c.ink,
                    foregroundColor: c.onInk,
                    minimumSize: const Size.square(AppSpacing.minTouch),
                  ),
                  onPressed: controller.swap,
                  icon: const Icon(AppIcons.arrowRight, size: 20),
                ),
              ),
              Expanded(
                child: _Person(
                  key: const Key('settle-to'),
                  member: d.members.firstWhere((m) => m.id == d.to),
                  name: name(d.to),
                  tooltip: l.settleChangePerson(name(d.to)),
                  onTap: () =>
                      unawaited(_pick(context, l.settleWhoReceived, d.to, controller.setTo)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            l.settlePaidSentence(name(d.from), name(d.to, start: false)),
            key: const Key('settle-sentence'),
            textAlign: TextAlign.center,
            style: context.text.title.w(600),
          ),
        ],
      ),
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
    if (picked != null) onPicked(picked);
  }
}

class _Person extends StatelessWidget {
  const _Person({
    required this.member,
    required this.name,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final LocalMember member;
  final String name;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadii.all16,
      child: Padding(
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
      ),
    ),
  );
}

/// Big centred amount input with the currency symbol and code.
class _AmountField extends StatelessWidget {
  const _AmountField({required this.draft, required this.controller, required this.onChanged});

  final SettleDraft draft;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final currency = Currencies.of(draft.currency);
    final error = l.amountError(draft.amountResult, draft.currency);
    final style = context.text.amountHero.copyWith(color: c.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(currency.symbol, style: style.copyWith(color: c.textSecondary)),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: TextField(
                key: const Key('settle-amount'),
                controller: controller,
                onChanged: onChanged,
                style: style,
                keyboardType: TextInputType.numberWithOptions(decimal: currency.exponent > 0),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(isDense: true, border: InputBorder.none),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s1,
              ),
              decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadii.allPill),
              child: Text(
                draft.currency,
                style: context.text.labelCaps.copyWith(color: c.onPrimaryContainer),
              ),
            ),
          ],
        ),
        const DashedDivider(),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(error, style: context.text.bodySmall.copyWith(color: c.oweText)),
        ],
      ],
    );
  }
}

/// How much of the debt this payment settles (646 gauge).
class _Gauge extends StatelessWidget {
  const _Gauge({required this.draft});

  final SettleDraft draft;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final owed = draft.owed;
    if (owed <= 0) {
      return Container(
        key: const Key('settle-gauge-none'),
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(color: c.infoContainer, borderRadius: AppRadii.all16),
        child: Row(
          children: [
            Icon(AppIcons.info, size: 20, color: c.info),
            const SizedBox(width: AppSpacing.s3),
            Expanded(child: Text(l.settleGaugeNone, style: context.text.bodySmall)),
          ],
        ),
      );
    }
    final amount = draft.amount ?? 0;
    final ratio = amount / owed;
    final owedText = listMoney(owed, draft.currency);
    final caption = amount == owed
        ? l.settleGaugeAll(owedText)
        : amount > owed
        ? l.settleGaugeOver(owedText)
        : l.settleGaugeOf(owedText);
    final percent = NumberFormat.percentPattern(Localizations.localeOf(context).toLanguageTag())
        .format(ratio > 1 ? 1 : ratio);
    return Center(
      child: ArcGauge(
        key: const Key('settle-gauge'),
        progress: ratio > 1 ? 1 : ratio,
        valueText: amount > owed ? '$percent+' : percent,
        caption: caption,
        size: 220,
      ),
    );
  }
}
