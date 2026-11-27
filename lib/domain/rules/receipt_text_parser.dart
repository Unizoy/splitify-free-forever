/// Reads what a receipt says from its recognised text (D-034 A3, P-1): the total, the date, the merchant,
/// tax / service / tip / discount lines and item lines. Pure Dart: the OCR runs on the phone
/// (`lib/features/receipt_scan`), this only reads its rows. Amounts are integer minor units (rule 1),
/// read digit by digit — never through a double.
///
/// Built for Indian receipts: `₹`, `Rs.`, `INR`, `/-`, Indian digit grouping (`1,23,456.00`), GST lines
/// (CGST, SGST, IGST), service charge, round off, "Net Amount" / "Grand Total" / "Amount Payable".
library;

/// One recognised line of text and where it sits in the picture (whole pixels, any origin).
final class OcrLine {
  const OcrLine(this.text, {this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});

  final String text;
  final int left;
  final int top;
  final int right;
  final int bottom;

  int get height => bottom - top;

  /// Twice the vertical centre (whole numbers only).
  int get center2 => top + bottom;
}

/// Receipt rows from OCR lines: lines at the same height (a name on the left, its price on the right)
/// join left to right, rows top to bottom. Lines without a box keep their order.
List<String> receiptRows(List<OcrLine> lines) {
  final boxed = [
    for (final l in lines)
      if (l.text.trim().isNotEmpty) l,
  ];
  if (boxed.every((l) => l.height <= 0)) return [for (final l in boxed) l.text.trim()];
  final heights = [for (final l in boxed) l.height]..sort();
  final typical = heights[heights.length ~/ 2];
  final sorted = [...boxed]..sort((a, b) => a.center2.compareTo(b.center2));
  final rows = <List<OcrLine>>[];
  var sum = 0;
  for (final line in sorted) {
    final h = line.height < typical ? line.height : typical;
    final row = rows.isEmpty ? null : rows.last;
    // Same row when the centre is within 0.55 of a line height of the row's mean centre.
    if (row != null && 10 * (line.center2 * row.length - sum).abs() <= 11 * h * row.length) {
      row.add(line);
      sum += line.center2;
    } else {
      rows.add([line]);
      sum = line.center2;
    }
  }
  return [
    for (final row in rows)
      ([...row]..sort((a, b) => a.left.compareTo(b.left))).map((l) => l.text.trim()).join('  '),
  ];
}

/// What was found on a receipt. Every field may be missing; amounts in minor units.
final class ReceiptScan {
  const ReceiptScan({
    this.total,
    this.date,
    this.merchant,
    this.tax = 0,
    this.service = 0,
    this.tip = 0,
    this.discount = 0,
    this.roundOff = 0,
    this.items = const [],
  });

  /// What was paid (the "Grand Total" / "Net Amount" line, else the biggest amount near the bottom).
  final int? total;
  final DateTime? date;

  /// The shop's name (first text line), or the payee of a UPI screenshot.
  final String? merchant;

  /// CGST + SGST + IGST + GST + VAT + cess (or the "Total tax" line).
  final int tax;
  final int service;
  final int tip;

  /// Discounts as a positive amount.
  final int discount;

  /// Round off, signed (+0.04 or −0.04).
  final int roundOff;

  /// Item lines (name + price), top to bottom.
  final List<({String name, int amount})> items;

  /// Nothing useful was read.
  bool get isEmpty => total == null && date == null && merchant == null && items.isEmpty;

  /// The lines plus the extras (round off folded into tax / discount) — what an Items split of these
  /// lines comes to.
  int get itemsTotal =>
      items.fold(0, (a, i) => a + i.amount) + tax + service + tip - discount + roundOff;

  @override
  String toString() =>
      'ReceiptScan(total: $total, date: $date, merchant: $merchant, tax: $tax, service: $service, '
      'tip: $tip, discount: $discount, roundOff: $roundOff, items: $items)';
}

