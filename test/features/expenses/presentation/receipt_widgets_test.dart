// TC-29 UI + W2-Y: the files field in the editor's receipt sheet (photos and PDFs, D-034 P-7) and the receipt
// card on the expense detail (the old single receipt photo, one saved photo, or several files).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/attachments_repository.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/features/attachments/application/attachment_picker.dart'
    show AttachmentSource;
import 'package:splitify/features/attachments/application/attachment_providers.dart';
import 'package:splitify/features/attachments/presentation/pdf_viewer_screen.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/features/photos/presentation/stored_photo.dart';

import '../../../support/attachment_fixtures.dart';
import '../../../support/photo_fixtures.dart';
import '../expense_fixtures.dart';
import 'presentation_harness.dart';

const _path = 'g-goa/e1/r1.jpg';

Finder _key(String k) => find.byKey(Key(k));

/// Opens the editor with [receipt] and its receipt sheet; [extra] overrides apply to the editor route.
Future<EditorHandle> _pumpDetails(
  WidgetTester t, {
  ReceiptDraft receipt = const ReceiptDraft.none(),
  List<Override> extra = const [],
}) async {
  final h = await pumpEditor(t, sampleDraft().copyWith(receipt: receipt), overrides: extra);
  await tapKey(t, 'expense-receipt-chip');
  return h;
}

/// Records receipt changes instead of touching the database.
class _RecordingActions extends ExpenseActions {
  _RecordingActions(super.ref, this.calls);

  final List<String> calls;

  @override
  Future<void> removeReceipt(LocalExpense e) async => calls.add('remove ${e.id}');
}

/// Records attachment removals and restores.
class _FakeAttachments extends Fake implements AttachmentsRepository {
  final calls = <String>[];

  @override
  Future<void> remove(LocalAttachment a) async => calls.add('remove ${a.id}');

  @override
  Future<void> restore(LocalAttachment a) async => calls.add('restore ${a.id}');
}

LocalExpense _withReceipt() => sampleExpense().copyWith(receiptPath: const Value(_path));

