// TC-29-01 (photo storage on the phone: staging, thumbnails, uploaded copies, cache, wipe).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/domain/entities/prepared_image.dart';

Uint8List _b(List<int> v) => Uint8List.fromList(v);

void main() {
  late Directory docs;
  late Directory cache;
  late MediaFiles files;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('media_docs');
    cache = Directory.systemTemp.createTempSync('media_cache');
    files = MediaFiles(docs: () async => docs, cache: () async => cache);
  });

  tearDown(() {
    for (final d in [docs, cache]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  final image = PreparedImage(full: _b([1, 2, 3]), thumb: _b([9]));
  const bucket = MediaBuckets.receipts;
  const path = 'g/e/p.jpg';

  // TC-29-01
  test('MediaFiles.stage writes the full photo and the thumbnail', () async {
    final rel = await files.stage(bucket, path, image);
    expect(rel, MediaFiles.pendingRel(bucket, path));
    expect(await files.read(rel), [1, 2, 3]);
    final thumb = await files.local(bucket, path, thumb: true);
    expect(thumb!.readAsBytesSync(), [9]);
    final full = await files.local(bucket, path, thumb: false);
    expect(full!.readAsBytesSync(), [1, 2, 3]);
  });

  // TC-29-01
  test('MediaFiles.read returns null when the file is gone', () async {
    expect(await files.read('media/pending/x/y.jpg'), isNull);
  });

  // TC-29-01
  test('MediaFiles.uploaded drops the full receipt photo and keeps the thumbnail', () async {
    await files.stage(bucket, path, image);
    await files.uploaded(bucket, path, keepFull: false);
    expect(await files.read(MediaFiles.pendingRel(bucket, path)), isNull);
    expect(await files.local(bucket, path, thumb: false), isNull);
    expect((await files.local(bucket, path, thumb: true))!.readAsBytesSync(), [9]);
  });

  // TC-29-01
  test('MediaFiles.uploaded moves a cover to the full folder, replacing an older copy', () async {
    const cover = MediaBuckets.groupCovers;
    await files.stage(cover, 'g/c.jpg', image);
    await files.uploaded(cover, 'g/c.jpg', keepFull: true);
    expect(await files.read(MediaFiles.pendingRel(cover, 'g/c.jpg')), isNull);
    final full = await files.local(cover, 'g/c.jpg', thumb: false);
    expect(full!.path.replaceAll(r'\', '/'), contains('media/full'));
    expect(full.readAsBytesSync(), [1, 2, 3]);
    await files.stage(cover, 'g/c.jpg', PreparedImage(full: _b([7, 7]), thumb: _b([8])));
    await files.uploaded(cover, 'g/c.jpg', keepFull: true);
    final again = await files.local(cover, 'g/c.jpg', thumb: false);
    expect(again!.readAsBytesSync(), [7, 7]);
  });

  // TC-29-01
  test('MediaFiles.uploaded does nothing when nothing is pending', () async {
    await files.uploaded(bucket, path, keepFull: true);
    expect(await files.local(bucket, path, thumb: false), isNull);
  });

  // TC-29-01
  test('MediaFiles.cache keeps a downloaded photo that local finds', () async {
    expect(await files.local(bucket, path, thumb: true), isNull);
    final f = await files.cache(bucket, path, _b([5, 5]));
    expect(f.path, startsWith(cache.path));
    expect((await files.local(bucket, path, thumb: true))!.readAsBytesSync(), [5, 5]);
    expect((await files.local(bucket, path, thumb: false))!.readAsBytesSync(), [5, 5]);
  });

  // TC-29-01
  test('MediaFiles.discard removes every local copy of one photo', () async {
    await files.stage(bucket, path, image);
    await files.cache(bucket, path, _b([5]));
    await files.discard(bucket, path);
    expect(await files.local(bucket, path, thumb: true), isNull);
    expect(await files.local(bucket, path, thumb: false), isNull);
    await files.discard(bucket, path);
  });

  // TC-29-01
  test('MediaFiles.wipe removes every stored photo, also when nothing is stored', () async {
    await files.wipe();
    await files.stage(bucket, path, image);
    await files.cache(bucket, 'g/o.jpg', _b([5]));
    await files.wipe();
    expect(Directory('${docs.path}/media').existsSync(), isFalse);
    expect(Directory('${cache.path}/media').existsSync(), isFalse);
    expect(await files.local(bucket, path, thumb: true), isNull);
  });
}
