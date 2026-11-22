import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Camera QR scanner ("Scan my UPI QR", "Scan invite QR"); pops with the first QR's raw text. The camera
/// permission is asked just in time, when this screen opens.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({this.title, this.hint, super.key});

  /// Defaults to the UPI copy.
  final String? title;
  final String? hint;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.navyTop,
      appBar: AppBar(
        backgroundColor: c.navyTop,
        foregroundColor: c.onHero,
        title: Text(widget.title ?? l.scanUpiQr),
        leading: AppIconButton(
          tooltip: l.close,
          icon: const Icon(AppIcons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
              if (raw == null || _done) return;
              _done = true;
              Navigator.of(context).pop(raw);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s8),
              child: Text(
                widget.hint ?? l.scanUpiHint,
                textAlign: TextAlign.center,
                style: context.text.body.copyWith(color: c.onHero),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
