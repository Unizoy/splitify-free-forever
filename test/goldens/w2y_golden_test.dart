// W2-Y goldens: the receipt sheet with several files (and the full ten), the expense page's attachments grid,
// the PDF viewer, the full-size photo viewer while it loads, the monthly summary card, the notification settings
// with the summary switch and the account settings with the crash-report switch — light and dark at text 1.0 and
// 2.0, plus a small phone (320 x 568) at text 1.0. Every state also runs the a11y guidelines (pumpFixedFrames).
import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/platform/crash_reporting.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';
import 'package:splitify/features/account/presentation/account_settings_sheet.dart';
import 'package:splitify/features/activity/application/monthly_summary.dart';
import 'package:splitify/features/activity/presentation/monthly_summary_card.dart';
import 'package:splitify/features/attachments/application/attachment_providers.dart';
import 'package:splitify/features/attachments/presentation/pdf_viewer_screen.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/receipt_field.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/notifications/presentation/notification_settings_screen.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/account/crash_toggle_test.dart'
    show FakeCrashReporter, accountSettingsOverrides;
import '../features/expenses/expense_fixtures.dart';
import '../features/notifications/presentation/notif_harness.dart';
import '../support/attachment_fixtures.dart';
import '../support/group_fakes.dart' as gf;
import '../support/notification_fakes.dart';
import '../support/sample_photo.dart';
import 'golden_support.dart';

const _small = Size(320, 568);

/// One golden scenario: the screen, its overrides and the frame height at text scale 1.0.
typedef _Case = (
  String name,
  Widget Function() screen,
  List<Override> Function() overrides,
  double height,
);

/// A sheet body at the bottom of a dimmed screen, like the real modal sheet.
class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.scrim,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(title: AppLocalizations.of(context).receiptLabel, child: child),
    ),
  );
}

/// A list screen: [child] in a scrolling page.
class _Page extends StatelessWidget {
  const _Page({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.s4),
        child: child,
      ),
    ),
  );
}

/// The crash switch "on" (a build with Firebase and the person's saved yes).
class _CrashOn extends CrashReportsSetting {
  @override
  bool build() => true;
}

const _pdfPath = 'g-goa/e1/a2.pdf';
const _fullPath = 'g-goa/e1/a1.jpg';
const _thumbPath = 'g-goa/e1/a1-thumb.jpg';

ReceiptDraft _files({int photos = 1, int pdfs = 1}) {
  const names = [
    'Hotel invoice.pdf',
    'Flight ticket.pdf',
    'Restaurant bill.pdf',
    'Boarding pass.pdf',
  ];
  return ReceiptDraft.none().addAll([
    for (var i = 0; i < photos; i++) pickedPhoto(),
    for (var i = 0; i < pdfs; i++)
      pickedPdf(name: names[i % names.length], bytes: i.isEven ? 1258291 : 340 * 1024),
  ]);
}

MonthSummary _month({
  Map<String, int> spent = const {'INR': 425000},
  int groups = 2,
  Map<String, int> balances = const {'INR': 120000},
  bool unsynced = false,
}) => MonthSummary(
  month: DateTime(2026, 10),
  spent: spent,
  groups: groups,
  balances: balances,
  unsynced: unsynced,
);

List<Override> _settings() => [
  ...notifOverrides(
    repo: FakeNotificationsRepository(
      prefs: const NotificationPrefs().withKind(
        NotificationKind.summary,
        NotificationChannel.push,
        on: true,
      ),
    ),
    push: FakePushMessaging(),
  ),
  groupsListProvider.overrideWithValue(
    AsyncData([gf.sampleGroup(), gf.sampleGroup(id: 'g-flat', name: 'Flat 4B', type: 'home')]),
  ),
];

/// Stored photos wait for this until the file is decoded (a load started in fake time never finishes).
// Created lazily inside the test body: a completer made in setUp would flush outside fake time.
Completer<void>? _decoded;

Future<void> _ready() => (_decoded ??= Completer<void>()).future;

late File _photo;
late SharedPreferences _prefs;

