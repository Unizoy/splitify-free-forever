// TC-29-01 (storage calls for photos: error mapping, glue, plain GET download).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _Boom implements Exception {
  @override
  String toString() => 'Boom';
}

class ClientException implements Exception {
  @override
  String toString() => 'ClientException: no route';
}

void main() {
  final jpeg = Uint8List.fromList([1, 2, 3]);

  SupabaseMediaRemote remote({StoragePut? put, StorageSign? sign, HttpGet? get}) =>
      SupabaseMediaRemote(
        put: put ?? (_, _, _) async {},
        sign: sign ?? (_, _, _) async => 'https://x.example/s',
        get: get ?? (_) async => jpeg,
      );

  // TC-29-01
  test('SupabaseMediaRemote passes upload, sign and download through', () async {
    final calls = <String>[];
    final r = remote(
      put: (b, p, bytes) async => calls.add('put $b $p ${bytes.length}'),
      sign: (b, p, s) async {
        calls.add('sign $b $p $s');
        return 'https://x.example/signed?t=1';
      },
      get: (u) async {
        calls.add('get $u');
        return jpeg;
      },
    );
    await r.upload('receipts', 'g/e/p.jpg', jpeg);
    final url = await r.signedUrl('receipts', 'g/e/p.jpg', const Duration(hours: 1));
    expect(url, Uri.parse('https://x.example/signed?t=1'));
    expect(await r.download(url), jpeg);
    expect(calls, [
      'put receipts g/e/p.jpg 3',
      'sign receipts g/e/p.jpg 3600',
      'get https://x.example/signed?t=1',
    ]);
  });

  group('error mapping', () {
    Future<void> up(Object error) =>
        remote(put: (_, _, _) => Future.error(error)).upload('b', 'p', jpeg);

    // TC-29-01
    test('SocketException, TimeoutException and HttpException mean offline', () async {
      await expectLater(
        up(const SocketException('down')),
        throwsA(isA<MediaOffline>().having((e) => e.message, 'message', 'down')),
      );
      await expectLater(
        up(TimeoutException('slow')),
        throwsA(isA<MediaOffline>().having((e) => e.message, 'message', 'timeout')),
      );
      await expectLater(
        up(const HttpException('reset')),
        throwsA(isA<MediaOffline>().having((e) => e.message, 'message', 'reset')),
      );
    });

    // TC-29-01
    test('a 5xx or a non-numeric storage status means offline', () async {
      await expectLater(
        up(const sb.StorageException('bad gateway', statusCode: '503')),
        throwsA(isA<MediaOffline>().having((e) => e.message, 'message', '503')),
      );
      await expectLater(
        up(const sb.StorageException('x', statusCode: 'ClientException')),
        throwsA(isA<MediaOffline>().having((e) => e.message, 'message', 'ClientException')),
      );
    });

    // TC-29-01
    test('a 4xx storage status is a refusal; no status falls back to the message', () async {
      await expectLater(
        up(const sb.StorageException('nope', statusCode: '403')),
        throwsA(isA<MediaRejected>().having((e) => e.code, 'code', '403')),
      );
      await expectLater(
        up(const sb.StorageException('too big')),
        throwsA(isA<MediaRejected>().having((e) => e.code, 'code', 'too big')),
      );
    });

    // TC-29-01
    test('an exception named ClientException means offline, others pass through', () async {
      await expectLater(up(ClientException()), throwsA(isA<MediaOffline>()));
      await expectLater(up(_Boom()), throwsA(isA<_Boom>()));
    });

    // TC-29-01
    test('signedUrl and download map errors too', () async {
      final r = remote(
        sign: (_, _, _) => Future.error(const sb.StorageException('x', statusCode: '404')),
        get: (_) => Future.error(const SocketException('down')),
      );
      await expectLater(
        r.signedUrl('b', 'p', const Duration(minutes: 1)),
        throwsA(isA<MediaRejected>()),
      );
      await expectLater(r.download(Uri.parse('https://x.example')), throwsA(isA<MediaOffline>()));
    });
  });

  // TC-29-01
  test('MediaOffline and MediaRejected print their reason', () {
    expect(const MediaOffline().toString(), 'MediaOffline(network)');
    expect(const MediaRejected('403').toString(), 'MediaRejected(403)');
  });

  // TC-29-01
  test('UnconfiguredMediaRemote fails every call like being offline', () async {
    const r = UnconfiguredMediaRemote();
    await expectLater(r.upload('b', 'p', jpeg), throwsA(isA<MediaOffline>()));
    await expectLater(r.signedUrl('b', 'p', Duration.zero), throwsA(isA<MediaOffline>()));
    await expectLater(r.download(Uri.parse('https://x.example')), throwsA(isA<MediaOffline>()));
  });

  // TC-29-01
  test('SupabaseMediaRemote.fromClient wires the storage client (unreachable host)', () async {
    final r = SupabaseMediaRemote.fromClient(sb.SupabaseClient('https://x.example', 'k'));
    final failed = throwsA(anyOf(isA<MediaRejected>(), isA<MediaOffline>()));
    await expectLater(r.upload('receipts', 'g/e/p.jpg', jpeg), failed);
    await expectLater(r.signedUrl('receipts', 'g/e/p.jpg', const Duration(hours: 1)), failed);
  });

  group('httpGet against a local server', () {
    late HttpServer server;
    late HttpOverrides? saved;

    setUp(() async {
      saved = HttpOverrides.current;
      HttpOverrides.global = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        switch (req.uri.path) {
          case '/ok':
            req.response.add([7, 8, 9]);
          case '/missing':
            req.response.statusCode = HttpStatus.notFound;
          default:
            req.response.statusCode = HttpStatus.serviceUnavailable;
        }
        unawaited(req.response.close());
      });
    });

    tearDown(() async {
      await server.close(force: true);
      HttpOverrides.global = saved;
    });

    Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

    // TC-29-01
    test('SupabaseMediaRemote.httpGet returns the bytes of a 200', () async {
      expect(await SupabaseMediaRemote.httpGet(url('/ok')), [7, 8, 9]);
    });

    // TC-29-01
    test('SupabaseMediaRemote.httpGet maps 404 to a refusal and 503 to offline', () async {
      await expectLater(
        SupabaseMediaRemote.httpGet(url('/missing')),
        throwsA(isA<MediaRejected>().having((e) => e.code, 'code', '404')),
      );
      await expectLater(
        SupabaseMediaRemote.httpGet(url('/down')),
        throwsA(isA<MediaOffline>().having((e) => e.message, 'message', '503')),
      );
    });

    // TC-29-01
    test('SupabaseMediaRemote.download uses httpGet by default', () async {
      final r = SupabaseMediaRemote(put: (_, _, _) async {}, sign: (_, _, _) async => '');
      expect(await r.download(url('/ok')), [7, 8, 9]);
    });
  });
}
