// W2-Y end to end on the emulator against the DEV project (TC-W2Y-E2E):
//   1. attachments: a phone-sized photo (made on the device, compressed by the real platform encoder: the sizes
//      are printed as `W2Y-PHOTO …`) and a two-page PDF are attached in the editor while OFFLINE (rows, outbox and
//      upload queue on the phone, nothing on the server), then sync: rows on the server, three files in the
//      private bucket (thumbnail, photo, PDF), readable by the other member;
//   2. full resolution on tap: the photo's big file is not kept on the phone, so the viewer downloads it once
//      (signed URL); the PDF opens page by page through Android's PdfRenderer;
//   3. remove + Undo, and delete + restore of the whole expense: the files follow (server rows checked);
//   4. the monthly summary card at the top of Activity (the phone's clock moved to 2 December) → Insights;
//   5. "Settle everything" with the friend over two groups → the friend has two bell rows but ONE push on the
//      server (`push_status`: one released, the other 'batched').
// The app is the side-by-side .qa build with --no-uninstall (S-310 / S-329):
//   powershell -Command ". tool\env.ps1; & tool\e2e\capture_w2y.ps1"
// Screens are captured inside the app (light and dark) into files/shots/w2y-<name>.png.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/features/attachments/application/attachment_picker.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/friends/presentation/friend_routes.dart';
import 'package:splitify/features/insights/presentation/insights_screen.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

const _hold = int.fromEnvironment('UI_HOLD');

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder _key(String k) => find.byKey(Key(k));

/// The top-most copy (a page under the current one can stay in the tree after `go`).
Finder _top(String k) => find.byKey(Key(k)).last;

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 700));
}

Future<void> _waitFor(WidgetTester t, Finder f, {String reason = '', int seconds = 30}) =>
    pumpUntil(
      t,
      () => f.evaluate().isNotEmpty,
      timeout: Duration(seconds: seconds),
      reason: reason.isEmpty ? '$f' : reason,
    );

late IntegrationTestWidgetsFlutterBinding _binding;
late ProviderContainer _container;
late String _shotDir;
var _surfaceConverted = false;

Future<void> _shot(WidgetTester t, String name) async {
  if (!_surfaceConverted) {
    await _binding.convertFlutterSurfaceToImage();
    _surfaceConverted = true;
  }
  await t.pump();
  final bytes = await _binding.takeScreenshot(name);
  File('$_shotDir/w2y-$name.png').writeAsBytesSync(bytes);
  debugPrint('UI-SHOT $name');
}

/// Light, then dark through the app's own theme setting.
Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(milliseconds: 900));
  if (_hold <= 0) return;
  await _shot(t, '$name-light');
  final theme = _container.read(themeModeControllerProvider.notifier);
  await theme.select(ThemeMode.dark);
  await _pumpFor(t, const Duration(milliseconds: 1200));
  await _shot(t, '$name-dark');
  await theme.select(ThemeMode.light);
  await _pumpFor(t, const Duration(milliseconds: 900));
}

/// The server with an "offline" switch for the sync engine.
class _Switchable implements RemoteApi {
  _Switchable(this.inner);

  final RemoteApi inner;
  bool offline = false;

  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) {
    if (offline) throw const NetworkException('offline (test)');
    return inner.applyMutations(batch);
  }

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) {
    if (offline) throw const NetworkException('offline (test)');
    return inner.pullChanges(cursors: cursors, userSeq: userSeq, pageSize: pageSize);
  }

  @override
  Future<void> refreshSession() => inner.refreshSession();
}

/// Storage with the same switch (uploads and downloads fail like a lost network).
class _SwitchableMedia implements MediaRemote {
  _SwitchableMedia(this.inner, this.remote);

  final MediaRemote inner;
  final _Switchable remote;
  final downloads = <String>[];

  @override
  Future<void> upload(String bucket, String path, Uint8List jpeg) {
    if (remote.offline) throw const MediaOffline('test');
    return inner.upload(bucket, path, jpeg);
  }

  @override
  Future<Uri> signedUrl(String bucket, String path, Duration lifetime) {
    if (remote.offline) throw const MediaOffline('test');
    downloads.add('$bucket/$path');
    return inner.signedUrl(bucket, path, lifetime);
  }

