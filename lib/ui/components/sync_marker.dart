import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Not synced yet" marker (PLAN.md rule 3): cloud-off icon + caption in the
/// `unsynced` colour. Long-press shows why; screen readers hear the same.
class SyncMarker extends StatelessWidget {
  const SyncMarker({this.compact = false, super.key});

  /// Icon only (dense rows); the text stays available to screen readers.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = context.colors.unsynced;
    return Tooltip(
      message: l.notSyncedYetHint,
      child: Semantics(
        label: '${l.notSyncedYet}. ${l.notSyncedYetHint}',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.unsynced, size: 14, color: color),
            if (!compact) ...[
              const SizedBox(width: AppSpacing.s1),
              Flexible(
                child: Text(l.notSyncedYet, style: context.text.caption.copyWith(color: color)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
