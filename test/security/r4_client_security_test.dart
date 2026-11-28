// R4-SEC-01…06: client security and privacy checks that need no device (R4 package, item 5): no secrets in
// tracked files, no Android backup of the database / sign-in, shared pictures only from other apps'
// content URIs, private-only file locations, debug sign-in links dead in release builds.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/app/router.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('R4-SEC-01 no tracked file looks like a secret (the commit guard patterns + more)', () {
    final git = Process.runSync('git', ['ls-files', '-z']);
    if (git.exitCode != 0) {
      markTestSkipped('git not available');
      return;
    }
    // Built from pieces so this file never matches itself.
    final patterns = {
      'supabase secret key': RegExp(
        'sb_'
        r'secret_[A-Za-z0-9_\-]{8,}',
      ),
      'supabase publishable key': RegExp(
        'sb_'
        r'publishable_[A-Za-z0-9_\-]{8,}',
      ),
      'private key block': RegExp(
        '-----BEGIN [A-Z ]*'
        'PRIVATE KEY-----',
      ),
      'service account json': RegExp(
        '"private_'
        r'key(_id)?"\s*:',
      ),
      'google api key': RegExp(
        'AI'
        r'za[0-9A-Za-z_\-]{35}',
      ),
      'jwt': RegExp(
        'eyJhbGciOi'
        r'[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.',
      ),
      'supabase access token': RegExp(
        r'\bsbp_'
        '[0-9a-f]{20,}',
      ),
      'github token': RegExp(
        r'\bgh[pousr]_'
        '[A-Za-z0-9]{30,}',
      ),
      'aws key': RegExp(
        r'\bAKIA'
        r'[0-9A-Z]{16}\b',
      ),
    };
    // Known non-secrets: a PEM header in code that builds a key at runtime (tests generate theirs).
    const allowed = {
      'supabase/functions/_shared/fcm.ts': {'private key block'},
      'supabase/functions/_shared/fcm_test.ts': {'private key block'},
    };
    final banned = RegExp(
      r'(^|/)secrets/(?!.*\.example\.)|(^|/)\.env($|\.(?!example))|\.(jks|keystore|p12|p8|pem|key)$|'
      r'key\.properties$|google-services\.json$|GoogleService-Info\.plist$|service-account|firebase-adminsdk|'
      r'(^|/)\.claude/settings\.local\.json$',
    );
    final hits = <String>[];
    final files = (git.stdout as String).split('\x00').where((f) => f.isNotEmpty);
    for (final f in files) {
      if (banned.hasMatch(f)) hits.add('$f: must not be tracked');
      if (RegExp(r'\.(png|jpg|jpeg|webp|gif|ico|ttf|otf|zip|jar|pdf|so|apk|aab|keystore)$')
          .hasMatch(f)) {
        continue;
      }
      final file = File(f);
      if (!file.existsSync() || file.lengthSync() > 2 << 20) continue;
      final String text;
      try {
        text = file.readAsStringSync();
      } on FileSystemException {
        continue; // binary
      }
      for (final p in patterns.entries) {
        if (p.value.hasMatch(text) && !(allowed[f]?.contains(p.key) ?? false))
          hits.add('$f: ${p.key}');
      }
    }
    expect(files.length, greaterThan(500));
    expect(hits, isEmpty);
  });

  test(
    'R4-SEC-02 no Android backup or phone-to-phone copy of the database, sign-in or lock keys',
    () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
      final rules = _read('android/app/src/main/res/xml/data_extraction_rules.xml');
      for (final section in ['cloud-backup', 'device-transfer']) {
        final body =
            RegExp('<$section>(.*?)</$section>', dotAll: true).firstMatch(rules)?.group(1) ?? '';
        for (final domain in ['root', 'file', 'database', 'sharedpref', 'external']) {
          expect(body, contains('<exclude domain="$domain" />'), reason: '$section $domain');
        }
      }
      expect(manifest, isNot(contains('usesCleartextTraffic="true"')));
      expect(manifest, isNot(contains('android:debuggable')));
    },
  );

  test(
    'R4-SEC-03 only the expected components are exported; the file provider shares cache/pdf only',
    () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final exported = RegExp(
        r'<(activity|receiver|service|provider)\s[^>]*?android:name="([^"]+)"[^>]*?android:exported="true"',
        dotAll: true,
      ).allMatches(manifest).map((m) => m.group(2)).toSet();
      expect(exported, {'.MainActivity', '.BalanceWidgetSmall', '.BalanceWidgetWide'});
      expect(
        RegExp(r'<provider[^>]*android:exported="false"[^>]*android:grantUriPermissions="true"')
            .hasMatch(manifest),
        isTrue,
      );
      final paths = _read('android/app/src/main/res/xml/splitify_pdf_paths.xml');
      expect(RegExp('<(cache|files|external|root)[a-z-]*-path').allMatches(paths), hasLength(1));
      expect(paths, contains('<cache-path name="pdf" path="pdf/" />'));
    },
  );

  test('R4-SEC-04 a shared picture is read only from another app\'s content:// URI', () {
    final kt = _read('android/app/src/main/kotlin/com/unizoy/splitify/MainActivity.kt');
    expect(kt, contains('stream?.takeIf { sharedFromOtherApp(it) }?.let { copyShared(it) }'));
    expect(
      kt,
      contains(
        'uri.scheme == "content" && uri.authority != null && uri.authority != "\$packageName.files"',
      ),
    );
    // A shared PDF name can't climb out of cache/pdf/.
    final pdf = _read('android/app/src/main/kotlin/com/unizoy/splitify/PdfBridge.kt');
    expect(pdf, contains(r'replace(Regex("[^A-Za-z0-9._ -]"), "_")'));
  });

  test('R4-SEC-05 photos, PDFs and the database live in app-private folders only', () {
    final lib = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final external = RegExp(
      r'getExternalStorage|getExternalFilesDir|getDownloadsDirectory|/sdcard|MODE_WORLD',
    );
    final offenders = [
      for (final f in lib)
        if (external.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(offenders, isEmpty);
    expect(_read('lib/data/media_providers.dart'), contains('getApplicationDocumentsDirectory'));
  });

  test('R4-SEC-06 the debug sign-in link does nothing in a release build', () {
    // Where the router ends up after following every redirect.
    String land(String link, {required bool signedIn}) {
      var at = link;
      for (var i = 0; i < 5; i++) {
        final next = authRedirect(Uri.parse(at), signedIn: signedIn, debug: false);
        if (next == null) return Uri.parse(at).path;
        at = next;
      }
      fail('redirect loop from $link');
    }

    for (final link in ['splitify://dev/login?user=e2e-a', 'splitify://login?user=e2e-a']) {
      expect(land(link, signedIn: false), Routes.welcome, reason: link);
    }
    for (final link in ['splitify://dev/login?user=e2e-a', 'splitify://login?user=e2e-a']) {
      for (final signedIn in [false, true]) {
        expect(land(link, signedIn: signedIn), isNot(Routes.devLogin), reason: '$link $signedIn');
      }
    }
    // The page itself exists only in debug builds.
    final router = _read('lib/app/router.dart');
    final debugOnly = router.indexOf('if (kDebugMode) ...[');
    final pages = RegExp(r'AppRoute\(\s*path: Routes\.devLogin,').allMatches(router).toList();
    expect(debugOnly, greaterThan(0));
    expect(pages, hasLength(1));
    expect(pages.single.start, greaterThan(debugOnly));
    expect(
      authRedirect(Uri.parse('splitify://dev/login?user=e2e-a'), signedIn: false, debug: true),
      startsWith(Routes.devLogin),
    );
  });
}
