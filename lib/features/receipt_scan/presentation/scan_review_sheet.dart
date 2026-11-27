import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart' show shortDate;
import 'package:splitify/features/photos/presentation/stored_photo.dart' show MemoryPhoto;
import 'package:splitify/features/receipt_scan/application/receipt_ocr.dart';
import 'package:splitify/features/receipt_scan/application/scan_apply.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// What the person chose in the review sheet: the ticked fields, and whether to split by the found lines.
typedef ScanDecision = ({ScanChoice choice, bool itemize});

/// "Reading the receipt…" while the text model runs (a second or two, on the phone).
class ScanReading extends StatelessWidget {
  const ScanReading({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Padding(
      key: const Key('scan-reading'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Column(
        children: [
          DotsPulse(color: c.primary, semanticLabel: l.entryScanReading),
          const SizedBox(height: AppSpacing.s4),
          ExcludeSemantics(
            child: Text(
              l.entryScanReading,
              style: context.text.body.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scan's review (D-034 A3): what was found, each with a tick; "Use these" fills the ticked fields,
/// "Split by items" also turns the found lines into an Items split. Nothing is saved here (S-373); the
/// photo is attached as the receipt either way.
class ScanReviewPanel extends StatefulWidget {
  const ScanReviewPanel({
    required this.outcome,
    required this.draft,
    required this.onDone,
    required this.onRetry,
    super.key,
  });

  final ScanOutcome outcome;

  /// The editor's draft: decides the starting ticks ("Replaces ₹500") and whether Itemize can run.
  final ExpenseDraft draft;
  final ValueChanged<ScanDecision> onDone;
  final VoidCallback onRetry;

  @override
  State<ScanReviewPanel> createState() => _ScanReviewPanelState();
}

class _ScanReviewPanelState extends State<ScanReviewPanel> {
  late ScanChoice _choice = defaultChoice(widget.draft, widget.outcome.scan);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final d = widget.draft;
    final s = widget.outcome.scan;
    final total = s.total;
    final date = s.date;
    final description = scanDescription(s);
    final photo = widget.outcome.photo;
    if (total == null && date == null && description == null) {
      return _Nothing(
        photo: photo != null,
        onKeep: () => widget.onDone((choice: _choice, itemize: false)),
        onRetry: widget.onRetry,
      );
    }
    String money(int v) => MoneyFormatter.detail.format(v, d.currency);
    final typedAmount = d.total;
    final rows = <Widget>[
      if (total != null)
        _FoundRow(
          key: const Key('scan-amount'),
          label: l.entryScanAmount,
          value: money(total),
          replaces: typedAmount != null && typedAmount != total
              ? MoneyFormatter.list.format(typedAmount, d.currency)
              : null,
          ticked: _choice.amount,
          onTap: () => setState(
            () => _choice = (
              amount: !_choice.amount,
              date: _choice.date,
              description: _choice.description,
            ),
          ),
        ),
      if (date != null)
        _FoundRow(
          key: const Key('scan-date'),
          label: l.entryScanDate,
          value: shortDate(context, date),
          ticked: _choice.date,
          onTap: () => setState(
            () => _choice = (
              amount: _choice.amount,
              date: !_choice.date,
              description: _choice.description,
            ),
          ),
        ),
      if (description != null)
        _FoundRow(
          key: const Key('scan-description'),
          label: l.entryScanDescription,
          value: description,
          replaces: d.description.trim().isNotEmpty && d.description.trim() != description
              ? d.description.trim()
              : null,
          ticked: _choice.description,
          onTap: () => setState(
            () => _choice = (
              amount: _choice.amount,
              date: _choice.date,
              description: !_choice.description,
            ),
          ),
        ),
      if (s.items.isNotEmpty)
        _ItemsRow(count: s.items.length, sum: money(s.items.fold(0, (a, i) => a + i.amount))),
    ];
    return Column(
      key: const Key('scan-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s1),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadii.all24,
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              for (final (i, row) in rows.indexed) ...[
                row,
                if (i < rows.length - 1) const DashedDivider(),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            if (photo != null) ...[
              ClipRRect(
                borderRadius: AppRadii.all16,
                child: SizedBox.square(
                  dimension: 44,
                  child: ExcludeSemantics(child: MemoryPhoto(bytes: photo.thumb, decodeWidth: 120)),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
            ],
            Expanded(
              child: Text(
                l.entryScanPhotoNote,
                style: context.text.bodySmall.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('scan-use'),
          label: l.entryScanUse,
          onPressed: () {
            HapticFeedback.selectionClick();
            widget.onDone((choice: _choice, itemize: false));
          },
        ),
        if (s.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s3),
          if (d.hasGroup)
            PillButton(
              key: const Key('scan-itemize'),
              label: l.entryScanItemize,
              icon: AppIcons.receipt,
              variant: PillVariant.outline,
              onPressed: () => widget.onDone((choice: _choice, itemize: true)),
            )
          else
            Text(
              l.entryScanItemizeNeedsGroup,
              key: const Key('scan-itemize-needs-group'),
              textAlign: TextAlign.center,
              style: context.text.bodySmall.copyWith(color: c.textSecondary),
            ),
        ],
      ],
    );
  }
}

/// A found field: tick, label, value (and what it would replace).
class _FoundRow extends StatelessWidget {
  const _FoundRow({
    required this.label,
    required this.value,
    required this.ticked,
    required this.onTap,
    this.replaces,
    super.key,
  });

  final String label;
  final String value;
  final String? replaces;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      checked: ticked,
      button: true,
      label: l.entryScanTickLabel(label, value),
      hint: replaces == null ? null : l.entryScanReplaces(replaces!),
      excludeSemantics: true,
      onTap: tap,
      child: Pressable(
        onTap: tap,
        borderRadius: AppRadii.all16,
        scale: AppMotion.rowPressScale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: context.motion.fast,
                  curve: context.motion.fastCurve,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ticked ? c.primaryFill : AppPalette.clear,
                    shape: BoxShape.circle,
                    border: Border.all(color: ticked ? c.primaryFill : c.divider, width: 1.5),
                  ),
                  child: ticked ? Icon(AppIcons.check, size: 16, color: c.onPrimaryFill) : null,
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: context.text.caption.copyWith(color: c.textSecondary)),
                      Text(
                        value,
                        style: context.text.body
                            .w(700)
                            .copyWith(
                              color: ticked ? c.textPrimary : c.textSecondary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                      if (replaces != null)
                        Text(
                          l.entryScanReplaces(replaces!),
                          style: context.text.caption.copyWith(color: c.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemsRow extends StatelessWidget {
  const _ItemsRow({required this.count, required this.sum});

  final int count;
  final String sum;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return MergeSemantics(
      child: ConstrainedBox(
        key: const Key('scan-items'),
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            SizedBox(width: 28, child: Icon(AppIcons.receipt, size: 20, color: c.primary)),
            const SizedBox(width: AppSpacing.s4),
            Expanded(child: Text(l.entryScanItemsFound(count), style: context.text.body.w(600))),
            Text(sum, style: context.text.body.copyWith(color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.photo, required this.onKeep, required this.onRetry});

  final bool photo;
  final VoidCallback onKeep;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      key: const Key('scan-nothing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmptyState(
          icon: AppIcons.receipt,
          title: l.entryScanNothingTitle,
          message: l.entryScanNothingBody,
        ),
        const SizedBox(height: AppSpacing.s4),
        if (photo) ...[
          PillButton(
            key: const Key('scan-keep-photo'),
            label: l.entryScanKeepPhoto,
            onPressed: onKeep,
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        PillButton(
          key: const Key('scan-retry'),
          label: l.entryScanRetry,
          icon: AppIcons.camera,
          variant: PillVariant.outline,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
