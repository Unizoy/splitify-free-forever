// Phase 14 (TC-32-09, TC-14-04, TC-32-07 on the device): A (e2e-a) uses the app, B (e2e-b) the API.
// A pulls the server's Frankfurter rates, then (rates server "offline") adds a USD expense with the
// currency picker, converts it to INR on the detail screen from the cached rates, and syncs: the server row
// carries the saved conversion, equal to an independent cross rate computed from the server's fx_rates rows.
// B records a USD payment through the API; the Balances tab's "In INR" view lists it as missing, "Convert
// all" converts it at its date's cached rate, and the converted nets equal a hand-written oracle.
//   flutter test integration_test/currencies_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json [--dart-define=PIN_HOST_IP=<ip resolved on the PC>]
// With `--dart-define=UI_HOLD=<s>` it holds each screen and prints `UI-CAPTURE <name>` for
// `.claude/skills/ui-review/scripts/capture_markers.ps1` (device UI review, G5).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/fx_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/fx_rates_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart' show FolderTabs;
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// Seconds each screen stays up for the host captures (`UI_HOLD`, 0 = no captures).
const _hold = int.fromEnvironment('UI_HOLD');

/// The server's rates, switchable "offline" (S-079 pattern): conversions must work from the cache.
class _SwitchRates implements FxRatesRemote {
  _SwitchRates(this.real);

  final FxRatesRemote real;
  bool online = true;

  @override
  Future<List<RemoteFxRate>> changedSince({
    required String? since,
    required String fromDate,
    int offset = 0,
    int limit = 1000,
  }) => online
      ? real.changedSince(since: since, fromDate: fromDate, offset: offset, limit: limit)
      : Future.error(const NetworkException('offline'));

  @override
  Future<List<RemoteFxRate>> between(Set<String> currencies, String from, String to) =>
      online ? real.between(currencies, from, to) : Future.error(const NetworkException('offline'));
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(WidgetTester t, Finder f, {int seconds = 20}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $f');
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 500));
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(FolderTabs), matching: find.text(label)).first;

/// Holds the screen for the host captures (real-time waits, never a tight pump loop: S-086 / phase 07).
Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(seconds: 1));
  if (_hold == 0) return;
  debugPrint('UI-CAPTURE $name');
  final end = DateTime.now().add(const Duration(seconds: _hold));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await t.pump();
  }
}

