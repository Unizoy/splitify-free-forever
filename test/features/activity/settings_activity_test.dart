// TC-17-03 (simplify debts is logged), TC-18-02 (feed sentences): `settings_changed` rows refined into
// simplify on / off / default split, for server rows and for my own pending change.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/activity_repository.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/application/settings_activity.dart';
import 'package:splitify/features/activity/presentation/activity_feed.dart';
import 'package:splitify/l10n/app_localizations_en.dart';

import '../../support/ledger_seed.dart';
import '../balances/balance_fixtures.dart' show activityAsha, activityMe, activityOf;

ActivitySources _sources({
  List<LocalActivity> activity = const [],
  List<OutboxItem> pending = const [],
  bool newGroup = false,
}) => ActivitySources(
  activity: activity,
  pending: pending,
  groups: {'g1': seedGroup(seq: newGroup ? 0 : 1)},
  members: {
    'm1': seedMember('m1', userId: 'u1', name: 'Mohit'),
    'm2': seedMember('m2', userId: 'u2', name: 'Asha', position: 1),
  },
  expenses: const {},
  payments: const {},
);

void main() {
  group('refineActivityType', () {
    // TC-17-03
    test('simplify_debts maps to on or off by the new value', () {
      expect(
        refineActivityType('settings_changed', {
          'setting': 'simplify_debts',
          'simplify_debts': true,
        }),
        'settings_simplify_on',
      );
      expect(
        refineActivityType('settings_changed', {
          'setting': 'simplify_debts',
          'simplify_debts': false,
        }),
        'settings_simplify_off',
      );
    });

    // TC-17-03
    test('a missing or odd value counts as off', () {
      expect(
        refineActivityType('settings_changed', {'setting': 'simplify_debts'}),
        'settings_simplify_off',
      );
      expect(
        refineActivityType('settings_changed', {
          'setting': 'simplify_debts',
          'simplify_debts': 'yes',
        }),
        'settings_simplify_off',
      );
    });

    // TC-17-03
    test('default_split maps to its own type', () {
      expect(
        refineActivityType('settings_changed', {'setting': 'default_split'}),
        'settings_default_split',
      );
    });

    // TC-17-03
    test('an unknown setting, or no setting, stays settings_changed', () {
      expect(refineActivityType('settings_changed', {'setting': 'colour'}), 'settings_changed');
      expect(refineActivityType('settings_changed', const {}), 'settings_changed');
    });

    // TC-17-03
    test('other activity types pass through untouched', () {
      expect(refineActivityType('expense_added', {'setting': 'simplify_debts'}), 'expense_added');
      expect(refineActivityType('group_updated', const {}), 'group_updated');
    });

    // TC-17-03
    test('simplifyActivityType names the two types', () {
      expect(simplifyActivityType(on: true), 'settings_simplify_on');
      expect(simplifyActivityType(on: false), 'settings_simplify_off');
    });
  });

  group('activitySentence', () {
    final l = AppLocalizationsEn();
    String s(String type, {ActivityPerson actor = activityMe}) =>
        activitySentence(l, activityOf(type, actor: actor));

    // TC-18-02
    test('simplify on / off and default split have their own sentences', () {
      expect(s('settings_simplify_on'), 'You turned on simplify debts');
      expect(s('settings_simplify_off'), 'You turned off simplify debts');
      expect(s('settings_default_split'), 'You changed the default split');
      expect(s('settings_simplify_on', actor: activityAsha), 'Asha Rao turned on simplify debts');
      expect(s('settings_simplify_off', actor: activityAsha), 'Asha Rao turned off simplify debts');
      expect(
        s('settings_default_split', actor: activityAsha),
        'Asha Rao changed the default split',
      );
    });

    // TC-18-02
    test('an unrefined settings_changed row keeps the general sentence', () {
      expect(s('settings_changed'), 'You changed the group settings');
    });

    // TC-18-02
    test('the new types show under the Groups filter', () {
      for (final t in ['settings_simplify_on', 'settings_simplify_off', 'settings_default_split']) {
        expect(ActivityItem.filterOf(t), ActivityFilter.groups, reason: t);
      }
    });
  });

  group('buildActivityItems', () {
    // TC-17-03
    test('a server settings_changed row becomes a simplify row', () {
      final items = buildActivityItems(
        _sources(
          activity: [
            seedActivity(
              'a1',
              'settings_changed',
              actorMemberId: 'm2',
              actorUserId: 'u2',
              targetType: 'group',
              targetId: 'g1',
              data: {'setting': 'simplify_debts', 'simplify_debts': true},
            ),
          ],
        ),
        'u1',
      );
      expect(items.single.type, 'settings_simplify_on');
      expect(items.single.actor.name, 'Asha');
      expect(items.single.pending, isFalse);
    });

    // TC-17-03
    test('my pending group upsert with only simplify_debts maps to settings_simplify_on / off', () {
      for (final (on, type) in [(true, 'settings_simplify_on'), (false, 'settings_simplify_off')]) {
        final items = buildActivityItems(
          _sources(
            pending: [
              seedOutbox(3, 'group', 'upsert', 'g1', payload: {'simplify_debts': on}),
            ],
          ),
          'u1',
        );
        expect(items.single.type, type);
        expect(items.single.pending, isTrue);
        expect(items.single.actor.isMe, isTrue);
        expect(items.single.groupName, 'Goa trip');
      }
    });

    // TC-17-03
    test('a pending group edit that also changes something else is a general group update', () {
      final items = buildActivityItems(
        _sources(
          pending: [
            seedOutbox(
              3,
              'group',
              'upsert',
              'g1',
              payload: {'simplify_debts': true, 'name': 'Goa 2026'},
            ),
          ],
        ),
        'u1',
      );
      expect(items.single.type, 'group_updated');
    });

    // TC-17-03
    test('a group that is not on the server yet is a creation, not a simplify change', () {
      final items = buildActivityItems(
        _sources(
          newGroup: true,
          pending: [
            seedOutbox(3, 'group', 'upsert', 'g1', payload: {'simplify_debts': true}),
          ],
        ),
        'u1',
      );
      expect(items.single.type, 'group_created');
    });
  });
}
