import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:share_plus/share_plus.dart';
import 'package:splitify/core/config/app_info.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/repositories/export_reads.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/attachments/application/attachment_providers.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/export/application/group_export.dart';
import 'package:splitify/features/export/domain/zip_writer.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

final _log = Logger('backup');

/// `format` of the backup JSON (docs/backup-format.md).
const backupFormat = 'splitify-backup';

/// `version` of the backup JSON; bump on a breaking change of its shape.
const backupVersion = 1;

/// Name of the JSON file inside the `.zip`.
const backupJsonName = 'splitify-backup.json';

/// The JSON object of "Download my data" (D-034 WP-D, P-4): every group on this phone with its members,
/// expenses, payments, comments and repeating expenses, deleted rows included (`deleted_at` set).
/// Amounts are integer minor units next to their currency code, never decimals (rule 1); exchange
/// rates stay the decimal strings they were saved as; rows not on the server yet carry `"pending": true`.
Map<String, Object?> backupJson({
  required List<BackupGroupRows> groups,
  required DateTime exportedAt,
  String? userId,
  LocalProfile? me,
  BackupFiles files = const BackupFiles(),
}) => {
  'format': backupFormat,
  'version': backupVersion,
  'exported_at': exportedAt.toUtc().toIso8601String(),
  'app_version': appVersion,
  'me': {
    'user_id': userId,
    'name': me?.displayName,
    'upi_id': me?.upiId,
    'default_currency': me?.defaultCurrency.trim(),
  },
  'groups': [for (final g in groups) _group(g, userId, files)],
};

