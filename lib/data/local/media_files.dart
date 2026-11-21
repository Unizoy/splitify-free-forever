import 'dart:io';
import 'dart:typed_data';

import 'package:splitify/domain/entities/prepared_image.dart';

/// Photos on this phone (04 §6). Under the app documents folder:
/// `media/pending/<bucket>/<path>` (full JPEG waiting for upload), `media/thumbs/<bucket>/<path>`
/// (thumbnail of every photo picked here) and `media/full/<bucket>/<path>` (covers kept after upload).
/// Downloaded photos go to `media/<bucket>/<path>` in the cache folder, which Android may clear.
class MediaFiles {
  MediaFiles({
    required Future<Directory> Function() docs,
    required Future<Directory> Function() cache,
  }) : _docsDir = docs,
       _cacheDir = cache;

  final Future<Directory> Function() _docsDir;
  final Future<Directory> Function() _cacheDir;
  Future<Directory>? _docs;
  Future<Directory>? _cache;

  /// Relative path (documents folder) of a full photo waiting for upload.
  static String pendingRel(String bucket, String path) => 'media/pending/$bucket/$path';
  static String _thumbRel(String bucket, String path) => 'media/thumbs/$bucket/$path';
  static String _fullRel(String bucket, String path) => 'media/full/$bucket/$path';

  Future<File> _doc(String rel) async => File('${(await (_docs ??= _docsDir())).path}/$rel');

  Future<File> _cached(String bucket, String path) async =>
      File('${(await (_cache ??= _cacheDir())).path}/media/$bucket/$path');

  static Future<File> _write(File f, Uint8List bytes) async {
    await f.parent.create(recursive: true);
    return f.writeAsBytes(bytes, flush: true);
  }

  /// Writes the full photo (waiting for upload) and its thumbnail; returns the pending relative path.
  Future<String> stage(String bucket, String path, PreparedImage image) async {
    final rel = pendingRel(bucket, path);
    await _write(await _doc(rel), image.full);
    await _write(await _doc(_thumbRel(bucket, path)), image.thumb);
    return rel;
  }

  /// Bytes of a file under the documents folder, or null when it is gone.
  Future<Uint8List?> read(String rel) async {
    final f = await _doc(rel);
    return f.existsSync() ? f.readAsBytes() : null;
  }

  /// After a successful upload the pending copy goes; covers keep the full photo, receipts only the
  /// thumbnail (the full one comes back through a signed URL).
  Future<void> uploaded(String bucket, String path, {required bool keepFull}) async {
    final pending = await _doc(pendingRel(bucket, path));
    if (!pending.existsSync()) return;
    if (keepFull) {
      final full = await _doc(_fullRel(bucket, path));
      await full.parent.create(recursive: true);
      if (full.existsSync()) await full.delete();
      await pending.rename(full.path);
    } else {
      await pending.delete();
    }
  }

  /// The best copy on this phone: thumbnails prefer the small file, full views the big one.
  Future<File?> local(String bucket, String path, {required bool thumb}) async {
    final full = [
      await _doc(pendingRel(bucket, path)),
      await _doc(_fullRel(bucket, path)),
      await _cached(bucket, path),
    ];
    final order = thumb ? [await _doc(_thumbRel(bucket, path)), ...full] : full;
    for (final f in order) {
      if (f.existsSync()) return f;
    }
    return null;
  }

  /// Keeps a downloaded photo in the cache folder.
  Future<File> cache(String bucket, String path, Uint8List bytes) async =>
      _write(await _cached(bucket, path), bytes);

  /// Deletes every local copy of one photo (removed before it was uploaded).
  Future<void> discard(String bucket, String path) async {
    for (final f in [
      await _doc(pendingRel(bucket, path)),
      await _doc(_thumbRel(bucket, path)),
      await _doc(_fullRel(bucket, path)),
      await _cached(bucket, path),
    ]) {
      if (f.existsSync()) await f.delete();
    }
  }

  /// Sign-out: removes every photo this phone stored (04 §7).
  Future<void> wipe() async {
    for (final d in [
      Directory((await _doc('media')).path),
      Directory('${(await (_cache ??= _cacheDir())).path}/media'),
    ]) {
      if (d.existsSync()) await d.delete(recursive: true);
    }
  }
}
