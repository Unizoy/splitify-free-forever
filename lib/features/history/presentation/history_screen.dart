import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/history/application/history_providers.dart';
import 'package:splitify/features/history/domain/version_diff.dart';
import 'package:splitify/features/history/presentation/history_copy.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/dashed.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Edit history (`/expense/:id/history`, `/payment/:id/history`; 08 #20, 07 "History", 646 rows): a vertical
/// timeline, newest first, of who changed what. Versions lost to a newer edit stay visible, muted and labelled
/// "Not applied (a newer edit won)". Cached versions show offline; newer ones are fetched when online.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({required this.target, super.key});

  final HistoryTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(historyViewProvider(target));
    final fetch = ref.watch(historyFetchProvider(target));
    final view = async.value;
    Future<void> retry() async {
      try {
        ref.invalidate(historyFetchProvider(target));
        await ref.read(historyFetchProvider(target).future);
      } on Exception {
        // Shown by the offline note / state below.
      }
    }

    final children = <Widget>[];
    if (view == null) {
      children.add(
        async.isLoading
            ? _Loading(label: l.loading)
            : EmptyState(
                icon: AppIcons.history,
                title: l.histNotFound,
                message: l.histNotFoundBody,
              ),
      );
    } else {
      final names = HistoryNames(l, view);
      children
        ..add(PageTitle(title: l.histTitle, subtitle: _subtitle(l, view, names)))
        ..add(const SizedBox(height: AppSpacing.s6));
      if (view.record.pending) {
        children.add(
          _Note(
            key: const Key('history-pending'),
            leading: const SyncMarker(compact: true),
            text: l.histPending,
          ),
        );
      }
      if (fetch.hasError && view.entries.isNotEmpty) {
        children.add(
          _Note(
            key: const Key('history-offline-note'),
            leading: Icon(AppIcons.unsynced, size: 18, color: context.colors.textSecondary),
            text: l.histOfflineNote,
          ),
        );
      }
      if (view.entries.isEmpty) {
        children.add(
          fetch.isLoading
              ? _Loading(label: l.loading)
              : fetch.hasError
              ? EmptyState(
                  key: const Key('history-offline'),
                  icon: AppIcons.unsynced,
                  title: l.histOfflineTitle,
                  message: l.histOfflineBody,
                  actions: [
                    PillButton(
                      key: const Key('history-retry'),
                      label: l.histRetry,
                      icon: AppIcons.refresh,
                      variant: PillVariant.outline,
                      onPressed: retry,
                    ),
                  ],
                )
              : EmptyState(
                  key: const Key('history-empty'),
                  icon: AppIcons.history,
                  title: l.histEmptyTitle,
                  message: l.histEmptyBody,
                ),
        );
      }
      for (var i = 0; i < view.entries.length; i++) {
        children.add(
          _TimelineEntry(
            key: Key('history-entry-${view.entries[i].seq}'),
            entry: view.entries[i],
            names: names,
            last: i == view.entries.length - 1,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: retry,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.s2,
              AppSpacing.screen,
              AppSpacing.s10,
            ),
            children: children,
          ),
        ),
      ),
    );
  }

  static String _subtitle(AppLocalizations l, HistoryView v, HistoryNames n) {
    final e = v.record.expense;
    if (e != null)
      return '${e.description}\u00A0· ${MoneyFormatter.detail.format(e.total, e.currency)}';
    final p = v.record.payment!;
    return '${l.histPaymentTitle(n.member(p.fromMember), n.member(p.toMember))}\u00A0· '
        '${MoneyFormatter.detail.format(p.amount, p.currency)}';
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
    child: Center(
      child: DotsPulse(color: context.colors.primary, semanticLabel: label),
    ),
  );
}

