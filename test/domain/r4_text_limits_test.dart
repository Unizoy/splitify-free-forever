// R4 robustness: very long, emoji, RTL and mixed text through the app's text limits (planning/08 cross-cutting
// "Limits"). Every place that shortens text must cut between whole characters (never half an emoji, a flag
// or a ZWJ family, which would leave a broken "�" in names and notes), and every check must count like the
// server's `char_length` (code points) or stricter.
//
// TC-R4-T-01  clipText: prefix of whole characters, within the limit, never a lone surrogate
// TC-R4-T-02  every clipping caller: import names / descriptions / notes / group name, itemized lines, receipt
//             items, attachment names
// TC-R4-T-03  validation rules count like the server (or stricter) for 5,000-character, emoji and RTL text
import 'dart:math';

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/utils/text_clip.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/rules/comment_rules.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/domain/rules/profile_rules.dart';
import 'package:splitify/domain/rules/receipt_text_parser.dart';
import 'package:splitify/features/expenses/application/itemize_draft.dart';
import 'package:splitify/features/import_splitwise/application/import_controller.dart'
    show groupNameFromFile;
import 'package:splitify/features/import_splitwise/domain/import_mapping.dart';

/// Pieces people really type: ASCII, accents (pre-composed and combining), Hindi conjuncts, Arabic, Hebrew,
/// emoji with skin tones, flags, ZWJ families, keycaps, direction marks.
const pieces = [
  'a',
  'Z',
  ' ',
  '7',
  '.',
  'é',
  'e\u0301',
  'क्षि',
  'मोहित',
  'مرحبا',
  'שלום',
  '😀',
  '👍🏽',
  '🇮🇳', //
  '👨\u200d👩\u200d👧\u200d👦', '1\ufe0f\u20e3', '\u200f', '\u202e', '中文', 'ñ', '🏳\ufe0f\u200d🌈',
];

String randomText(Random r, int pieceCount) =>
    [for (var i = 0; i < pieceCount; i++) pieces[r.nextInt(pieces.length)]].join();

/// No unpaired UTF-16 surrogate.
bool wellFormed(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0xD800 && c <= 0xDBFF) {
      if (i + 1 >= s.length) return false;
      final d = s.codeUnitAt(i + 1);
      if (d < 0xDC00 || d > 0xDFFF) return false;
      i++;
    } else if (c >= 0xDC00 && c <= 0xDFFF) {
      return false;
    }
  }
  return true;
}

/// [cut]'s characters are the first characters of [whole] (spaces trimmed at either end of [cut] allowed).
void expectWholeCharacterPrefix(String cut, String whole, String reason) {
  expect(wellFormed(cut), isTrue, reason: '$reason: lone surrogate in "$cut"');
  final a = cut.trim().characters.toList();
  final b = whole.trim().characters.toList();
  expect(a.length <= b.length, isTrue, reason: reason);
  final start = b.indexWhere((c) => c.trim().isNotEmpty);
  for (var i = 0; i < a.length; i++) {
    expect(a[i], b[(start < 0 ? 0 : start) + i], reason: '$reason: character $i of "$cut"');
  }
}

