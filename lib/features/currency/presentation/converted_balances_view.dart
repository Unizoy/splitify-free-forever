import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/balances.dart' show Transfer;
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/currency/application/conversion_actions.dart';
import 'package:splitify/features/currency/application/currency_providers.dart';
import 'package:splitify/features/currency/domain/converted_balances.dart';
import 'package:splitify/features/currency/presentation/conversion_sheet.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart' show parseIsoDate;
import 'package:splitify/features/expenses/presentation/expense_copy.dart' show dayMonth;
import 'package:splitify/features/groups/presentation/group_visuals.dart' show SectionLabel;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Show balances: By currency | In INR" (#32), shown on the Balances tab of groups with records in
/// another currency.
class BalancesViewToggle extends StatelessWidget {
  const BalancesViewToggle({
    required this.currency,
    required this.inMain,
    required this.onChanged,
    super.key,
  });

  final String currency;
  final bool inMain;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      label: l.fxViewLabel,
      container: true,
      child: SegmentedPill<bool>(
        key: const Key('balances-view-toggle'),
        value: inMain,
        onChanged: onChanged,
        items: [
          SegmentedPillItem(value: false, label: l.fxViewByCurrency),
          SegmentedPillItem(value: true, label: l.fxViewInMain(currency)),
        ],
      ),
    );
  }
}

