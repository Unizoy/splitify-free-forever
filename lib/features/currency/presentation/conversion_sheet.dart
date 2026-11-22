import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/currency/application/conversion_controller.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';
import 'package:splitify/features/currency/presentation/fx_copy.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Opens "Convert to INR" for an expense or payment in another currency (#32, T5). [to] is the group's
/// main currency (the sheet title).
Future<void> showConversionSheet(
  BuildContext context, {
  required String recordId,
  required bool payment,
  required String to,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<void>(
    context,
    title: l.fxConvertTo(to),
    builder: (_) => ConversionSheet(args: (recordId: recordId, payment: payment)),
  );
}

/// The sheet body: original → converted amount, the rate (automatic from the cached Frankfurter rates for
/// the record date, or typed), where it comes from, Save / Remove.
class ConversionSheet extends ConsumerStatefulWidget {
  const ConversionSheet({required this.args, super.key});

  final ConversionArgs args;

  @override
  ConsumerState<ConversionSheet> createState() => _ConversionSheetState();
}

class _ConversionSheetState extends ConsumerState<ConversionSheet> {
  final _rate = TextEditingController();
  bool _filled = false;
  bool _saving = false;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  ConversionController get _ctrl => ref.read(conversionProvider(widget.args).notifier);

  Future<void> _done(Future<bool> Function() action, String message) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    unawaited(HapticFeedback.lightImpact());
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    // "Use Frankfurter rate" and a late-arriving server rate change the text: keep the field in step.
    ref.listen(conversionProvider(widget.args), (_, next) {
      final text = next.value?.rateText;
      if (_filled && text != null && _rate.text != text) _rate.text = text;
    });
    final async = ref.watch(conversionProvider(widget.args));
    final d = async.value;
    if (d == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: async.hasError
            ? EmptyState(icon: AppIcons.info, title: l.fxNotPossible)
            : Center(
                child: DotsPulse(color: c.primary, semanticLabel: l.loading),
              ),
      );
    }
    if (!_filled) {
      _filled = true;
      _rate.text = d.rateText;
    }
    final auto = d.autoRate;
    final rate = d.rate;
    final problem = d.problem;
    final lookup = d.lookup;
    final String source;
    final bool warn;
    if (!d.manual && auto != null) {
      source = sourceLine(context, auto, asked: d.date);
      warn = false;
    } else if (rate != null && d.manual) {
      source = sourceLine(context, rate);
      warn = false;
    } else if (lookup is FxNeedsManualRate) {
      source = noRateText(context, lookup);
      warn = true;
    } else {
      source = l.fxRateError;
      warn = true;
    }
    final showError = problem != null && _rate.text.trim().isNotEmpty;

    return Column(
      key: const Key('conversion-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(draft: d),
        const SizedBox(height: AppSpacing.s6),
        UnderlineField(
          key: const Key('conversion-rate'),
          label: l.fxRateFieldLabel(d.from),
          hint: l.fxRateHint,
          controller: _rate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.]'))],
          errorText: showError
              ? (problem == RateProblem.tooLarge ? l.fxTooLarge : l.fxRateError)
              : null,
          suffix: Text(d.to, style: context.text.labelCaps.copyWith(color: c.textSecondary)),
          onChanged: _ctrl.setRateText,
        ),
        const SizedBox(height: AppSpacing.s3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              warn ? AppIcons.warning : AppIcons.info,
              size: 18,
              color: warn ? c.oweText : c.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(
                source,
                key: const Key('conversion-source'),
                style: context.text.bodySmall.copyWith(color: warn ? c.oweText : c.textSecondary),
              ),
            ),
          ],
        ),
        if (d.manual && auto != null) ...[
          const SizedBox(height: AppSpacing.s3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconChip(
              key: const Key('conversion-use-auto'),
              label: l.fxUseAuto,
              icon: AppIcons.refresh,
              onTap: _ctrl.useAuto,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s4),
        Text(l.fxReferenceNote, style: context.text.caption.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('conversion-save'),
          label: l.fxSave,
          variant: PillVariant.money,
          loading: _saving,
          onPressed: d.canSave && !_saving
              ? () => unawaited(_done(_ctrl.save, l.fxSavedSnack))
              : null,
        ),
        if (d.hasSaved) ...[
          const SizedBox(height: AppSpacing.s2),
          PillButton(
            key: const Key('conversion-remove'),
            label: l.fxRemove,
            variant: PillVariant.ghost,
            onPressed: _saving
                ? null
                : () => unawaited(
                    _done(() async {
                      await _ctrl.remove();
                      return true;
                    }, l.fxRemovedSnack),
                  ),
          ),
        ],
      ],
    );
  }
}

/// "USD $100.00 → INR ≈ ₹8,964.37" on a soft blob card.
class _Summary extends StatelessWidget {
  const _Summary({required this.draft});

  final ConversionDraft draft;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final d = draft;
    final converted = d.converted;
    final fromText = MoneyFormatter.detail.format(d.record.amount, d.from);
    final toText = converted == null
        ? l.fxRateNeeded
        : MoneyFormatter.detail.format(converted, d.to);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    Widget side(String code, String amount, {required bool result}) => Column(
      crossAxisAlignment: result && !large ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(code, style: context.text.labelCaps.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.s1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            result && converted != null ? l.fxApprox(amount) : amount,
            key: Key(result ? 'conversion-result' : 'conversion-original'),
            maxLines: 1,
            style: context.text.title
                .w(700)
                .copyWith(
                  color: !result
                      ? c.textPrimary
                      : converted == null
                      ? c.textSecondary
                      : c.primary,
                ),
          ),
        ),
      ],
    );
    final arrow = RotatedBox(
      quarterTurns: large ? 1 : 0,
      child: Icon(AppIcons.arrowRight, size: 20, color: c.textSecondary),
    );
    return Semantics(
      container: true,
      label: '$fromText, ${l.fxApprox(toText)}',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: AppRadii.all24,
        child: BlobBackground(
          seed: 5,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s5),
            child: large
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      side(d.from, fromText, result: false),
                      const SizedBox(height: AppSpacing.s3),
                      Align(alignment: AlignmentDirectional.centerStart, child: arrow),
                      const SizedBox(height: AppSpacing.s3),
                      side(d.to, toText, result: true),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: side(d.from, fromText, result: false)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                        child: arrow,
                      ),
                      Expanded(child: side(d.to, toText, result: true)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