  @override
  Future<Uint8List> download(Uri url) {
    if (remote.offline) throw const MediaOffline('test');
    return inner.download(url);
  }
}

/// The real clock, or a fixed day for the monthly card.
class _MovableClock implements Clock {
  DateTime? fixed;

  @override
  DateTime now() => fixed ?? DateTime.now().toUtc();
}

/// A phone-camera-sized picture of a bill on a table (4032 × 3024), as a camera JPEG (q95).
Future<Uint8List> _cameraPhoto() async {
  const w = 4032.0;
  const h = 3024.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint();
  // Wood-like table: many thin bands of slightly different browns.
  for (var y = 0.0; y < h; y += 6) {
    final v = 90 + ((y * 7919) % 37).toInt();
    paint.color = ui.Color.fromARGB(255, v + 40, v, v - 40);
    canvas.drawRect(ui.Rect.fromLTWH(0, y, w, 6), paint);
  }
  // Speckles (camera noise), so the picture does not compress unrealistically well.
  for (var i = 0; i < 60000; i++) {
    final x = (i * 7919) % w;
    final y = (i * 104729) % h;
    paint.color = ui.Color.fromARGB(255, (i * 13) % 255, (i * 29) % 255, (i * 47) % 255);
    canvas.drawRect(ui.Rect.fromLTWH(x, y, 3, 3), paint);
  }
  // The bill: white paper with lines of "text".
  paint.color = const ui.Color(0xFFF7F5EE);
  canvas.drawRect(const ui.Rect.fromLTWH(1100, 200, 1800, 2650), paint);
  paint.color = const ui.Color(0xFF222222);
  for (var line = 0; line < 60; line++) {
    final y = 320.0 + line * 42;
    for (var word = 0; word < 9; word++) {
      final len = 60.0 + ((line * 31 + word * 17) % 120);
      canvas.drawRect(ui.Rect.fromLTWH(1180 + word * 185.0, y, len, 18), paint);
    }
  }
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose();
  return platformJpeg(png, bound: 3024, quality: 95);
}

