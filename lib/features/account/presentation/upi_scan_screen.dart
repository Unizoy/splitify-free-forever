import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Scan my UPI QR": camera preview; pops with the first QR's raw text.
class UpiScanScreen extends StatefulWidget {
  const UpiScanScreen({super.key});

  @override
  State<UpiScanScreen> createState() => _UpiScanScreenState();
}

class _UpiScanScreenState extends State<UpiScanScreen> {
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
        title: Text(l.scanUpiQr),
        leading: IconButton(
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
                l.scanUpiHint,
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
