// Recurring next-date vectors (phase 16 T1). The same file feeds the SQL generator tests of
// phase 16 T2, so Dart and Postgres must agree on every vector.
//
// TC-12-05  next-date calculator parity with SQL (every vector in recurring_vectors.json)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/rules/recurrence.dart';

const _fixture = 'test/fixtures/recurring_vectors.json';

typedef _Json = Map<String, dynamic>;

String? _text(DateTime? date) => date == null ? null : formatIsoDate(date);

_Json _evaluate(_Json vector) {
  final input = vector['input'] as _Json;
  try {
    final rule = Recurrence.parse(
      interval: input['interval'] as String,
      anchor: input['anchor'] as String,
      endsOn: input['ends_on'] as String?,
    );
    switch (vector['op']) {
      case 'next':
        return {'next': _text(rule.nextAfter(parseIsoDate(input['after'] as String)))};
      case 'series':
        return {
          'dates': [for (var i = 0; i < (input['count'] as int); i++) _text(rule.occurrence(i))],
        };
      case 'run':
        final run = rule.run(
          nextDate: parseIsoDate(input['next_date'] as String),
          today: parseIsoDate(input['today'] as String),
        );
        return {'dates': run.dates.map(_text).toList(), 'next': _text(run.next)};
    }
    throw StateError('unknown op ${vector['op']}');
  } on RecurrenceError catch (e) {
    return {'error': e.code};
  }
}

DateTime _d(String text) => parseIsoDate(text);