void main() {
  // TC-R4-T-01
  group('clipText', () {
    test('random text and limits: whole characters only, within the limit, a prefix', () {
      final r = Random(4301);
      for (var k = 0; k < 5000; k++) {
        final text = randomText(r, r.nextInt(80));
        final max = r.nextInt(120);
        final cut = clipText(text, max);
        expect(cut.length, lessThanOrEqualTo(max), reason: 'case $k');
        expect(text.startsWith(cut), isTrue, reason: 'case $k');
        expectWholeCharacterPrefix(cut, text, 'case $k');
        if (text.length <= max) expect(cut, text);
        // Nothing that would still fit was dropped: the next character did not fit.
        if (cut.length < text.length) {
          final next = text.substring(cut.length).characters.first;
          expect(cut.length + next.length, greaterThan(max), reason: 'case $k');
        }
      }
    });

    test('examples', () {
      expect(clipText('${'a' * 49}👍', 50), 'a' * 49);
      expect(clipText('${'a' * 48}👍', 50), '${'a' * 48}👍');
      expect(clipText('👨\u200d👩\u200d👧\u200d👦', 10), '');
      expect(clipText('🇮🇳🇮🇳', 6), '🇮🇳');
      expect(clipText('e\u0301e\u0301', 3), 'e\u0301');
      expect(clipText('', 5), '');
      expect(clipText('abc', 0), '');
    });
  });

  // TC-R4-T-02
  group('every place that shortens text cuts whole characters', () {
    test('import: member names (50), group name from the file name (60)', () {
      final r = Random(4302);
      for (var k = 0; k < 3000; k++) {
        final name = randomText(r, 10 + r.nextInt(60));
        final member = clipName(name);
        expect(member.length, lessThanOrEqualTo(maxMemberName));
        expectWholeCharacterPrefix(member, name, 'member $k');
        final group = groupNameFromFile('$name.csv');
        expect(group.length, lessThanOrEqualTo(GroupRules.nameMax));
        expect(wellFormed(group), isTrue, reason: 'group $k: "$group"');
      }
      expect(clipName('${'a' * 49}🇮🇳'), 'a' * 49);
      expect(groupNameFromFile('${'b' * 59}😀.csv'), 'B${'b' * 58}');
    });

    test('itemized lines from a receipt or a saved split (60)', () {
      final r = Random(4303);
      for (var k = 0; k < 2000; k++) {
        final name = randomText(r, 10 + r.nextInt(60));
        final fromScan = ItemizeDraft.fromLines([(name: name, amount: 100)], const ['m1'], 2);
        final cut = fromScan.items.single.name;
        expect(cut.length, lessThanOrEqualTo(maxItemName));
        expectWholeCharacterPrefix(cut, name, 'item $k');
        final stored = ItemizeDraft.fromStored(
          {
            itemizedKey: {
              'items': [
                {
                  'name': name,
                  'amount': 100,
                  'members': ['m1'],
                },
              ],
            },
          },
          2,
          members: const ['m1'],
        )!;
        expectWholeCharacterPrefix(stored.items.single.name, name, 'stored $k');
      }
    });

    test('receipt item names and the merchant (60)', () {
      final r = Random(4304);
      for (var k = 0; k < 1000; k++) {
        final name = 'Paneer ${randomText(r, 20 + r.nextInt(40))}';
        final scan = parseReceipt(['Cafe ${randomText(r, 30)}', '$name  250.00', 'Total  250.00']);
        for (final i in scan.items) {
          expect(i.name.length, lessThanOrEqualTo(60));
          expect(wellFormed(i.name), isTrue, reason: 'item $k: "${i.name}"');
        }
        final merchant = scan.merchant;
        if (merchant != null) expect(wellFormed(merchant), isTrue, reason: 'merchant $k');
      }
    });

    test('attachment names (120) keep the extension and whole characters', () {
      final r = Random(4305);
      for (var k = 0; k < 2000; k++) {
        final base = randomText(r, 30 + r.nextInt(80));
        final name = cleanAttachmentName('$base.pdf')!;
        expect(name.length, lessThanOrEqualTo(AttachmentLimits.nameMaxLength));
        expect(wellFormed(name), isTrue, reason: 'case $k: "$name"');
        if ('$base.pdf'.length > AttachmentLimits.nameMaxLength) {
          expect(name.endsWith('.pdf'), isTrue);
        }
      }
      expect(cleanAttachmentName('${'x' * 115}😀😀.jpg'), '${'x' * 115}.jpg');
    });
  });

  // TC-R4-T-03
  group('validation counts like the server, or stricter', () {
    int codePoints(String s) => s.runes.length;

    test('group and member names: 60 / 50 code points; blank is required', () {
      final r = Random(4306);
      for (var k = 0; k < 3000; k++) {
        final text = randomText(r, r.nextInt(70));
        final group = GroupRules.name(text);
        final member = GroupRules.memberName(text);
        final t = text.trim();
        if (t.isEmpty) {
          expect(group, GroupFieldError.required);
        } else {
          expect(group == null, codePoints(t) <= GroupRules.nameMax, reason: 'case $k');
          expect(member == null, codePoints(t) <= GroupRules.memberNameMax, reason: 'case $k');
        }
      }
      expect(
        GroupRules.name('\u200f'),
        isNull,
        reason: 'a direction mark alone is text the server keeps',
      );
      expect(GroupRules.name('   \n\t '), GroupFieldError.required);
      expect(GroupRules.name('ש' * 60), isNull);
      expect(GroupRules.name('ש' * 61), GroupFieldError.tooLong);
    });

    test(
      'profile names never pass with more code points than the server allows; comments at 1,000',
      () {
        final r = Random(4307);
        for (var k = 0; k < 3000; k++) {
          final text = randomText(r, r.nextInt(70));
          if (ProfileRules.isValidName(text)) {
            expect(
              codePoints(text.trim()),
              lessThanOrEqualTo(ProfileRules.maxNameLength),
              reason: 'case $k',
            );
          }
          final long = randomText(r, 200 + r.nextInt(400));
          final cleaned = CommentRules.clean(long);
          if (cleaned != null) {
            expect(codePoints(cleaned), lessThanOrEqualTo(CommentRules.maxLength));
          }
          expect(CommentRules.tooLong(long), codePoints(long.trim()) > CommentRules.maxLength);
        }
        expect(CommentRules.clean('x' * 5000), isNull);
        expect(CommentRules.clean('🇮🇳' * 500), isNotNull, reason: '1,000 code points');
        expect(CommentRules.clean('🇮🇳' * 501), isNull);
      },
    );
  });
}