/// Reads [rows] (top to bottom) for a currency with [exponent] decimals. [today] (local calendar day)
/// rejects dates in the future.
ReceiptScan parseReceipt(List<String> rows, {int exponent = 2, DateTime? today}) {
  final clean = [
    for (final r in rows)
      if (r.trim().isNotEmpty) r.replaceAll(RegExp(r'\s+'), ' ').trim(),
  ];
  final parsed = [for (final (i, r) in clean.indexed) _Row.parse(i, r, exponent)];
  final total = _total(parsed);
  final date = _date(clean, today);
  final merchant = _merchant(clean);

  var tax = 0;
  var service = 0;
  var tip = 0;
  var discount = 0;
  var roundOff = 0;
  int? taxTotal;
  final seenTax = <(String, int)>{};
  final footerStart = _footerStart(parsed);
  final items = <({String name, int amount})>[];
  for (final row in parsed) {
    final amount = row.amount;
    final kind = row.kind;
    if (amount == null) continue;
    switch (kind) {
      case _Kind.taxTotal:
        taxTotal = (taxTotal ?? 0) + amount.value.abs();
      case _Kind.tax:
        // GST invoices often repeat the tax in a summary table: count each (name, amount) once.
        if (seenTax.add((row.taxName, amount.value.abs()))) tax += amount.value.abs();
      case _Kind.service:
        service += amount.value.abs();
      case _Kind.tip:
        tip += amount.value.abs();
      case _Kind.discount:
        discount += amount.value.abs();
      case _Kind.roundOff:
        roundOff += amount.value;
      case _Kind.item:
        if (row.index < footerStart && amount.value > 0) {
          items.add((name: row.itemName, amount: amount.value));
        }
      case _Kind.total || _Kind.subtotal || _Kind.payment || _Kind.plain || _Kind.ignored:
        break;
    }
  }
  if (taxTotal != null) tax = taxTotal;
  return ReceiptScan(
    total: total,
    date: date,
    merchant: merchant,
    tax: tax,
    service: service,
    tip: tip,
    discount: discount,
    roundOff: roundOff,
    items: items,
  );
}

// ------------------------------------------------------------------------------------------- rows

enum _Kind {
  total,
  subtotal,
  payment,
  tax,
  taxTotal,
  service,
  tip,
  discount,
  roundOff,
  item,

  /// No keyword and no item name (a lone "₹250").
  plain,

  /// Not money: bill numbers, phones, dates, quantities, "in words".
  ignored,
}

/// An amount on a row: minor units, and whether a currency sign or `/-` marked it.
typedef _Amount = ({int value, bool marked, bool decimals});

final class _Row {
  _Row(this.index, this.text, this.amounts, this.kind, this.tier, this.taxName, this.itemName);

  factory _Row.parse(int index, String text, int exponent) {
    final lower = text.toLowerCase();
    final amounts = _amounts(text, exponent);
    final (kind, tier, taxName) = _classify(lower);
    final name = kind == _Kind.item ? _itemName(text) : '';
    final resolved = kind != _Kind.item
        ? kind
        : name.isEmpty
        ? _Kind.plain
        : _Kind.item;
    return _Row(index, text, amounts, resolved, tier, taxName, name);
  }

  final int index;
  final String text;
  final List<_Amount> amounts;
  final _Kind kind;

  /// How strongly the row's words say "this is the total" (0 = not a total line).
  final int tier;
  final String taxName;
  final String itemName;

  /// The row's amount: the one with a currency sign, else the rightmost.
  _Amount? get amount {
    if (amounts.isEmpty) return null;
    for (final a in amounts.reversed) {
      if (a.marked) return a;
    }
    return amounts.last;
  }
}

