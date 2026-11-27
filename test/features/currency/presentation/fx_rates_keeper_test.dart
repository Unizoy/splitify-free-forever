// TC-32-03: the exchange-rate cache refreshes after a successful sync while the signed-in shell is shown.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/fx_providers.dart';
import 'package:splitify/data/repositories/fx_rates_repository.dart';
import 'package:splitify/features/balances/application/balances_providers.dart'
    show lastSyncProvider;
import 'package:splitify/features/currency/application/currency_providers.dart';
import 'package:splitify/features/currency/presentation/fx_rates_keeper.dart';

import '../../../support/fakes.dart';
import '../currency_harness.dart';

class _LastSync extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void set(DateTime? v) => state = v;
}

final _lastSync = NotifierProvider<_LastSync, DateTime?>(_LastSync.new);

/// The database closes under a refresh in flight (sign-out / sign-in wipe): drift throws a StateError.
class _ClosedDbRates extends FxRatesRepository {
  _ClosedDbRates(super.db, super.remote, super.clock);

  int calls = 0;

  @override
  Future<int?> refresh({bool force = false}) {
    calls++;
    return Future.error(
      StateError('Tried to send Request over isolate channel, but the connection was closed!'),
    );
  }
}

void main() {
  late FakeFxRemote remote;
  late ProviderContainer container;

  setUp(() async {
    final db = testDb();
    addTearDown(db.close);
    remote = FakeFxRemote();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...dbOverrides(db, remote, lastSync: false),
        lastSyncProvider.overrideWith((ref) => ref.watch(_lastSync)),
      ],
    );
    addTearDown(container.dispose);
  });

  group('fxAutoRefreshProvider', () {
    // TC-32-03
    test('does nothing before the first sync', () async {
      container.listen(fxAutoRefreshProvider, (_, _) {});
      await pumpEventQueue();
      expect(remote.changedSinceCalls, 0);
    });

    // TC-32-03
    test('refreshes right away when a sync already happened', () async {
      container.read(_lastSync.notifier).set(DateTime.utc(2026, 11, 22, 8));
      container.listen(fxAutoRefreshProvider, (_, _) {});
      await pumpEventQueue();
      expect(remote.changedSinceCalls, 1);
    });

    // TC-32-03
    test('refreshes after a sync finishes; a second sync within 6 hours pulls nothing', () async {
      container.listen(fxAutoRefreshProvider, (_, _) {});
      await pumpEventQueue();
      expect(remote.changedSinceCalls, 0);

      container.read(_lastSync.notifier).set(DateTime.utc(2026, 11, 22, 8));
      await pumpEventQueue();
      expect(remote.changedSinceCalls, 1);

      container.read(_lastSync.notifier).set(DateTime.utc(2026, 11, 22, 8, 5));
      await pumpEventQueue();
      expect(remote.changedSinceCalls, 1);
    });

    // Final QA (S-412): seen on the device — the sign-in wipe closed the database under a refresh and the
    // unawaited StateError surfaced as an uncaught error.
    test('a database closed under the refresh is not an error', () async {
      final db = testDb();
      addTearDown(db.close);
      final rates = _ClosedDbRates(db, FakeFxRemote(), FakeClock(DateTime.utc(2026, 11, 22, 12)));
      final c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          fxRatesRepositoryProvider.overrideWithValue(rates),
          lastSyncProvider.overrideWithValue(DateTime.utc(2026, 11, 22, 8)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(fxAutoRefreshProvider, (_, _) {});
      await pumpEventQueue();
      expect(rates.calls, 1);
    });

    // TC-32-03
    test('an offline server leaves the cache alone without failing', () async {
      remote.error = Exception('offline');
      container.read(_lastSync.notifier).set(DateTime.utc(2026, 11, 22, 8));
      container.listen(fxAutoRefreshProvider, (_, _) {});
      await pumpEventQueue();
      expect(remote.changedSinceCalls, 1);
    });
  });

  group('FxRatesKeeper', () {
    // TC-32-03
    testWidgets('shows its child and keeps the refresh running', (t) async {
      final db = testDb();
      addTearDown(
        () => t.runAsync(() => db.close().timeout(const Duration(seconds: 3), onTimeout: () {})),
      );
      final server = FakeFxRemote();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            ...dbOverrides(db, server, lastSync: false),
            lastSyncProvider.overrideWithValue(DateTime.utc(2026, 11, 22, 8)),
          ],
          child: const MaterialApp(
            home: FxRatesKeeper(child: Text('shell', textDirection: TextDirection.ltr)),
          ),
        ),
      );
      await t.pump();
      expect(find.text('shell'), findsOneWidget);
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump();
      expect(server.changedSinceCalls, 1);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 50));
    });
  });
}