void main() {
  final doc = jsonDecode(File(_fixture).readAsStringSync()) as _Json;
  final vectors = (doc['vectors'] as List).cast<_Json>();

  group('recurring vectors', () {
    test('fixture covers every op, interval and error code', () {
      final ops = {for (final v in vectors) v['op']};
      final intervals = {for (final v in vectors) (v['input'] as _Json)['interval']};
      final errors = {for (final v in vectors) (v['expect'] as _Json)['error']}..remove(null);
      expect(ops, {'next', 'series', 'run'});
      expect(intervals, containsAll(RecurrenceInterval.values.map((i) => i.key)));
      expect(errors, {'UNKNOWN_INTERVAL', 'ENDS_BEFORE_ANCHOR', 'NOT_A_DATE'});
    });

    for (final vector in vectors) {
      test('${vector['id']} ${vector['op']} matches the vector', () {
        expect(_evaluate(vector), vector['expect']);
      });
    }
  });

  group('Recurrence', () {
    test('nextAfter equals a brute-force scan of the series for every day in a window', () {
      final anchors = [
        '2023-01-28',
        '2023-01-29',
        '2023-01-30',
        '2023-01-31',
        '2024-01-31',
        '2024-02-29',
        '2024-08-31',
        '2025-12-31',
      ];
      for (final interval in RecurrenceInterval.values) {
        for (final anchor in anchors) {
          final rule = Recurrence(interval: interval, anchor: _d(anchor));
          final copies = [for (var i = 1; i <= 60; i++) rule.occurrence(i)];
          for (var day = -20; day < 420; day++) {
            final date = DateTime.utc(rule.anchor.year, rule.anchor.month, rule.anchor.day + day);
            final expected = copies.firstWhere((c) => c.isAfter(date));
            expect(rule.nextAfter(date), expected, reason: '$interval $anchor after $date');
          }
        }
      }
    });

    test('firstCopy is the next_date of a new template', () {
      final rule = Recurrence.parse(interval: 'monthly', anchor: '2026-01-31');
      expect(rule.firstCopy, _d('2026-02-28'));
      expect(rule.endsOn, isNull);
      final once = Recurrence.parse(interval: 'yearly', anchor: '2026-01-31', endsOn: '2026-01-31');
      expect(once.firstCopy, isNull);
    });

    test('run returns no dates and keeps going when today is before next_date', () {
      final rule = Recurrence(interval: RecurrenceInterval.weekly, anchor: _d('2026-01-05'));
      final run = rule.run(nextDate: _d('2026-01-12'), today: _d('2026-01-11'));
      expect(run.dates, isEmpty);
      expect(run.next, _d('2026-01-12'));
    });

    test('occurrence rejects a negative index', () {
      final rule = Recurrence(interval: RecurrenceInterval.weekly, anchor: _d('2026-01-05'));
      expect(() => rule.occurrence(-1), throwsRangeError);
    });

    test('dates with a time part or a local zone are rejected', () {
      final anchor = DateTime.utc(2026, 1, 5);
      expect(
        () => Recurrence(interval: RecurrenceInterval.weekly, anchor: DateTime(2026, 1, 5)),
        throwsA(isA<NotADate>()),
      );
      expect(
        () => Recurrence(
          interval: RecurrenceInterval.weekly,
          anchor: anchor,
          endsOn: DateTime.utc(2026, 2, 1, 9),
        ),
        throwsA(isA<NotADate>()),
      );
      final rule = Recurrence(interval: RecurrenceInterval.weekly, anchor: anchor);
      expect(() => rule.nextAfter(DateTime.utc(2026, 1, 5, 0, 0, 1)), throwsA(isA<NotADate>()));
      expect(
        () => rule.run(nextDate: anchor, today: DateTime.utc(2026, 1, 5, 12)),
        throwsA(isA<NotADate>()),
      );
    });

    test('ends_on before the anchor is rejected', () {
      expect(
        () => Recurrence(
          interval: RecurrenceInterval.monthly,
          anchor: _d('2026-01-05'),
          endsOn: _d('2026-01-04'),
        ),
        throwsA(isA<EndsBeforeAnchor>()),
      );
    });
  });

  group('RecurrenceInterval', () {
    test('parse round-trips every stored key', () {
      for (final interval in RecurrenceInterval.values) {
        expect(RecurrenceInterval.parse(interval.key), interval);
      }
      expect(RecurrenceInterval.values.map((i) => i.key), [
        'weekly',
        'fortnightly',
        'monthly',
        'yearly',
      ]);
    });

    test('parse rejects an unknown key', () {
      expect(
        () => RecurrenceInterval.parse('Weekly'),
        throwsA(isA<UnknownInterval>().having((e) => e.interval, 'interval', 'Weekly')),
      );
    });
  });

  group('dates', () {
    test('parseIsoDate and formatIsoDate round-trip', () {
      expect(parseIsoDate('2024-02-29'), DateTime.utc(2024, 2, 29));
      expect(formatIsoDate(DateTime.utc(999, 1, 2)), '0999-01-02');
      expect(parseIsoDate('0999-01-02'), DateTime.utc(999, 1, 2));
    });

    test('parseIsoDate rejects impossible or malformed dates', () {
      for (final text in [
        '2023-02-29',
        '2026-13-01',
        '2026-00-10',
        '2026-1-01',
        '',
        '2026-01-01T00:00',
      ]) {
        expect(() => parseIsoDate(text), throwsA(isA<NotADate>()), reason: text);
      }
    });

    test('daysInMonth knows leap years and centuries', () {
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2000, 2), 29);
      expect(daysInMonth(2100, 2), 28);
      expect(daysInMonth(2026, 4), 30);
      expect(daysInMonth(2026, 12), 31);
    });
  });

  group('RecurrenceError', () {
    test('codes, data and toString are stable', () {
      expect(const UnknownInterval('daily').code, 'UNKNOWN_INTERVAL');
      expect(
        const UnknownInterval('daily').toString(),
        'RecurrenceError(UNKNOWN_INTERVAL, {interval: daily})',
      );
      expect(const EndsBeforeAnchor().code, 'ENDS_BEFORE_ANCHOR');
      expect(const EndsBeforeAnchor().data, isEmpty);
      expect(const EndsBeforeAnchor().toString(), 'RecurrenceError(ENDS_BEFORE_ANCHOR)');
      expect(const NotADate('x').code, 'NOT_A_DATE');
      expect(const NotADate('x').data, {'value': 'x'});
    });
  });
}
