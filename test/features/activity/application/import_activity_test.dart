import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/activity_repository.dart';
import 'package:splitify/data/repositories/import_repository.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/application/settings_activity.dart';

import '../../../support/ledger_seed.dart';

ActivitySources _sources(List<OutboxItem> pending) => ActivitySources(
  activity: const [],
  pending: pending,
  groups: {'g1': seedGroup()},
  members: {'m1': seedMember('m1', userId: 'u1', name: 'Mohit')},
  expenses: const {},
  payments: const {},
);

void main() {
  group('refineActivityType', () {
    test('import_completed + undone becomes import_undone', () {
      expect(refineActivityType('import_completed', {'undone': true}), 'import_undone');
    });

    test('import_completed from a Splitify file', () {
      expect(
        refineActivityType('import_completed', {'source': 'splitify'}),
        'import_completed_file',
      );
    });

    test('a plain import_completed is unchanged', () {
      expect(refineActivityType('import_completed', {}), 'import_completed');
      expect(refineActivityType('import_completed', {'source': 'splitwise'}), 'import_completed');
      expect(refineActivityType('import_completed', {'undone': false}), 'import_completed');
    });

    test('other types are unchanged', () {
      expect(refineActivityType('expense_added', {'undone': true}), 'expense_added');
    });

    test('undone wins over a Splitify source', () {
      expect(
        refineActivityType('import_completed', {'undone': true, 'source': 'splitify'}),
        'import_undone',
      );
    });

    test('import types land in the expenses chip', () {
      expect(ActivityItem.filterOf('import_undone'), ActivityFilter.expenses);
      expect(ActivityItem.filterOf('import_completed_file'), ActivityFilter.expenses);
    });
  });

  group('buildActivityItems with pending import rows', () {
    test('rows with source import and no note are skipped', () {
      final items = buildActivityItems(
        _sources([
          seedOutbox(
            1,
            'expense',
            'upsert',
            'e1',
            payload: {'source': 'import', 'split_values': <String, Object?>{}},
          ),
          seedOutbox(2, 'payment', 'upsert', 'p1', payload: {'source': 'import'}),
        ]),
        'u1',
      );
      expect(items, isEmpty);
    });

    test('the summary row becomes one pending import_completed', () {
      final items = buildActivityItems(
        _sources([
          seedOutbox(1, 'expense', 'upsert', 'e1', payload: {'source': 'import'}),
          seedOutbox(
            2,
            'expense',
            'upsert',
            'e2',
            payload: {
              'source': 'import',
              'split_values': {
                importSummaryKey: {'source': 'splitwise', 'expenses': 3},
              },
            },
          ),
        ]),
        'u1',
      );
      final i = items.single;
      expect(i.type, 'import_completed');
      expect(i.pending, isTrue);
      expect(i.id, 'pending-2');
      expect(i.actor.isMe, isTrue);
      expect((i.targetType, i.targetId), ('group', 'g1'));
      expect(i.filter, ActivityFilter.expenses);
    });

    test('a Splitify file summary is import_completed_file', () {
      final i = buildActivityItems(
        _sources([
          seedOutbox(
            1,
            'expense',
            'upsert',
            'e2',
            payload: {
              'source': 'import',
              'split_values': {
                importSummaryKey: {'source': 'splitify'},
              },
            },
          ),
        ]),
        'u1',
      ).single;
      expect(i.type, 'import_completed_file');
      expect(i.pending, isTrue);
    });

    test('the undo note becomes import_undone', () {
      final i = buildActivityItems(
        _sources([
          seedOutbox(
            1,
            'expense',
            'delete',
            'e2',
            payload: {
              'source': 'import',
              'split_values': {importUndoKey: 'batch-1'},
            },
          ),
        ]),
        'u1',
      ).single;
      expect(i.type, 'import_undone');
      expect(i.pending, isTrue);
    });

    test('ordinary pending rows still appear', () {
      final items = buildActivityItems(
        _sources([
          seedOutbox(1, 'expense', 'upsert', 'e1', payload: {'source': 'import'}),
          seedOutbox(
            2,
            'expense',
            'upsert',
            'e9',
            payload: {'description': 'Chai', 'total': 40, 'currency': 'INR'},
          ),
        ]),
        'u1',
      );
      expect(items.single.type, 'expense_added');
      expect(items.single.description, 'Chai');
    });
  });
}