/// (kind, total tier, tax name) of a row from its words.
(_Kind, int, String) _classify(String lower) {
  bool has(String pattern) => RegExp(pattern).hasMatch(lower);
  if (has(r'in words|rupees .* only|amount chargeable')) return (_Kind.ignored, 0, '');
  if (has(r'sub[\s\-]?total|\bsub\s*tot|gross\s*(amount|amt|total|value)')) {
    return (_Kind.subtotal, 0, '');
  }
  if (has(r'round(ed|ing)?[\s\-]*off|\brounding\b|\bround\b')) return (_Kind.roundOff, 0, '');
  if (has(r'total\s*(tax|gst|vat)|(tax|gst)\s*total|total\s*taxes')) {
    return (_Kind.taxTotal, 0, '');
  }
  if (has(
    r'total\s*(qty|quantity|items?|no\.? of|savings?|saved|discount|mrp|weight|pcs)|'
    r'no\.?\s*of\s*items|\bqty\b.*\btotal\b|you\s*saved|saving',
  )) {
    return (_Kind.ignored, 0, '');
  }
  if (has(r'\b(discount|disc\.?|coupon|promo|offer)\b')) return (_Kind.discount, 0, '');
  if (has(r'service\s*(charge|chg|chrg)|\bs\.?\s?c\.?\s*@|\bsvc\b')) return (_Kind.service, 0, '');
  if (has(r'\b(tip|tips|gratuity)\b')) return (_Kind.tip, 0, '');
  final tax = RegExp(
    r'\b(c\.?gst|s\.?gst|igst|utgst|gst|vat|cess|service\s*tax|luxury\s*tax|tax(es)?)\b',
  ).firstMatch(lower);
  if (tax != null && !has(r'gstin|gst\s*(no|number|reg)|taxable|incl|inclusive|tax\s*invoice')) {
    return (_Kind.tax, 0, tax.group(1)!.replaceAll('.', ''));
  }
  if (has(
    r'grand\s*total|net\s*payable|(amount|amt|total|bill)\s*payable|\bto\s*pay\b|you\s*pay|'
    r'amount\s*due|total\s*due|balance\s*due|net\s*bill|bill\s*total',
  )) {
    return (_Kind.total, 6, '');
  }
  if (has(
    r'net\s*(amount|amt|total|value)|bill\s*(amount|amt)|invoice\s*(total|value|amount)|'
    r'total\s*(amount|amt|value|rs|inr|₹|fare|price)|final\s*(amount|total)|trip\s*total',
  )) {
    return (_Kind.total, 5, '');
  }
  if (has(r'\btotal\b|\btot\b|\btot\.|\bttl\b')) return (_Kind.total, 4, '');
  if (has(
    r'\b(amount|amt)\b.*(paid|received)|\bpaid\b|\breceived\b|tender|\bchange\b|'
    r'\b(cash|card|upi|paytm|gpay|phonepe)\b',
  )) {
    return (_Kind.payment, 2, '');
  }
  if (has(r'^(sale\s*)?(amount|amt)\b|\bsale\b')) return (_Kind.payment, 2, '');
  if (has(
    r'gstin|fssai|\bphone\b|\bph\b|\bmob|\btel\b|cin\b|\bpan\b|invoice\s*(no|#)|bill\s*(no|#)|'
    r'taxable|\bhsn\b|\bsac\b|\bno\s*[.:#]|receipt\s*(no|#)|slip\s*(no|#)|'
    r'order\s*(no|id|#)|token|\bkot\b|table|cashier|counter|\bpos\b|terminal|txn|transaction|'
    r'\bref\b|\butr\b|upi\s*id|@ok|\bdate\b|\btime\b|\bcovers?\b|\bpax\b|guest|thank|visit|www|http|'
    r'rate\s*\(|volume|density|\bnozzle\b|\bpump\b|vehicle|\bkm\b|distance|duration|\bmin(s|utes)?\b',
  )) {
    return (_Kind.ignored, 0, '');
  }
  return (_Kind.item, 0, '');
}

