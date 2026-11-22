import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Short "Coming soon" snackbar for actions a later phase builds.
void showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).comingSoon),
        duration: const Duration(seconds: 2),
      ),
    );
}

/// A short message: a snackbar on a page, or the same-looking toast above the sheet when [context] is inside
/// a bottom sheet or dialog — a page's snackbar would sit hidden under the sheet (final QA, S-256).
void showAppMessage(BuildContext context, String message) {
  if (ModalRoute.of(context) is PopupRoute) {
    _SheetToast.show(context, message);
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Snackbar-styled toast in the root overlay (above every route), gone after 3 s.
abstract final class _SheetToast {
  static OverlayEntry? _current;

  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _Toast(
        message: message,
        onDone: () {
          if (identical(_current, entry)) _remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static void _remove() {
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

/// The toast; its own timer ends with it (no timer outlives the screen).
class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), widget.onDone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom;
    return Positioned(
      left: AppSpacing.screen,
      right: AppSpacing.screen,
      bottom: bottom + AppSpacing.s4,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          child: Material(
            key: const Key('sheet-toast'),
            color: c.ink,
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.all16),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s3 + AppSpacing.s1,
              ),
              child: Text(widget.message, style: context.text.bodySmall.copyWith(color: c.onInk)),
            ),
          ),
        ),
      ),
    );
  }
}
