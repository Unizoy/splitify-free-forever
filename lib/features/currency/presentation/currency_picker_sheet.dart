import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/currency.dart';
import 'package:splitify/features/currency/application/currency_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show SectionLabel;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Opens the currency picker (#14): search by code or name; the group's currency on top, then recently
/// used ones, then every currency. Returns the chosen code (null when dismissed).
///
/// Without [groupCurrency] (group form, profile: final QA S-253) there is no group section; the same
/// searchable list replaced a 160-row list of buttons without search.
Future<String?> showCurrencyPicker(
  BuildContext context, {
  required String selected,
  String? groupCurrency,
  String? title,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<String>(
    context,
    title: title ?? l.curPickerTitle,
    builder: (_) => CurrencyPicker(selected: selected, groupCurrency: groupCurrency),
  );
}

/// [showCurrencyPicker] for a record of [groupId] (its main currency on top; [selected] when the group
/// can't be read).
Future<String?> pickGroupCurrency(
  BuildContext context,
  WidgetRef ref, {
  required String groupId,
  required String selected,
}) async {
  final provider = groupMainCurrencyProvider(groupId);
  final keep = ref.listenManual(provider, (_, _) {});
  String? main;
  try {
    main = await ref.read(provider.future).timeout(const Duration(seconds: 2));
  } on Object {
    main = null;
  } finally {
    keep.close();
  }
  if (!context.mounted) return null;
  return showCurrencyPicker(context, selected: selected, groupCurrency: main ?? selected);
}

/// Currencies whose code starts with, or whose name contains, [query] (case-insensitive), in code order.
List<Currency> searchCurrencies(String query) {
  final q = query.trim().toLowerCase();
  final all = Currencies.all.values.toList();
  if (q.isEmpty) return all;
  return [
    for (final c in all)
      if (c.code.toLowerCase().startsWith(q) || c.name.toLowerCase().contains(q)) c,
  ];
}

/// The picker body (inside an [AppSheet]); pops with the chosen code.
class CurrencyPicker extends ConsumerStatefulWidget {
  const CurrencyPicker({required this.selected, this.groupCurrency, super.key});

  final String selected;

  /// Shown on top as "Group currency"; null = no group section.
  final String? groupCurrency;

  @override
  ConsumerState<CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends ConsumerState<CurrencyPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final recent = [
      for (final code in ref.watch(recentCurrenciesProvider).value ?? const <String>[])
        if (code != widget.groupCurrency && Currencies.all.containsKey(code)) code,
    ];
    final media = MediaQuery.of(context);
    final height = (media.size.height * 0.62 - media.viewInsets.bottom).clamp(240.0, 640.0);
    Widget row(Currency cur, String section) => CurrencyRow(
      key: Key('currency-$section-${cur.code}'),
      currency: cur,
      selected: cur.code == widget.selected,
      onTap: () => Navigator.of(context).pop(cur.code),
    );

    final List<Widget> rows;
    if (_query.trim().isEmpty) {
      rows = [
        if (Currencies.all[widget.groupCurrency ?? ''] case final g?) ...[
          SectionLabel(l.curGroupSection),
          row(g, 'group'),
          const SizedBox(height: AppSpacing.s4),
        ],
        if (recent.isNotEmpty) ...[
          SectionLabel(l.curRecentSection),
          for (final code in recent) row(Currencies.all[code]!, 'recent'),
          const SizedBox(height: AppSpacing.s4),
        ],
        SectionLabel(l.curAllSection),
        for (final cur in Currencies.all.values) row(cur, 'all'),
      ];
    } else {
      final found = searchCurrencies(_query);
      rows = found.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                child: Text(
                  l.curNoMatch(_query.trim()),
                  key: const Key('currency-no-match'),
                  textAlign: TextAlign.center,
                  style: context.text.body.copyWith(color: c.textSecondary),
                ),
              ),
            ]
          : [for (final cur in found) row(cur, 'found')];
    }

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UnderlineField(
            key: const Key('currency-search'),
            label: l.curSearchLabel,
            hint: l.curSearchHint,
            controller: _search,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            suffix: Icon(AppIcons.search, size: 20, color: c.textSecondary),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.s4),
          Expanded(
            child: ListView(
              key: const Key('currency-list'),
              padding: EdgeInsets.zero,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

/// One currency: symbol disc, name, code; a check when it is the current one.
class CurrencyRow extends StatelessWidget {
  const CurrencyRow({
    required this.currency,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Currency currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final label = l.curRowLabel(currency.name, currency.code);
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, ${l.curSelected}' : label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.all16,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.primaryContainer : c.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s1),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currency.symbol,
                        maxLines: 1,
                        style: context.text.bodySmall
                            .w(700)
                            .copyWith(color: selected ? c.onPrimaryContainer : c.textPrimary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(child: Text(currency.name, style: context.text.body.w(600))),
                const SizedBox(width: AppSpacing.s3),
                Text(
                  currency.code,
                  style: context.text.labelCaps.copyWith(
                    color: selected ? c.primary : c.textSecondary,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: selected
                      ? Icon(AppIcons.check, size: 18, color: c.primary)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "USD ▾" pill that opens the picker (expense editor, Settle up). The pill stays 36 dp tall; the tap area
/// around it is 48 dp (final QA S-258: a 36 dp target failed the touch-size check once TalkBack could press it).
class CurrencyChip extends StatelessWidget {
  const CurrencyChip({required this.code, required this.onTap, super.key});

  final String code;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      label: l.expCurrencyLabel(code),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouch,
            minWidth: AppSpacing.minTouch,
          ),
          child: Center(
            widthFactor: 1,
            child: Material(
              color: c.primaryContainer,
              shape: const StadiumBorder(),
              child: InkWell(
                onTap: onTap,
                customBorder: const StadiumBorder(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36, minWidth: AppSpacing.minTouch),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4,
                      vertical: AppSpacing.s1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          code,
                          style: context.text.labelCaps.copyWith(color: c.onPrimaryContainer),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: AppSpacing.s1),
                          Icon(AppIcons.chevronDown, size: 14, color: c.onPrimaryContainer),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
