// W2-Y expense attachments (D-034 P-7): the grid of photo and PDF tiles, the add flow, the PDF viewer and the
// full-size photo viewer with its thumbnail placeholder. No network, no platform channel: a fake picker, a
// fake PDF platform and stored-file overrides.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/features/attachments/application/attachment_providers.dart';
import 'package:splitify/features/attachments/presentation/attachment_flows.dart';
import 'package:splitify/features/attachments/presentation/attachment_widgets.dart';
import 'package:splitify/features/attachments/presentation/pdf_viewer_screen.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/receipt_field.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/features/photos/presentation/stored_photo.dart';
import 'package:splitify/l10n/app_localizations_en.dart';
import 'package:splitify/ui/components/components.dart';

import '../../support/attachment_fixtures.dart';
import '../../support/photo_fixtures.dart';
import '../expenses/expense_fixtures.dart';
import '../expenses/presentation/presentation_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

/// [child] in a themed, scrollable screen (phone-sized).
Future<void> _pumpWidget(
  WidgetTester t,
  Widget child, {
  List<Override> overrides = const [],
  double scale = 1,
}) async {
  usePhone(t);
  await t.pumpWidget(
    expenseApp(
      Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
      overrides: overrides,
      scale: scale,
    ),
  );
  await settle(t);
}

/// A [screen] pushed from a home button, so it can pop like in the app.
Future<void> _pumpScreen(
  WidgetTester t,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  usePhone(t);
  await t.pumpWidget(expenseApp(PushHost(screen), overrides: overrides));
  await t.tap(_key('open'));
  await settle(t);
}

/// The receipt field with its own draft, recording every change.
class _FieldHost extends StatefulWidget {
  const _FieldHost({required this.log, this.initial = const ReceiptDraft.none()});

  final List<ReceiptDraft> log;
  final ReceiptDraft initial;

  @override
  State<_FieldHost> createState() => _FieldHostState();
}

class _FieldHostState extends State<_FieldHost> {
  late ReceiptDraft draft = widget.initial;

  @override
  Widget build(BuildContext context) => ReceiptField(
    receipt: draft,
    onChanged: (d) {
      widget.log.add(d);
      setState(() => draft = d);
    },
  );
}

List<AttachmentItem> _picked(int n) => [
  for (var i = 0; i < n; i++) PickedAttachment(pickedPhoto(id: 'p$i')),
];