/// The item's name: the words before its trailing numbers ("Dolo 650 Tab  2  30.91  61.82" → "Dolo 650
/// Tab"; "Tea x 4 = 40" → "Tea"; a leading "2 x" is dropped).
String _itemName(String text) {
  final tokens = _stripNoise(text).split(' ').where((w) => w.isNotEmpty).toList();
  var end = tokens.length;
  while (end > 0 && _numericToken.hasMatch(tokens[end - 1])) {
    end--;
  }
  if (end == tokens.length) return '';
  var name = tokens.take(end).join(' ');
  name = name
      .replaceFirst(RegExp(r'^\d+(\.\d+)?\s*[x×*]\s+', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^\d+\s*[x×*](?=[A-Za-z])', caseSensitive: false), '')
      .replaceAll(RegExp(r'^[\s\-=:.,|*#]+|[\s\-=:.,|*#@]+$'), '')
      .trim();
  if (_letters(name) < 2) return '';
  if (RegExp(
    r'^(item|items|description|particulars|qty|rate|price|amount|amt|mrp|s\.?\s*no|balance|product)\b',
    caseSensitive: false,
  ).hasMatch(name)) {
    return '';
  }
  return name.length > 60 ? name.substring(0, 60).trim() : name;
}

final _numericToken = RegExp(
  r'^([₹$£€]|rs\.?|inr)?[\d.,/\-−]+(/-)?$|^(x|×|\*|@|=|-|:|rs\.?|inr|/-|nos?|pcs)$|^x\d+$|^\d+x$|^[(\[]?\d+[)\]]?$',
  caseSensitive: false,
);

/// The text without dates, times, percentages, GSTINs and long digit runs (phones, ids), which must
/// never be read as amounts.
String _stripNoise(String text) => text
    .replaceAll(RegExp(r'\b\d{2}[A-Z]{5}\d{4}[A-Z][A-Z\d]Z[A-Z\d]\b'), ' ')
    .replaceAll(_numericDate, ' ')
    .replaceAll(_wordDate, ' ')
    .replaceAll(RegExp(r'\b\d{1,2}:\d{2}(:\d{2})?\s*(am|pm|hrs)?\b', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'[@(]?\s*\d+(\.\d+)?\s*%\s*\)?'), ' ')
    .replaceAll(RegExp(r'(?<![\d,.])\d{9,}(?![\d,.])'), ' ')
    .replaceAll(RegExp(r'\+91[\s\-]?\d{5}[\s\-]?\d{5}'), ' ');

final _numericDate = RegExp(r'\b\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b');
final _wordDate = RegExp(
  r'\b\d{1,2}(st|nd|rd|th)?[\s\-/.]*(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?'
  r'[\s\-/.,]*\d{2,4}\b|\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+\d{1,2},?\s+\d{4}\b',
  caseSensitive: false,
);

final _amountToken = RegExp(
  r'(₹|\brs\.?|\binr(?![a-z])|[$£€])?\s*((?:-|−)(?=\d))?(?<!\d)(?<!\d[.,])(?<!,)(\d{1,3}(?:,\d{2,3})+|\d+)(?:\.(\d{1,2}))?'
  r'(?![\d]|[.,]\d)(\s*/-)?',
  caseSensitive: false,
);

final _letter = RegExp('[A-Za-z]');

/// Amounts on a row, left to right, as minor units with [exponent] decimals.
List<_Amount> _amounts(String text, int exponent) {
  final t = _stripNoise(text);
  final out = <_Amount>[];
  for (final m in _amountToken.allMatches(t)) {
    var whole = m[3]!;
    final digitsAt = m.start + m[0]!.indexOf(whole);
    // A number glued to letters ("A1", "x2", "500ml", "5kg") is not an amount.
    if (m[1] == null && digitsAt > 0 && _letter.hasMatch(t[digitsAt - 1])) continue;
    if (m[5] == null && m.end < t.length && _letter.hasMatch(t[m.end])) continue;
    var fraction = m[4] ?? '';
    final groups = whole.split(',');
    if (groups.length == 2 && groups.last.length == 2 && fraction.isEmpty) {
      // "945,00": one comma before exactly two digits is a decimal comma (Indian groups end in three).
      whole = groups.first;
      fraction = groups.last;
    } else if (groups.length > 1 && groups.last.length != 3) {
      continue;
    }
    whole = whole.replaceAll(',', '');
    if (whole.length > 9) continue;
    final hadDecimals = fraction.isNotEmpty;
    if (fraction.length > exponent) {
      if (!RegExp(r'^0+$').hasMatch(fraction.substring(exponent))) continue;
      fraction = fraction.substring(0, exponent);
    }
    final value = int.parse(whole + fraction.padRight(exponent, '0'));
    out.add((
      value: m[2] != null ? -value : value,
      marked: m[1] != null || m[5] != null,
      decimals: hadDecimals,
    ));
  }
  return out;
}

// ------------------------------------------------------------------------------------------ total

int? _total(List<_Row> rows) {
  // 1. The strongest "total" words; the lowest such line wins a tie (a final total sits under the others).
  _Row? best;
  for (final row in rows) {
    final a = row.amount;
    if (row.kind != _Kind.total || a == null || a.value <= 0) continue;
    if (best == null || row.tier >= best.tier) best = row;
  }
  // A "Total" line whose amount is only on the next row ("Grand Total" / "₹945.00").
  if (best == null) {
    for (final row in rows) {
      if (row.kind != _Kind.total || row.amount != null) continue;
      final next = row.index + 1 < rows.length ? rows[row.index + 1] : null;
      final a = next?.amount;
      if (next != null && a != null && a.value > 0 && next.kind != _Kind.subtotal) {
        if (best == null || row.tier >= best.tier)
          best = _Row(next.index, next.text, next.amounts, _Kind.total, row.tier, '', '');
      }
    }
  }
  if (best != null) return best.amount!.value;
  // 2. Amounts marked ₹ / Rs. / /- (a UPI screenshot shows just "₹250"): the biggest.
  int? marked;
  for (final row in rows) {
    if (row.kind == _Kind.ignored || row.kind == _Kind.subtotal) continue;
    for (final a in row.amounts) {
      if (a.marked && a.value > 0 && (marked == null || a.value > marked)) marked = a.value;
    }
  }
  if (marked != null) return marked;
  // 3. What was paid ("Cash 500", "Amount 2000.00").
  int? paid;
  for (final row in rows) {
    final a = row.amount;
    if (row.kind == _Kind.payment && a != null && a.value > 0 && row.text.contains(RegExp(r'\d'))) {
      if (paid == null || a.value > paid) paid = a.value;
    }
  }
  if (paid != null) return paid;
  // 4. The biggest amount in the lower part of the receipt.
  int? largest;
  final from = rows.length < 4 ? 0 : (rows.length * 0.4).floor();
  for (final row in rows.skip(from)) {
    if (row.kind == _Kind.ignored || row.kind == _Kind.roundOff) continue;
    // Only a number that ends its row ("Petrol 2000.00"), not one inside words ("Open 24 hours").
    final a = row.amount;
    final words = row.text.split(' ');
    if (a == null || !_numericToken.hasMatch(words.last)) continue;
    final year = !a.decimals && !a.marked && a.value >= 1900 * 100 && a.value <= 2100 * 100;
    if (a.value > 0 && !year && (largest == null || a.value > largest)) largest = a.value;
  }
  return largest;
}

/// Index of the first row of the receipt's footer (sub total, tax, total …): item lines sit above it.
int _footerStart(List<_Row> rows) {
  for (final row in rows) {
    if (row.amount == null) continue;
    if (const {
      _Kind.subtotal,
      _Kind.total,
      _Kind.tax,
      _Kind.taxTotal,
      _Kind.service,
    }.contains(row.kind)) {
      return row.index;
    }
  }
  return rows.length;
}

// ------------------------------------------------------------------------------------------- date

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

DateTime? _date(List<String> rows, DateTime? today) {
  DateTime? first;
  for (final row in rows) {
    final d = _dateIn(row, today);
    if (d == null) continue;
    // A row that says "Date" (bill date, invoice date) beats a date found elsewhere.
    if (RegExp(r'\b(date|dt|dated)\b', caseSensitive: false).hasMatch(row)) return d;
    first ??= d;
  }
  return first;
}

DateTime? _dateIn(String row, DateTime? today) {
  DateTime? valid(int y, int m, int d) {
    if (y < 100) y += 2000;
    if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    if (date.month != m) return null;
    if (today != null && date.isAfter(today.add(const Duration(days: 1)))) return null;
    return date;
  }

  final iso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').firstMatch(row);
  if (iso != null) {
    final d = valid(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
    if (d != null) return d;
  }
  final numeric = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b').firstMatch(row);
  if (numeric != null) {
    final a = int.parse(numeric[1]!);
    final b = int.parse(numeric[2]!);
    final y = int.parse(numeric[3]!);
    // India writes day first; month first only when the second number cannot be a month.
    final d = b <= 12 ? valid(y, b, a) : valid(y, a, b);
    if (d != null) return d;
  }
  final dayFirst = RegExp(
    r'\b(\d{1,2})(?:st|nd|rd|th)?[\s\-/.]*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?[\s\-/.,]*(\d{2,4})\b',
    caseSensitive: false,
  ).firstMatch(row);
  if (dayFirst != null) {
    final d = valid(
      int.parse(dayFirst[3]!),
      _months[dayFirst[2]!.toLowerCase()]!,
      int.parse(dayFirst[1]!),
    );
    if (d != null) return d;
  }
  final monthFirst = RegExp(
    r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})\b',
    caseSensitive: false,
  ).firstMatch(row);
  if (monthFirst != null) {
    return valid(
      int.parse(monthFirst[3]!),
      _months[monthFirst[1]!.toLowerCase()]!,
      int.parse(monthFirst[2]!),
    );
  }
  return null;
}

// --------------------------------------------------------------------------------------- merchant

final _notMerchant = RegExp(
  r'tax\s*invoice|retail\s*invoice|\binvoice\b|bill\s*of\s*supply|cash\s*memo|\breceipt\b|\bwelcome\b|'
  r'original|duplicate|customer\s*copy|gstin|fssai|\bphone\b|\bph\b|\bmob|\btel\b|www|http|e-?mail|'
  r'\bdate\b|\btime\b|\btable\b|bill\s*no|order|token|\bkot\b|cashier|payment\s*(successful|done|complete)|'
  r'^(paid|completed|success|successful|transaction)',
  caseSensitive: false,
);

String? _merchant(List<String> rows) {
  // A UPI screenshot: "Paid to Ramesh Kumar" (or "Paid to" with the name on the next row).
  for (final (i, row) in rows.indexed) {
    final m = RegExp(
      r'^(?:paid|sent|payment)\s+to\b[:\s]*(.*)$|^to[:\s]+(.+)$',
      caseSensitive: false,
    ).firstMatch(row);
    if (m == null) continue;
    var name = (m[1] ?? m[2] ?? '').trim();
    if (_letters(name) < 3 && i + 1 < rows.length) name = rows[i + 1];
    final clean = _cleanName(name);
    if (clean != null) return clean;
  }
  // Text a UPI app shares: "Paid ₹250 to Ramesh Kumar via Google Pay." (D-034 A7).
  for (final row in rows) {
    final m = RegExp(
      r'\b(?:paid|sent|payment of)\b.*?\bto\s+([A-Za-z][A-Za-z .&\x27]{1,40}?)'
      r'(?=\s+(?:via|on|using|upi|from|for|with|successfully)\b|[.,!]|$)',
      caseSensitive: false,
    ).firstMatch(row);
    final clean = m == null ? null : _cleanName(m[1]!);
    if (clean != null) return clean;
  }
  for (final row in rows.take(8)) {
    if (_notMerchant.hasMatch(row)) continue;
    final digits = RegExp(r'\d').allMatches(row).length;
    if (_letters(row) < 3 || digits > _letters(row)) continue;
    final clean = _cleanName(row);
    if (clean != null) return clean;
  }
  return null;
}

int _letters(String s) => RegExp('[A-Za-z]').allMatches(s).length;

String? _cleanName(String raw) {
  var s = raw
      .replaceAll(RegExp(r'[^A-Za-z0-9&\x27.,()\- ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s\-.,]+|[\s\-.,]+$'), '')
      .trim();
  if (_letters(s) < 3) return null;
  if (s.length > 3 && s == s.toUpperCase()) {
    s = s
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
  return s.length > 60 ? s.substring(0, 60).trim() : s;
}
