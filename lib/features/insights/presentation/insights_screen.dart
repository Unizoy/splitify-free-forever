import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart' show listMoney;
import 'package:splitify/features/balances/presentation/balances_tab.dart' show BalancesSkeleton;
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/presentation/insights_charts.dart';
import 'package:splitify/features/insights/presentation/trend_cards.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Insights (`/insights`, #33, 07 §2): Group / Me, a group picker, spending by category (donut +
/// legend chips, all time), by month (last 12 months), one category over time and (Group mode) who
/// paid against their share (D-034 P-6), in one main currency. Records in other currencies count only
/// with their saved conversion; the rest are left out with a note. The picked month is shared.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({this.mode = InsightsMode.group, this.groupId, super.key});

  final InsightsMode mode;

  /// Group to open on (Group mode) or to narrow Me to; null = default group / everything.
  final String? groupId;

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  late InsightsMode _mode = widget.mode;
  late String? _groupId = widget.mode == InsightsMode.group ? widget.groupId : null;
  late String? _meGroupId = widget.mode == InsightsMode.me ? widget.groupId : null;
  String? _category;
  String? _month;

  /// "Category over time" pick (null: the donut's pick, else the biggest category).
  String? _trendCategory;

  /// "Who paid" pick (null: me, else the first person).
  String? _person;

  InsightsQuery get _query =>
      (mode: _mode, groupId: _mode == InsightsMode.group ? _groupId : _meGroupId);

  void _setMode(InsightsMode m) => setState(() {
    _mode = m;
    _category = null;
    _month = null;
    _trendCategory = null;
    _person = null;
  });

  void _setGroup(String? id) => setState(() {
    if (_mode == InsightsMode.group) {
      _groupId = id;
    } else {
      _meGroupId = id;
    }
    _category = null;
    _month = null;
    _trendCategory = null;
    _person = null;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(insightsProvider(_query));
    final v = async.value;
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: PageBody(
        child: SafeArea(
          top: false,
          child: ListView(
            key: const Key('insights-list'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.s2,
              AppSpacing.screen,
              AppSpacing.s10,
            ),
            children: [
              PageTitle(
                title: l.insTitle,
                subtitle: v == null ? null : l.insSpendingIn(v.currency),
              ),
              const SizedBox(height: AppSpacing.s6),
              Semantics(
                label: l.insModeLabel,
                container: true,
                child: SegmentedPill<InsightsMode>(
                  key: const Key('insights-mode'),
                  items: [
                    SegmentedPillItem(
                      value: InsightsMode.group,
                      label: l.insModeGroup,
                      icon: AppIcons.groups,
                    ),
                    SegmentedPillItem(
                      value: InsightsMode.me,
                      label: l.insModeMe,
                      icon: AppIcons.user,
                    ),
                  ],
                  value: _mode,
                  onChanged: _setMode,
                ),
              ),
              ..._body(context, async, v),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, AsyncValue<InsightsView> async, InsightsView? v) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    if (v == null) {
      if (async.hasError) {
        return [EmptyState(icon: AppIcons.warning, title: l.insLoadError)];
      }
      return const [SizedBox(height: AppSpacing.s6), BalancesSkeleton()];
    }
    if (v.groups.isEmpty && v.mode == InsightsMode.group) {
      return [
        EmptyState(
          key: const Key('insights-no-groups'),
          icon: AppIcons.groups,
          title: l.insNoGroupsTitle,
          message: l.insNoGroupsBody,
        ),
      ];
    }
    final month = _month ?? v.currentMonth;
    final monthSpend = v.months.where((m) => m.month == month).firstOrNull?.minor ?? 0;
    final withSpending = v.months.where((m) => m.minor > 0).length;
    return [
      const SizedBox(height: AppSpacing.s4),
      _GroupPicker(view: v, onTap: () => unawaited(_pickGroup(context, v))),
      if (v.isEmpty)
        if (v.unconverted > 0)
          EmptyState(
            key: const Key('insights-convert'),
            icon: AppIcons.coins,
            title: l.insConvertTitle,
            message: l.insConvertBody(v.unconverted, v.currency),
          )
        else
          EmptyState(
            key: const Key('insights-empty'),
            icon: AppIcons.chart,
            title: l.insEmptyTitle,
            message: v.mode == InsightsMode.group && v.group != null
                ? l.insEmptyGroupBody(v.group!.name)
                : l.insEmptyMeBody,
          )
      else ...[
        if (v.unconverted > 0) ...[
          const SizedBox(height: AppSpacing.s4),
          _Note(
            key: const Key('insights-unconverted'),
            text: l.insUnconverted(v.unconverted, v.currency),
          ),
        ],
        const SizedBox(height: AppSpacing.s5),
        InsightsCard(
          key: const Key('insights-categories'),
          title: l.insByCategory,
          trailing: l.insAllTime,
          child: CategoryDonut(
            summary: v.summary,
            totalLabel: v.mode == InsightsMode.group ? l.insTotalSpent : l.insYourShare,
            selected: _category,
            onSelect: (k) => setState(() => _category = k),
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        InsightsCard(
          key: const Key('insights-months'),
          title: l.insByMonth,
          trailing: l.insLast12Months,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                monthTitle(context, month),
                key: const Key('insights-month-title'),
                style: context.text.body.copyWith(color: c.textSecondary),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  listMoney(monthSpend, v.currency),
                  key: const Key('insights-month-amount'),
                  maxLines: 1,
                  style: context.text.amountHero.copyWith(color: c.textPrimary),
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              MonthBars(
                months: v.months,
                currency: v.currency,
                selected: month,
                onSelect: (m) => setState(() => _month = m),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                withSpending == 0
                    ? l.insNoRecentMonths
                    : withSpending == 1
                    ? l.insOneMonthHint
                    : l.insMonthHint,
                key: const Key('insights-month-hint'),
                style: context.text.bodySmall.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                l.insYearTotal(listMoney(v.months.fold(0, (sum, m) => sum + m.minor), v.currency)),
                style: context.text.bodySmall.w(600).copyWith(color: c.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        CategoryTrendCard(
          view: v,
          category: _trendPick(v),
          month: month,
          onCategory: (k) => setState(() => _trendCategory = k),
          onMonth: (m) => setState(() => _month = m),
        ),
        if (v.whoPaid.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s5),
          WhoPaidCard(
            view: v,
            memberId: _personPick(v),
            month: month,
            onMember: (id) => setState(() => _person = id),
            onMonth: (m) => setState(() => _month = m),
          ),
        ],
      ],
      const SizedBox(height: AppSpacing.s5),
      Text(l.totFootnote, style: context.text.caption.copyWith(color: c.textSecondary)),
    ];
  }

  /// The category over time shows: the picked one if it has spending, else the donut's, else the
  /// biggest.
  String _trendPick(InsightsView v) {
    final keys = {for (final s in v.summary.byCategory) s.category};
    for (final k in [_trendCategory, _category]) {
      if (k != null && keys.contains(k)) return k;
    }
    return v.summary.byCategory.first.category;
  }

  /// Whose paid / share shows: the picked person, else me, else the first person.
  String _personPick(InsightsView v) {
    final ids = {for (final t in v.whoPaid) t.memberId};
    for (final id in [_person, v.meMemberId]) {
      if (id != null && ids.contains(id)) return id;
    }
    return v.whoPaid.first.memberId;
  }

  Future<void> _pickGroup(BuildContext context, InsightsView v) async {
    final l = AppLocalizations.of(context);
    final picked = await showAppSheet<({String? id})>(
      context,
      title: l.insPickGroup,
      builder: (sheet) =>
          InsightsGroupOptions(view: v, onPick: (id) => Navigator.of(sheet).pop((id: id))),
    );
    if (picked != null && mounted) _setGroup(picked.id);
  }
}

/// The picked group (cover, name, caption) with a chevron; opens the picker.
class _GroupPicker extends StatelessWidget {
  const _GroupPicker({required this.view, required this.onTap});

  final InsightsView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final g = view.group;
    final caption = view.mode == InsightsMode.group
        ? l.insPickerCaptionGroup
        : l.insPickerCaptionMe;
    return Semantics(
      button: true,
      hint: l.insPickerHint,
      child: Pressable(
        key: const Key('insights-group-picker'),
        onTap: onTap,
        scale: AppMotion.rowPressScale,
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.all24,
            side: BorderSide(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s3),
            child: Row(
              children: [
                _GroupThumb(group: g),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g == null ? l.insAllGroupsCaption : caption,
                        style: context.text.caption.copyWith(color: c.textSecondary),
                      ),
                      Text(
                        g?.name ?? l.insAllGroups,
                        style: context.text.body.w(600).copyWith(color: c.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Icon(AppIcons.chevronDown, size: 18, color: c.textSecondary),
                const SizedBox(width: AppSpacing.s1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small generated cover of a group, or the groups icon for "everything".
class _GroupThumb extends StatelessWidget {
  const _GroupThumb({required this.group});

  final InsightsGroup? group;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final g = group;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: AppRadii.all16,
        child: SizedBox.square(
          dimension: 44,
          child: g == null
              ? ColoredBox(
                  color: c.primaryContainer,
                  child: Icon(AppIcons.groups, size: 22, color: c.onPrimaryContainer),
                )
              : CoverArt(seed: g.id, family: coverFamilyFor(g.type)),
        ),
      ),
    );
  }
}

/// Picker sheet: in Me mode "All groups and friends" first, then every group (archived last).
class InsightsGroupOptions extends StatelessWidget {
  const InsightsGroupOptions({required this.view, required this.onPick});

  final InsightsView view;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = <({String? id, InsightsGroup? group})>[
      if (view.mode == InsightsMode.me) (id: null, group: null),
      for (final g in view.groups) (id: g.id, group: g),
    ];
    return Column(
      key: const Key('insights-group-options'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          _OptionRow(
            key: Key('insights-option-${rows[i].id ?? 'all'}'),
            group: rows[i].group,
            title: rows[i].group?.name ?? l.insAllGroups,
            caption: rows[i].group == null
                ? l.insAllGroupsCaption
                : rows[i].group!.archived
                ? l.insArchived
                : null,
            selected: rows[i].id == view.group?.id,
            showDivider: i < rows.length - 1,
            onTap: () => onPick(rows[i].id),
          ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.group,
    required this.title,
    required this.caption,
    required this.selected,
    required this.showDivider,
    required this.onTap,
    super.key,
  });

  final InsightsGroup? group;
  final String title;
  final String? caption;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          selected: selected,
          child: Pressable(
            onTap: onTap,
            scale: AppMotion.rowPressScale,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                child: Row(
                  children: [
                    _GroupThumb(group: group),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.text.body.w(600)),
                          if (caption != null)
                            Text(
                              caption!,
                              style: context.text.bodySmall.copyWith(color: c.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: AppSpacing.s2),
                      Icon(AppIcons.checkCircle, size: 24, color: c.primary),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider) const DashedDivider(),
      ],
    );
  }
}

/// Info note (left-out records): tinted card with an info icon.
class _Note extends StatelessWidget {
  const _Note({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: c.infoContainer, borderRadius: AppRadii.all16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.info, size: 20, color: c.info),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(text, style: context.text.bodySmall.copyWith(color: c.textPrimary)),
          ),
        ],
      ),
    );
  }
}
