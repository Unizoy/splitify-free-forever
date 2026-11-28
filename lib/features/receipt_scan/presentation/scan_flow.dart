import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/photos/application/photo_providers.dart' show PhotoSource;
import 'package:splitify/features/receipt_scan/application/receipt_ocr.dart';
import 'package:splitify/features/receipt_scan/presentation/scan_review_sheet.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

final _log = Logger('receipt_scan');

/// A finished scan: what the person chose and what was read.
typedef ScanResult = ({ScanDecision decision, ScanOutcome outcome});

/// "Scan receipt" (D-034 A3): camera or gallery, the text read on this phone (offline), then the review
/// sheet. Returns null when the person backs out. [read] reads a picked file (tests replace it).
///
/// With [path] (a picture shared to Splitify, D-034 A7) the first read skips the camera / gallery choice.
Future<ScanResult?> scanReceipt(
  BuildContext context,
  WidgetRef ref, {
  required ExpenseDraft draft,
  DateTime? today,
  String? path,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final picker = ref.read(receiptImagePickerProvider);
  final ocr = ref.read(receiptOcrProvider);
  final prepare = ref.read(receiptPhotoPreparerProvider);
  var shared = path;
  while (context.mounted) {
    var path = shared;
    shared = null;
    if (path == null) {
      final source = await showAppSheet<PhotoSource>(
        context,
        title: l.entryScanReceipt,
        builder: (sheet) => const _ScanSource(),
      );
      if (source == null || !context.mounted) return null;
      try {
        path = await picker(source);
      } on Exception catch (e) {
        _log.warning('receipt pick failed: $e');
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.entryScanFailed)));
        return null;
      }
    }
    if (path == null || !context.mounted) return null;
    final reading = readReceipt(ocr, prepare, path, exponent: draft.exponent, today: today);
    var retry = false;
    final decision = await showAppSheet<ScanDecision>(
      context,
      title: l.entryScanTitle,
      builder: (sheet) => FutureBuilder<ScanOutcome>(
        future: reading,
        // Reading → what was found (or the failure) folds in place; the sheet's height follows (S-451).
        builder: (context, snap) => AnimatedSize(
          duration: context.motion.expand,
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: MotionSwitcher(
            scale: false,
            child: switch ((snap.hasError, snap.data)) {
              (true, _) => _Failed(
                key: const ValueKey('motion-scan-failed'),
                onRetry: () {
                  retry = true;
                  Navigator.of(sheet).pop();
                },
              ),
              (_, null) => const ScanReading(key: ValueKey('motion-scan-reading')),
              (_, final ScanOutcome outcome) => ScanReviewPanel(
                key: const ValueKey('motion-scan-found'),
                outcome: outcome,
                draft: draft,
                onDone: (d) => Navigator.of(sheet).pop(d),
                onRetry: () {
                  retry = true;
                  Navigator.of(sheet).pop();
                },
              ),
            },
          ),
        ),
      ),
    );
    if (decision != null) {
      try {
        return (decision: decision, outcome: await reading);
      } on Exception {
        return null;
      }
    }
    if (!retry) {
      // Backed out of the review: nothing changes. A failed read is only logged.
      unawaited(reading.then<void>((_) {}, onError: (Object e) => _log.warning('scan: $e')));
      return null;
    }
  }
  return null;
}

class _ScanSource extends StatelessWidget {
  const _ScanSource();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionTile(
          key: const Key('scan-camera'),
          label: l.photoTake,
          leading: Icon(AppIcons.camera, size: 20, color: c.primary),
          onTap: () => Navigator.of(context).pop(PhotoSource.camera),
        ),
        const SizedBox(height: AppSpacing.s3),
        OptionTile(
          key: const Key('scan-gallery'),
          label: l.photoChoose,
          leading: Icon(AppIcons.images, size: 20, color: c.primary),
          onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          l.entryScanReceiptHint,
          textAlign: TextAlign.center,
          style: context.text.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      key: const Key('scan-failed'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmptyState(icon: AppIcons.imageBroken, title: l.entryScanFailed),
        const SizedBox(height: AppSpacing.s4),
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