/// Small info line above the timeline (pending change, offline).
class _Note extends StatelessWidget {
  const _Note({required this.leading, required this.text, super.key});

  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all16),
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(text, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One version: an op dot on a dashed rail, who/when, and the changed fields in a card.
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.entry, required this.names, required this.last, super.key});

  final HistoryEntry entry;
  final HistoryNames names;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final muted = entry.muted;
    final rows = historyRows(context, entry, names);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                _OpDot(op: entry.op),
                if (!last)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: DashedDivider(color: c.divider, height: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Semantics(
                    header: true,
                    child: Text(
                      historyHeadline(l, entry, names),
                      style: context.text.body
                          .w(600)
                          .copyWith(color: muted ? c.textSecondary : c.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    historyWhen(context, entry.changedAt),
                    style: context.text.bodySmall.copyWith(color: c.textSecondary),
                  ),
                  if (muted) ...[
                    const SizedBox(height: AppSpacing.s2),
                    _NotAppliedPill(label: l.histNotApplied),
                  ],
                  if (rows.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s3),
                    _ChangesCard(rows: rows, muted: muted),
                  ] else if (entry.op == HistoryOp.update) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      l.histNoVisibleChange,
                      style: context.text.bodySmall.copyWith(color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpDot extends StatelessWidget {
  const _OpDot({required this.op});

  final HistoryOp op;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = context.isDark;
    final (IconData icon, Color fg, Color bg) = switch (op) {
      HistoryOp.create => (AppIcons.plus, c.onPrimaryContainer, c.primaryContainer),
      HistoryOp.update => (AppIcons.edit, c.textPrimary, c.chip),
      HistoryOp.delete => (
        AppIcons.trash,
        c.oweText,
        c.oweAccent.withValues(alpha: dark ? 0.2 : 0.12),
      ),
      HistoryOp.restore => (
        AppIcons.restore,
        c.owedText,
        c.owedAccent.withValues(alpha: dark ? 0.2 : 0.14),
      ),
      HistoryOp.conflictLost => (AppIcons.warning, c.textSecondary, c.surfaceMuted),
    };
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }
}

class _NotAppliedPill extends StatelessWidget {
  const _NotAppliedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      key: const Key('history-not-applied'),
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.s3, 6, AppSpacing.s4, 6),
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.allPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.info, size: 16, color: c.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: context.text.bodySmall.w(600).copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The changed fields of one version; dashed outline instead of a fill when the version was not applied.
class _ChangesCard extends StatelessWidget {
  const _ChangesCard({required this.rows, required this.muted});

  final List<ChangeRow> rows;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const DashedDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: _Row(row: rows[i], muted: muted),
            ),
          ],
        ],
      ),
    );
    if (muted) {
      return CustomPaint(
        painter: DashedBorderPainter(color: c.divider, radius: AppRadii.r16, dash: 6, gap: 4),
        child: body,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all16),
      child: body,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.muted});

  final ChangeRow row;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final label = Text(
      row.label.toUpperCase(),
      style: context.text.labelCaps.copyWith(color: c.textSecondary),
    );
    switch (row) {
      case NoteRow():
        return Text(
          row.label,
          style: context.text.body.w(600).copyWith(color: muted ? c.textSecondary : c.textPrimary),
        );
      case ValueRow(:final from, :final to, :final showFrom):
        final none = l.histNoValue;
        return Semantics(
          container: true,
          label: showFrom
              ? l.histChangeA11y(row.label, from ?? none, to ?? none)
              : '${row.label}: ${to ?? none}',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: AppSpacing.s1),
              _Diff(from: showFrom ? (from ?? none) : null, to: to ?? none, muted: muted),
            ],
          ),
        );
      case MemberRow(:final members, :final showFrom):
        final none = l.histNoValue;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label,
            for (final m in members)
              Semantics(
                container: true,
                label: showFrom
                    ? l.histChangeA11y(m.name, m.from ?? none, m.to ?? none)
                    : '${m.name}: ${m.to ?? none}',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s2),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.s3,
                    runSpacing: AppSpacing.s1,
                    children: [
                      Text(
                        m.name,
                        style: context.text.body.copyWith(
                          color: muted ? c.textSecondary : c.textPrimary,
                        ),
                      ),
                      _Diff(
                        from: showFrom ? (m.from ?? none) : null,
                        to: m.to ?? none,
                        muted: muted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
    }
  }
}

/// "old → new" (old struck through), or just the value.
class _Diff extends StatelessWidget {
  const _Diff({required this.from, required this.to, required this.muted});

  final String? from;
  final String to;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.text.body;
    return Text.rich(
      TextSpan(
        children: [
          if (from != null) ...[
            TextSpan(
              text: from,
              style: style.copyWith(
                color: c.textSecondary,
                decoration: TextDecoration.lineThrough,
                decorationColor: c.textSecondary,
              ),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(AppIcons.arrowRight, size: 16, color: c.textSecondary),
              ),
            ),
          ],
          TextSpan(
            text: to,
            style: style.w(600).copyWith(color: muted ? c.textSecondary : c.textPrimary),
          ),
        ],
      ),
    );
  }
}
