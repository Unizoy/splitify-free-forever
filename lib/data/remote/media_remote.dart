import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:splitify/domain/entities/attachment.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Storage calls for photos and attachments (receipts, group covers, expense files; 03 §3, 04 §6). Tests use a
/// fake.
abstract interface class MediaRemote {
  /// Uploads a JPEG (or an attachment's PDF, by its `.pdf` path) to `bucket/path` (replaces an earlier partial
  /// upload of the same path).
  Future<void> upload(String bucket, String path, Uint8List jpeg);

  /// A signed URL for reading `bucket/path`, valid for [lifetime].
  Future<Uri> signedUrl(String bucket, String path, Duration lifetime);

  /// Downloads a signed URL.
  Future<Uint8List> download(Uri url);
}

/// No connection, timeout or 5xx: try again later.
class MediaOffline implements Exception {
  const MediaOffline([this.message = 'network']);
  final String message;

  @override
  String toString() => 'MediaOffline($message)';
}

/// Storage refused the request (not a member, too big, wrong type, not found).
class MediaRejected implements Exception {
  const MediaRejected(this.code);
  final String code;

  @override
  String toString() => 'MediaRejected($code)';
}

/// No Supabase settings (D-020) and widget tests: every call fails like being offline.
class UnconfiguredMediaRemote implements MediaRemote {
  const UnconfiguredMediaRemote();

  @override
  Future<void> upload(String bucket, String path, Uint8List jpeg) =>
      Future.error(const MediaOffline('not_configured'));

  @override
  Future<Uri> signedUrl(String bucket, String path, Duration lifetime) =>
      Future.error(const MediaOffline('not_configured'));

  @override
  Future<Uint8List> download(Uri url) => Future.error(const MediaOffline('not_configured'));
}

typedef StoragePut = Future<void> Function(String bucket, String path, Uint8List jpeg);
typedef StorageSign = Future<String> Function(String bucket, String path, int seconds);
typedef HttpGet = Future<Uint8List> Function(Uri url);

/// [MediaRemote] over Supabase Storage; errors become [MediaOffline] / [MediaRejected].
class SupabaseMediaRemote implements MediaRemote {
  SupabaseMediaRemote({required this.put, required this.sign, HttpGet? get})
    : _get = get ?? httpGet;

  /// Wires the real client (thin glue).
  factory SupabaseMediaRemote.fromClient(sb.SupabaseClient c) => SupabaseMediaRemote(
    put: (bucket, path, jpeg) => c.storage
        .from(bucket)
        .uploadBinary(
          path,
          jpeg,
          fileOptions: sb.FileOptions(contentType: AttachmentPaths.contentType(path), upsert: true),
        ),
    sign: (bucket, path, seconds) => c.storage.from(bucket).createSignedUrl(path, seconds),
  );

  final StoragePut put;
  final StorageSign sign;
  final HttpGet _get;

  static const _timeout = Duration(seconds: 60);

  /// Plain GET with dart:io (signed URLs need no headers).
  static Future<Uint8List> httpGet(Uri url) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(url);
      final res = await req.close();
      final bytes = BytesBuilder(copy: false);
      await res.forEach(bytes.add);
      if (res.statusCode >= 500) throw MediaOffline('${res.statusCode}');
      if (res.statusCode != 200) throw MediaRejected('${res.statusCode}');
      return bytes.takeBytes();
    } finally {
      client.close();
    }
  }

  @override
  Future<void> upload(String bucket, String path, Uint8List jpeg) =>
      _guard(() => put(bucket, path, jpeg));

  @override
  Future<Uri> signedUrl(String bucket, String path, Duration lifetime) =>
      _guard(() async => Uri.parse(await sign(bucket, path, lifetime.inSeconds)));

  @override
  Future<Uint8List> download(Uri url) => _guard(() => _get(url));

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body().timeout(_timeout);
    } on SocketException catch (e) {
      throw MediaOffline(e.message);
    } on TimeoutException {
      throw const MediaOffline('timeout');
    } on HttpException catch (e) {
      throw MediaOffline(e.message);
    } on sb.StorageException catch (e) {
      final status = e.statusCode ?? '';
      // Non-HTTP failures carry the error type as their "status" (ClientException, …).
      if (status.startsWith('5') || (status.isNotEmpty && !_digits.hasMatch(status))) {
        throw MediaOffline(status);
      }
      throw MediaRejected(status.isEmpty ? e.message : status);
    } on Exception catch (e) {
      // package:http's ClientException (no connection) is not exported here.
      if ('$e'.startsWith('ClientException')) throw const MediaOffline('client');
      rethrow;
    }
  }

  static final _digits = RegExp(r'^\d+$');
}