/// The group's balances in its main currency (#32, T5/T6): records still without a saved conversion
/// (with "Convert all at their dates' rates"), else who owes whom in that currency — original debts or,
/// with "Simplify in INR", simplified on the converted nets — and everyone's net.
class ConvertedBalancesView extends ConsumerStatefulWidget {
  const ConvertedBalancesView({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<ConvertedBalancesView> createState() => _ConvertedBalancesViewState();
}

class _ConvertedBalancesViewState extends ConsumerState<ConvertedBalancesView> {
  /// Null = follow the group's simplify setting.
  bool? _simplified;
  bool _converting = false;

  Future<void> _convertAll() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _converting = true);
    final r = await ref.read(conversionActionsProvider).convertAll(widget.groupId);
    if (!mounted) return;
    setState(() => _converting = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            [
              l.fxConvertedCount(r.converted),
              if (r.needRate > 0) l.fxNeedRateCount(r.needRate),
            ].join(' · '),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(convertedGroupProvider(widget.groupId)).value;
    if (view == null) return const SizedBox.shrink();
    final converted = view.converted;
    if (converted.missing.isNotEmpty) return _missing(context, view);
    final b = converted.balances;
    if (b == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: EmptyState(icon: AppIcons.warning, title: l.fxCombineError),
      );
    }
    final simplified = _simplified ?? view.group.simplify;
    final shown = b.shown(simplify: simplified);
    final currency = view.currency;
    final group = view.group;
    final people = [
      for (final m in group.members)
        if ((b.nets[m.id] ?? 0) != 0 || (m.deletedAt == null && m.status == 'active')) m,
    ];
    return Column(
      key: const Key('converted-balances'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s8),
        Semantics(
          header: true,
          child: Text(l.fxSectionInMain(currency), style: context.text.title.w(700)),
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          l.fxConvertedNote,
          style: context.text.bodySmall.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s3),
        SectionLabel(
          simplified ? l.balSuggestedPayments : l.balWhoOwesWhom,
          trailing: _Link(
            key: const Key('converted-simplify-toggle'),
            label: simplified ? l.balShowOriginal : l.fxSimplifyInMain(currency),
            onTap: () => setState(() => _simplified = !simplified),
          ),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Row(
              children: [
                Icon(AppIcons.checkCircle, size: 22, color: context.colors.owedAccent),
                const SizedBox(width: AppSpacing.s3),
                Expanded(child: Text(l.balEveryoneSettled, style: context.text.body.w(600))),
              ],
            ),
          )
        else
          for (var i = 0; i < shown.length; i++)
            _TransferLine(
              key: Key('converted-transfer-${shown[i].from}-${shown[i].to}'),
              view: view,
              transfer: shown[i],
              showDivider: i < shown.length - 1,
            ),
        const SizedBox(height: AppSpacing.s6),
        SectionLabel(l.balEveryone),
        for (var i = 0; i < people.length; i++)
          Builder(
            builder: (context) {
              final m = people[i];
              final net = b.nets[m.id] ?? 0;
              return AmountRow(
                key: Key('converted-net-${m.id}'),
                title: personName(l, group, m.id),
                amountText: net == 0 ? '' : listMoney(net.abs(), currency),
                amountCaption: net > 0
                    ? l.balGetsBack
                    : net < 0
                    ? l.balOwes
                    : l.balSettledUp,
                tone: toneOfNet(net),
                leading: Avatar(name: group.nameOf(m.id), seed: m.id, tint: m.tint),
                showDivider: i < people.length - 1,
              );
            },
          ),
      ],
    );
  }

  Widget _missing(BuildContext context, ConvertedGroupView view) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final missing = view.converted.missing;
    final group = view.group;
    return Column(
      key: const Key('converted-missing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s6),
        ClipRRect(
          borderRadius: AppRadii.all24,
          child: BlobBackground(
            seed: 7,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                        child: Icon(AppIcons.swap, size: 20, color: c.primary),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Text(
                          l.fxMissingTitle(missing.length),
                          style: context.text.title.w(700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    l.fxMissingBody(view.currency),
                    style: context.text.bodySmall.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  PillButton(
                    key: const Key('convert-all'),
                    label: l.fxConvertAll,
                    variant: PillVariant.money,
                    loading: _converting,
                    onPressed: _converting ? null : () => unawaited(_convertAll()),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        for (var i = 0; i < missing.length; i++)
          _MissingRow(
            key: Key('missing-${missing[i].id}'),
            record: missing[i],
            title: missing[i].isPayment
                ? l.settlePaidSentence(
                    personName(l, group, missing[i].from!),
                    personName(l, group, missing[i].to!, start: false),
                  )
                : missing[i].description,
            onTap: () => unawaited(
              showConversionSheet(
                context,
                recordId: missing[i].id,
                payment: missing[i].isPayment,
                to: view.currency,
              ),
            ),
            showDivider: i < missing.length - 1,
          ),
      ],
    );
  }
}

/// A record to convert: what it is, its date, its amount, "Convert to INR" on tap.
class _MissingRow extends StatelessWidget {
  const _MissingRow({
    required this.record,
    required this.title,
    required this.onTap,
    required this.showDivider,
    super.key,
  });

  final FxRecord record;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AmountRow(
      title: title,
      caption: dayMonth(context, parseIsoDate(record.date)),
      amountText: listMoney(record.amount, record.currency),
      amountCaption: record.currency,
      leading: TintedIcon(
        icon: record.isPayment ? AppIcons.payment : AppIcons.receipt,
        color: record.isPayment ? c.owedAccent : c.primary,
        size: 44,
      ),
      onTap: onTap,
      showDivider: showDivider,
    );
  }
}

/// "Asha owes you · ₹1,200" in the converted view (settling stays per currency, S-155).
class _TransferLine extends StatelessWidget {
  const _TransferLine({
    required this.view,
    required this.transfer,
    required this.showDivider,
    super.key,
  });

  final ConvertedGroupView view;
  final Transfer transfer;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final b = view.group;
    final t = transfer;
    final tone = t.from == b.meId
        ? MoneyTone.owe
        : t.to == b.meId
        ? MoneyTone.owed
        : MoneyTone.settled;
    final title = t.from == b.meId
        ? l.balYouOwePerson(personName(l, b, t.to, start: false))
        : l.balPairOwes(personName(l, b, t.from), personName(l, b, t.to, start: false));
    return AmountRow(
      title: title,
      amountText: listMoney(t.amount, view.currency),
      tone: tone,
      leading: _PairAvatars(view: view, from: t.from, to: t.to),
      showDivider: showDivider,
    );
  }
}

/// Payer avatar overlapping the receiver's with an arrow badge (same look as the Balances tab rows).
class _PairAvatars extends StatelessWidget {
  const _PairAvatars({required this.view, required this.from, required this.to});

  final ConvertedGroupView view;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final g = view.group;
    return ExcludeSemantics(
      child: SizedBox(
        width: 74,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Avatar(name: g.nameOf(from), seed: from, tint: g.member(from)?.tint),
            Positioned(
              left: 34,
              child: Avatar(name: g.nameOf(to), seed: to, tint: g.member(to)?.tint, ring: true),
            ),
            Positioned(
              left: 27,
              top: 24,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bg, width: 1.5),
                ),
                child: Icon(AppIcons.arrowRight, size: 10, color: c.onInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small text link in a section header.
class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadii.allPill,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              style: context.text.bodySmall.w(600).copyWith(color: context.colors.primary),
            ),
          ),
        ),
      ),
    ),
  );
}