/// [pumpFixedFrames] while stored photos are held back, then the sample photo is decoded on the real event loop
/// (into the image cache, at every width a tile or page can ask for) and released: the next frame shows it.
Future<void> _pumpWithImages(WidgetTester tester) async {
  await pumpFixedFrames(tester);
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(() async {
    for (var width = 80; width <= 260; width++) {
      await precacheImage(ResizeImage(FileImage(_photo), width: width), context);
      await precacheImage(ResizeImage(MemoryImage(samplePhotoPng), width: width), context);
    }
    await precacheImage(FileImage(_photo), context);
    await precacheImage(MemoryImage(samplePhotoPng), context);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  (_decoded ??= Completer<void>()).complete();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

List<_Case> _cases() {
  final rows = [
    sampleAttachmentRow(id: 'a1'),
    sampleAttachmentRow(id: 'a2', kind: AttachmentKind.pdf, sizeBytes: 1258291, position: 1),
    sampleAttachmentRow(id: 'a3', position: 2),
  ];
  return [
    (
      'receipt_files',
      () => _SheetHost(
        child: ReceiptField(receipt: _files(), onChanged: (_) {}),
      ),
      () => const <Override>[],
      915,
    ),
    (
      'receipt_full',
      () => _SheetHost(
        child: ReceiptField(receipt: _files(photos: 6, pdfs: 4), onChanged: (_) {}),
      ),
      () => const <Override>[],
      915,
    ),
    (
      'expense_attachments',
      () => const ExpenseDetailScreen(expenseId: 'e1'),
      () => [
        noRepeat('e1'),
        commentThreadProvider((groupId: gid, targetType: 'expense', targetId: 'e1'))
            .overrideWithValue(const AsyncData([])),
        expenseViewProvider('e1').overrideWithValue(AsyncData(sampleView(sampleExpense()))),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
        expenseAttachmentsProvider('e1').overrideWith((ref) => Stream.value(rows)),
        ...storedAttachments(rows, _photo, ready: _ready),
      ],
      1300,
    ),
    (
      'pdf_viewer',
      () => PdfViewerScreen(name: 'Hotel invoice.pdf', path: _pdfPath, onRemove: () async => false),
      () => [
        pdfPlatformProvider.overrideWithValue(FakePdfPlatform()),
        attachmentFileProvider(_pdfPath).overrideWith((ref) async => _photo),
      ],
      915,
    ),
    (
      'photo_viewer_full_loading',
      () => const PhotoViewerScreen(
        title: 'Photo',
        bucket: AttachmentPaths.bucket,
        path: _fullPath,
        placeholderPath: _thumbPath,
      ),
      () => [
        storedPhotoProvider((bucket: AttachmentPaths.bucket, path: _thumbPath, thumb: true))
            .overrideWith((ref) async {
              await _ready();
              return _photo;
            }),
        // The full photo never arrives: the thumbnail and the note stay.
        storedPhotoProvider((bucket: AttachmentPaths.bucket, path: _fullPath, thumb: false))
            .overrideWith((ref) => Completer<File>().future),
      ],
      915,
    ),
    (
      'month_summary_owed',
      () => _Page(child: MonthlySummaryCard(summary: _month())),
      () => const <Override>[],
      420,
    ),
    (
      'month_summary_two_currencies',
      () => _Page(
        child: MonthlySummaryCard(
          summary: _month(
            spent: const {'INR': 425000, 'USD': 2000},
            groups: 3,
            balances: const {'INR': 120000, 'USD': -500},
            unsynced: true,
          ),
        ),
      ),
      () => const <Override>[],
      420,
    ),
    ('notification_settings_summary', () => const NotificationSettingsScreen(), _settings, 2150),
    (
      'account_settings_crash_on',
      () => const _Page(child: AccountSettingsList()),
      () => [
        ...accountSettingsOverrides(),
        sharedPreferencesProvider.overrideWithValue(_prefs),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        crashReportsSettingProvider.overrideWith(_CrashOn.new),
      ],
      1500,
    ),
    (
      'account_settings_crash_unavailable',
      () => const _Page(child: AccountSettingsList()),
      () => [...accountSettingsOverrides(), sharedPreferencesProvider.overrideWithValue(_prefs)],
      1500,
    ),
  ];
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });
  setUp(() => _decoded = null);
  final dir = Directory.systemTemp.createTempSync('splitify_golden_w2y');
  _photo = File('${dir.path}/p.png')..writeAsBytesSync(samplePhotoPng);
  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the image file open a little longer; the OS clears the temp folder later.
    }
  });
  for (final (name, screen, overrides, height) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'w2y $name ${mode.name} $suffix',
          fileName: 'w2y_${name}_${mode.name}_$suffix',
          pumpBeforeTest: _pumpWithImages,
          builder: () => expenseApp(
            screen(),
            overrides: overrides(),
            mode: mode,
            scale: scale,
            size: Size(goldenWidth, scale > 1 ? height * 1.8 : height),
          ),
        );
      }
    }
    goldenTest(
      'w2y $name small phone',
      fileName: 'w2y_${name}_small_light_text100',
      pumpBeforeTest: _pumpWithImages,
      builder: () => expenseApp(screen(), overrides: overrides(), size: _small),
    );
  }
}
