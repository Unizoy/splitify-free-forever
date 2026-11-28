import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/stream_ext.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';

import '../../support/fakes.dart';
import '../../support/ledger_seed.dart';

void main() {
  group('distinctRows', () {
    test('drops a list equal to the previous one and passes changed ones', () async {
      final source = Stream.fromIterable([
        [1, 2],
        [1, 2],
        [1, 2, 3],
        [1, 2, 3],
        <int>[],
        <int>[],
        [1, 2],
      ]);
      expect(await source.distinctRows().toList(), [
        [1, 2],
        [1, 2, 3],
        <int>[],
        [1, 2],
      ]);
    });

    test('compares elements by value', () async {
      final a = seedMember('m1');
      final b = seedMember('m1');
      expect(identical(a, b), isFalse);
      final out = await Stream.fromIterable([
        [a],
        [b],
        [seedMember('m1', name: 'Other')],
      ]).distinctRows().toList();
      expect(out, hasLength(2));
    });
  });

  group('asyncMapLatest', () {
    late StreamController<int> source;
    late List<int> calls;
    late List<Completer<String>> pending;
    late List<String> values;
    late List<Object> errors;
    late bool done;
    late StreamSubscription<String> sub;

    Future<String> load(int event) {
      calls.add(event);
      final c = Completer<String>();
      pending.add(c);
      return c.future;
    }

    void listen() {
      sub = source.stream
          .asyncMapLatest(load)
          .listen(values.add, onError: errors.add, onDone: () => done = true);
    }

    setUp(() {
      source = StreamController<int>();
      calls = [];
      pending = [];
      values = [];
      errors = [];
      done = false;
    });

    tearDown(() async {
      await sub.cancel();
      if (!source.isClosed) await source.close();
    });

    test(
      'five events during one slow load cause exactly two loads, the second with the last',
      () async {
        listen();
        source.add(1);
        await pumpEventQueue();
        expect(calls, [1]);

        source
          ..add(2)
          ..add(3)
          ..add(4)
          ..add(5);
        await pumpEventQueue();
        expect(calls, [1], reason: 'no second load while the first runs');

        pending[0].complete('one');
        await pumpEventQueue();
        expect(values, ['one']);
        expect(calls, [1, 5]);

        pending[1].complete('five');
        await pumpEventQueue();
        expect(values, ['one', 'five']);
        expect(calls, [1, 5]);
      },
    );

    test('an event after the loads finished starts a fresh load', () async {
      listen();
      source.add(1);
      await pumpEventQueue();
      pending[0].complete('one');
      await pumpEventQueue();
      source.add(2);
      await pumpEventQueue();
      expect(calls, [1, 2]);
      pending[1].complete('two');
      await pumpEventQueue();
      expect(values, ['one', 'two']);
    });

    test('a load error arrives as a stream error and later events still load', () async {
      listen();
      source.add(1);
      await pumpEventQueue();
      pending[0].completeError(StateError('boom'));
      await pumpEventQueue();
      expect(errors.single, isA<StateError>());
      expect(values, isEmpty);

      source.add(2);
      await pumpEventQueue();
      expect(calls, [1, 2]);
      pending[1].complete('two');
      await pumpEventQueue();
      expect(values, ['two']);
    });

    test('an error thrown synchronously by load is also a stream error', () async {
      final out = <Object>[];
      final s = source.stream
          .asyncMapLatest<String>((e) => throw ArgumentError('bad $e'))
          .listen((_) {}, onError: out.add);
      source.add(1);
      await pumpEventQueue();
      expect(out.single, isA<ArgumentError>());
      await s.cancel();
    });

    test('a source error is forwarded', () async {
      listen();
      source.addError('src');
      await pumpEventQueue();
      expect(errors, ['src']);
    });

    test('source done closes the output after the running load, which still delivers', () async {
      listen();
      source.add(1);
      await pumpEventQueue();
      source
        ..add(2)
        ..add(3);
      await source.close();
      await pumpEventQueue();
      expect(done, isFalse, reason: 'a load is still running');

      pending[0].complete('one');
      await pumpEventQueue();
      expect(done, isFalse, reason: 'the coalesced load still has to run');
      expect(calls, [1, 3]);

      pending[1].complete('three');
      await pumpEventQueue();
      expect(values, ['one', 'three']);
      expect(done, isTrue);
    });

    test('source done with no load running closes at once', () async {
      listen();
      await source.close();
      await pumpEventQueue();
      expect(done, isTrue);
      expect(calls, isEmpty);
    });

    test('cancel while idle stops loads', () async {
      listen();
      source.add(1);
      await pumpEventQueue();
      pending[0].complete('one');
      await pumpEventQueue();
      await sub.cancel();
      expect(source.hasListener, isFalse);
      source.add(2);
      await pumpEventQueue();
      expect(calls, [1]);
      expect(values, ['one']);
    });

    test('cancel during a load delivers nothing from it', () async {
      listen();
      source.add(1);
      await pumpEventQueue();
      await sub.cancel();
      pending[0].complete('one');
      await pumpEventQueue();
      expect(values, isEmpty);
      expect(source.hasListener, isFalse);
    });
  });

  group('GroupLedger equality', () {
    GroupLedger ledger({
      String name = 'Goa trip',
      int payments = 1,
      int expenseTotal = 100,
      List<String> memberIds = const ['m1', 'm2'],
    }) => GroupLedger(
      group: seedGroup(name: name),
      members: [for (final id in memberIds) seedMember(id)],
      expenses: [
        seedExpense(
          'e1',
          total: expenseTotal,
          payers: {'m1': expenseTotal},
          shares: {'m2': expenseTotal},
        ),
      ],
      payments: [
        for (var i = 0; i < payments; i++) seedPayment('p$i', from: 'm2', to: 'm1', amount: 10),
      ],
    );

    test('two ledgers built from equal rows are equal and share a hash code', () {
      final a = ledger();
      final b = ledger();
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a changed group, member list, expense or payment makes them differ', () {
      final base = ledger();
      expect(base, isNot(ledger(name: 'Renamed')));
      expect(base, isNot(ledger(payments: 2)));
      expect(base, isNot(ledger(expenseTotal: 200)));
      expect(base, isNot(ledger(memberIds: ['m1'])));
      expect(base == Object(), isFalse);
    });

    test('distinct() on a stream of equal ledgers drops repeats', () async {
      final out = await Stream.fromIterable([ledger(), ledger(), ledger(payments: 2)])
          .distinct()
          .toList();
      expect(out, hasLength(2));
    });

    test('watchGroup sends nothing new for a write to another group', () async {
      final db = testDb();
      addTearDown(db.close);
      await db.seed(
        groups: [
          seedGroup(),
          seedGroup(id: 'g2', name: 'Flat'),
        ],
        members: [
          seedMember('m1'),
          seedMember('x1', groupId: 'g2'),
        ],
      );
      final seen = <GroupLedger?>[];
      final sub = LedgerRepository(db).watchGroup('g1').listen(seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(seen, hasLength(1));

      await db.seed(
        expenses: [
          seedExpense('e9', groupId: 'g2', total: 50, payers: {'x1': 50}, shares: {'x1': 50}),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(seen, hasLength(1), reason: 'the re-run read equal rows');

      await db.seed(
        expenses: [
          seedExpense('e1', total: 70, payers: {'m1': 70}, shares: {'m1': 70}),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(seen, hasLength(2));
      expect(seen.last!.expenses.single.id, 'e1');
      await sub.cancel();
    });
  });
}