void main() {
  final l = AppLocalizationsEn();

  group('texts', () {
    // TC-29 UI
    test('sizes read in KB below a megabyte and MB with one decimal above', () {
      expect(attachmentSize(l, 'en', 340 * 1024), '340 KB');
      expect(attachmentSize(l, 'en', 1), '1 KB');
      expect(attachmentSize(l, 'en', 1024 * 1024), '1.0 MB');
      expect(attachmentSize(l, 'en', 1258291), '1.2 MB');
      expect(attachmentSize(l, 'en', 24 * 1024 * 1024), '24.0 MB');
    });

    // TC-29 UI
    test('every reason a file is refused has its own line', () {
      expect(
        attachmentProblemText(l, AttachmentProblem.tooMany),
        'An expense can have up to 10 files.',
      );
      expect(
        attachmentProblemText(l, AttachmentProblem.tooBig),
        'That PDF is over 5 MB. Try a smaller one.',
      );
      expect(
        attachmentProblemText(l, AttachmentProblem.tooMuchInTotal),
        'Files on one expense can be up to 25 MB together.',
      );
      expect(
        attachmentProblemText(l, AttachmentProblem.unreadable),
        "Couldn't use that file. Pick a photo or a PDF.",
      );
    });

    // TC-29 UI
    testWidgets('the summary line counts files against the limit and shows the size', (t) async {
      await _pumpWidget(t, const AttachmentSummaryLine(count: 2, bytes: 1258291));
      expect(find.text('2 of 10 files · 1.2 MB'), findsOneWidget);
    });
  });

  group('AttachmentGrid', () {
    // TC-29 UI
    testWidgets('a photo and a PDF: tiles with names and sizes, labelled for screen readers', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await _pumpWidget(
        t,
        AttachmentGrid(
          items: [
            PickedAttachment(pickedPhoto(id: 'p1')),
            PickedAttachment(pickedPdf(id: 'd1', bytes: 1258291)),
          ],
          onOpen: (_) {},
        ),
      );
      expect(_key('attachment-open-p1'), findsOneWidget);
      expect(_key('attachment-open-d1'), findsOneWidget);
      // The PDF face: name and size.
      expect(find.text('Hotel invoice.pdf'), findsOneWidget);
      expect(find.text('1.2 MB'), findsOneWidget);
      // The photo tile shows the thumbnail, not a PDF face.
      expect(find.byType(MemoryPhoto), findsOneWidget);
      // Screen readers: "Photo 1 of 2, open" and "PDF Hotel invoice.pdf 1.2 MB, open".
      expect(find.bySemanticsLabel('Photo 1 of 2, open'), findsOneWidget);
      expect(find.bySemanticsLabel('PDF Hotel invoice.pdf 1.2 MB, open'), findsOneWidget);
      handle.dispose();
    });

    // TC-29 UI
    testWidgets('saved files: a stored photo tile and a PDF tile with its stored size', (t) async {
      final handle = t.ensureSemantics();
      final file = samplePhotoFile(addTearDown);
      final rows = [
        sampleAttachmentRow(id: 'a1'),
        sampleAttachmentRow(id: 'a2', kind: AttachmentKind.pdf, name: 'Ticket.pdf', position: 1),
      ];
      await _pumpWidget(
        t,
        AttachmentGrid(items: [for (final r in rows) SavedAttachment(r)], onOpen: (_) {}),
        overrides: storedAttachments(rows, file),
      );
      expect(find.byType(StoredPhoto), findsOneWidget);
      expect(find.text('Ticket.pdf'), findsOneWidget);
      expect(find.text('340 KB'), findsOneWidget);
      expect(find.bySemanticsLabel('PDF Ticket.pdf 340 KB, open'), findsOneWidget);
      handle.dispose();
    });

    // TC-29 UI
    testWidgets('a file waiting for upload carries the cloud badge', (t) async {
      final row = sampleAttachmentRow(id: 'a1', kind: AttachmentKind.pdf);
      await _pumpWidget(
        t,
        AttachmentGrid(items: [SavedAttachment(row)], onOpen: (_) {}),
        overrides: [
          photoPendingProvider((bucket: AttachmentPaths.bucket, path: row.path, thumb: false))
              .overrideWith((ref) => Stream.value(true)),
        ],
      );
      expect(_key('attachment-waiting-a1'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('three tiles across at normal text, two across at 2.0', (t) async {
      final items = _picked(3);
      await _pumpWidget(t, AttachmentGrid(items: items, onOpen: (_) {}));
      var tops = [for (final i in items) t.getTopLeft(_key('attachment-open-${i.key}')).dy];
      expect(tops.toSet(), hasLength(1));
      expect(
        t.getSize(_key('attachment-open-p0')).width,
        closeTo(t.getSize(_key('attachment-open-p0')).height, 0.5),
      );

      await _pumpWidget(t, AttachmentGrid(items: items, onOpen: (_) {}), scale: 2);
      tops = [for (final i in items) t.getTopLeft(_key('attachment-open-${i.key}')).dy];
      expect(tops.toSet(), hasLength(2));
    });

    // TC-29 UI
    testWidgets('Add shows while there is room and is gone at ten files', (t) async {
      await _pumpWidget(t, AttachmentGrid(items: _picked(9), onOpen: (_) {}, onAdd: () {}));
      expect(_key('attachment-add'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      await _pumpWidget(t, AttachmentGrid(items: _picked(10), onOpen: (_) {}, onAdd: () {}));
      expect(_key('attachment-add'), findsNothing);
    });

    // TC-29 UI
    testWidgets('without onAdd there is no Add tile; without onRemove no × buttons', (t) async {
      await _pumpWidget(t, AttachmentGrid(items: _picked(2), onOpen: (_) {}));
      expect(_key('attachment-add'), findsNothing);
      expect(_key('attachment-remove-p0'), findsNothing);
      expect(_key('attachment-remove-p1'), findsNothing);
    });

    // TC-29 UI
    testWidgets('open, remove and add call back with the right file', (t) async {
      final opened = <String>[];
      final removed = <String>[];
      var adds = 0;
      await _pumpWidget(
        t,
        AttachmentGrid(
          items: _picked(2),
          onOpen: (i) => opened.add(i.key),
          onRemove: (i) => removed.add(i.key),
          onAdd: () => adds++,
        ),
      );
      await t.tap(_key('attachment-open-p1'));
      await t.tap(_key('attachment-remove-p0'));
      await t.tap(_key('attachment-add'));
      expect(opened, ['p1']);
      expect(removed, ['p0']);
      expect(adds, 1);
    });
  });

  group('add flow (receipt field)', () {
    // TC-29 UI
    testWidgets('two photos picked: onChanged gets both, the grid and summary show them', (
      t,
    ) async {
      final log = <ReceiptDraft>[];
      final picker = FakeAttachmentPicker(
        files: [
          pickedPhoto(id: 'p1'),
          pickedPhoto(id: 'p2'),
        ],
      );
      await _pumpWidget(t, _FieldHost(log: log), overrides: [picker.override]);
      await t.tap(_key('receipt-add'));
      await settle(t);
      await t.tap(_key('attach-photos'));
      await settle(t);
      expect(log.single.added.map((a) => a.id), ['p1', 'p2']);
      expect(_key('attachment-open-p1'), findsOneWidget);
      expect(_key('attachment-open-p2'), findsOneWidget);
      expect(find.textContaining('2 of 10 files'), findsOneWidget);
      expect(picker.calls.single.max, 10);
    });

    // TC-29 UI
    testWidgets('a pick that comes back "too big" says so and adds nothing', (t) async {
      final log = <ReceiptDraft>[];
      final picker = FakeAttachmentPicker(problem: AttachmentProblem.tooBig);
      await _pumpWidget(t, _FieldHost(log: log), overrides: [picker.override]);
      await t.tap(_key('receipt-add'));
      await settle(t);
      await t.tap(_key('attach-pdf'));
      await settle(t);
      expect(find.text(l.w2yAttachTooBig(5)), findsOneWidget);
      expect(log, isEmpty);
      expect(_key('receipt-add'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('a PDF over 5 MB is refused here too, while the photo next to it is kept', (
      t,
    ) async {
      final log = <ReceiptDraft>[];
      final picker = FakeAttachmentPicker(
        files: [
          pickedPhoto(id: 'p1'),
          pickedPdf(id: 'big', bytes: 5 * 1024 * 1024 + 1),
        ],
      );
      await _pumpWidget(t, _FieldHost(log: log), overrides: [picker.override]);
      await t.tap(_key('receipt-add'));
      await settle(t);
      await t.tap(_key('attach-photos'));
      await settle(t);
      expect(log.single.added.map((a) => a.id), ['p1']);
      expect(find.text('That PDF is over 5 MB. Try a smaller one.'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('files that together pass 25 MB are refused', (t) async {
      final log = <ReceiptDraft>[];
      final rows = [
        for (var i = 0; i < 8; i++)
          sampleAttachmentRow(
            id: 's$i',
            kind: AttachmentKind.pdf,
            sizeBytes: 3 * 1024 * 1024,
            position: i,
          ),
      ];
      final picker = FakeAttachmentPicker(
        files: [pickedPdf(id: 'n1', bytes: 2 * 1024 * 1024)],
      );
      await _pumpWidget(
        t,
        _FieldHost(
          log: log,
          initial: ReceiptDraft.saved(null, attachments: rows),
        ),
        overrides: [picker.override],
      );
      await t.tap(_key('attachment-add'));
      await settle(t);
      await t.tap(_key('attach-pdf'));
      await settle(t);
      expect(find.text('Files on one expense can be up to 25 MB together.'), findsOneWidget);
      expect(log, isEmpty);
    });

    // TC-29 UI
    testWidgets('the source sheet offers camera, photos and PDF with the privacy hint', (t) async {
      final picker = FakeAttachmentPicker();
      await _pumpWidget(t, _FieldHost(log: []), overrides: [picker.override]);
      await t.tap(_key('receipt-add'));
      await settle(t);
      expect(find.text('Add to this expense'), findsOneWidget);
      expect(_key('attach-camera'), findsOneWidget);
      expect(_key('attach-photos'), findsOneWidget);
      expect(_key('attach-pdf'), findsOneWidget);
      expect(find.text(l.w2yAttachSourceHint), findsOneWidget);
    });
  });

  group('PdfViewerScreen', () {
    Future<(FakePdfPlatform, File)> pumpPdf(
      WidgetTester t, {
      FakePdfPlatform? platform,
      Future<bool> Function()? onRemove,
      Object? fileError,
    }) async {
      final fake = platform ?? FakePdfPlatform();
      final file = samplePhotoFile(addTearDown, 'invoice.pdf');
      await _pumpScreen(
        t,
        PdfViewerScreen(name: 'Hotel invoice.pdf', path: 'g-goa/e1/a2.pdf', onRemove: onRemove),
        overrides: [
          pdfPlatformProvider.overrideWithValue(fake),
          attachmentFileProvider('g-goa/e1/a2.pdf').overrideWith((ref) async {
            if (fileError != null) throw fileError;
            return file;
          }),
        ],
      );
      // Page images decode on the real event loop.
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(t);
      return (fake, file);
    }

    // TC-29 UI
    testWidgets('both pages render under the file name; a tap opens the page zoomed', (t) async {
      final (fake, _) = await pumpPdf(t);
      expect(find.text('Hotel invoice.pdf'), findsOneWidget);
      expect(_key('pdf-pages'), findsOneWidget);
      expect(_key('pdf-page-0'), findsOneWidget);
      expect(_key('pdf-page-1'), findsOneWidget);
      expect(fake.rendered, containsAll([0, 1]));
      expect(find.byType(Image), findsNWidgets(2));
      expect(_key('pdf-remove'), findsNothing);

      await t.tap(_key('pdf-page-1'));
      await settle(t);
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(find.text('Page 2 of 2'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('Open with hands the file on; with no app it says so and keeps the pages', (
      t,
    ) async {
      final (fake, file) = await pumpPdf(t, platform: FakePdfPlatform(canOpen: false));
      await t.tap(_key('pdf-open-with'));
      await settle(t);
      expect(fake.opened, [file.path]);
      expect(find.text(l.w2yPdfNoApp), findsOneWidget);
      expect(_key('pdf-pages'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('Open with is quiet when an app takes the PDF', (t) async {
      final (fake, _) = await pumpPdf(t);
      await t.tap(_key('pdf-open-with'));
      await settle(t);
      expect(fake.opened, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    // TC-29 UI
    testWidgets('offline and not on this phone: says it opens when online; Open with is off', (
      t,
    ) async {
      await pumpPdf(t, fileError: const MediaOffline());
      expect(_key('pdf-problem'), findsOneWidget);
      expect(find.text("Opens when you're online"), findsOneWidget);
      expect(t.widget<HeroIconButton>(_key('pdf-open-with')).onPressed, isNull);
      expect(_key('pdf-pages'), findsNothing);
    });

    // TC-29 UI
    testWidgets('a file that is not a readable PDF says so', (t) async {
      await pumpPdf(t, platform: FakePdfPlatform(fails: true));
      expect(find.text("This PDF can't be shown."), findsOneWidget);
      expect(_key('pdf-pages'), findsNothing);
    });

    // TC-29 UI
    testWidgets('a download that fails for another reason says the PDF cannot be shown', (t) async {
      await pumpPdf(t, fileError: const MediaRejected('not_found'));
      expect(find.text("This PDF can't be shown."), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('Remove closes the viewer when it removed the file', (t) async {
      var calls = 0;
      await pumpPdf(
        t,
        onRemove: () async {
          calls++;
          return true;
        },
      );
      await t.tap(_key('pdf-remove'));
      await settle(t);
      expect(calls, 1);
      expect(find.byType(PdfViewerScreen), findsNothing);
    });

    // TC-29 UI
    testWidgets('Remove keeps the viewer open when nothing was removed (confirm cancelled)', (
      t,
    ) async {
      await pumpPdf(t, onRemove: () async => false);
      await t.tap(_key('pdf-remove'));
      await settle(t);
      expect(find.byType(PdfViewerScreen), findsOneWidget);
      expect(t.widget<PillButton>(_key('pdf-remove')).onPressed, isNotNull);
    });

    // TC-29 UI
    testWidgets('close pops the viewer', (t) async {
      await pumpPdf(t);
      await t.tap(_key('pdf-close'));
      await settle(t);
      expect(find.byType(PdfViewerScreen), findsNothing);
    });
  });

  group('PhotoViewerScreen full size over its thumbnail', () {
    const full = 'g-goa/e1/a1.jpg';
    const thumb = 'g-goa/e1/a1-thumb.jpg';

    Override stored(String path, bool isThumb, Future<File> Function() answer) =>
        storedPhotoProvider((bucket: AttachmentPaths.bucket, path: path, thumb: isThumb))
            .overrideWith((ref) => answer());

    Future<void> pumpViewer(WidgetTester t, Future<File> Function() fullAnswer) async {
      final file = samplePhotoFile(addTearDown);
      await _pumpScreen(
        t,
        const PhotoViewerScreen(
          title: 'Photo',
          bucket: AttachmentPaths.bucket,
          path: full,
          placeholderPath: thumb,
        ),
        overrides: [stored(thumb, true, () async => file), stored(full, false, fullAnswer)],
      );
    }

    // TC-29 UI
    testWidgets('while the full photo loads: the thumbnail shows with a "Loading full size" note', (
      t,
    ) async {
      final never = Completer<File>();
      await pumpViewer(t, () => never.future);
      expect(_key('photo-full-note'), findsOneWidget);
      expect(find.text('Loading full size'), findsOneWidget);
      expect(_key('photo-full'), findsNothing);
      expect(find.byType(StoredPhoto), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('offline and not downloaded: keeps the thumbnail with the "online" note', (
      t,
    ) async {
      await pumpViewer(t, () async => throw const MediaOffline());
      expect(find.text("Full size shows when you're online"), findsOneWidget);
      expect(_key('photo-full'), findsNothing);
      expect(find.byType(StoredPhoto), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('loaded: the full photo replaces the thumbnail and the note goes', (t) async {
      final file = samplePhotoFile(addTearDown, 'full.png');
      await pumpViewer(t, () async => file);
      expect(_key('photo-full'), findsOneWidget);
      expect(_key('photo-full-note'), findsNothing);
      expect(find.byType(StoredPhoto), findsNothing);
    });

    // TC-29 UI
    testWidgets('another failure shows no note and keeps the thumbnail', (t) async {
      await pumpViewer(t, () async => throw const MediaRejected('not_found'));
      expect(_key('photo-full-note'), findsNothing);
      expect(_key('photo-full'), findsNothing);
      expect(find.byType(StoredPhoto), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('a photo with no thumbnail has no note, just the stored photo', (t) async {
      final never = Completer<File>();
      await _pumpScreen(
        t,
        const PhotoViewerScreen(title: 'Receipt photo', bucket: AttachmentPaths.bucket, path: full),
        overrides: [stored(full, false, () => never.future)],
      );
      expect(_key('photo-full-note'), findsNothing);
      expect(find.byType(StoredPhoto), findsOneWidget);
    });
  });
}
