import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// How long the settled celebration stays before it closes itself.
const celebrationHold = Duration(milliseconds: 2400);

/// T6 (§6 Celebration): "all *settled*" over a scrim when a payment brings what one person owes another
/// to zero. Closes itself after [celebrationHold] or on a tap.
Future<void> showSettledCelebration(BuildContext context, {required String name}) {
  final l = AppLocalizations.of(context);
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: l.close,
    barrierColor: context.colors.scrim,
    transitionDuration: context.motion.base,
    pageBuilder: (dialog, _, _) => _SettledCelebration(name: name),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _SettledCelebration extends StatefulWidget {
  const _SettledCelebration({required this.name});

  final String name;

  @override
  State<_SettledCelebration> createState() => _SettledCelebrationState();
}

class _SettledCelebrationState extends State<_SettledCelebration> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(celebrationHold, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    _timer?.cancel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GestureDetector(
      key: const Key('settled-celebration'),
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Material(
                type: MaterialType.transparency,
                child: Celebration(
                  lead: l.celebrationLead,
                  highlight: l.celebrationHighlight,
                  message: l.celebrationSettledWith(widget.name),
                  seed: widget.name,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
