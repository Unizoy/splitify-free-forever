import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/rules/comment_rules.dart';

void main() {
  group('CommentRules', () {
    // 08 Limits: comment 1..1000 characters
    test('clean trims the text', () {
      expect(CommentRules.clean('  hello \n'), 'hello');
      expect(CommentRules.clean('a b'), 'a b');
    });

    // 08 Limits: comment 1..1000 characters
    test('clean returns null for empty or whitespace-only text', () {
      expect(CommentRules.clean(''), isNull);
      expect(CommentRules.clean('   \n\t '), isNull);
    });

    // 08 Limits: comment 1..1000 characters
    test('exactly 1000 characters is allowed, 1001 is not', () {
      final ok = 'a' * CommentRules.maxLength;
      expect(CommentRules.maxLength, 1000);
      expect(CommentRules.clean(ok), ok);
      expect(CommentRules.tooLong(ok), isFalse);
      final tooLong = 'a' * (CommentRules.maxLength + 1);
      expect(CommentRules.clean(tooLong), isNull);
      expect(CommentRules.tooLong(tooLong), isTrue);
    });

    // 08 Limits: comment 1..1000 characters
    test('the limit counts trimmed text', () {
      final padded = '  ${'a' * 1000}  ';
      expect(CommentRules.clean(padded), 'a' * 1000);
      expect(CommentRules.tooLong(padded), isFalse);
    });

    // 08 Limits: comment 1..1000 characters
    test('characters are counted as runes, not UTF-16 units', () {
      final emoji = '😀' * 1000; // 2000 UTF-16 units, 1000 characters
      expect(CommentRules.clean(emoji), emoji);
      expect(CommentRules.tooLong(emoji), isFalse);
      expect(CommentRules.tooLong('${'😀' * 1000}😀'), isTrue);
    });

    test('tooLong is false for empty text', () {
      expect(CommentRules.tooLong(''), isFalse);
      expect(CommentRules.tooLong('   '), isFalse);
    });
  });
}