/// Independent cross rate from the server's rows (most recent date ≤ [date] with both currencies).
String _serverCrossRate(List<Map<String, dynamic>> rows, String from, String to, String date) {
  final byDate = <String, Map<String, String>>{};
  for (final r in rows) {
    final d = r['date']! as String;
    if (d.compareTo(date) > 0) continue;
    (byDate[d] ??= {})[(r['currency']! as String).trim()] = r['rate']! as String;
  }
  final days =
      byDate.keys.where((d) => byDate[d]!.containsKey(from) && byDate[d]!.containsKey(to)).toList()
        ..sort();
  final day = byDate[days.last]!;
  // rate(A→B) = eur[B] / eur[A], half away from zero to 10 decimals, done here with integers.
  BigInt scaled(String v) {
    final parts = v.split('.');
    final frac = (parts.length > 1 ? parts[1] : '').padRight(20, '0').substring(0, 20);
    return BigInt.parse(parts[0]) * BigInt.from(10).pow(20) + BigInt.parse(frac);
  }

  final num = scaled(day[to]!) * BigInt.from(10).pow(10);
  final den = scaled(day[from]!);
  final q = (num * BigInt.two + den) ~/ (den * BigInt.two);
  final s = q.toString().padLeft(11, '0');
  return '${s.substring(0, s.length - 10)}.${s.substring(s.length - 10)}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC-32-09 USD expense converted offline from cached rates; In INR + Convert all', (
    t,
  ) async {
    final env = devEnv();
    final services = await initRemote(env);
    await services.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
    final uidA = services.auth.currentUser!.id;
    final client = Supabase.instance.client;
    final db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final rates = _SwitchRates(SupabaseFxRatesRemote(client));
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(SupabaseRemoteApi.client(client)),
        balancesRemoteProvider.overrideWithValue(SupabaseBalancesRemote.fromClient(client)),
        groupsRemoteProvider.overrideWithValue(services.groups),
        authRepositoryProvider.overrideWithValue(services.auth),
        profileRemoteProvider.overrideWithValue(services.profiles),
        fxRatesRemoteProvider.overrideWithValue(rates),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(syncEngineProvider);
    Future<void> sync() => t.runAsync(() async {
      await engine.sync();
      await engine.sync();
    });

    final b = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-b')))!;

    // A creates an INR trip; B joins with the invite code.
    final gid = await container
        .read(groupsRepositoryProvider)
        .create(
          name: 'E2E Bali ${DateTime.now().millisecondsSinceEpoch}',
          ownerName: 'E2E A',
          ownerUserId: uidA,
          type: 'trip',
        );
    await sync();
    final code =
        (await t.runAsync(
              () => client.from('groups').select('invite_code').eq('id', gid).single(),
            ))!['invite_code']!
            as String;
    final joined = (await t.runAsync(() => b.rpc('join_group', {'code': code})))!;
    expect(joined['group_id'], gid);
    await sync();
    final rows = await (db.select(db.groupMembers)..where((m) => m.groupId.equals(gid))).get();
    final a = rows.firstWhere((m) => m.userId == uidA).id;
    final mb = rows.firstWhere((m) => m.userId == b.id).id;

    // The rate cache: one pull from the server, then the rates server goes "offline".
    final pulled = (await t.runAsync(
      () => container.read(fxRatesRepositoryProvider).refresh(force: true),
    ))!;
    expect(pulled, greaterThan(100), reason: 'rows pulled');
    rates.online = false;

    // The app, signed in as A: add a USD expense with the currency picker.
    final router = buildRouter(initialLocation: Routes.group(gid));
    addTearDown(router.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    await _pumpFor(t, const Duration(seconds: 2));
    router.go(ExpenseRoutes.add(gid));
    await _waitFor(t, find.byKey(const Key('expense-amount')));
    await _tap(t, find.text('INR'));
    await _waitFor(t, find.byKey(const Key('currency-search')));
    await _capture(t, 'currency-picker');
    await t.enterText(find.byKey(const Key('currency-search')), 'USD');
    await _pumpFor(t, const Duration(milliseconds: 500));
    await _tap(t, find.byKey(const Key('currency-found-USD')));
    await t.enterText(
      find.descendant(
        of: find.byKey(const Key('expense-amount')),
        matching: find.byType(TextField),
      ),
      '120',
    );
    await t.enterText(
      find.descendant(
        of: find.byKey(const Key('expense-description')),
        matching: find.byType(TextField),
      ),
      'Surf lessons',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await _pumpFor(t, const Duration(milliseconds: 500));
    await _capture(t, 'expense-amount-usd');
    await _tap(t, find.byKey(const Key('expense-save')));
    await _pumpFor(t, const Duration(seconds: 2));
    final saved = await (db.select(db.expenses)..where((e) => e.groupId.equals(gid))).getSingle();
    expect(saved.currency.trim(), 'USD');
    expect(saved.total, 12000);
    expect(saved.fxRate, isNull);

    // Convert it on the detail screen from the cached rate (rates server still offline).
    router.go(ExpenseRoutes.detail(saved.id));
    await _waitFor(t, find.byKey(const Key('conversion-tile')));
    await _capture(t, 'expense-detail-not-converted');
    await _tap(t, find.byKey(const Key('conversion-tile')));
    await _waitFor(t, find.byKey(const Key('conversion-save')));
    await _pumpFor(t, const Duration(seconds: 1));
    await _capture(t, 'conversion-sheet');
    await _tap(t, find.byKey(const Key('conversion-save')));
    await _waitFor(t, find.byKey(const Key('conversion-tile-amount')));
    await _capture(t, 'expense-detail-converted');
    await sync();

    // Server row = independent cross rate from the server's fx_rates rows.
    final server = (await t.runAsync(
      () => client
          .from('expenses')
          .select('total,currency,fx_rate::text,fx_rate_date,fx_source,fx_currency,fx_total')
          .eq('id', saved.id)
          .single(),
    ))!;
    final date = saved.date.substring(0, 10);
    final serverRates = (await t.runAsync(
      () => client
          .from('fx_rates')
          .select('date,currency,rate::text')
          .inFilter('currency', ['USD', 'INR'])
          .lte('date', date)
          .gte(
            'date',
            DateTime.parse(date)
                .subtract(const Duration(days: 10))
                .toIso8601String()
                .substring(0, 10),
          ),
    ))!;
    final expected = _serverCrossRate(serverRates, 'USD', 'INR', date);
    expect(parseRate(server['fx_rate']! as String), parseRate(expected));
    expect(server['fx_source'], 'frankfurter');
    expect((server['fx_currency']! as String).trim(), 'INR');
    expect(server['fx_total'], convert(12000, 'USD', 'INR', expected));

    // B records a USD payment of $20 to A through the API (no conversion).
    final paymentId = newId();
    final r = (await t.runAsync(
      () => b.rpc('apply_mutations', {
        'batch': [
          {
            'mutation_id': newId(),
            'entity': 'payment',
            'op': 'upsert',
            'id': paymentId,
            'group_id': gid,
            'client_updated_at': DateTime.now().toUtc().toIso8601String(),
            'source': 'app',
            'data': {
              'from_member': mb,
              'to_member': a,
              'amount': 2000,
              'currency': 'USD',
              'date': date,
              'method': 'cash',
            },
          },
        ],
      }),
    ))!;
    expect(((r['results']! as List).single! as Map)['status'], 'applied', reason: '$r');
    await sync();

    // Balances → "In INR": the payment needs a rate; Convert all uses the cached one.
    router.go(Routes.group(gid));
    await _waitFor(t, find.byKey(const Key('group-settle')));
    await _tap(t, _tab('Balances'));
    await _waitFor(t, find.byKey(const Key('balances-view-toggle')));
    await _capture(t, 'balances-by-currency');
    await _tap(t, find.text('In INR'));
    await _waitFor(t, find.byKey(const Key('convert-all')));
    await _capture(t, 'balances-in-inr-missing');
    await _tap(t, find.byKey(const Key('convert-all')));
    await _waitFor(t, find.byKey(const Key('converted-balances')));
    await _capture(t, 'balances-in-inr');
    await sync();

    final pay = (await t.runAsync(
      () => client.from('payments').select('fx_amount,fx_rate::text').eq('id', paymentId).single(),
    ))!;
    expect(pay['fx_amount'], convert(2000, 'USD', 'INR', expected));

    // Oracle in INR: A paid the whole $120 (split equally: $60 each → in INR the converted halves, the odd
    // unit to A, the first in fixed order); then B paid A $20. B's net = −B's converted share + payment.
    final fxTotal = convert(12000, 'USD', 'INR', expected);
    final bNet = -(fxTotal ~/ 2) + convert(2000, 'USD', 'INR', expected);
    final bRow = find.byKey(Key('converted-net-$mb'));
    await t.ensureVisible(bRow);
    expect(
      find.descendant(of: bRow, matching: find.textContaining(listMoney(bNet.abs(), 'INR'))),
      findsOneWidget,
    );

    // Tidy up the dev project: soft-delete the test group (creator only, restorable).
    await container.read(groupsRepositoryProvider).delete(gid, gid);
    await sync();
    await t.runAsync(b.dispose);
    router.go(Routes.groups);
    await _pumpFor(t, const Duration(seconds: 1));
    await t.pumpWidget(const SizedBox());
  });
}
