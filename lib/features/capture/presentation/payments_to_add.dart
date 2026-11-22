import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/features/capture/presentation/capture_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Paid ₹500 to Rahul" / "Paid ₹500".
String capturePaidText(AppLocalizations l, PaymentCapture c) {
  final amount = MoneyFormatter.list.format(c.amount, c.currency);
  return c.payee == null ? l.capturePaid(amount) : l.capturePaidTo(amount, c.payee!);
}

/// "Google Pay · 10:42 AM" (today) or "Google Pay · 21 Nov, 10:42 AM".
String captureViaText(AppLocalizations l, PaymentCapture c, DateTime now) {
  final t = c.capturedAt.toLocal();
  final n = now.toLocal();
  final sameDay = t.year == n.year && t.month == n.month && t.day == n.day;
  final time = sameDay ? DateFormat.jm().format(t) : DateFormat('d MMM, h:mm a').format(t);
  return l.captureVia(c.appName, time);
}

String captureSourceLabel(AppLocalizations l, CaptureSource s) => switch (s) {
  CaptureSource.notification => l.captureSourceLabelNotification,
  CaptureSource.sms => l.captureSourceLabelSms,
  CaptureSource.screen => l.captureSourceLabelScreen,
};

/// Groups hero: a pill on the glass card, shown only while something waits (S-228).
class PaymentsToAddPill extends ConsumerWidget {
  const PaymentsToAddPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(pendingCapturesProvider).value?.length ?? 0;
    if (n == 0) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s3),
      child: Semantics(
        button: true,
        label: l.paymentsToAdd(n),
        excludeSemantics: true,
        onTap: () => unawaited(showPaymentsToAdd(context)),
        child: Material(
          color: c.money,
          borderRadius: AppRadii.allPill,
          child: InkWell(
            key: const Key('payments-to-add-pill'),
            borderRadius: AppRadii.allPill,
            onTap: () => unawaited(showPaymentsToAdd(context)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4,
                  vertical: AppSpacing.s2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.payment, size: 18, color: c.onMoney),
                    const SizedBox(width: AppSpacing.s2),
                    Flexible(
                      child: Text(
                        l.paymentsToAdd(n),
                        style: context.text.button.copyWith(color: c.onMoney),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s1),
                    Icon(AppIcons.chevronRight, size: 16, color: c.onMoney),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Activity tab: the waiting payments on top of the feed (at most 3; "See all" opens the sheet).
class PaymentsToAddSection extends ConsumerWidget {
  const PaymentsToAddSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pendingCapturesProvider).value ?? const <PaymentCapture>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4),
      child: Container(
        key: const Key('payments-to-add-section'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s4,
          AppSpacing.s4,
          AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: c.bgSubtle,
          borderRadius: AppRadii.all24,
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.paymentsToAdd(items.length).toUpperCase(),
                      style: context.text.labelCaps.copyWith(color: c.textSecondary),
                    ),
                  ),
                ),
                if (items.length > 3)
                  PillButton(
                    key: const Key('payments-to-add-all'),
                    label: l.captureSeeAll,
                    variant: PillVariant.ghost,
                    size: PillSize.medium,
                    expand: false,
                    onPressed: () => unawaited(showPaymentsToAdd(context)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            for (var i = 0; i < items.length && i < 3; i++)
              CaptureTile(capture: items[i], showDivider: i < items.length - 1 && i < 2),
          ],
        ),
      ),
    );
  }
}

/// The full list in a sheet (Groups hero pill, Activity "See all").
Future<void> showPaymentsToAdd(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showAppSheet<void>(
    context,
    title: l.paymentsToAddTitle,
    builder: (sheet) => const PaymentsToAddList(),
  );
}

class PaymentsToAddList extends ConsumerWidget {
  const PaymentsToAddList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = ref.watch(pendingCapturesProvider).value ?? const <PaymentCapture>[];
    return Column(
      key: const Key('payments-to-add-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.paymentsToAddHint,
          style: context.text.bodySmall.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s3),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
            child: EmptyState(icon: AppIcons.checkCircle, title: l.paymentsToAddEmpty),
          ),
        for (var i = 0; i < items.length; i++)
          CaptureTile(capture: items[i], showDivider: i < items.length - 1, closeSheet: true),
      ],
    );
  }
}

/// One waiting payment: amount, payee, app and time, with Add and Dismiss.
class CaptureTile extends ConsumerWidget {
  const CaptureTile({
    required this.capture,
    this.showDivider = true,
    this.closeSheet = false,
    super.key,
  });

  final PaymentCapture capture;
  final bool showDivider;

  /// Inside the sheet: Add closes it first.
  final bool closeSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final now = DateTime.now();
    final amount = MoneyFormatter.list.format(capture.amount, capture.currency);
    void add() {
      final router = GoRouter.of(context);
      if (closeSheet) Navigator.of(context).pop();
      unawaited(router.push(CaptureRoutes.add(capture.id)));
    }

    return Column(
      key: Key('capture-${capture.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
                child: Icon(AppIcons.payment, size: 20, color: c.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      label: capturePaidText(l, capture),
                      excludeSemantics: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              capture.payee ?? capture.appName,
                              style: context.text.title.w(600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s2),
                          Text(amount, style: context.text.amount.w(700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      '${captureViaText(l, capture, now)} · ${captureSourceLabel(l, capture.source)}',
                      style: context.text.bodySmall.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Wrap(
                      spacing: AppSpacing.s2,
                      runSpacing: AppSpacing.s2,
                      children: [
                        PillButton(
                          key: Key('capture-add-${capture.id}'),
                          label: l.captureAdd,
                          icon: AppIcons.plus,
                          variant: PillVariant.money,
                          size: PillSize.medium,
                          expand: false,
                          onPressed: add,
                        ),
                        PillButton(
                          key: Key('capture-dismiss-${capture.id}'),
                          label: l.captureDismiss,
                          variant: PillVariant.ghost,
                          size: PillSize.medium,
                          expand: false,
                          onPressed: () {
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            unawaited(ref.read(captureRepositoryProvider).dismiss(capture.id));
                            messenger
                              ?..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(content: Text(l.captureDismissed)));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const DashedDivider(),
      ],
    );
  }
}
