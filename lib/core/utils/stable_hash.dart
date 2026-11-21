/// FNV-1a 32-bit hash of [value]. Stable across runs and platforms (unlike
/// `String.hashCode`), so colours and covers picked from ids never change.
int stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}
