import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/domain/rules/receipt_text_parser.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/itemize_draft.dart';

/// Which found fields the person kept ticked in the review sheet (D-034 A3).
typedef ScanChoice = ({bool amount, bool date, bool description});

/// The description a scan suggests: the merchant, cut to the description limit.
String? scanDescription(ReceiptScan s) {
  final m = s.merchant?.trim();
  if (m == null || m.isEmpty) return null;
  return m.length > maxDescription ? m.substring(0, maxDescription).trim() : m;
}

/// The review sheet's starting ticks: a found field is ticked when the editor's field is still empty
/// (or already says the same), so a scan never overwrites what was typed without a tap.
ScanChoice defaultChoice(ExpenseDraft d, ReceiptScan s) {
  final total = s.total;
  final description = scanDescription(s);
  return (
    amount: total != null && (d.amountText.trim().isEmpty || d.total == total),
    date: s.date != null,
    description: description != null && d.description.trim().isEmpty,
  );
}

/// [d] with what the person kept from [s], plus the scanned [photo] as the receipt. With [itemize] the
/// split becomes Items with the found lines (each shared by the people in the split) and the tax,
/// service, tip and discount lines; round off goes into tax (+) or discount (−) so the lines still add
/// up. Never moves money on its own and never saves (S-373).
ExpenseDraft applyScan(
  ExpenseDraft d,
  ReceiptScan s,
  ScanChoice choice, {
  PreparedImage? photo,
  bool itemize = false,
}) {
  var next = d;
  final total = s.total;
  if (choice.amount && total != null) {
    next = next.copyWith(amountText: ScaledInput.format(total, d.exponent));
  }
  if (choice.date && s.date != null) next = next.copyWith(date: s.date);
  final description = scanDescription(s);
  if (choice.description && description != null) next = next.copyWith(description: description);
  if (photo != null) next = next.copyWith(receipt: next.receipt.pick(photo));
  if (itemize && next.hasGroup && s.items.isNotEmpty) {
    final round = s.roundOff;
    final items = ItemizeDraft.fromLines(
      s.items,
      next.split.chosen,
      next.exponent,
      extras: {
        ItemExtra.tax: s.tax + (round > 0 ? round : 0),
        ItemExtra.service: s.service,
        ItemExtra.tip: s.tip,
        ItemExtra.discount: s.discount + (round < 0 ? -round : 0),
      },
    );
    next = next.copyWith(split: next.split.withItems(items));
    // No total ticked: the lines decide the amount.
    if (!(choice.amount && total != null) && next.amountText.trim().isEmpty) {
      final t = items.total;
      if (t != null && t > 0) next = next.copyWith(amountText: ScaledInput.format(t, d.exponent));
    }
  }
  return next;
}
