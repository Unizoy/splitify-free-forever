// Final QA pass #2 on the emulator (S-250..S-259): regression tests for the defects found on the device.
import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/app/not_found_screen.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/core/utils/member_tints.dart';
import 'package:splitify/data/data_providers.dart' show networkStatusProvider;
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/network_status.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/data/sync/uploads.dart' show UploadQueue;
import 'package:splitify/features/activity/presentation/activity_feed.dart' show activityDay;
import 'package:splitify/features/currency/application/conversion_controller.dart'
    show rateFieldText;
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/sync/application/sync_texts.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../support/a11y_guidelines.dart';
import '../balances/balance_fixtures.dart' as bal;
import '../expenses/expense_fixtures.dart' hide sampleGroup;
import '../../support/group_fakes.dart';
import '../../support/group_harness.dart';
import '../../support/quiet_sync.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
  theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  group('S-250 app links', () {
    test('splitify://<page> opens /<page>; group is an alias; bare / goes to Groups', () {
      expect(linkRedirect(Uri.parse('splitify://notifications')), '/notifications');
      expect(linkRedirect(Uri.parse('splitify://group/abc')), '/groups/abc');
      expect(
        linkRedirect(Uri.parse('splitify://groups/abc?tab=balances')),
        '/groups/abc?tab=balances',
      );
      expect(linkRedirect(Uri.parse('splitify://join?code=ABCDEFGH')), '/join?code=ABCDEFGH');
      // The payment bubble is not in this build (D-030): its old link is just an unknown page.
      expect(linkRedirect(Uri.parse('splitify://capture?id=c1')), '/capture?id=c1');
      expect(linkRedirect(Uri.parse('/')), Routes.groups);
      expect(linkRedirect(Uri.parse('/groups')), isNull);
      // The debug sign-in link keeps its own handling.
      expect(linkRedirect(Uri.parse('splitify://dev/login?user=e2e-a')), isNull);
      expect(authRedirect(Uri.parse('/'), signedIn: false), Routes.groups);
    });

    testWidgets('an unknown page shows the friendly page whose button leads to Groups', (
      tester,
    ) async {
      final h = await pumpGroups(tester, '/groups', overrides: fixedGroupData());
      h.open('/no-such-page');
      await settle(tester);
      expect(find.byType(NotFoundScreen), findsOneWidget);
      expect(find.text("This link doesn't open anything"), findsOneWidget);
      await tester.tap(find.byKey(const Key('not-found-home')));
      await settle(tester);
      expect(h.location, '/groups');
    });

    testWidgets('an old payment-bubble link shows the friendly page (D-030)', (tester) async {
      final h = await pumpGroups(tester, '/groups', overrides: fixedGroupData());
      h.open(linkRedirect(Uri.parse('splitify://capture?id=c1&group=g1'))!);
      await settle(tester);
      expect(find.byType(NotFoundScreen), findsOneWidget);
      h.open('/account/payment-bubble');
      await settle(tester);
      expect(find.byType(NotFoundScreen), findsOneWidget);
    });
  });

  testWidgets('S-250 the Groups bell opens Notifications (it said "Coming soon")', (tester) async {
    final h = await pumpGroups(tester, '/groups', overrides: fixedGroupData());
    await tester.tap(find.byKey(const Key('groups-bell')));
    await settle(tester);
    expect(h.location, '/notifications');
    expect(find.text('Coming soon'), findsNothing);
  });

  group('S-258 accessibility services can press every button', () {
    testWidgets('the guideline fails a button whose tap was excluded with its semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Material(
            child: Semantics(
              button: true,
              label: 'Get started',
              excludeSemantics: true,
              child: InkWell(onTap: () {}, child: const SizedBox.square(dimension: 48)),
            ),
          ),
        ),
      );
      final result = await buttonsHaveTapGuideline.evaluate(tester);
      expect(result.passed, isFalse);
      handle.dispose();
    });

    testWidgets('DashedCircleButton, HeroIconButton and the nav bar can be pressed', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: [
                DashedCircleButton(label: 'Get\nstarted', onPressed: () => taps++),
                HeroIconButton(
                  icon: AppIcons.bell,
                  tooltip: 'Notifications',
                  onPressed: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(buttonsHaveTapGuideline));
      final node = tester.getSemantics(find.bySemanticsLabel('Get started'));
      tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });
  });

  group('S-253 text fields', () {
    testWidgets('e-mail, number and code fields are not capitalised or autocorrected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: Column(
              children: [
                UnderlineField(
                  key: Key('mail'),
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                UnderlineField(
                  key: Key('code'),
                  label: 'Code',
                  keyboardType: TextInputType.visiblePassword,
                ),
                UnderlineField(key: Key('note'), label: 'Note'),
              ],
            ),
          ),
        ),
      );
      TextField field(String key) => tester.widget<TextField>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)),
      );
      expect(field('mail').textCapitalization, TextCapitalization.none);
      expect(field('mail').autocorrect, isFalse);
      expect(field('code').textCapitalization, TextCapitalization.none);
      expect(field('note').textCapitalization, TextCapitalization.sentences);
      expect(field('note').autocorrect, isTrue);
    });
  });

  group('S-256 messages from sheets', () {
    testWidgets('inside a sheet the message shows above it; on a page it is a snackbar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showAppMessage(context, 'On the page'),
                    child: const Text('page'),
                  ),
                  TextButton(
                    onPressed: () => showAppSheet<void>(
                      context,
                      title: 'Invite people',
                      builder: (sheet) => TextButton(
                        onPressed: () => showAppMessage(sheet, 'Code copied'),
                        child: const Text('copy'),
                      ),
                    ),
                    child: const Text('sheet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('page'));
      await tester.pump();
      expect(find.widgetWithText(SnackBar, 'On the page'), findsOneWidget);
      await tester.tap(find.text('sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('copy'));
      await tester.pump();
      expect(find.byKey(const Key('sheet-toast')), findsOneWidget);
      expect(find.text('Code copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('sheet-toast')), findsNothing);
    });
  });

  group('S-255 status bar over a scrolled sheet', () {
    testWidgets('no scrim while the hero is under the status bar, page colour once the sheet is', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: OverlapColumn(
                top: const SizedBox(height: 300),
                bottom: const OverlapSheet(child: SizedBox(height: 1600)),
              ),
            ),
          ),
        ),
      );
      final bg = AppTheme.light().extension<AppColors>()!.bg;
      final column = find.byType(OverlapColumn);
      expect(column, isNot(paints..rect(color: bg)));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pump();
      // In the column's own coordinates the screen top is 500 px down (the page scrolled 500 px).
      expect(column, paints..rect(rect: const Rect.fromLTWH(0, 500, 400, 24), color: bg));
    });
  });

  group('S-251/S-252 people look and read the same everywhere', () {
    tearDown(MemberTints.clear);

    testWidgets('an avatar that only knows the member id uses the member’s chosen colour', (
      tester,
    ) async {
      MemberTints.remember([(id: 'm-rahul', tint: 1)]);
      late Color byId;
      late Color chosen;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              byId = Avatar.tintFor(context, 'm-rahul').bg;
              chosen = Avatar.tintFor(context, 'other', 1).bg;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(byId, chosen);
    });

    test('expense rows follow the group’s member order', () {
      final members = [
        sampleMember(id: 'm-me', userId: 'u1', name: 'Me'),
        sampleMember(id: 'm-rahul', name: 'Rahul', position: 1),
        sampleMember(id: 'm-vikram', name: 'Vikram', position: 2),
      ];
      final e = sampleExpense(
        total: 300,
        payers: const {'m-me': 300},
        shares: const {'m-vikram': 100, 'm-me': 100, 'm-rahul': 100},
      );
      final v = expenseViews([e], members, 'u1').single;
      expect(v.owed.keys, ['m-me', 'm-rahul', 'm-vikram']);
    });
  });

  group('final QA follow-ups from the text pass', () {
    test('a stopped photo upload is not "Everything is synced"', () {
      final l = lookupAppLocalizations(const Locale('en'));
      const synced = SyncStatus(phase: SyncPhase.idle);
      const stopped = SyncUpload(
        id: 'p1',
        bucket: 'receipts',
        recordId: 'e1',
        attempts: UploadQueue.skipAfter,
      );
      const waiting = SyncUpload(id: 'p2', bucket: 'receipts', recordId: 'e2', attempts: 1);
      expect(describeSync(l, synced).title, l.syncStateSynced);
      final head = describeSync(l, synced, uploads: const [stopped, waiting]);
      expect(head.title, '1 photo stopped uploading');
      expect(head.tone, SyncTone.problem);
      expect(describeSync(l, synced, uploads: const [waiting]).title, '1 photo waiting to upload');
      expect(syncRowValue(l, synced, uploads: const [stopped]), '1 photo stopped');
      expect(syncRowValue(l, synced, uploads: const [waiting]), l.syncRowSynced);
    });

    testWidgets('Delete my account is a red (danger) button; disabled until armed', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              PillButton(
                key: const Key('on'),
                label: 'Delete my account',
                variant: PillVariant.danger,
                onPressed: () {},
              ),
              const PillButton(
                key: Key('off'),
                label: 'Delete my account',
                variant: PillVariant.danger,
                onPressed: null,
              ),
            ],
          ),
        ),
      );
      Color fill(String key) => tester
          .widget<Material>(
            find.descendant(of: find.byKey(Key(key)), matching: find.byType(Material)).first,
          )
          .color!;
      final c = AppTheme.light().extension<AppColors>()!;
      expect(fill('on'), c.oweText);
      expect(fill('off'), c.chip);
    });

    testWidgets('the Google button carries the four-colour G', (tester) async {
      await tester.pumpWidget(
        _app(
          PillButton(
            label: 'Continue with Google',
            leading: const GoogleMark(),
            variant: PillVariant.outline,
            onPressed: () {},
          ),
        ),
      );
      final mark = find.byType(GoogleMark);
      expect(mark, findsOneWidget);
      expect(tester.getSize(mark), const Size(20, 20));
      expect(
        find.descendant(of: mark, matching: find.byType(CustomPaint)),
        paints
          ..path(color: AppPalette.googleRed)
          ..path(color: AppPalette.googleBlue)
          ..path(color: AppPalette.googleYellow)
          ..path(color: AppPalette.googleGreen),
      );
    });
  });

  test('a payment knows who recorded it (detail said only "Added on")', () {
    final members = [
      sampleMember(id: 'm1', userId: 'u1', name: 'Mohit'),
      sampleMember(id: 'm2', userId: 'u2', name: 'Asha', position: 1),
    ];
    final v = paymentViews([bal.samplePayment()], members, 'u2').single;
    expect(v.userNames, {'u1': 'Mohit', 'u2': 'Asha'});
    expect(v.userNames[v.payment.createdBy], 'Mohit');
  });

  group('dates follow the phone, not UTC (00:08 IST gave the day before)', () {
    // 18:40 UTC on 22 Nov is 00:10 on 23 Nov in India; the expectations hold in any time zone.
    final utcNow = DateTime.utc(2026, 11, 22, 18, 40);

    test('Clock.today() is the local calendar day', () {
      final local = utcNow.toLocal();
      expect(_FixedClock(utcNow).today(), DateTime(local.year, local.month, local.day));
    });

    testWidgets('feed day headings compare local days', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final earlier = DateTime.utc(2026, 11, 22, 17, 34);
      final sameDay = DateUtils.isSameDay(utcNow.toLocal(), earlier.toLocal());
      expect(activityDay(ctx, earlier, utcNow), sameDay ? 'Today' : 'Yesterday');
    });
  });

  test('the rate field reads 92.8272, not 92.8272346623', () {
    expect(rateFieldText('92.8272346623'), '92.8272');
    expect(rateFieldText('83.12'), '83.12');
    expect(rateFieldText('0.0053123456'), '0.005312');
    expect(rateFieldText('not a rate'), 'not a rate');
  });

  testWidgets(
    'S-255 the group page keeps a status-bar scrim once its rows scroll under the clock',
    (tester) async {
      tester.view.padding = const FakeViewPadding(top: 63);
      addTearDown(tester.view.resetPadding);
      await pumpGroups(
        tester,
        '/groups/$gid',
        overrides: fixedGroupData(
          groups: [sampleGroup(id: gid, name: 'Goa trip')],
          expenses: {
            gid: [for (var i = 0; i < 30; i++) sampleView(sampleExpense(id: 'e$i'))],
          },
        ),
      );
      expect(find.byKey(const Key('group-status-scrim')), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await settle(tester);
      expect(find.byKey(const Key('group-status-scrim')), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
      await settle(tester);
      expect(find.byKey(const Key('group-status-scrim')), findsNothing);
    },
  );

  test('airplane mode shows as offline at once, not only after a failed sync', () async {
    final net = StreamController<bool>();
    final container = ProviderContainer(
      overrides: [
        ...quietSyncOverrides(),
        networkStatusProvider.overrideWithValue(_Net(net.stream)),
      ],
    );
    addTearDown(container.dispose);
    final seen = <bool>[];
    container.listen(syncOfflineProvider, (_, v) {
      if (v.hasValue) seen.add(v.requireValue);
    }, fireImmediately: true);
    await pumpEventQueue();
    net.add(false);
    await pumpEventQueue();
    expect(seen.last, isTrue);
    net.add(true);
    await pumpEventQueue();
    expect(seen.last, isFalse);
    await net.close();
  });
}

class _Net implements NetworkStatus {
  _Net(this.changes);

  final Stream<bool> changes;

  @override
  Stream<bool> watch() => changes;

  @override
  Future<bool> isOnline() async => true;
}

class _FixedClock implements Clock {
  _FixedClock(this.at);

  final DateTime at;

  @override
  DateTime now() => at;
}
