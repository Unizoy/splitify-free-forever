import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/upi/upi_link.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart' show QrRing;
import 'package:splitify/features/payments/application/upi_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Pay via UPI (#26): opens the UPI app with [link]; back in Splitify asks "Did the payment go through?"
/// (or, with no UPI app, offers the UPI ID / amount / QR fallbacks). True when the person tapped
/// "Mark as paid" — a payment is recorded only then (rule 13).
Future<bool> payViaUpi(
  BuildContext context,
  WidgetRef ref,
  UpiLink link, {
  required String payeeName,
  required int amountMinor,
}) async {
  final l = AppLocalizations.of(context);
  final launched = await ref.read(upiLauncherProvider).launch(link.uri);
  if (!context.mounted) return false;
  final paid = await showAppSheet<bool>(
    context,
    title: launched ? l.upiReturnTitle : l.upiNoAppTitle,
    builder: (sheet) => UpiResultSheet(
      link: link,
      payeeName: payeeName,
      amountMinor: amountMinor,
      noApp: !launched,
    ),
  );
  return paid ?? false;
}

/// "Did the payment go through?" → Mark as paid / Not yet, with the fallbacks; or, after a failed launch,
/// "No UPI app found" with the same fallbacks.
class UpiResultSheet extends StatelessWidget {
  const UpiResultSheet({
    required this.link,
    required this.payeeName,
    required this.amountMinor,
    this.noApp = false,
    super.key,
  });

  final UpiLink link;
  final String payeeName;
  final int amountMinor;
  final bool noApp;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Column(
      key: Key(noApp ? 'upi-no-app' : 'upi-return'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          noApp ? l.upiNoAppBody(payeeName) : l.upiReturnBody,
          style: context.text.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s5),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.upiPayTo(payeeName), style: context.text.body.w(600)),
              const SizedBox(height: AppSpacing.s1),
              Text(
                listMoney(amountMinor, UpiLinkBuilder.currency),
                style: context.text.amount.w(700).copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                l.upiIdLine(link.vpa),
                style: context.text.bodySmall.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s4),
              UpiFallbacks(link: link, payeeName: payeeName, amountMinor: amountMinor),
            ],
          ),
        ),
        if (!noApp) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(l.upiFailedHint, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
        ],
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('upi-mark-paid'),
          label: l.upiMarkPaid,
          icon: AppIcons.check,
          variant: PillVariant.money,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpacing.s3),
        PillButton(
          key: const Key('upi-not-yet'),
          label: l.upiNotYet,
          variant: PillVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

/// Copy UPI ID · Copy amount · UPI QR — always offered next to Pay via UPI (some apps decline P2P links).
class UpiFallbacks extends StatefulWidget {
  const UpiFallbacks({
    required this.link,
    required this.payeeName,
    required this.amountMinor,
    super.key,
  });

  final UpiLink link;
  final String payeeName;
  final int amountMinor;

  @override
  State<UpiFallbacks> createState() => _UpiFallbacksState();
}

class _UpiFallbacksState extends State<UpiFallbacks> {
  /// Which chip just copied (shows "Copied" for a moment).
  String? _copied;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy(String which, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppHaptics.selection();
    setState(() => _copied = which);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final link = widget.link;
    IconChip chip(String which, String label, IconData icon, VoidCallback onTap) => IconChip(
      key: Key('upi-$which'),
      label: _copied == which ? l.upiCopied : label,
      icon: _copied == which ? AppIcons.check : icon,
      selected: _copied == which,
      onTap: onTap,
    );
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: [
        chip('copy-id', l.upiCopyId, AppIcons.copy, () => unawaited(_copy('copy-id', link.vpa))),
        chip(
          'copy-amount',
          l.upiCopyAmount,
          AppIcons.copy,
          () => unawaited(_copy('copy-amount', link.amount)),
        ),
        chip(
          'qr',
          l.upiShowQr,
          AppIcons.qr,
          () => unawaited(
            showUpiQr(context, link, payeeName: widget.payeeName, amountMinor: widget.amountMinor),
          ),
        ),
      ],
    );
  }
}

/// The same `upi://pay` link as a QR code, to pay from another phone or app.
Future<void> showUpiQr(
  BuildContext context,
  UpiLink link, {
  required String payeeName,
  required int amountMinor,
}) {
  final l = AppLocalizations.of(context);
  final amount = listMoney(amountMinor, UpiLinkBuilder.currency);
  return showAppSheet<void>(
    context,
    title: l.upiQrTitle(payeeName),
    builder: (sheet) => Column(
      key: const Key('upi-qr-sheet'),
      children: [
        QrRing(data: link.uri, label: l.upiQrTitle(payeeName)),
        const SizedBox(height: AppSpacing.s5),
        Text(
          l.upiQrBody(amount),
          textAlign: TextAlign.center,
          style: sheet.text.body.copyWith(color: sheet.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(l.upiIdLine(link.vpa), textAlign: TextAlign.center, style: sheet.text.body.w(600)),
        const SizedBox(height: AppSpacing.s4),
      ],
    ),
  );
}
