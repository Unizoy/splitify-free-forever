import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_profile_remote.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/local_wipe.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fakes.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('ProfileRepository', () {
    test('load caches the server copy and falls back to it offline', () async {
      final remote = FakeProfileRemote(sampleProfile);
      final repo = ProfileRepository(remote: remote, prefs: prefs);
      expect(repo.cached, isNull);
      expect(await repo.load(sampleProfile.id), sampleProfile);
      expect(repo.cached, sampleProfile);
      remote.fail = const ProfileFailure(ProfileFailureCode.offline);
      expect(await repo.load(sampleProfile.id), sampleProfile);
      remote.fail = const ProfileFailure(ProfileFailureCode.unknown);
      await expectLater(repo.load(sampleProfile.id), throwsA(isA<ProfileFailure>()));
      remote
        ..fail = null
        ..profile = null;
      expect(await repo.load(sampleProfile.id), sampleProfile);
    });

    test('save uploads the photo first and stores the result', () async {
      final remote = FakeProfileRemote(sampleProfile);
      final repo = ProfileRepository(remote: remote, prefs: prefs);
      final saved = await repo.save(
        sampleProfile.copyWith(displayName: 'Asha R'),
        photo: Uint8List.fromList([1, 2, 3]),
      );
      expect(saved.avatarPath, '${sampleProfile.id}/0.jpg');
      expect(repo.cached?.displayName, 'Asha R');
    });

    test('without a remote: cache only, save needs internet', () async {
      final repo = ProfileRepository(remote: null, prefs: prefs);
      expect(await repo.load('x'), isNull);
      await expectLater(repo.save(sampleProfile), throwsA(isA<ProfileFailure>()));
      expect(const ProfileFailure(ProfileFailureCode.offline).toString(), contains('offline'));
    });
  });

  group('SupabaseProfileRemote', () {
    test('fetch, update and upload call the server functions', () async {
      final rpcs = <String, Map<String, Object?>>{};
      final puts = <String>[];
      final remote = SupabaseProfileRemote(
        rpc: (name, params) async {
          rpcs[name] = params;
          return {...sampleProfile.toJson(), 'display_name': params['p_display_name']};
        },
        select: (id) async => id == sampleProfile.id ? sampleProfile.toJson() : null,
        putAvatar: (path, jpeg) async => puts.add(path),
      );
      expect(await remote.fetch(sampleProfile.id), sampleProfile);
      expect(await remote.fetch('nobody'), isNull);
      final saved = await remote.update(sampleProfile.copyWith(displayName: 'New'));
      expect(saved.displayName, 'New');
      expect(rpcs['update_profile'], {
        'p_display_name': 'New',
        'p_upi_id': 'asha.rao@okaxis',
        'p_default_currency': 'INR',
        'p_avatar_path': null,
      });
      final path = await remote.uploadAvatar('u1', Uint8List(1));
      expect(path, startsWith('u1/'));
      expect(path, endsWith('.jpg'));
      expect(puts, [path]);
    });

    Future<ProfileFailureCode> codeOf(Object error) async {
      final remote = SupabaseProfileRemote(
        rpc: (_, _) async => throw error,
        select: (_) async => throw error,
        putAvatar: (_, _) async => throw error,
      );
      try {
        await remote.update(sampleProfile);
      } on ProfileFailure catch (e) {
        return e.code;
      }
      throw StateError('no failure');
    }

    test('maps server errors to profile failures', () async {
      expect(await codeOf(const SocketException('x')), ProfileFailureCode.offline);
      expect(await codeOf(TimeoutException('x')), ProfileFailureCode.offline);
      expect(
        await codeOf(const sb.PostgrestException(message: 'INVALID_NAME')),
        ProfileFailureCode.invalidName,
      );
      expect(
        await codeOf(const sb.PostgrestException(message: 'INVALID_UPI')),
        ProfileFailureCode.invalidUpi,
      );
      expect(
        await codeOf(const sb.PostgrestException(message: 'UNKNOWN_CURRENCY')),
        ProfileFailureCode.unknownCurrency,
      );
      expect(await codeOf(const sb.PostgrestException(message: 'X')), ProfileFailureCode.unknown);
      expect(await codeOf(const sb.StorageException('x')), ProfileFailureCode.unknown);
    });
  });

  test('fromClient wires PostgREST and Storage (requests fail in tests)', () async {
    // flutter_test answers every HTTP request with 400, so each call maps to a failure.
    final client = sb.SupabaseClient('https://x.example', 'k');
    addTearDown(client.dispose);
    final remote = SupabaseProfileRemote.fromClient(client);
    await expectLater(remote.fetch('u1'), throwsA(anything));
    await expectLater(remote.update(sampleProfile), throwsA(anything));
    await expectLater(remote.uploadAvatar('u1', Uint8List(1)), throwsA(anything));
  });

  test('T8 LocalWipe clears secure storage and prefs but keeps the theme', () async {
    FlutterSecureStorage.setMockInitialValues({'token': 't'});
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark', 'profile.cache': '{}', 'x': 1});
    final p = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    await LocalWipe(prefs: p, secure: secure).wipe();
    expect(p.getKeys(), {'theme_mode'});
    expect(await secure.readAll(), isEmpty);
  });

  test('initRemote without real Supabase settings stays signed out (BLK-001)', () async {
    final env = Env.fromValues(
      supabaseUrl: 'https://your-project-ref.supabase.co',
      supabasePublishableKey: 'your-publishable-key',
      googleWebClientId: '',
      devLogin: 'true',
      e2ePassword: 'pw',
    );
    final r = await initRemote(env);
    expect(r.auth, isA<UnconfiguredAuthRepository>());
    expect(r.profiles, isNull);
  });
}
