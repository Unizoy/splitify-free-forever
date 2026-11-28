/// Turns a rebuilt import into the rows the outbox sends (X1, phase 18 T3; S-190).
///
/// Every row goes out with `source = 'import'`, so the server writes no activity per row; the last
/// expense carries `split_values.import_summary` and the server turns that into the one
/// `import_completed` activity (0021). Expenses keep the batch id in `split_values.import_batch_id`
/// (08 X1). A file without expenses has nothing to carry the summary, so its payments go out as
/// ordinary payments (each logged, rule 9).
library;

import 'package:splitify/core/utils/text_clip.dart';
import 'package:splitify/data/repositories/import_repository.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/import_splitwise/domain/import_csv.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_reconstruction.dart';

/// Longest expense description / notes and payment note (server checks, 0004).
const maxImportDescription = 120;
const maxImportNotes = 1000;
const maxImportPaymentNote = 200;

/// Everything an import writes, in the order it is written.
final class ImportRows {
  const ImportRows({required this.batchId, required this.payments, required this.expenses});

  final String batchId;
  final List<ImportWrite> payments;
  final List<ImportWrite> expenses;
}

/// `YYYY-MM-DD` of a UTC calendar date.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _clip(String s, int max) => s.length <= max ? s : clipText(s, max).trimRight();

/// Rows for [import]. [memberIds] maps every file name left in the import to a member id.
/// [fallbackDescription] names an expense whose description cell is empty. [suggestCategory] (auto-category,
/// D-028) picks a category from the description for rows the file left uncategorised (Splitwise `General`);
/// a category the file has is kept.
ImportRows buildImportRows({
  required SplitwiseImport import,
  required Map<String, String> memberIds,
  required String batchId,
  required ImportFormat format,
  required String fallbackDescription,
  required String Function() newId,
  String? Function(String description)? suggestCategory,
}) {
  Map<String, int> ids(Map<String, int> byName) => {
    for (final e in byName.entries) memberIds[e.key]!: e.value,
  };
  final hasExpenses = import.expenses.isNotEmpty;
  final payments = <ImportWrite>[
    for (final p in import.payments)
      (
        id: newId(),
        data: {
          'from_member': memberIds[p.from]!,
          'to_member': memberIds[p.to]!,
          'amount': p.amountMinor,
          'currency': p.currency,
          'date': isoDay(p.date),
          'method': 'other',
          'note': _paymentNote(p),
          'source': hasExpenses ? 'import' : 'app',
        },
      ),
  ];
  final expenses = <ImportWrite>[];
  for (var i = 0; i < import.expenses.length; i++) {
    final e = import.expenses[i];
    final shares = ids(e.shares);
    final description = e.description.trim().isEmpty ? fallbackDescription : e.description.trim();
    final notes = e.notes == null ? null : _clip(e.notes!, maxImportNotes);
    expenses.add((
      id: newId(),
      data: {
        'kind': 'expense',
        'description': _clip(description, maxImportDescription),
        'notes': notes,
        'category': e.categoryKey == ExpenseCategories.defaultKey
            ? suggestCategory?.call(description) ?? e.categoryKey
            : e.categoryKey,
        'date': isoDay(e.date),
        'currency': e.currency,
        'total': e.totalMinor,
        'payers': ids(e.paidBy),
        'shares': shares,
        'split_kind': 'exact',
        'split_values': {
          ...shares,
          importBatchKey: batchId,
          if (i == import.expenses.length - 1)
            importSummaryKey: {
              'source': format.name,
              'expenses': import.expenses.length,
              'payments': import.payments.length,
            },
        },
        'source': 'import',
      },
    ));
  }
  return ImportRows(batchId: batchId, payments: payments, expenses: expenses);
}

final _paidSentence = RegExp(r'^.+ paid .+$', caseSensitive: false);

/// A payment's note: the row's own note, else its description unless that only says who paid whom.
String? _paymentNote(ImportedPayment p) {
  final own = p.note?.trim() ?? '';
  if (own.isNotEmpty) return _clip(own, maxImportPaymentNote);
  final d = p.description.trim();
  if (d.isEmpty || _paidSentence.hasMatch(d) || d.toLowerCase() == 'payment') return null;
  return _clip(d, maxImportPaymentNote);
}