/// A small valid PDF with [pages] pages of text (PdfRenderer reads it).
Uint8List _pdf(int pages) {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [${[for (var i = 0; i < pages; i++) '${3 + i * 2} 0 R'].join(' ')}] /Count $pages >>',
  ];
  final font = 3 + pages * 2;
  for (var i = 0; i < pages; i++) {
    final content =
        'BT /F1 30 Tf 72 760 Td (Hotel invoice page ${i + 1}) Tj 0 -60 Td (Total Rs 4250) Tj ET';
    objects
      ..add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents ${4 + i * 2} 0 R '
        '/Resources << /Font << /F1 $font 0 R >> >> >>',
      )
      ..add('<< /Length ${content.length} >>\nstream\n$content\nendstream');
  }
  objects.add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  final b = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(b.length);
    b.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = b.length;
  b.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  b.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(b.toString()));
}

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'W2-Y: attachments offline → online, full size, PDF, restore; monthly card; one push per batch',
    (t) async {
      final env = devEnv();
      final services = await initRemote(env);
      await services.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
      final uidA = services.auth.currentUser!.id;
      final client = Supabase.instance.client;
      final db = AppDatabase(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final files = (await t.runAsync(getApplicationSupportDirectory))!;
      final remote = _Switchable(SupabaseRemoteApi.client(client));
      final media = _SwitchableMedia(services.media, remote);
      final clock = _MovableClock();

      // The photo, compressed by the real platform encoder (sizes printed for the storage budget).
      final camera = (await t.runAsync(_cameraPhoto))!;
      final photo = (await t.runAsync(
        () => prepareAttachmentPhoto(camera, encode: platformJpeg, sizeOf: readImageSize),
      ))!;
      debugPrint(
        'W2Y-PHOTO camera ${camera.length} B -> stored ${photo.sizeBytes} B '
        '(${photo.width}x${photo.height}), thumb ${photo.image!.thumb.length} B',
      );
      expect(photo.sizeBytes, lessThanOrEqualTo(AttachmentLimits.photoMaxBytes));
      expect(
        [photo.width, photo.height].reduce((a, b) => a! > b! ? a : b),
        lessThanOrEqualTo(3072),
      );
      final pdf = preparePdf(_pdf(2), 'Hotel invoice.pdf').file!;
      debugPrint('W2Y-PDF ${pdf.sizeBytes} B');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          remoteApiProvider.overrideWithValue(remote),
          mediaRemoteProvider.overrideWithValue(media),
          clockProvider.overrideWithValue(clock),
          balancesRemoteProvider.overrideWithValue(SupabaseBalancesRemote.fromClient(client)),
          groupsRemoteProvider.overrideWithValue(services.groups),
          friendsRemoteProvider.overrideWithValue(SupabaseFriendsRemote.fromClient(client)),
          authRepositoryProvider.overrideWithValue(services.auth),
          profileRemoteProvider.overrideWithValue(services.profiles),
          // The system pickers are not driven here: the prepared photo / PDF come back as if picked.
          attachmentPickerProvider.overrideWithValue(
            (source, {required max}) async =>
                (files: [source == AttachmentSource.pdf ? pdf : photo], problem: null),
          ),
        ],
      );
      addTearDown(container.dispose);
      _container = container;
      _shotDir = '${files.path}/shots';
      Directory(_shotDir).createSync(recursive: true);
      await container.read(themeModeControllerProvider.notifier).select(ThemeMode.light);
      final engine = container.read(syncEngineProvider);
      Future<void> sync() => t.runAsync(() async {
        await engine.sync();
        await engine.sync();
      });

      // F: a new account each run; two groups with A, F owes A in both.
      final stamp = DateTime.now().millisecondsSinceEpoch % 10000000;
      final f = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-w2y-$stamp')))!;
      addTearDown(() => t.runAsync(f.dispose));
      await t.runAsync(
        () => f.client.rpc<Object?>(
          'update_profile',
          params: {
            'p_display_name': 'Farah W2Y',
            'p_upi_id': null,
            'p_default_currency': 'INR',
            'p_avatar_path': null,
          },
        ),
      );
      final groups = container.read(groupsRepositoryProvider);
      final g1 = await groups.create(
        name: 'W2Y Goa $stamp',
        ownerName: 'E2E A',
        ownerUserId: uidA,
        type: 'trip',
      );
      final g2 = await groups.create(
        name: 'W2Y Flat $stamp',
        ownerName: 'E2E A',
        ownerUserId: uidA,
        type: 'home',
      );
      await sync();
      addTearDown(() async {
        remote.offline = false;
        await groups.delete(g1, g1);
        await groups.delete(g2, g2);
        await sync();
      });
      for (final g in [g1, g2]) {
        final code =
            (await t.runAsync(
                  () => client.from('groups').select('invite_code').eq('id', g).single(),
                ))!['invite_code']!
                as String;
        expect((await t.runAsync(() => f.rpc('join_group', {'code': code})))!['group_id'], g);
      }
      await sync();
      Future<String> memberOf(String group, String user) async => (await (db.select(
        db.groupMembers,
      )..where((m) => m.groupId.equals(group) & m.userId.equals(user))).getSingle()).id;
      final a1 = await memberOf(g1, uidA);
      final f1 = await memberOf(g1, f.id);
      final a2 = await memberOf(g2, uidA);
      final f2 = await memberOf(g2, f.id);
      final expenses = container.read(expensesRepositoryProvider);
      Map<String, Object?> row(String description, int total, String a, String fm) => {
        'kind': 'expense',
        'description': description,
        'category': 'travel.hotel',
        'date': '2026-11-27',
        'currency': 'INR',
        'total': total,
        'payers': {a: total},
        'shares': {a: total ~/ 2, fm: total - total ~/ 2},
        'split_kind': 'equal',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      final e1 = await expenses.save(g1, row('Hotel $stamp', 40000, a1, f1));
      await expenses.save(g2, row('Groceries $stamp', 10000, a2, f2));
      await sync();

      final router = buildRouter(initialLocation: ExpenseRoutes.detail(e1));
      addTearDown(router.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
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
              themeMode: ref.watch(themeModeControllerProvider),
              debugShowCheckedModeBanner: false,
            ),
          ),
        ),
      );
      await _waitFor(t, find.text('Hotel $stamp'), seconds: 60);
      if (_hold > 0) {
        debugPrint('UI-READY');
        await _pumpFor(t, const Duration(seconds: 6));
      }

      // ------------------------------------------------------------------ 1. attach offline, then sync
      remote.offline = true;
      unawaited(router.push(ExpenseRoutes.edit(e1)));
      await _waitFor(t, _key('expense-receipt-chip'));
      await _tap(t, _key('expense-receipt-chip'));
      await _waitFor(t, _key('receipt-add'));
      await _capture(t, 'editor-empty');
      await _tap(t, _key('receipt-add'));
      await _waitFor(t, _key('attach-photos'));
      await _capture(t, 'source-sheet');
      await _tap(t, _key('attach-photos'));
      await _waitFor(t, _key('attachment-open-${photo.id}'));
      await _tap(t, _key('attachment-add'));
      await _waitFor(t, _key('attach-pdf'));
      await _tap(t, _key('attach-pdf'));
      await _waitFor(t, _key('attachment-open-${pdf.id}'));
      await _capture(t, 'editor-files');
      await _tap(t, _key('receipt-done'));
      await _tap(t, _top('expense-save'));
      await _waitFor(t, _key('expense-attachments'), seconds: 20);
      await t.ensureVisible(_key('expense-attachments'));
      await _capture(t, 'detail-files-offline');

      final local = await (db.select(
        db.expenseAttachments,
      )..where((a) => a.expenseId.equals(e1))).get();
      expect(local.map((a) => a.kind).toSet(), {'photo', 'pdf'});
      expect(local.every((a) => a.syncState == 'pending'), isTrue, reason: 'not synced yet');
      expect(
        await db.select(db.pendingUploads).get(),
        hasLength(3),
        reason: 'thumbnail, photo, PDF',
      );
      final early = (await t.runAsync(
        () => f.client.from('expense_attachments').select('id').eq('expense_id', e1),
      ))!;
      expect(early, isEmpty, reason: 'offline: nothing reached the server');
      debugPrint('W2Y-OFFLINE OK');

      remote.offline = false;
      await sync();
      expect(await db.select(db.pendingUploads).get(), isEmpty, reason: 'every file went up');
      final server = (await t.runAsync(
        () => f.client
            .from('expense_attachments')
            .select('id, kind, size_bytes, path, thumb_path, deleted_at')
            .eq('expense_id', e1),
      ))!;
      expect(
        {for (final r in server) r['kind']},
        {'photo', 'pdf'},
        reason: 'the friend sees both rows',
      );
      final objects = (await t.runAsync(
        () => f.client.storage.from(AttachmentPaths.bucket).list(path: '$g1/$e1'),
      ))!;
      expect(objects, hasLength(3), reason: 'thumbnail, photo and PDF in the private bucket');
      for (final o in objects) {
        debugPrint('W2Y-STORED ${o.name} ${o.metadata?['size']} B ${o.metadata?['mimetype']}');
      }
      debugPrint('W2Y-SYNC OK');
      await t.ensureVisible(_key('expense-attachments'));
      await _capture(t, 'detail-files-synced');

      // ------------------------------------------------------------------ 2. full size on tap, PDF pages
      final full = AttachmentPaths.file(g1, e1, photo.id, AttachmentKind.photo);
      expect(
        await container.read(mediaFilesProvider).local(AttachmentPaths.bucket, full, thumb: false),
        isNull,
        reason: 'the big photo is not kept on the phone after upload',
      );
      await _tap(t, _key('attachment-open-${photo.id}'));
      await _waitFor(t, _key('photo-full'), seconds: 60);
      expect(
        media.downloads,
        contains('${AttachmentPaths.bucket}/$full'),
        reason: 'downloaded once, full size',
      );
      await _capture(t, 'photo-full');
      await _tap(t, _key('photo-close'));
      await _tap(t, _key('attachment-open-${pdf.id}'));
      await _waitFor(t, _key('pdf-page-1'), seconds: 30);
      await _pumpFor(t, const Duration(seconds: 2));
      expect(find.descendant(of: _key('pdf-page-0'), matching: find.byType(Image)), findsOneWidget);
      await _capture(t, 'pdf');
      debugPrint('W2Y-VIEWERS OK');

      // ------------------------------------------------------------------ 3. remove + Undo, delete + restore
      await _tap(t, _key('pdf-remove'));
      await _waitFor(t, find.text('Undo'));
      await sync();
      Future<String?> deletedAt(String id) async =>
          (await t.runAsync(
                () =>
                    f.client.from('expense_attachments').select('deleted_at').eq('id', id).single(),
              ))!['deleted_at']
              as String?;
      expect(await deletedAt(pdf.id), isNotNull, reason: 'removed (soft) on the server');
      await _tap(t, find.text('Undo'));
      await sync();
      expect(await deletedAt(pdf.id), isNull, reason: 'Undo restored it');
      await _waitFor(t, _key('attachment-open-${pdf.id}'));

      final e = await (db.select(db.expenses)..where((x) => x.id.equals(e1))).getSingle();
      await container.read(expensesRepositoryProvider).delete(e.id, e.groupId);
      await sync();
      await container.read(expensesRepositoryProvider).restore(e.id, e.groupId);
      await sync();
      final after = (await t.runAsync(
        () => f.client.from('expense_attachments').select('id, deleted_at').eq('expense_id', e1),
      ))!;
      expect(
        after.where((r) => r['deleted_at'] == null),
        hasLength(2),
        reason: 'the files came back with the expense',
      );
      await _waitFor(t, _key('expense-attachments'));
      final activity = (await t.runAsync(
        () => f.client
            .from('activity')
            .select('type')
            .eq('target_id', e1)
            .like('type', 'attachment_%'),
      ))!;
      expect(
        {for (final r in activity) r['type']},
        {'attachment_added', 'attachment_removed', 'attachment_restored'},
      );
      debugPrint('W2Y-RESTORE OK');

      // ------------------------------------------------------------------ 4. monthly summary card
      clock.fixed = DateTime(2026, 12, 2, 9).toUtc();
      router.go('/activity');
      await _waitFor(t, _key('month-summary'), seconds: 20);
      expect(find.text('Your November'), findsOneWidget);
      // e2e-a also has DEV groups from earlier runs, so only the shape of the line is checked.
      expect(find.textContaining(RegExp(r'^You spent .+ across \d+ groups?$')), findsOneWidget);
      await _capture(t, 'month-card');
      await _tap(t, _key('month-summary-open'));
      await _waitFor(t, find.byType(InsightsScreen));
      clock.fixed = null;
      debugPrint('W2Y-MONTH-CARD OK');

      // ------------------------------------------------------------------ 5. one push per batch settle
      router.go(FriendRoutes.page('u:${f.id}'));
      await _waitFor(t, _key('friend-settle'), seconds: 30);
      await _tap(t, _top('friend-settle'));
      await _waitFor(t, _key('settle-all-INR'));
      await _tap(t, _key('settle-all-INR'));
      await _waitFor(t, _key('settle-all-form'));
      await _capture(t, 'batch-form');
      // Offline for a moment so the queued batch can be read before it is sent.
      remote.offline = true;
      await _tap(t, _key('settle-save'));
      await _pumpFor(t, const Duration(seconds: 3));
      final batch = [
        for (final o in await db.select(db.outbox).get())
          if (o.entity == 'payment') jsonDecode(o.payload)['batch_id'],
      ];
      expect(batch, hasLength(2));
      expect(batch.toSet(), hasLength(1), reason: 'one batch id on both payments');
      remote.offline = false;
      await sync();
      // The server's fan-out: one bell row per group for F, one push between them.
      var rows = <Map<String, dynamic>>[];
      for (var i = 0; i < 20; i++) {
        rows = (await t.runAsync(
          () => f.client
              .from('notifications')
              .select('push_status, data, push_title, push_body')
              .eq('type', 'payment_added')
              .inFilter('group_id', [g1, g2]),
        ))!;
        if (rows.length == 2 && rows.every((r) => r['push_status'] != 'pending')) break;
        await _pumpFor(t, const Duration(seconds: 1));
      }
      expect(rows, hasLength(2), reason: 'a bell row per group');
      final statuses = [for (final r in rows) r['push_status']! as String]..sort();
      debugPrint(
        'W2Y-BATCH-PUSH ${statuses.join(',')} ${rows.map((r) => r['push_body']).join(' | ')}',
      );
      expect(
        statuses.where((s) => s == 'batched'),
        hasLength(1),
        reason: 'one row is covered by the other push',
      );
      final released = rows.firstWhere((r) => r['push_status'] != 'batched');
      expect(released['push_body'], contains('settled up with you in 2 groups'));
      expect((released['data']! as Map)['batch_count'], 2);
      debugPrint('W2Y-BATCH OK');
    },
  );
}
