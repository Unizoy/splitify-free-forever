import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/utils/stable_hash.dart';

void main() {
  // TC-B3-03: ids always map to the same colour/cover, so the hash is pinned.
  test('known FNV-1a 32-bit values', () {
    expect(stableHash(''), 0x811c9dc5);
    expect(stableHash('a'), 0xe40c292c);
    expect(stableHash('foobar'), 0xbf9cf968);
  });

  test('same input gives the same value; different input differs', () {
    expect(stableHash('group-1'), stableHash('group-1'));
    expect(stableHash('group-1'), isNot(stableHash('group-2')));
    expect(stableHash('x'), inInclusiveRange(0, 0xffffffff));
  });
}
