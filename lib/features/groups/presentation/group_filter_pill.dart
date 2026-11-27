import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splitify/features/groups/domain/group_extras.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Short label of [f] on the pill.
String groupFilterLabel(AppLocalizations l, GroupFilter f) => switch (f) {
  GroupFilter.all => l.groupFilterAll,
  GroupFilter.outstanding => l.groupFilterOutstanding,
  GroupFilter.iOwe => l.groupFilterIOwe,
  GroupFilter.owedToMe => l.groupFilterOwesMe,
};

/// The small filter pill next to "Active groups · N" (D-034 C3, Splitwise's four choices): opens a sheet
/// with All groups / Outstanding / I owe / Owe me. Highlighted while a filter is on.
class GroupFilterPill extends StatelessWidget {
  const GroupFilterPill({required this.value, required this.onChanged, super.key});

  final GroupFilter value;
  final ValueChanged<GroupFilter> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showAppSheet<GroupFilter>(
      context,
      title: AppLocalizations.of(context).groupFilterLabel,
      builder: (sheet) =>
          GroupFilterOptions(value: value, onPicked: (f) => Navigator.of(sheet).pop(f)),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      label: l.groupFilterButton(groupFilterLabel(l, value)),
      button: true,
      excludeSemantics: true,
      onTap: () => unawaited(_open(context)),
      child: IconChip(
        key: const Key('groups-filter'),
        label: groupFilterLabel(l, value),
        icon: AppIcons.filter,
        selected: value != GroupFilter.all,
        onTap: () => unawaited(_open(context)),
      ),
    );
  }
}

/// The filter sheet's choices (also rendered on their own in goldens).
class GroupFilterOptions extends StatelessWidget {
  const GroupFilterOptions({required this.value, required this.onPicked, super.key});

  final GroupFilter value;
  final ValueChanged<GroupFilter> onPicked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    String hint(GroupFilter f) => switch (f) {
      GroupFilter.all => '',
      GroupFilter.outstanding => l.groupFilterOutstandingHint,
      GroupFilter.iOwe => l.groupFilterIOweHint,
      GroupFilter.owedToMe => l.groupFilterOwesMeHint,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in GroupFilter.values) ...[
          OptionTile(
            key: Key('groups-filter-${f.name}'),
            label: f == GroupFilter.all ? l.groupFilterAllGroups : groupFilterLabel(l, f),
            selected: f == value,
            onTap: () => onPicked(f),
          ),
          if (hint(f).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s1, AppSpacing.s4, 0),
              child: Text(hint(f), style: context.text.bodySmall.copyWith(color: c.textSecondary)),
            ),
          const SizedBox(height: AppSpacing.s3),
        ],
      ],
    );
  }
}