Map<String, Object?> _group(BackupGroupRows x, String? userId, BackupFiles files) {
  final g = x.group;
  return {
    'group': {
      'id': g.id,
      'name': g.name,
      'type': g.type,
      'main_currency': g.mainCurrency.trim(),
      'simplify_debts': g.simplifyDebts,
      'default_split': _json(g.defaultSplit),
      'archived_at': g.archivedAt,
      // D-034 WP-C (0026): trip dates, settle-up reminders and the group notes.
      'trip_starts_on': g.tripStartsOn,
      'trip_ends_on': g.tripEndsOn,
      'settle_reminder': g.settleReminder ?? 'off',
      'whiteboard': g.whiteboard,
      'created_at': g.createdAt,
      'created_by': g.createdBy,
      'updated_at': g.updatedAt,
      'deleted_at': g.deletedAt,
      'pending': _pending(g.syncState),
    },
    'me_member_id': x.members
        .where((m) => userId != null && m.userId == userId && m.deletedAt == null)
        .map((m) => m.id)
        .firstOrNull,
    'members': [
      for (final m in x.members)
        {
          'id': m.id,
          'name': m.displayName,
          'user_id': m.userId,
          'position': m.position,
          'role': m.role,
          'status': m.status,
          'claimed_at': m.claimedAt,
          'created_at': m.createdAt,
          'deleted_at': m.deletedAt,
          'pending': _pending(m.syncState),
        },
    ],
    'expenses': [
      for (final e in x.expenses)
        {
          'id': e.id,
          'kind': e.kind,
          'description': e.description,
          'notes': e.notes,
          'category': e.category,
          'date': e.date,
          'currency': e.currency.trim(),
          'total': e.total,
          'paid_by': _minor(e.payers),
          'owed': _minor(e.shares),
          'split_kind': e.splitKind,
          'split_values': _json(e.splitValues),
          'fx': e.fxCurrency == null
              ? null
              : {
                  'currency': e.fxCurrency!.trim(),
                  'rate': e.fxRate,
                  'rate_date': e.fxRateDate,
                  'source': e.fxSource,
                  'total': e.fxTotal,
                  'paid_by': e.fxPayers == null ? null : _minor(e.fxPayers),
                  'owed': e.fxShares == null ? null : _minor(e.fxShares),
                },
          'receipt_path': e.receiptPath,
          // W2-Y: the photo itself inside the .zip, when it could be included.
          'receipt_file': e.receiptPath == null ? null : files.receiptEntry(e.id),
          'recurring_id': e.recurringId,
          'source': e.source,
          'created_at': e.createdAt,
          'created_by': e.createdBy,
          'updated_at': e.updatedAt,
          'updated_by': e.updatedBy,
          'deleted_at': e.deletedAt,
          'deleted_by': e.deletedBy,
          'pending': _pending(e.syncState),
        },
    ],
    'payments': [
      for (final p in x.payments)
        {
          'id': p.id,
          'from_member': p.fromMember,
          'to_member': p.toMember,
          'amount': p.amount,
          'currency': p.currency.trim(),
          'date': p.date,
          'method': p.method,
          'note': p.note,
          'fx': p.fxCurrency == null
              ? null
              : {
                  'currency': p.fxCurrency!.trim(),
                  'rate': p.fxRate,
                  'rate_date': p.fxRateDate,
                  'source': p.fxSource,
                  'amount': p.fxAmount,
                },
          'created_at': p.createdAt,
          'created_by': p.createdBy,
          'updated_at': p.updatedAt,
          'deleted_at': p.deletedAt,
          'deleted_by': p.deletedBy,
          'pending': _pending(p.syncState),
        },
    ],
    'comments': [
      for (final c in x.comments)
        {
          'id': c.id,
          'target_type': c.targetType,
          'target_id': c.targetId,
          'body': c.body,
          'created_at': c.createdAt,
          'created_by': c.createdBy,
          'deleted_at': c.deletedAt,
          'pending': _pending(c.syncState),
        },
    ],
    // W2-Y (0029): photos and PDFs of the expenses, removed ones too; `file` = their place in the .zip.
    'attachments': [
      for (final a in files.attachments)
        if (a.groupId == x.group.id)
          {
            'id': a.id,
            'expense_id': a.expenseId,
            'kind': a.kind,
            'name': a.name,
            'size_bytes': a.sizeBytes,
            'width': a.width,
            'height': a.height,
            'position': a.position,
            'file': files.attachmentEntry(a),
            'created_at': a.createdAt,
            'created_by': a.createdBy,
            'deleted_at': a.deletedAt,
            'pending': _pending(a.syncState),
          },
    ],
    'recurring': [
      for (final r in x.recurring)
        {
          'id': r.id,
          'expense_id': r.expenseId,
          'interval': r.interval,
          'anchor_date': r.anchorDate,
          'next_date': r.nextDate,
          'ends_on': r.endsOn,
          'active': r.active,
          'template': _json(r.template),
          'created_at': r.createdAt,
          'deleted_at': r.deletedAt,
          'pending': _pending(r.syncState),
        },
    ],
  };
}

bool _pending(String syncState) => syncState != SyncState.synced;

/// A stored member → minor-units map (`{"m1": 1200}`); anything else is left out.
Map<String, int> _minor(String? json) {
  final v = _json(json);
  if (v is! Map) return const {};
  return {
    for (final e in v.entries)
      if (e.value is int) e.key.toString(): e.value as int,
  };
}

/// A stored JSON text as JSON; text that is not JSON stays text.
Object? _json(String? text) {
  if (text == null) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}

/// `csv/goa-trip.csv` for a group: the name in lower-case ASCII words (`group` when nothing is left),
/// `-2`, `-3`\u2026 when another group already has it ([used] remembers the names).
String backupCsvName(String groupName, Set<String> used) {
  var slug = groupName
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  if (slug.length > 40) slug = slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
  if (slug.isEmpty) slug = 'group';
  var name = 'csv/$slug.csv';
  for (var i = 2; !used.add(name); i++) {
    name = 'csv/$slug-$i.csv';
  }
  return name;
}

/// `splitify-backup-2026-11-27.zip` (local date).
String backupFileName(DateTime now) {
  final d = now.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'splitify-backup-${d.year}-${two(d.month)}-${two(d.day)}.zip';
}