void main() {
  group('Receipt field (editor receipt sheet)', () {
    // TC-29 UI
    testWidgets('empty: shows the dashed "Add photo or PDF" tile and no grid', (t) async {
      await _pumpDetails(t);
      await reveal(t, _key('receipt-add'));
      expect(_key('receipt-add'), findsOneWidget);
      expect(_key('receipt-photo'), findsNothing);
      expect(find.text('Add photo or PDF'), findsOneWidget);
      expect(find.text('Bills, tickets, invoices. Up to 10 files per expense.'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('add tile opens the source sheet: camera, photos and PDF', (t) async {
      await _pumpDetails(t);
      await tapKey(t, 'receipt-add');
      expect(find.text('Add to this expense'), findsOneWidget);
      expect(_key('attach-camera'), findsOneWidget);
      expect(_key('attach-photos'), findsOneWidget);
      expect(_key('attach-pdf'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('closing the sheet without choosing keeps the add tile and asks no picker', (
      t,
    ) async {
      final picker = FakeAttachmentPicker(files: [pickedPhoto()]);
      final h = await _pumpDetails(t, extra: [picker.override]);
      await tapKey(t, 'receipt-add');
      await t.tapAt(const Offset(200, 20));
      await settle(t);
      expect(_key('attach-camera'), findsNothing);
      expect(h.draft.receipt.hasPhoto, isFalse);
      expect(_key('receipt-add'), findsOneWidget);
      expect(picker.calls, isEmpty);
    });

    // TC-29 UI
    testWidgets(
      'picking a photo shows the grid with Add and the summary; × goes back to the add tile',
      (t) async {
        final picker = FakeAttachmentPicker(files: [pickedPhoto(id: 'p1')]);
        final h = await _pumpDetails(t, extra: [picker.override]);
        await tapKey(t, 'receipt-add');
        await tapKey(t, 'attach-photos');
        await reveal(t, _key('receipt-photo'));
        expect(picker.calls.single.source, AttachmentSource.photos);
        expect(picker.calls.single.max, 10);
        expect(_key('receipt-photo'), findsOneWidget);
        expect(_key('attachment-open-p1'), findsOneWidget);
        expect(_key('attachment-add'), findsOneWidget);
        expect(_key('receipt-add'), findsNothing);
        expect(h.draft.receipt.added.single.id, 'p1');
        expect(find.textContaining('1 of 10 files'), findsOneWidget);

        await tapKey(t, 'attachment-remove-p1');
        expect(_key('receipt-add'), findsOneWidget);
        expect(_key('receipt-photo'), findsNothing);
        expect(h.draft.receipt.hasPhoto, isFalse);
      },
    );

    // TC-29 UI
    testWidgets('the camera and PDF choices reach the picker; a PDF shows as a PDF tile', (
      t,
    ) async {
      final picker = FakeAttachmentPicker(files: [pickedPdf(id: 'd1')]);
      final h = await _pumpDetails(t, extra: [picker.override]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'attach-pdf');
      expect(picker.calls.single.source, AttachmentSource.pdf);
      await reveal(t, _key('attachment-open-d1'));
      expect(find.text('Hotel invoice.pdf'), findsOneWidget);
      expect(find.text('340 KB'), findsWidgets);
      expect(h.draft.receipt.added.single.kind, AttachmentKind.pdf);

      picker.files = [pickedPhoto(id: 'p2')];
      await tapKey(t, 'attachment-add');
      await tapKey(t, 'attach-camera');
      expect(picker.calls.last.source, AttachmentSource.camera);
      expect(picker.calls.last.max, 9);
    });

    // TC-29 UI
    testWidgets('a picker that throws shows a snackbar and keeps the add tile', (t) async {
      final picker = FakeAttachmentPicker(error: Exception('cannot read photo'));
      final h = await _pumpDetails(t, extra: [picker.override]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'attach-photos');
      expect(find.text("Couldn't use that file. Pick a photo or a PDF."), findsOneWidget);
      expect(h.draft.receipt.hasPhoto, isFalse);
      expect(_key('receipt-add'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('a picker that returns nothing (backed out) changes nothing', (t) async {
      final picker = FakeAttachmentPicker();
      final h = await _pumpDetails(t, extra: [picker.override]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'attach-photos');
      expect(h.draft.receipt.hasPhoto, isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    // TC-29 UI
    testWidgets('a file the picker reports as too big says so and is not added', (t) async {
      final picker = FakeAttachmentPicker(problem: AttachmentProblem.tooBig);
      final h = await _pumpDetails(t, extra: [picker.override]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'attach-pdf');
      expect(find.text('That PDF is over 5 MB. Try a smaller one.'), findsOneWidget);
      expect(h.draft.receipt.hasPhoto, isFalse);
    });

    // TC-29 UI
    testWidgets('only what fits is added: the tenth file goes in, the eleventh is refused', (
      t,
    ) async {
      final saved = [
        for (var i = 0; i < 9; i++)
          sampleAttachmentRow(id: 's$i', kind: AttachmentKind.pdf, position: i),
      ];
      final picker = FakeAttachmentPicker(
        files: [
          pickedPdf(id: 'n1'),
          pickedPdf(id: 'n2'),
        ],
      );
      final h = await _pumpDetails(
        t,
        receipt: ReceiptDraft.saved(null, attachments: saved),
        extra: [picker.override],
      );
      await reveal(t, _key('attachment-add'));
      await tapKey(t, 'attachment-add');
      await tapKey(t, 'attach-pdf');
      expect(picker.calls.single.max, 1);
      expect(h.draft.receipt.count, 10);
      expect(h.draft.receipt.added.single.id, 'n1');
      expect(find.text('An expense can have up to 10 files.'), findsOneWidget);
      expect(_key('attachment-add'), findsNothing);
    });

    // TC-29 UI
    testWidgets('saved files show as tiles; × takes one out before Save', (t) async {
      final file = samplePhotoFile(addTearDown);
      final rows = [
        sampleAttachmentRow(id: 'a1'),
        sampleAttachmentRow(id: 'a2', kind: AttachmentKind.pdf, position: 1),
      ];
      final h = await _pumpDetails(
        t,
        receipt: ReceiptDraft.saved(null, attachments: rows),
        extra: storedAttachments(rows, file),
      );
      await reveal(t, _key('receipt-photo'));
      expect(_key('attachment-open-a1'), findsOneWidget);
      expect(_key('attachment-open-a2'), findsOneWidget);
      expect(find.byType(StoredPhoto), findsOneWidget);
      await tapKey(t, 'attachment-remove-a2');
      expect(_key('attachment-open-a2'), findsNothing);
      expect(h.draft.receipt.removedIds, {'a2'});
      expect(h.draft.receipt.changed, isTrue);
    });

    // TC-29 UI
    testWidgets('the old single receipt shows as a photo tile; pending shows the upload badge', (
      t,
    ) async {
      final file = samplePhotoFile(addTearDown);
      await _pumpDetails(
        t,
        receipt: const ReceiptDraft.saved(_path),
        extra: storedReceipt(_path, file, pending: true),
      );
      await reveal(t, _key('receipt-photo'));
      expect(find.byType(StoredPhoto), findsOneWidget);
      expect(_key('attachment-waiting-legacy:$_path'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('the old receipt that is not pending has no badge; × marks it removed', (t) async {
      final file = samplePhotoFile(addTearDown);
      final h = await _pumpDetails(
        t,
        receipt: const ReceiptDraft.saved(_path),
        extra: storedReceipt(_path, file),
      );
      await reveal(t, _key('receipt-photo'));
      expect(_key('attachment-waiting-legacy:$_path'), findsNothing);
      await tapKey(t, 'attachment-remove-legacy:$_path');
      expect(h.draft.receipt.removed, isTrue);
      expect(_key('receipt-add'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('tapping a picked photo opens the full-screen viewer; Remove drops it and closes', (
      t,
    ) async {
      final picker = FakeAttachmentPicker(files: [pickedPhoto(id: 'p1')]);
      final h = await _pumpDetails(t, extra: [picker.override]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'attach-photos');
      await tapKey(t, 'attachment-open-p1');
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(_key('photo-replace'), findsNothing);

      await tapKey(t, 'photo-close');
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(h.draft.receipt.added, hasLength(1));

      await tapKey(t, 'attachment-open-p1');
      await tapKey(t, 'photo-remove');
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(h.draft.receipt.added, isEmpty);
      expect(_key('receipt-add'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('tapping a picked PDF opens the PDF viewer', (t) async {
      final picker = FakeAttachmentPicker(files: [pickedPdf(id: 'd1')]);
      await _pumpDetails(t, extra: [picker.override]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'attach-pdf');
      await tapKey(t, 'attachment-open-d1');
      expect(find.byType(PdfViewerScreen), findsOneWidget);
      expect(find.text('Hotel invoice.pdf'), findsWidgets);
      expect(_key('pdf-remove'), findsOneWidget);
    });
  });

  group('Receipt card (expense detail)', () {
    Future<({List<String> calls, _FakeAttachments repo})> pumpDetail(
      WidgetTester t,
      LocalExpense e, {
      bool pending = false,
      List<LocalAttachment> rows = const [],
    }) async {
      usePhone(t);
      final file = samplePhotoFile(addTearDown);
      final calls = <String>[];
      final repo = _FakeAttachments();
      await t.pumpWidget(
        expenseApp(
          const ExpenseDetailScreen(expenseId: 'e1'),
          overrides: [
            expenseViewProvider('e1').overrideWithValue(AsyncData(sampleView(e))),
            expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
            expenseActionsProvider.overrideWith((ref) => _RecordingActions(ref, calls)),
            attachmentsRepositoryProvider.overrideWithValue(repo),
            expenseAttachmentsProvider('e1').overrideWith((ref) => Stream.value(rows)),
            ...storedReceipt(_path, file, pending: pending),
            ...storedAttachments(rows, file),
          ],
        ),
      );
      await settle(t);
      return (calls: calls, repo: repo);
    }

    // TC-29 UI
    testWidgets('no receipt and no files: no card', (t) async {
      await pumpDetail(t, sampleExpense());
      expect(_key('expense-receipt'), findsNothing);
      expect(_key('expense-attachments'), findsNothing);
    });

    // TC-29 UI
    testWidgets('with the old receipt: the wide photo shows "Open photo", no pending chip', (
      t,
    ) async {
      await pumpDetail(t, _withReceipt());
      await reveal(t, _key('expense-receipt'));
      expect(_key('expense-receipt'), findsOneWidget);
      expect(_key('expense-attachments'), findsNothing);
      expect(find.text('Open photo'), findsOneWidget);
      expect(find.text("Uploads when you're online"), findsNothing);
    });

    // TC-29 UI
    testWidgets('pending receipt shows the upload chip', (t) async {
      await pumpDetail(t, _withReceipt(), pending: true);
      await reveal(t, _key('expense-receipt'));
      expect(find.text("Uploads when you're online"), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('tap opens the viewer with Remove (no Replace any more)', (t) async {
      await pumpDetail(t, _withReceipt());
      await tapKey(t, 'expense-receipt');
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(_key('photo-replace'), findsNothing);
      expect(_key('photo-remove'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('Remove asks first; confirming clears the old receipt and says so', (t) async {
      final r = await pumpDetail(t, _withReceipt());
      await tapKey(t, 'expense-receipt');
      await tapKey(t, 'photo-remove');
      expect(find.text('Remove the receipt photo?'), findsOneWidget);
      expect(r.calls, isEmpty);
      await tapKey(t, 'confirm-action');
      expect(r.calls, ['remove e1']);
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(find.text('Receipt photo removed'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('cancelling the Remove confirmation keeps the receipt and the viewer', (t) async {
      final r = await pumpDetail(t, _withReceipt());
      await tapKey(t, 'expense-receipt');
      await tapKey(t, 'photo-remove');
      await tapText(t, 'Cancel');
      expect(r.calls, isEmpty);
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('a deleted expense opens its receipt without Remove', (t) async {
      await pumpDetail(t, _withReceipt().copyWith(deletedAt: const Value('2026-11-21T09:00:00Z')));
      await tapKey(t, 'expense-receipt');
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(_key('photo-remove'), findsNothing);
    });

    // TC-29 UI
    testWidgets('one saved photo is the wide photo too', (t) async {
      await pumpDetail(t, sampleExpense(), rows: [sampleAttachmentRow()]);
      await reveal(t, _key('expense-receipt'));
      expect(_key('expense-receipt'), findsOneWidget);
      expect(_key('expense-attachments'), findsNothing);
    });

    // TC-29 UI
    testWidgets('several files show a grid under "Receipts and files" without × buttons', (
      t,
    ) async {
      final rows = [
        sampleAttachmentRow(id: 'a1'),
        sampleAttachmentRow(id: 'a2', kind: AttachmentKind.pdf, position: 1),
        sampleAttachmentRow(id: 'a3', position: 2),
      ];
      await pumpDetail(t, sampleExpense(), rows: rows);
      await reveal(t, _key('expense-attachments'));
      expect(_key('expense-attachments'), findsOneWidget);
      expect(_key('expense-receipt'), findsNothing);
      expect(find.text('Receipts and files'), findsOneWidget);
      for (final id in ['a1', 'a2', 'a3']) {
        expect(_key('attachment-open-$id'), findsOneWidget);
        expect(_key('attachment-remove-$id'), findsNothing);
      }
      expect(_key('attachment-add'), findsNothing);
    });

    // TC-29 UI
    testWidgets('a single PDF is a grid, not the wide photo; the old receipt joins the grid', (
      t,
    ) async {
      await pumpDetail(
        t,
        _withReceipt(),
        rows: [sampleAttachmentRow(id: 'a2', kind: AttachmentKind.pdf)],
      );
      await reveal(t, _key('expense-attachments'));
      expect(_key('expense-attachments'), findsOneWidget);
      expect(_key('attachment-open-legacy:$_path'), findsOneWidget);
      expect(_key('attachment-open-a2'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('removing a saved photo from the viewer shows Undo, which restores it', (t) async {
      final row = sampleAttachmentRow(id: 'a1');
      final r = await pumpDetail(t, sampleExpense(), rows: [row]);
      await tapKey(t, 'expense-receipt');
      expect(_key('photo-remove'), findsOneWidget);
      await tapKey(t, 'photo-remove');
      expect(r.repo.calls, ['remove a1']);
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(find.text('Photo removed'), findsOneWidget);
      await tapText(t, 'Undo');
      expect(r.repo.calls, ['remove a1', 'restore a1']);
    });

    // TC-29 UI
    testWidgets('a saved PDF opens in the PDF viewer with Remove', (t) async {
      final rows = [
        sampleAttachmentRow(id: 'a1'),
        sampleAttachmentRow(id: 'a2', kind: AttachmentKind.pdf, position: 1),
      ];
      final fake = FakePdfPlatform();
      usePhone(t);
      final file = samplePhotoFile(addTearDown, 'i.pdf');
      await t.pumpWidget(
        expenseApp(
          const ExpenseDetailScreen(expenseId: 'e1'),
          overrides: [
            expenseViewProvider('e1').overrideWithValue(AsyncData(sampleView(sampleExpense()))),
            expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
            attachmentsRepositoryProvider.overrideWithValue(_FakeAttachments()),
            expenseAttachmentsProvider('e1').overrideWith((ref) => Stream.value(rows)),
            pdfPlatformProvider.overrideWithValue(fake),
            ...storedAttachments(rows, file),
          ],
        ),
      );
      await settle(t);
      await tapKey(t, 'attachment-open-a2');
      expect(find.byType(PdfViewerScreen), findsOneWidget);
      expect(_key('pdf-pages'), findsOneWidget);
      expect(_key('pdf-remove'), findsOneWidget);
    });
  });
}
