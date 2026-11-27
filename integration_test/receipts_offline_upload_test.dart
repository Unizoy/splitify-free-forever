// Phase 10 e2e (TC-29-03, TC-29-01 on the device, TC-10/TC-11 round trip): offline, add an expense paid
// by two people with a receipt photo (real compression on the device), record a loan and give the group
// a photo cover; back online the sync pushes the rows, the queue uploads both photos, and user B (harness,
// after claiming "Asha") reads the receipt and the cover through signed URLs. Runs on the DEV project:
//   flutter test integration_test/receipts_offline_upload_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=<ip resolved on the PC>
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/expenses/presentation/amount_keypad.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/photos/application/photo_compression.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'expenses_offline_sync_test.dart' show SwitchableRemote;
import 'support/harness.dart';

/// Storage switched off while "offline".
class SwitchableMedia implements MediaRemote {
  SwitchableMedia(this.inner);

  final MediaRemote inner;
  bool online = false;
  int uploads = 0;

  void _check() {
    if (!online) throw const MediaOffline('offline (test)');
  }

  @override
  Future<void> upload(String bucket, String path, Uint8List jpeg) async {
    _check();
    await inner.upload(bucket, path, jpeg);
    uploads++;
  }

  @override
  Future<Uri> signedUrl(String bucket, String path, Duration lifetime) {
    _check();
    return inner.signedUrl(bucket, path, lifetime);
  }

  @override
  Future<Uint8List> download(Uri url) {
    _check();
    return inner.download(url);
  }
}

/// A busy 3000 × 2000 photo (noise makes JPEGs big, so the size ladder is exercised).
Future<Uint8List> _bigPhoto() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final r = Random(7);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 3000, 2000), Paint()..color = const Color(0xFFF4EFE6));
  for (var i = 0; i < 6000; i++) {
    canvas.drawRect(
      Rect.fromLTWH(r.nextDouble() * 3000, r.nextDouble() * 2000, 4 + r.nextDouble() * 40, 4),
      Paint()..color = Color(0xFF000000 | r.nextInt(0xFFFFFF)),
    );
  }
  final image = await recorder.endRecording().toImage(3000, 2000);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 400));
}

