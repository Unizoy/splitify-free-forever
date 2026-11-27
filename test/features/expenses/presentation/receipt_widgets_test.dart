// TC-29 UI: receipt photo field in the editor's receipt sheet (D-032) and the receipt card on the expense detail.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/features/photos/presentation/stored_photo.dart';

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

  @override
  Future<void> replaceReceipt(LocalExpense e, PreparedImage image) async =>
      calls.add('replace ${e.id}');
}

LocalExpense _withReceipt() => sampleExpense().copyWith(receiptPath: const Value(_path));

void main() {
  group('Receipt field (editor receipt sheet)', () {
    // TC-29 UI
    testWidgets('empty: shows the dashed add tile and no photo row', (t) async {
      await _pumpDetails(t);
      await reveal(t, _key('receipt-add'));
      expect(_key('receipt-add'), findsOneWidget);
      expect(_key('receipt-photo'), findsNothing);
      expect(find.text('Add receipt photo'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('add tile opens the source sheet with camera and gallery', (t) async {
      await _pumpDetails(t);
      await tapKey(t, 'receipt-add');
      expect(find.text('Add a photo'), findsOneWidget);
      expect(_key('photo-camera'), findsOneWidget);
      expect(_key('photo-gallery'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('closing the sheet without choosing keeps the add tile', (t) async {
      final h = await _pumpDetails(t, extra: [pickerReturns(samplePrepared)]);
      await tapKey(t, 'receipt-add');
      await t.tapAt(const Offset(200, 20));
      await settle(t);
      expect(_key('photo-camera'), findsNothing);
      expect(h.draft.receipt.hasPhoto, isFalse);
      expect(_key('receipt-add'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('picking a photo shows the photo row; Remove goes back to the add tile', (t) async {
      final h = await _pumpDetails(t, extra: [pickerReturns(samplePrepared)]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'photo-gallery');
      await reveal(t, _key('receipt-photo'));
      expect(_key('receipt-photo'), findsOneWidget);
      expect(_key('receipt-replace'), findsOneWidget);
      expect(_key('receipt-remove'), findsOneWidget);
      expect(_key('receipt-add'), findsNothing);
      expect(h.draft.receipt.picked, isNotNull);
      expect(find.text('Receipt photo'), findsOneWidget);

      await tapKey(t, 'receipt-remove');
      expect(_key('receipt-add'), findsOneWidget);
      expect(_key('receipt-photo'), findsNothing);
      expect(h.draft.receipt.hasPhoto, isFalse);
    });

    // TC-29 UI
    testWidgets('Replace asks for a new photo through the same sheet', (t) async {
      await _pumpDetails(t, extra: [pickerReturns(samplePrepared)]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'photo-camera');
      await tapKey(t, 'receipt-replace');
      expect(find.text('Add a photo'), findsOneWidget);
      await tapKey(t, 'photo-gallery');
      expect(_key('receipt-photo'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('a picker that throws shows a snackbar and keeps the add tile', (t) async {
      final h = await _pumpDetails(t, extra: [pickerThrows()]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'photo-gallery');
      expect(find.text("Couldn't use that photo. Try another one."), findsOneWidget);
      expect(h.draft.receipt.hasPhoto, isFalse);
      expect(_key('receipt-add'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('a picker that returns nothing (backed out) changes nothing', (t) async {
      final h = await _pumpDetails(t, extra: [pickerReturns(null)]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'photo-gallery');
      expect(h.draft.receipt.hasPhoto, isFalse);
      expect(find.text("Couldn't use that photo. Try another one."), findsNothing);
    });

    // TC-29 UI
    testWidgets('a saved receipt shows a stored photo; pending shows the upload note', (t) async {
      final file = samplePhotoFile(addTearDown);
      await _pumpDetails(
        t,
        receipt: const ReceiptDraft.saved(_path),
        extra: storedReceipt(_path, file, pending: true),
      );
      await reveal(t, _key('receipt-photo'));
      expect(find.byType(StoredPhoto), findsOneWidget);
      expect(find.text("Uploads when you're online"), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('a saved receipt that is not pending has no upload note; Remove marks it removed', (
      t,
    ) async {
      final file = samplePhotoFile(addTearDown);
      final h = await _pumpDetails(
        t,
        receipt: const ReceiptDraft.saved(_path),
        extra: storedReceipt(_path, file),
      );
      await reveal(t, _key('receipt-photo'));
      expect(find.text("Uploads when you're online"), findsNothing);
      await tapKey(t, 'receipt-remove');
      expect(h.draft.receipt.removed, isTrue);
      expect(_key('receipt-add'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('tapping the thumbnail opens the full-screen viewer, close returns', (t) async {
      await _pumpDetails(t, extra: [pickerReturns(samplePrepared)]);
      await tapKey(t, 'receipt-add');
      await tapKey(t, 'photo-gallery');
      await tapKey(t, 'receipt-open');
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      // The editor's own Replace/Remove are not offered in the viewer from the field.
      expect(_key('photo-replace'), findsNothing);
      await tapKey(t, 'photo-close');
      expect(find.byType(PhotoViewerScreen), findsNothing);
    });
  });

  group('Receipt card (expense detail)', () {
    Future<List<String>> pumpDetail(WidgetTester t, LocalExpense e, {bool pending = false}) async {
      usePhone(t);
      final file = samplePhotoFile(addTearDown);
      final calls = <String>[];
      await t.pumpWidget(
        expenseApp(
          const ExpenseDetailScreen(expenseId: 'e1'),
          overrides: [
            expenseViewProvider('e1').overrideWithValue(AsyncData(sampleView(e))),
            expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
            expenseActionsProvider.overrideWith((ref) => _RecordingActions(ref, calls)),
            pickerReturns(samplePrepared),
            ...storedReceipt(_path, file, pending: pending),
          ],
        ),
      );
      await settle(t);
      return calls;
    }

    // TC-29 UI
    testWidgets('no receipt: no card', (t) async {
      await pumpDetail(t, sampleExpense());
      expect(_key('expense-receipt'), findsNothing);
    });

    // TC-29 UI
    testWidgets('with a receipt: card shows "Open photo", no pending chip', (t) async {
      await pumpDetail(t, _withReceipt());
      await reveal(t, _key('expense-receipt'));
      expect(_key('expense-receipt'), findsOneWidget);
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
    testWidgets('tap opens the viewer with Replace and Remove', (t) async {
      await pumpDetail(t, _withReceipt());
      await tapKey(t, 'expense-receipt');
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(_key('photo-replace'), findsOneWidget);
      expect(_key('photo-remove'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('Remove asks first; confirming removes the receipt and says so', (t) async {
      final calls = await pumpDetail(t, _withReceipt());
      await tapKey(t, 'expense-receipt');
      await tapKey(t, 'photo-remove');
      expect(find.text('Remove the receipt photo?'), findsOneWidget);
      expect(calls, isEmpty);
      await tapKey(t, 'confirm-action');
      expect(calls, ['remove e1']);
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(find.text('Receipt photo removed'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('cancelling the Remove confirmation keeps the receipt and the viewer', (t) async {
      final calls = await pumpDetail(t, _withReceipt());
      await tapKey(t, 'expense-receipt');
      await tapKey(t, 'photo-remove');
      await tapText(t, 'Cancel');
      expect(calls, isEmpty);
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('Replace picks a photo, replaces the receipt and closes the viewer', (t) async {
      final calls = await pumpDetail(t, _withReceipt());
      await tapKey(t, 'expense-receipt');
      await tapKey(t, 'photo-replace');
      await tapKey(t, 'photo-gallery');
      expect(calls, ['replace e1']);
      expect(find.byType(PhotoViewerScreen), findsNothing);
      expect(find.text('Receipt photo replaced'), findsOneWidget);
    });
  });
}
