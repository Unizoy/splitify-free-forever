// W2-Y (P-7, S-432): attachment limits, names, PDF checks and the high-resolution photo compression ladder.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/attachments/application/attachment_picker.dart';
import 'package:splitify/features/photos/application/photo_compression.dart';

/// Fake encoder: the output's size follows the requested bound and quality, so the ladder can be checked.
class _Encoder {
  final calls = <(int, int)>[];
  int bytesPerStep = 0;

  Future<Uint8List> call(Uint8List source, {required int bound, required int quality}) async {
    calls.add((bound, quality));
    // A thumbnail (small bound) is always small; big photos shrink by [bytesPerStep] per ladder step.
    final size = bound < 1000 ? 40 * 1024 : (4 * 1024 * 1024) - bytesPerStep * (calls.length - 1);
    return Uint8List(size < 1 ? 1 : size);
  }
}

void main() {
  group('limits', () {
    test('a file fits until 10 files, 5 MB per PDF and 25 MB together', () {
      expect(attachmentProblem(count: 0, totalBytes: 0, sizeBytes: 100, isPdf: false), isNull);
      expect(
        attachmentProblem(count: 10, totalBytes: 0, sizeBytes: 1, isPdf: false),
        AttachmentProblem.tooMany,
      );
      expect(
        attachmentProblem(count: 1, totalBytes: 0, sizeBytes: 5 * 1024 * 1024 + 1, isPdf: true),
        AttachmentProblem.tooBig,
      );
      expect(
        attachmentProblem(count: 1, totalBytes: 0, sizeBytes: 5 * 1024 * 1024, isPdf: true),
        isNull,
      );
      expect(
        attachmentProblem(
          count: 5,
          totalBytes: 24 * 1024 * 1024,
          sizeBytes: 1024 * 1024 + 1,
          isPdf: false,
        ),
        AttachmentProblem.tooMuchInTotal,
      );
    });

    test('the app stays below the server limits (0029)', () {
      expect(AttachmentLimits.photoMaxBytes, lessThan(3 * 1024 * 1024));
      expect(AttachmentLimits.pdfMaxBytes, 5 * 1024 * 1024);
      expect(AttachmentLimits.perExpense, 10);
      expect(AttachmentLimits.bytesPerExpense, 25 * 1024 * 1024);
      expect(AttachmentLimits.ladder.first, (AttachmentLimits.photoSide, 85));
    });
  });

  group('names', () {
    test('folders and control characters go, long names keep their extension', () {
      expect(cleanAttachmentName(null), isNull);
      expect(cleanAttachmentName('   '), isNull);
      expect(cleanAttachmentName('/storage/emulated/0/Download/Hotel bill.pdf'), 'Hotel bill.pdf');
      expect(cleanAttachmentName(r'C:\docs\a.pdf'), 'a.pdf');
      expect(cleanAttachmentName('a\u0000b\u0007c.pdf'), 'abc.pdf');
      final long = cleanAttachmentName('${'x' * 200}.pdf')!;
      expect(long.length, AttachmentLimits.nameMaxLength);
      expect(long.endsWith('.pdf'), isTrue);
    });

    test('a PDF is recognised by its header', () {
      expect(looksLikePdf(Uint8List.fromList(utf8.encode('%PDF-1.7\n'))), isTrue);
      expect(looksLikePdf(Uint8List.fromList(utf8.encode('%PDF'))), isFalse);
      expect(looksLikePdf(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0, 0])), isFalse);
    });
  });

  group('new files', () {
    final image = PreparedImage(full: Uint8List(700), thumb: Uint8List(30));

    test('a photo row has its paths, size and pixels', () {
      final a = NewAttachment.photo(image, id: 'a1', width: 3072, height: 2304);
      expect(a.row('g', 'e', position: 2), {
        'expense_id': 'e',
        'kind': 'photo',
        'path': 'g/e/a1.jpg',
        'thumb_path': 'g/e/a1-thumb.jpg',
        'name': null,
        'size_bytes': 700,
        'width': 3072,
        'height': 2304,
        'position': 2,
      });
    });

    test('a PDF row has its name and no thumbnail', () {
      final a = NewAttachment.pdf(Uint8List(5), name: 'folder/Ticket.pdf', id: 'p1');
      expect(a.row('g', 'e', position: 0)['thumb_path'], isNull);
      expect(a.row('g', 'e', position: 0)['path'], 'g/e/p1.pdf');
      expect(a.name, 'Ticket.pdf');
      expect(a.sizeBytes, 5);
    });

    test('preparePdf keeps real PDFs up to 5 MB', () {
      final ok = preparePdf(Uint8List.fromList(utf8.encode('%PDF-1.4 hello')), 'Bill.pdf');
      expect(ok.file!.kind, AttachmentKind.pdf);
      expect(ok.problem, isNull);
      expect(
        preparePdf(Uint8List.fromList([1, 2, 3, 4, 5, 6]), 'x.pdf').problem,
        AttachmentProblem.unreadable,
      );
      final big = Uint8List(5 * 1024 * 1024 + 1)..setAll(0, utf8.encode('%PDF-'));
      expect(preparePdf(big, 'big.pdf').problem, AttachmentProblem.tooBig);
    });
  });

  group('photo compression (high resolution, S-432)', () {
    test(
      'a photo that fits at the first step stays at 3072 px, q85, with a 480 px thumbnail',
      () async {
        final enc = _Encoder()..bytesPerStep = 3 * 1024 * 1024; // 4 MB -> 1 MB at step 2
        final first = _Encoder();
        final small = await prepareAttachmentPhoto(
          Uint8List(10),
          encode: (s, {required bound, required quality}) async {
            first.calls.add((bound, quality));
            return Uint8List(bound < 1000 ? 30000 : 900 * 1024);
          },
          sizeOf: (b) async =>
              b.length == 10 ? (width: 4000, height: 3000) : (width: 3072, height: 2304),
        );
        expect(first.calls.first, (squareBound((width: 4000, height: 3000), 3072), 85));
        expect(first.calls.last, (squareBound((width: 4000, height: 3000), 480), 70));
        expect(first.calls, hasLength(2));
        expect(small.image!.full.length, 900 * 1024);
        expect((small.width, small.height), (3072, 2304));
        expect(enc.calls, isEmpty);
      },
    );

    test('a heavy photo walks down the ladder until it fits 1.5 MB', () async {
      final enc = _Encoder()..bytesPerStep = 1024 * 1024; // 4 MB, 3 MB, 2 MB, 1 MB ...
      final a = await prepareAttachmentPhoto(
        Uint8List(10),
        encode: enc.call,
        sizeOf: (b) async => (width: 3000, height: 4000),
      );
      expect(a.image!.full.length, lessThanOrEqualTo(AttachmentLimits.photoMaxBytes));
      // Steps 1–4 for the photo, then the thumbnail.
      expect(enc.calls.map((c) => c.$2), [85, 78, 75, 72, 70]);
      expect(enc.calls.last.$1, squareBound((width: 3000, height: 4000), 480));
    });

    test('a photo the size reader cannot read (HEIC) is re-encoded once first', () async {
      var reads = 0;
      final enc = _Encoder()..bytesPerStep = 4 * 1024 * 1024;
      await prepareAttachmentPhoto(
        Uint8List(10),
        encode: enc.call,
        sizeOf: (b) async {
          reads++;
          if (reads == 1) throw Exception('no decoder');
          return (width: 2000, height: 1500);
        },
      );
      expect(enc.calls.first, (AttachmentLimits.photoSide * 2, 95));
    });
  });
}
