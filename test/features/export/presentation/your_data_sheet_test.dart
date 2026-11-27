// TC-D34D-01 (D-034 WP-D, P-4): the "Your data" row and sheet: counts, the pending note, Download my data
// (save dialog) with its progress and result, Share instead, nothing yet, a failure; the real file from
// the phone's database.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/account/presentation/your_data_sheet.dart';
import 'package:splitify/features/export/application/backup_export.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/fakes.dart' show testDb;
import '../../search/d034_seed.dart';
import '../zip_reader.dart';

class _Calls {
  final saved = <(Uint8List, String)>[];
  final shared = <(Uint8List, String, String)>[];
}

class _FakeExporter extends BackupExporter {
  _FakeExporter(super.ref, this.result);

  final Future<BackupFile?> Function() result;

  @override
  Future<BackupFile?> build({required String Function(String key) categoryLabel}) => result();
}

final _file = BackupFile(bytes: Uint8List.fromList([1, 2, 3]), fileName: 'b.zip', json: const {});

Widget _host(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light(),
    home: const Scaffold(
      body: SingleChildScrollView(padding: EdgeInsets.all(20), child: YourDataPanel()),
    ),
  ),
);

List<Override> _fixed(
  _Calls calls, {
  Future<BackupFile?> Function()? result,
  Future<String?> Function()? save,
  ({int groups, int expenses, int payments, int pending}) counts = (
    groups: 3,
    expenses: 12,
    payments: 1,
    pending: 0,
  ),
}) => [
  backupCountsProvider.overrideWith((ref) => Stream.value(counts)),
  backupExporterProvider.overrideWith((ref) => _FakeExporter(ref, result ?? () async => _file)),
  backupSaverProvider.overrideWithValue((bytes, name, title) async {
    calls.saved.add((bytes, name));
    return save == null ? 'splitify-backup-2026-11-21.zip' : save();
  }),
  backupSharerProvider.overrideWithValue((bytes, name, subject) async {
    calls.shared.add((bytes, name, subject));
  }),
];

String _text(WidgetTester t, String key) => t.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  // TC-D34D-01
  testWidgets('shows what is in the file, the counts and the two actions', (t) async {
    await t.pumpWidget(_host(_fixed(_Calls())));
    await t.pump();
    expect(find.textContaining('a full backup (JSON)'), findsOneWidget);
    expect(_text(t, 'your-data-counts'), '3 groups · 12 expenses · 1 payment');
    expect(find.byKey(const Key('your-data-pending')), findsNothing);
    expect(find.text('Download my data'), findsOneWidget);
    expect(find.text('Share instead'), findsOneWidget);
    expect(find.textContaining('whole paise'), findsOneWidget);
  });

  // TC-D34D-01
  testWidgets('unsynced rows: the marker and "marked as pending"', (t) async {
    await t.pumpWidget(
      _host(_fixed(_Calls(), counts: (groups: 1, expenses: 1, payments: 0, pending: 2))),
    );
    await t.pump();
    expect(_text(t, 'your-data-counts'), '1 group · 1 expense · 0 payments');
    expect(find.text('Not synced yet'), findsOneWidget);
    expect(_text(t, 'your-data-pending'), contains('2 changes are not synced yet'));
  });

  // TC-D34D-01
  testWidgets('Download: busy while it works, then "Saved …"; both buttons wait', (t) async {
    final calls = _Calls();
    final gate = Completer<BackupFile?>();
    await t.pumpWidget(_host(_fixed(calls, result: () => gate.future)));
    await t.pump();
    await t.tap(find.byKey(const Key('your-data-download')));
    await t.pump();
    expect(find.text('Preparing your file…'), findsOneWidget);
    await t.tap(find.byKey(const Key('your-data-share')));
    await t.pump();
    expect(calls.shared, isEmpty, reason: 'disabled while busy');
    gate.complete(_file);
    await t.pump();
    await t.pump();
    expect(calls.saved.single.$2, 'b.zip');
    expect(calls.saved.single.$1, [1, 2, 3]);
    expect(find.text('Saved splitify-backup-2026-11-21.zip'), findsOneWidget);
    expect(find.text('Download my data'), findsOneWidget);
  });

  // TC-D34D-01
  testWidgets('a cancelled save says nothing; Share instead opens the share sheet', (t) async {
    final calls = _Calls();
    await t.pumpWidget(_host(_fixed(calls, save: () async => null)));
    await t.pump();
    await t.tap(find.byKey(const Key('your-data-download')));
    await t.pump();
    await t.pump();
    expect(calls.saved, hasLength(1));
    expect(find.byKey(const Key('your-data-message')), findsNothing);
    await t.tap(find.byKey(const Key('your-data-share')));
    await t.pump();
    await t.pump();
    expect(calls.shared.single.$2, 'b.zip');
    expect(calls.shared.single.$3, 'My Splitify data');
  });

  // TC-D34D-01
  testWidgets('nothing on the phone, and a failure, each say so', (t) async {
    final calls = _Calls();
    await t.pumpWidget(_host(_fixed(calls, result: () async => null)));
    await t.pump();
    await t.tap(find.byKey(const Key('your-data-download')));
    await t.pump();
    await t.pump();
    expect(find.text('Nothing to download yet. Create a group first.'), findsOneWidget);
    expect(calls.saved, isEmpty);

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      _host(_fixed(calls, result: () async => throw const FormatException('disk'))),
    );
    await t.pump();
    await t.tap(find.byKey(const Key('your-data-share')));
    await t.pump();
    await t.pump();
    expect(find.text('The file could not be made. Try again.'), findsOneWidget);
    expect(calls.shared, isEmpty);
  });

  // TC-D34D-01: the real file, built from the phone's database through the sheet.
  testWidgets('the real backup from the database reaches the save dialog', (t) async {
    final w = (await t.runAsync(seedD034))!;
    final calls = _Calls();
    final c = ProviderContainer(
      overrides: [
        ...d034Overrides(w.db, (await t.runAsync(d034Prefs))!),
        backupSaverProvider.overrideWithValue((bytes, name, title) async {
          calls.saved.add((bytes, name));
          return name;
        }),
      ],
    );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async {
        c.dispose();
        await w.dispose();
      });
    });
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: YourDataPanel())),
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    expect(_text(t, 'your-data-counts'), '2 groups · 4 expenses · 2 payments');
    expect(_text(t, 'your-data-file'), 'splitify‑backup‑2026‑11‑21.zip');
    await t.tap(find.byKey(const Key('your-data-download')));
    for (var i = 0; i < 10 && calls.saved.isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump();
    }
    final (bytes, name) = calls.saved.single;
    expect(name, 'splitify-backup-2026-11-21.zip');
    expect(zipTexts(bytes).keys, contains('splitify-backup.json'));
    await t.pump();
    expect(find.text('Saved splitify-backup-2026-11-21.zip'), findsOneWidget);
  });

  // TC-D34D-01: the entry on the Account list.
  testWidgets('Account → Your data opens the sheet', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = testDb();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        routerProvider.overrideWith((ref) => buildRouter(initialLocation: Routes.account)),
      ],
    );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async {
        container.dispose();
        await db.close();
      });
    });
    t.view.physicalSize = const Size(412 * 2, 915 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    await t.pump(const Duration(milliseconds: 500));
    final row = find.byKey(const Key('settings-your-data'));
    await t.ensureVisible(row);
    await t.pump();
    expect(find.descendant(of: row, matching: find.text('Your data')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Download')), findsOneWidget);
    await t.tap(row);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('your-data')), findsOneWidget);
    expect(find.text('Download my data'), findsOneWidget);
  });
}