/// Text of `README.txt` inside the `.zip`.
const backupReadme =
    'Splitify data export\r\n'
    '\r\n'
    '$backupJsonName  Everything on the phone that made this file: groups, members, expenses,\r\n'
    '                     payments, comments and repeating expenses (deleted ones too).\r\n'
    '                     Amounts are whole minor units (paise, cents) next to their currency code.\r\n'
    'csv/                 One spreadsheet per group, like "Export CSV" in the app.\r\n'
    'attachments/         Photos and PDFs of the expenses, one folder per expense.\r\n'
    'receipts/            Receipt photos saved by older versions of the app.\r\n'
    '\r\n'
    'The format: https://github.com/Unizoy/splitify-free-forever/blob/main/docs/backup-format.md\r\n';

/// The files that go into the backup besides the JSON and CSVs (W2-Y): every attachment row, and the bytes
/// of the files this phone has or could fetch, up to [BackupFiles.maxBytes] together.
final class BackupFiles {
  const BackupFiles({
    this.attachments = const [],
    this.attachmentBytes = const {},
    this.receiptBytes = const {},
  });

  /// All of them together stay below this (the .zip is built in memory).
  static const maxBytes = 64 * 1024 * 1024;

  final List<LocalAttachment> attachments;

  /// Attachment id → file bytes.
  final Map<String, Uint8List> attachmentBytes;

  /// Expense id → its old single receipt photo.
  final Map<String, Uint8List> receiptBytes;

  /// `attachments/<expense>/<id>.jpg|pdf` when the file is included.
  String? attachmentEntry(LocalAttachment a) => attachmentBytes.containsKey(a.id)
      ? 'attachments/${a.expenseId}/${a.id}.${a.kind == AttachmentKind.pdf.wire ? 'pdf' : 'jpg'}'
      : null;

  /// `receipts/<expense>.jpg` when the photo is included.
  String? receiptEntry(String expenseId) =>
      receiptBytes.containsKey(expenseId) ? 'receipts/$expenseId.jpg' : null;

  List<ZipEntry> entries() => [
    for (final a in attachments)
      if (attachmentEntry(a) case final path?) ZipEntry(path, attachmentBytes[a.id]!),
    for (final e in receiptBytes.entries) ZipEntry(receiptEntry(e.key)!, e.value),
  ];
}

/// A finished backup.
final class BackupFile {
  const BackupFile({required this.bytes, required this.fileName, required this.json});

  final Uint8List bytes;
  final String fileName;

  /// The JSON object inside (for tests and the counts).
  final Map<String, Object?> json;
}

/// The `.zip` of [groups]: `splitify-backup.json`, `README.txt` and one CSV per group that is not deleted
/// and has expenses or payments. [categoryLabel] names categories in the CSVs.
BackupFile buildBackup({
  required List<BackupGroupRows> groups,
  required DateTime now,
  required String Function(String key) categoryLabel,
  String? userId,
  LocalProfile? me,
  BackupFiles files = const BackupFiles(),
}) {
  final json = backupJson(groups: groups, exportedAt: now, userId: userId, me: me, files: files);
  final used = <String>{};
  final entries = <ZipEntry>[
    ZipEntry.text(backupJsonName, const JsonEncoder.withIndent('  ').convert(json)),
    ZipEntry.text('README.txt', backupReadme),
    for (final g in groups)
      if (g.group.deletedAt == null && (g.expenses.isNotEmpty || g.payments.isNotEmpty))
        ZipEntry.text(
          backupCsvName(g.group.name, used),
          csvOfExport(
            ExportLedger(
              group: g.group,
              members: g.members,
              expenses: g.expenses,
              payments: g.payments,
            ),
            categoryLabel: categoryLabel,
            myUserId: userId,
          ),
        ),
    ...files.entries(),
  ];
  return BackupFile(
    bytes: buildZip(entries, modified: now.toLocal()),
    fileName: backupFileName(now),
    json: json,
  );
}

