import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';

void main() {
  const push = NotificationChannel.push;
  const inapp = NotificationChannel.inapp;

  group('NotificationKind', () {
    test('tryParse finds kinds by name and returns null otherwise', () {
      expect(NotificationKind.tryParse('payments'), NotificationKind.payments);
      expect(NotificationKind.tryParse('nope'), isNull);
      expect(NotificationKind.tryParse(null), isNull);
    });
  });

  group('NotificationPrefs', () {
    // TC-19-05
    test('TC-19-05 everything is on by default and nothing is muted', () {
      const p = NotificationPrefs();
      // The monthly summary (W2-Y) is the one opt-in push; see its own test.
      for (final k in NotificationKind.switchable) {
        for (final c in NotificationChannel.values) {
          expect(p.isOn(k, c), isTrue);
        }
      }
      expect(p.isMuted('g1'), isFalse);
      expect(p.kindsJson(), isEmpty);
      expect(p.mutedJson(), isEmpty);
    });

    // TC-19-05
    test('TC-19-05 withKind switches one channel off and back on', () {
      final off = const NotificationPrefs().withKind(NotificationKind.comments, push, on: false);
      expect(off.isOn(NotificationKind.comments, push), isFalse);
      expect(off.isOn(NotificationKind.comments, inapp), isTrue);
      expect(off.isOn(NotificationKind.expenses, push), isTrue);
      final on = off.withKind(NotificationKind.comments, push, on: true);
      expect(on, const NotificationPrefs());
    });

    // TC-19-05
    test('TC-19-05 withMuted mutes and unmutes a group', () {
      final m = const NotificationPrefs().withMuted('g1', muted: true);
      expect(m.isMuted('g1'), isTrue);
      expect(m.withMuted('g1', muted: false).isMuted('g1'), isFalse);
    });

    // TC-19-05
    test('TC-19-05 kindsJson lists only switched-off channels in enum order; mutedJson sorted', () {
      final p = const NotificationPrefs()
          .withKind(NotificationKind.groups, inapp, on: false)
          .withKind(NotificationKind.expenses, push, on: false)
          .withKind(NotificationKind.expenses, inapp, on: false)
          .withMuted('b', muted: true)
          .withMuted('a', muted: true);
      expect(p.kindsJson(), {
        'expenses': {'push': false, 'inapp': false},
        'groups': {'inapp': false},
      });
      expect(p.kindsJson().keys.toList(), ['expenses', 'groups']);
      expect(p.mutedJson(), ['a', 'b']);
    });

    // TC-19-05
    test('TC-19-05 fromJson reads kinds and muted groups and round-trips', () {
      final p = NotificationPrefs.fromJson({
        'kinds': {
          'payments': {'push': false, 'inapp': true},
          'reminders': {'inapp': false},
        },
        'muted_group_ids': ['g2', 'g1'],
      });
      expect(p.isOn(NotificationKind.payments, push), isFalse);
      expect(p.isOn(NotificationKind.payments, inapp), isTrue);
      expect(p.isOn(NotificationKind.reminders, inapp), isFalse);
      expect(p.mutedGroupIds, {'g1', 'g2'});
      final again = NotificationPrefs.fromJson({
        'kinds': p.kindsJson(),
        'muted_group_ids': p.mutedJson(),
      });
      expect(again, p);
      expect(again.hashCode, p.hashCode);
    });

    // TC-19-05
    test('TC-19-05 fromJson ignores unknown kinds, bad values and wrong shapes', () {
      final p = NotificationPrefs.fromJson({
        'kinds': {
          'future_kind': {'push': false},
          'expenses': 'off',
          'comments': {'push': 'no', 'inapp': null},
        },
        'muted_group_ids': ['g1', 3, null],
      });
      expect(p.off, isEmpty);
      expect(p.mutedGroupIds, {'g1'});
      expect(
        NotificationPrefs.fromJson({'kinds': 5, 'muted_group_ids': 'x'}),
        const NotificationPrefs(),
      );
      expect(NotificationPrefs.fromJson(const {}), const NotificationPrefs());
    });

    test('W2-Y: the monthly summary is off unless the server says push: true', () {
      const summary = NotificationKind.summary;
      expect(const NotificationPrefs().isOn(summary, push), isFalse);
      expect(const NotificationPrefs().isOn(summary, NotificationChannel.inapp), isTrue);
      expect(
        const NotificationPrefs().kindsJson(),
        isEmpty,
        reason: 'off is the default: nothing to send',
      );
      final on = const NotificationPrefs().withKind(summary, push, on: true);
      expect(on.monthlySummary, isTrue);
      expect(on.kindsJson(), {
        'summary': {'push': true},
      });
      expect(NotificationPrefs.fromJson({'kinds': on.kindsJson()}), on);
      expect(
        NotificationPrefs.fromJson({
          'kinds': {
            'summary': {'push': 'yes'},
          },
        }).monthlySummary,
        isFalse,
      );
      final both = on
          .withKind(NotificationKind.payments, push, on: false)
          .withMuted('g1', muted: true);
      expect(both.monthlySummary, isTrue, reason: 'other changes keep it');
      expect(both.kindsJson(), {
        'payments': {'push': false},
        'summary': {'push': true},
      });
      expect(both.withKind(summary, push, on: false).kindsJson(), {
        'payments': {'push': false},
      });
      expect(on == const NotificationPrefs(), isFalse);
      expect(NotificationKind.switchable, isNot(contains(summary)));
      expect(NotificationKind.tryParse('summary'), summary);
    });

    test('equality compares both sets and differs when either differs', () {
      final a = const NotificationPrefs().withKind(NotificationKind.expenses, push, on: false);
      final b = const NotificationPrefs().withKind(NotificationKind.expenses, push, on: false);
      expect(a, b);
      expect(a == const NotificationPrefs(), isFalse);
      expect(a == a.withMuted('g', muted: true), isFalse);
      expect(a == Object(), isFalse);
    });
  });
}
