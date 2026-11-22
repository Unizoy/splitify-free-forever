import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/import_splitwise/application/import_controller.dart';
import 'package:splitify/features/import_splitwise/domain/import_mapping.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Why a file can't be imported, in words.
String importProblemText(AppLocalizations l, ImportProblem p) => switch (p.code) {
  'IMPORT_EMPTY_FILE' => l.impErrEmpty,
  'IMPORT_BAD_HEADER' => l.impErrHeader,
  'IMPORT_WRONG_COLUMN_COUNT' => l.impErrColumns(p.row),
  'IMPORT_INVALID_DATE' => l.impErrDate(p.row, p.value ?? ''),
  'IMPORT_INVALID_CURRENCY' => l.impErrCurrency(p.row, p.value ?? ''),
  'IMPORT_INVALID_AMOUNT' => l.impErrAmount(p.row, p.value ?? ''),
  'IMPORT_ROW_NOT_BALANCED' => l.impErrUnbalanced(p.row),
  'IMPORT_DUPLICATE_TOTALS' => l.impErrDuplicateTotals(p.row, p.value ?? ''),
  'IMPORT_TOO_LARGE' => l.impErrTooLarge,
  'IMPORT_UNSUPPORTED_CURRENCY' => l.impErrUnsupported(p.value ?? ''),
  _ => l.impErrNoRows,
};

String mappingProblemText(AppLocalizations l, MappingProblem p) => switch (p) {
  MappingProblem.sameMemberTwice => l.impProblemSameMember,
  MappingProblem.emptyName => l.impProblemEmptyName,
  MappingProblem.nobodyLeft => l.impProblemNobody,
  MappingProblem.tooManyMembers => l.impProblemTooMany,
};

/// "gets back ₹5,550" / "owes ₹3,783.34" / "settled up" for one currency's net.
String importNetText(AppLocalizations l, int net, String currency) {
  final amount = MoneyFormatter.list.format(net.abs(), currency);
  if (net > 0) return l.impNetPlus(amount);
  if (net < 0) return l.impNetMinus(amount);
  return l.impNetZero;
}

/// Nets of [name] in every currency of [sums], joined with ` · `; null when all are 0.
String? importNetsLine(AppLocalizations l, Map<String, Map<String, int>> sums, String name) {
  final parts = [
    for (final c in sums.keys.toList()..sort())
      if ((sums[c]![name] ?? 0) != 0) importNetText(l, sums[c]![name]!, c),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// `5 Jan 2026`.
String importDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

/// Bordered surface card (sync status card style) for the import steps.
class ImportCard extends StatelessWidget {
  const ImportCard({required this.child, this.padding = AppSpacing.s5, super.key});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.all24,
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card(c, dark: context.isDark),
      ),
      child: child,
    );
  }
}

/// Round tinted icon (44 dp) used at the start of import cards.
class ImportIconBadge extends StatelessWidget {
  const ImportIconBadge({required this.icon, required this.color, super.key});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
    child: Icon(icon, size: 22, color: color),
  );
}
