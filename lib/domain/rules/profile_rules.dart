/// Profile validation (B2, planning/03-backend.md §2). Mirrors the SQL checks.
abstract final class ProfileRules {
  /// Display name limit (08 cross-cutting rules).
  static const maxNameLength = 50;

  // Same pattern as the `profiles.upi_id` check constraint.
  static final _upi = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z0-9.\-]{1,63}$');

  /// True when [value] looks like a UPI ID (`name@bank`), TC-B2-01.
  static bool isValidUpiId(String value) => _upi.hasMatch(value.trim());

  /// True when the trimmed name has 1–50 characters.
  static bool isValidName(String value) {
    final n = value.trim().length;
    return n >= 1 && n <= maxNameLength;
  }

  /// UPI ID from a `upi://pay?pa=…` QR (TC-B2-02), or null when the QR is not
  /// a UPI payment code or carries an invalid ID.
  static String? upiIdFromQr(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'upi') return null;
    if (uri.host.toLowerCase() != 'pay') return null;
    final pa = uri.queryParameters['pa']?.trim();
    if (pa == null || !isValidUpiId(pa)) return null;
    return pa;
  }
}
