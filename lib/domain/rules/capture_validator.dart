import 'package:splitify/domain/entities/payment_capture.dart';

/// Checks every capture that comes from the native store (and every capture link) before it reaches the
/// database (phase 18b, S-229): integer paise in range, INR only, short single-line texts, a plain UPI ref,
/// a known source and a time from the last 7 days. Anything else is dropped, never "fixed".
abstract final class CaptureValidator {
  /// ₹10,00,000 — the same ceiling as the recipes' `maxAmountPaise`.
  static const maxAmount = 100000000;
  static const keep = Duration(days: 7);

  static final _id = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _ref = RegExp(r'^[0-9A-Za-z]{6,20}$');
  static final _package = RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$');
  static final _control = RegExp(r'[\u0000-\u001F\u007F  ]');

  /// A valid capture id (UUID).
  static bool isId(String? s) => s != null && _id.hasMatch(s);

  /// The record as the native `CaptureStore` exports it, or null when anything is off.
  static PaymentCapture? parse(Object? raw, {required DateTime now}) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final amount = raw['amount'];
    final currency = raw['currency'] ?? 'INR';
    final source = CaptureSource.fromWire(raw['source']);
    final package = raw['app_package'];
    final appName = _text(raw['app_name'], 40);
    final at = raw['captured_at'];
    if (id is! String || !isId(id)) return null;
    if (amount is! int || amount <= 0 || amount > maxAmount) return null;
    if (currency != 'INR' || source == null) return null;
    if (package is! String || package.length > 120 || !_package.hasMatch(package)) return null;
    if (appName == null || at is! int) return null;
    final time = DateTime.fromMillisecondsSinceEpoch(at, isUtc: true);
    if (time.isAfter(now.add(const Duration(minutes: 5))) || now.difference(time) > keep)
      return null;
    final ref = raw['ref'];
    if (ref != null && (ref is! String || !_ref.hasMatch(ref))) return null;
    final payee = raw['payee'];
    final note = raw['note'];
    final cleanPayee = _text(payee, 60);
    final cleanNote = _text(note, 60);
    if ((payee != null && cleanPayee == null) || (note != null && cleanNote == null)) return null;
    return PaymentCapture(
      id: id,
      amount: amount,
      payee: cleanPayee,
      note: cleanNote,
      ref: ref as String?,
      appPackage: package,
      appName: appName,
      source: source,
      capturedAt: time,
    );
  }

  static String? _text(Object? v, int max) {
    if (v is! String) return null;
    final t = v.trim();
    if (t.isEmpty || t.length > max || _control.hasMatch(t)) return null;
    return t;
  }
}

/// `splitify://capture?id=<capture id>[&group=<group id>]` (S-228), checked before routing.
typedef CaptureLink = ({String captureId, String? groupId});

/// Parses a capture link (host `capture`, or the in-app path `/capture`); null when it is not one or its ids are
/// malformed.
CaptureLink? parseCaptureLink(Uri uri) {
  final isCapture = uri.host == 'capture' || uri.path == '/capture';
  if (!isCapture) return null;
  final id = uri.queryParameters['id'];
  final group = uri.queryParameters['group'];
  if (!CaptureValidator.isId(id)) return null;
  if (group != null && !CaptureValidator.isId(group)) return null;
  return (captureId: id!, groupId: group);
}