/// Saves the backup where the person picks (the system "Save to" dialog); returns the saved file's
/// name, or null when they cancelled. Tests override.
typedef BackupSaver = Future<String?> Function(Uint8List bytes, String fileName, String title);

/// Hands the backup to the share sheet (Drive, mail, chat). Tests override.
typedef BackupSharer = Future<void> Function(Uint8List bytes, String fileName, String subject);

Future<String?> saveBackupFile(Uint8List bytes, String fileName, String title) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: 'application/zip',
    dialogTitle: title,
  );
  if (uri == null) return null;
  final last = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
  final decoded = last == null ? null : Uri.decodeComponent(last);
  // SAF names look like "primary:Download/splitify-backup-\u2026.zip".
  final name = decoded?.split(RegExp('[/:]')).last;
  return (name == null || name.isEmpty) ? fileName : name;
}

Future<void> shareBackupFile(Uint8List bytes, String fileName, String subject) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/zip', name: fileName)],
      fileNameOverrides: [fileName],
      subject: subject,
    ),
  );
}

final backupSaverProvider = Provider<BackupSaver>((ref) => saveBackupFile);
final backupSharerProvider = Provider<BackupSharer>((ref) => shareBackupFile);

/// Counts on the Your data sheet, live.
final backupCountsProvider = StreamProvider.autoDispose<BackupCounts>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchBackupCounts(),
);

/// Builds the backup from the phone's database (works offline).
class BackupExporter {
  BackupExporter(this._ref);

  final Ref _ref;

  /// The backup of everything on this phone; null when there is no group at all.
  Future<BackupFile?> build({required String Function(String key) categoryLabel}) async {
    final uid = _ref.read(currentUserIdProvider);
    final rows = await _ref.read(ledgerRepositoryProvider).loadBackup(uid);
    if (rows.groups.isEmpty) return null;
    return buildBackup(
      groups: rows.groups,
      now: _ref.read(clockProvider).now(),
      categoryLabel: categoryLabel,
      userId: uid,
      me: rows.me,
      files: await _files(rows.groups),
    );
  }

  /// Attachments and old receipt photos: this phone's copies, else downloaded once (online); a file that
  /// can't be had (offline, refused) or doesn't fit [BackupFiles.maxBytes] is listed without its bytes.
  Future<BackupFiles> _files(List<BackupGroupRows> groups) async {
    final attachments = await _ref.read(attachmentsRepositoryProvider).forGroups([
      for (final g in groups) g.group.id,
    ]);
    final media = _ref.read(mediaRepositoryProvider);
    var budget = BackupFiles.maxBytes;
    Future<Uint8List?> fetch(String bucket, String path) async {
      try {
        final bytes = await (await media.file(bucket, path)).readAsBytes();
        if (bytes.length > budget) return null;
        budget -= bytes.length;
        return bytes;
      } on Exception catch (e) {
        // Offline, refused, gone from the phone: listed without its bytes.
        _log.info(
          'backup: ${bucket == AttachmentPaths.bucket ? 'attachment' : 'receipt'} left out (${e.runtimeType})',
        );
        return null;
      }
    }

    final attachmentBytes = <String, Uint8List>{};
    for (final a in attachments) {
      final bytes = await fetch(AttachmentPaths.bucket, a.path);
      if (bytes != null) attachmentBytes[a.id] = bytes;
    }
    final receiptBytes = <String, Uint8List>{};
    for (final g in groups) {
      for (final e in g.expenses) {
        final path = e.receiptPath;
        if (path == null) continue;
        final bytes = await fetch(MediaBuckets.receipts, path);
        if (bytes != null) receiptBytes[e.id] = bytes;
      }
    }
    return BackupFiles(
      attachments: attachments,
      attachmentBytes: attachmentBytes,
      receiptBytes: receiptBytes,
    );
  }
}

final backupExporterProvider = Provider<BackupExporter>(BackupExporter.new);
