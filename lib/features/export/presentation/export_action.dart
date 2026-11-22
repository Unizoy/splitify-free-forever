import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/export/application/group_export.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show showGroupMessage;
import 'package:splitify/l10n/app_localizations.dart';

final _log = Logger('export');

/// "Export CSV" (#22): builds the group's CSV on the phone and opens the share sheet; says so when
/// there is nothing to export or the export failed.
Future<void> exportGroupCsv(BuildContext context, WidgetRef ref, String groupId) async {
  final l = AppLocalizations.of(context);
  ExportOutcome outcome;
  try {
    outcome = await ref
        .read(groupExporterProvider)
        .export(groupId, categoryLabel: l.category, subject: l.exportSubject);
  } on Exception catch (e) {
    _log.warning('group $groupId: export failed (${e.runtimeType})');
    if (context.mounted) showGroupMessage(context, l.exportFailed);
    return;
  }
  if (!context.mounted) return;
  switch (outcome) {
    case ExportOutcome.shared:
      break;
    case ExportOutcome.empty:
      showGroupMessage(context, l.exportEmpty);
    case ExportOutcome.notFound:
      showGroupMessage(context, l.groupNotFound);
  }
}
