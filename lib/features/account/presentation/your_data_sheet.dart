import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:splitify/data/data_providers.dart' show clockProvider;
import 'package:splitify/features/expenses/presentation/expense_copy.dart' show ExpenseCopy;
import 'package:splitify/features/export/application/backup_export.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

final _log = Logger('backup');

/// "Your data" (D-034 WP-D, P-4) as a sheet from the Account list (D-033: a sheet, not a page): what the
/// file holds, the counts, Download my data (the system "Save to" dialog) and Share instead.
Future<void> showYourDataSheet(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  return showAppSheet<void>(
    context,
    title: AppLocalizations.of(context).backupTitle,
    builder: (sheet) =>
        UncontrolledProviderScope(container: container, child: const YourDataPanel()),
  );
}

enum _Busy { save, share }

/// The sheet's content. Builds the `.zip` on the phone (works offline) for each tap, then hands it to the
/// save dialog or the share sheet; says when it is saved, when there is nothing yet and when it failed.
class YourDataPanel extends ConsumerStatefulWidget {
  const YourDataPanel({super.key});

  @override
  ConsumerState<YourDataPanel> createState() => _YourDataPanelState();
}

class _YourDataPanelState extends ConsumerState<YourDataPanel> {
  _Busy? _busy;
  String? _message;
  bool _failed = false;

  Future<void> _run(_Busy what) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = what;
      _message = null;
      _failed = false;
    });
    String? message;
    var failed = false;
    try {
      final file = await ref.read(backupExporterProvider).build(categoryLabel: l.category);
      if (file == null) {
        message = l.backupEmpty;
      } else if (what == _Busy.save) {
        final saved = await ref.read(backupSaverProvider)(
          file.bytes,
          file.fileName,
          l.backupDownload,
        );
        if (saved != null) message = l.backupSaved(saved);
      } else {
        await ref.read(backupSharerProvider)(file.bytes, file.fileName, l.backupSubject);
      }
    } on Exception catch (e) {
      _log.warning('backup failed (${e.runtimeType})');
      message = l.backupFailed;
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _busy = null;
      _message = message;
      _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final counts = ref.watch(backupCountsProvider).value;
    final busy = _busy != null;
    return Column(
      key: const Key('your-data'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.backupBody, style: context.text.body.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.s5),
        Container(
          key: const Key('your-data-card'),
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TintedIcon(icon: AppIcons.archive, color: c.primary, size: 44),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backupFileName(ref.watch(clockProvider).now()).replaceAll('-', '\u2011'),
                      key: const Key('your-data-file'),
                      style: context.text.body.w(600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      counts == null
                          ? l.loading
                          : [
                              l.backupGroups(counts.groups),
                              l.backupExpenses(counts.expenses),
                              l.backupPayments(counts.payments),
                            ].join('\u00A0· '),
                      key: const Key('your-data-counts'),
                      style: context.text.bodySmall.copyWith(color: c.textSecondary),
                    ),
                    if ((counts?.pending ?? 0) > 0) ...[
                      const SizedBox(height: AppSpacing.s2),
                      const SyncMarker(),
                      const SizedBox(height: 2),
                      Text(
                        l.backupPending(counts!.pending),
                        key: const Key('your-data-pending'),
                        style: context.text.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(l.backupFormatNote, style: context.text.caption.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('your-data-download'),
          label: l.backupDownload,
          icon: AppIcons.fileCsv,
          loading: _busy == _Busy.save,
          onPressed: busy ? null : () => _run(_Busy.save),
        ),
        const SizedBox(height: AppSpacing.s2),
        PillButton(
          key: const Key('your-data-share'),
          label: l.backupShare,
          icon: AppIcons.share,
          variant: PillVariant.ghost,
          loading: _busy == _Busy.share,
          onPressed: busy ? null : () => _run(_Busy.share),
        ),
        if (busy || _message != null) ...[
          const SizedBox(height: AppSpacing.s3),
          Semantics(
            liveRegion: true,
            child: Row(
              key: Key(busy ? 'your-data-working' : 'your-data-message'),
              children: [
                Icon(
                  busy
                      ? AppIcons.clock
                      : _failed
                      ? AppIcons.warning
                      : AppIcons.checkCircle,
                  size: 18,
                  color: busy
                      ? c.textSecondary
                      : _failed
                      ? c.oweAccent
                      : c.owedAccent,
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    busy ? l.backupWorking : _message!,
                    style: context.text.bodySmall.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s2),
      ],
    );
  }
}
