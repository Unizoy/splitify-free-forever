import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/export_reads.dart';
import 'package:splitify/features/balances/application/balance_views.dart' show decodeMinorMap;
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/export/domain/csv_export.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/insights/domain/aggregations.dart' show expenseKindIou;

/// `Split type` cell of a loan (IOU) row.
const String csvLoanSplitType = 'loan';

/// The CSV text of [x] (#22): every member as a column (removed ones too), every expense and payment
/// with deleted ones flagged. [categoryLabel] turns a category key into the text shown; [myUserId]
/// names the rows this phone added that the server has not stamped yet.
String csvOfExport(
  ExportLedger x, {
  required String Function(String key) categoryLabel,
  String? myUserId,
}) {
  final byUser = {
    for (final m in x.members)
      if (m.userId != null) m.userId!: m.displayName,
  };
  String? addedBy(String? createdBy, int seq) {
    final user = createdBy ?? (seq == 0 ? myUserId : null);
    return user == null ? null : byUser[user];
  }

  String day(String date) => date.length > 10 ? date.substring(0, 10) : date;

  return buildGroupCsv(
    members: [for (final m in x.members) CsvMember(m.id, m.displayName)],
    expenses: [
      for (final e in x.expenses)
        CsvExpense(
          date: day(e.date),
          description: e.description,
          category: categoryLabel(e.category),
          currency: e.currency.trim(),
          total: e.total,
          splitType: e.kind == expenseKindIou ? csvLoanSplitType : e.splitKind,
          paid: decodeMinorMap(e.payers),
          owed: decodeMinorMap(e.shares),
          notes: e.notes,
          addedBy: addedBy(e.createdBy, e.seq),
          deleted: e.deletedAt != null,
        ),
    ],
    payments: [
      for (final p in x.payments)
        CsvPayment(
          date: day(p.date),
          fromId: p.fromMember,
          toId: p.toMember,
          currency: p.currency.trim(),
          amount: p.amount,
          method: p.method,
          note: p.note,
          addedBy: addedBy(p.createdBy, p.seq),
          deleted: p.deletedAt != null,
        ),
    ],
  );
}

/// `splitify-goa-trip-2026-11-22.csv`: the group name in lower-case ASCII words (`group` when
/// nothing is left) and the local date.
String exportFileName(String groupName, DateTime today) {
  var slug = groupName
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  if (slug.length > 40) slug = slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
  if (slug.isEmpty) slug = 'group';
  final d = today.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'splitify-$slug-${d.year}-${two(d.month)}-${two(d.day)}.csv';
}

/// Hands a CSV file to the system share sheet (save to Files/Drive, mail, chat); tests override.
typedef CsvSharer = Future<void> Function(Uint8List bytes, String fileName, String subject);

/// The real sharer: the file goes to share_plus as `text/csv` (a temporary file on Android).
Future<void> shareCsvFile(Uint8List bytes, String fileName, String subject) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
      fileNameOverrides: [fileName],
      subject: subject,
    ),
  );
}

final csvSharerProvider = Provider<CsvSharer>((ref) => shareCsvFile);

/// What an export did.
enum ExportOutcome {
  /// The share sheet opened with the file.
  shared,

  /// The group has no expenses or payments yet; nothing was shared.
  empty,

  /// The group is not on this phone.
  notFound,
}

/// Builds a group's CSV from the phone's database (works offline) and shares it.
class GroupExporter {
  GroupExporter(this._ref);

  final Ref _ref;

  Future<ExportOutcome> export(
    String groupId, {
    required String Function(String key) categoryLabel,
    required String Function(String groupName) subject,
  }) async {
    final x = await _ref.read(ledgerRepositoryProvider).loadExport(groupId);
    if (x == null) return ExportOutcome.notFound;
    if (x.expenses.isEmpty && x.payments.isEmpty) return ExportOutcome.empty;
    final text = csvOfExport(
      x,
      categoryLabel: categoryLabel,
      myUserId: _ref.read(currentUserIdProvider),
    );
    // UTF-8; the text already starts with the BOM, so spreadsheet apps read it as UTF-8.
    final bytes = utf8.encode(text);
    final name = exportFileName(x.group.name, _ref.read(clockProvider).now());
    await _ref.read(csvSharerProvider)(bytes, name, subject(x.group.name));
    return ExportOutcome.shared;
  }
}

final groupExporterProvider = Provider<GroupExporter>(GroupExporter.new);