Future<void> _keys(WidgetTester t, String amount) async {
  for (final ch in amount.split('')) {
    await _tap(t, find.byKey(Key('key-${ch == '.' ? 'dot' : 'd$ch'}')));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'offline receipt + loan + cover, then online: rows sync, photos upload, B reads them',
    (t) async {
      final env = devEnv();
      final remote = await initRemote(env);
      await remote.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
      final uid = remote.auth.currentUser!.id;
      final client = Supabase.instance.client;
      final server = SwitchableRemote(SupabaseRemoteApi.client(client));
      final storage = SwitchableMedia(SupabaseMediaRemote.fromClient(client));
      final tmp = (await t.runAsync(getTemporaryDirectory))!;
      final root = Directory('${tmp.path}/e2e_media_${DateTime.now().millisecondsSinceEpoch}');
      final files = MediaFiles(
        docs: () async => Directory('${root.path}/docs'),
        cache: () async => Directory('${root.path}/cache'),
      );

      // TC-29-01 on the device: real platform compression of a big photo.
      final photo = (await t.runAsync(
        () async => preparePhoto(await _bigPhoto(), encode: platformJpeg, sizeOf: readImageSize),
      ))!;
      final fullSize = (await t.runAsync(() => readImageSize(photo.full)))!;
      final thumbSize = (await t.runAsync(() => readImageSize(photo.thumb)))!;
      expect(photo.full.lengthInBytes, lessThanOrEqualTo(PhotoLimits.maxBytes));
      expect(max(fullSize.width, fullSize.height), lessThanOrEqualTo(PhotoLimits.maxSide));
      expect(max(thumbSize.width, thumbSize.height), lessThanOrEqualTo(PhotoLimits.thumbSide));
      expect(photo.full.sublist(0, 2), [0xFF, 0xD8], reason: 'JPEG');
      debugPrint(
        'compressed: ${photo.full.lengthInBytes} bytes, ${fullSize.width}x${fullSize.height}; '
        'thumb ${thumbSize.width}x${thumbSize.height}',
      );

      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          remoteApiProvider.overrideWithValue(server),
          mediaRemoteProvider.overrideWithValue(storage),
          mediaFilesProvider.overrideWithValue(files),
          authRepositoryProvider.overrideWithValue(remote.auth),
          preparedPhotoPickerProvider.overrideWithValue((source) async => photo),
        ],
      );
      addTearDown(container.dispose);

      // Offline: a group with two name-only members.
      final groups = container.read(groupsRepositoryProvider);
      final members = container.read(membersRepositoryProvider);
      final gid = await groups.create(
        name: 'E2E receipts ${DateTime.now().millisecondsSinceEpoch}',
        ownerName: 'E2E A',
        ownerUserId: uid,
      );
      final asha = await members.addNameOnly(gid, 'Asha');
      await members.addNameOnly(gid, 'Rahul');
      final me = (await members.watchForGroup(gid).first).firstWhere((m) => m.userId == uid).id;

      final router = buildRouter(initialLocation: ExpenseRoutes.add(gid));
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
          ),
        ),
      );
      await _pumpFor(t, const Duration(seconds: 2));

      // Expense: ₹1,200 paid by me (₹700) and Asha (₹500), split equally, with a receipt photo.
      await t.enterText(
        find.descendant(
          of: find.byKey(const Key('expense-description')),
          matching: find.byType(TextField),
        ),
        'Receipt dinner',
      );
      await t.enterText(
        find.descendant(
          of: find.byKey(const Key('expense-amount')),
          matching: find.byType(TextField),
        ),
        '1200',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await _pumpFor(t, const Duration(milliseconds: 400));
      await _tap(t, find.byKey(const Key('split-summary'))); // → Paid by · split sheet
      await _pumpFor(t, const Duration(milliseconds: 800));
      await _tap(t, find.byKey(const Key('payer-multiple')));
      for (final (id, amount) in [(me, '700'), (asha, '500')]) {
        final field = find.descendant(
          of: find.byKey(Key('payer-amount-$id')),
          matching: find.byType(TextField),
        );
        await t.ensureVisible(field);
        await t.enterText(field, amount);
        await t.pump();
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await _pumpFor(t, const Duration(milliseconds: 400));
      expect(find.textContaining('covered'), findsOneWidget);
      await _tap(t, find.byKey(const Key('paid-split-done')));
      await _pumpFor(t, const Duration(milliseconds: 600));
      await _tap(t, find.byKey(const Key('expense-receipt-chip'))); // → the receipt sheet
      await _pumpFor(t, const Duration(milliseconds: 1000));
      await _tap(t, find.byKey(const Key('receipt-add')));
      await _pumpFor(t, const Duration(milliseconds: 1500)); // the sheet slides up
      await _tap(t, find.byKey(const Key('photo-gallery')));
      await _pumpFor(t, const Duration(seconds: 1));
      expect(find.byKey(const Key('receipt-photo')), findsOneWidget);
      await _tap(t, find.byKey(const Key('receipt-done')));
      await _pumpFor(t, const Duration(milliseconds: 600));
      expect(find.text('2 people paid\u00A0· split equally'), findsOneWidget);
      await _tap(t, find.byKey(const Key('expense-save')));
      await _pumpFor(t, const Duration(seconds: 2));

      // Loan: I lent Asha ₹500.
      router.go(ExpenseRoutes.addLoan(gid));
      await pumpUntil(
        t,
        () => find.byKey(const Key('loan-direction')).evaluate().isNotEmpty,
        reason: 'loan screen',
      );
      if (find.byType(AmountKeypad).evaluate().isEmpty) {
        debugPrint('loan keypad closed (viewInsets ${t.view.viewInsets}); opening it');
        await _tap(t, find.byKey(const Key('loan-amount-tap')));
      }
      await _keys(t, '500');
      await _tap(t, find.byKey(Key('loan-person-$asha')));
      expect(find.text('You lent Asha ₹500'), findsOneWidget);
      await _tap(t, find.byKey(const Key('loan-save')));
      await _pumpFor(t, const Duration(seconds: 2));

      // Cover photo, offline too.
      await container.read(groupActionsProvider).setCoverPhoto(gid, photo);

      // Still offline: rows pending, two photos queued, nothing uploaded.
      final local = await (db.select(db.expenses)..where((e) => e.groupId.equals(gid))).get();
      final dinner = local.firstWhere((e) => e.kind == 'expense');
      final loan = local.firstWhere((e) => e.kind == 'iou');
      expect(dinner.receiptPath, startsWith('$gid/${dinner.id}/'));
      expect(await db.select(db.pendingUploads).get(), hasLength(2));
      expect(storage.uploads, 0);
      final cover = (await groups.watchOne(gid).first)!;
      expect(cover.coverKind, 'photo');

      // Online: push, upload, pull.
      server.online = true;
      storage.online = true;
      final engine = container.read(syncEngineProvider);
      await t.runAsync(() async {
        await engine.sync();
        await engine.sync();
      });
      expect(await db.select(db.pendingUploads).get(), isEmpty, reason: '${engine.lastError}');
      expect(storage.uploads, 2);
      final synced = await (db.select(db.expenses)..where((e) => e.groupId.equals(gid))).get();
      expect(synced.every((e) => e.syncState == SyncState.synced), isTrue);

      // Server rows.
      final rows = (await t.runAsync(
        () => client.from('expenses').select().eq('group_id', gid).isFilter('deleted_at', null),
      ))!;
      final dinnerRow = rows.firstWhere((r) => r['id'] == dinner.id);
      expect(dinnerRow['receipt_path'], dinner.receiptPath);
      expect(dinnerRow['payers'], {me: 70000, asha: 50000});
      final loanRow = rows.firstWhere((r) => r['id'] == loan.id);
      expect(loanRow['kind'], 'iou');
      expect(loanRow['payers'], {me: 50000});
      expect(loanRow['shares'], {asha: 50000});

      // User B claims Asha and reads both photos through signed URLs.
      final code = await t.runAsync(
        () => client.from('groups').select('invite_code').eq('id', gid).single(),
      );
      final b = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-b')))!;
      await t.runAsync(
        () => b.client.rpc<Object?>(
          'join_group',
          params: {'code': code!['invite_code'], 'claim_member_id': asha},
        ),
      );
      for (final (bucket, path) in [
        (MediaBuckets.receipts, dinner.receiptPath!),
        (MediaBuckets.groupCovers, cover.coverPath!),
      ]) {
        final url = await t.runAsync(() => b.client.storage.from(bucket).createSignedUrl(path, 60));
        final bytes = await t.runAsync(() => SupabaseMediaRemote.httpGet(Uri.parse(url!)));
        expect(bytes, photo.full, reason: '$bucket/$path');
      }
      debugPrint('B fetched receipt and cover via signed URLs');

      // Tidy up: soft-delete the test group (restorable), remove local files.
      await groups.delete(gid, gid);
      await t.runAsync(engine.sync);
      await t.runAsync(b.dispose);
      await t.runAsync(() => root.delete(recursive: true));
    },
  );
}
