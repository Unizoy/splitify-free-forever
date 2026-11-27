// Final QA (S-403): avatar initials use letters only. "E2E A 82348" showed "E8": now only words that start
// with a letter count (a number or an emoji is skipped), with the first letter anywhere as a last resort.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/components/avatar.dart';

void main() {
  const cases = <String, String>{
    'Asha Rao': 'AR',
    'asha': 'A',
    'Mohit Kumar Bindal': 'MB',
    '  Neha   ': 'N',
    'E2E A 82348': 'EA',
    'E2E B 12': 'EB',
    'Flat 4B': 'F',
    '2nd floor': 'F',
    'Rahul 🙂': 'R',
    '4B': 'B',
    '82348': '?',
    '': '?',
    '   ': '?',
    'राहुल शर्मा': 'राश',
    'élodie ünal': 'ÉÜ',
  };
  for (final e in cases.entries) {
    test('"${e.key}" → "${e.value}"', () => expect(Avatar.initials(e.key), e.value));
  }
}
