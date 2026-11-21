# 04 - Flutter architecture and packages (research, 2026-11-21)

Method: throwaway app `probe` in the scratchpad (`flutter create --org com.unizoy --project-name splitify --platforms android`), Flutter 3.50.1 / Dart 3.14.0, `flutter pub add` for everything, then `flutter build apk --debug`. Versions below are from `pubspec.lock`. Items marked (unverified) were not confirmed from a primary source.

## A. Resolution result

**Everything resolved except `custom_lint`.** `riverpod_lint 3.2.0` resolves on its own (no custom_lint needed any more), so skip custom_lint.

| Item | Result | Note |
| --- | --- | --- |
| custom_lint | FAILS | Needs analyzer 7/8; `build_runner >=2.16.2` needs analyzer 14 and `freezed_annotation 3`. Dead end. Use `riverpod_lint` alone. |
| sqlite3_flutter_libs `0.6.0+eol` | Resolves but is a no-op | Its README: obsolete once `sqlite3` 3.x is used (lock has sqlite3 3.9.1). **Do not add it.** `drift_flutter` brings sqlite3 via build hooks. |
| material_ui 1.1.0 (added by `flutter create` template) | Present | New default template dependency in Flutter 3.50; keep or remove deliberately. |
| analyzer | 14.7.0 (transitive) | Everything generator-related is aligned on it. |
| glados 1.1.7 | Resolves, but last release about 2 years ago | Works; low maintenance risk for property tests (pub.dev page). |

### Resolved versions (lock)

| Package | Version | Package | Version |
| --- | --- | --- | --- |
| supabase_flutter | 2.18.3 | flutter_secure_storage | 11.2.0 |
| drift / drift_dev | 2.35.4 / 2.35.3 | local_auth | 3.0.2 |
| drift_flutter | 0.3.1 | home_widget | 0.10.0 |
| flutter_riverpod / riverpod | 3.5.0 | logging | 1.3.0 |
| riverpod_annotation | 4.0.8 | shared_preferences | 2.5.6 |
| riverpod_generator | 4.0.10 | flutter_animate | 4.5.2 |
| riverpod_lint | 3.2.0 | build_runner | 2.17.1 |
| go_router | 18.1.4 | freezed / freezed_annotation | 4.0.3 / 3.1.0 |
| json_annotation / json_serializable | 4.12.0 / 6.15.2 | uuid | 4.6.0 |
| connectivity_plus | 7.3.2 | workmanager | 0.10.10 |
| firebase_core | 5.2.0 | firebase_messaging | 17.1.0 |
| flutter_local_notifications | 23.0.3 | google_sign_in | 7.2.0 |
| image_picker | 1.2.4 | flutter_image_compress | 2.5.1 |
| qr_flutter | 4.1.0 | mobile_scanner | 7.5.0 |
| url_launcher | 6.3.3 | share_plus | 13.3.1 |
| csv | 8.0.0 | file_picker | 13.4.0 |
| path_provider | 2.1.6 | fl_chart | 1.3.1 |
| intl | 0.20.3 | decimal | 3.2.6 |
| mocktail | 1.0.5 | alchemist | 0.15.0 |
| glados | 1.1.7 | patrol | 4.11.0 |
| very_good_analysis | 11.0.0 | sqlite3 (transitive) | 3.9.1 |

### Exact pubspec block that resolved (minus sqlite3_flutter_libs, which is not needed)

```yaml
environment:
  sdk: ^3.14.0
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.18.3
  drift: ^2.35.4
  drift_flutter: ^0.3.1
  flutter_riverpod: ^3.5.0
  riverpod_annotation: ^4.0.8
  go_router: ^18.1.4
  freezed_annotation: ^3.1.0
  json_annotation: ^4.12.0
  uuid: ^4.6.0
  connectivity_plus: ^7.3.2
  workmanager: ^0.10.10
  firebase_core: ^5.2.0
  firebase_messaging: ^17.1.0
  flutter_local_notifications: ^23.0.3
  google_sign_in: ^7.2.0
  image_picker: ^1.2.4
  flutter_image_compress: ^2.5.1
  qr_flutter: ^4.1.0
  mobile_scanner: ^7.5.0
  url_launcher: ^6.3.3
  share_plus: ^13.3.1
  csv: ^8.0.0
  file_picker: ^13.4.0
  path_provider: ^2.1.6
  fl_chart: ^1.3.1
  intl: ^0.20.3
  decimal: ^3.2.6
  flutter_secure_storage: ^11.2.0
  local_auth: ^3.0.2
  home_widget: ^0.10.0
  logging: ^1.3.0
  shared_preferences: ^2.5.6
  flutter_animate: ^4.5.2
dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.17.1
  drift_dev: ^2.35.3
  riverpod_generator: ^4.0.10
  freezed: ^4.0.3
  json_serializable: ^6.15.2
  mocktail: ^1.0.5
  alchemist: ^0.15.0
  glados: ^1.1.7
  patrol: ^4.11.0
  very_good_analysis: ^11.0.0
  riverpod_lint: ^3.2.0
```

(The probe also had `sqlite3_flutter_libs: ^0.6.0+eol`, `flutter_lints`, `material_ui`, `cupertino_icons`; the build passed with them. Replace `flutter_lints` with `very_good_analysis` in `analysis_options.yaml`.) Also add `integration_test: sdk: flutter` if not using Patrol for everything.

### Debug APK build: PASSED, but only after two Android config fixes

| Attempt | Result | Fix |
| --- | --- | --- |
| 1 (template defaults) | FAILED after 21m 31s (first-ever Gradle download/compile; later builds took 35s-140s) | `flutter_local_notifications` 23.0.3 warns "requires Android SDK version 37 or higher": set `compileSdk = 37` |
| 2 | FAILED in 35s | `flutter_local_notifications` requires core library desugaring |
| 3 | `Built build\app\outputs\flutter-apk\app-debug.apk` (140s) | below |

`android/app/build.gradle.kts` changes needed:

```kotlin
android {
    compileSdk = 37
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        // sourceCompatibility / targetCompatibility as generated
    }
    defaultConfig { minSdk = 24 }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

- **minSdk needed: 24.** `local_auth` 3.0.2 table says Android SDK 24+; `mobile_scanner` 7.5.0 minSdk 23; `patrol` 21. Flutter default minSdk is lower, so set 24 explicitly (about 99% of active Android devices).
- **compileSdk 37 does not mean emulator image 37.** Only the platform jar (auto-downloaded by Gradle) is needed; keep emulator on API 36 as CLAUDE.md says. `targetSdk` can stay at the Flutter default.
- Build side effect: Gradle auto-installed CMake 3.22.1 into `C:\Users\mohit\AppData\Local\Android\Sdk\cmake` (SDK change outside scratchpad; harmless, needed by a plugin).
- Warning to plan for: `flutter_image_compress_common`, `home_widget`, `patrol`, `workmanager_android` apply the Kotlin Gradle Plugin; "future Flutter versions will fail to build" with such plugins (Built-in Kotlin migration). Not a failure today. Watch for plugin updates; re-run the probe build each Flutter upgrade.
- Java deprecation warnings (source 8) come from plugins; ignore.

## B. Recommendations

### Local DB and sync

| Topic | Recommendation | Why |
| --- | --- | --- |
| Local DB | **Drift 2.35 + drift_flutter** (SQLite) | Relational (matches Postgres schema), SQL aggregates for local "not synced yet" balances, typed migrations with schema tests, streams for UI, in-memory DB for unit tests. Money as `int` columns fits rule 1. No `sqlite3_flutter_libs` (obsolete, see above). |
| Isar | Avoid | Original project discontinued; only a community fork `isar_db` (single maintainer) ([pub.dev isar_db](https://pub.dev/documentation/isar_db/latest/)). |
| Realm | Avoid | MongoDB deprecated Atlas Device SDKs, end-of-life 2025-09-30; local DB survives only as unmaintained open source ([MongoDB deprecation](https://www.mongodb.com/docs/atlas/device-sdks/deprecation.md)). |
| Sync | **Custom outbox** | Matches rules 5-7 and "Supabase only". See table below. |

| Sync option | Fit | Verdict |
| --- | --- | --- |
| Custom outbox (Drift table `outbox`, client UUIDs, ordered push via RPC/upsert, pull by `updated_at` cursor + Realtime) | Full control of LWW + edit history, soft deletes, activity log, server-computed balances | **Choose** |
| PowerSync | Needs a separate PowerSync Service (their cloud free tier with soft limits, or self-hosted Open Edition under Functional Source License) plus sync rules ([docs](https://docs.powersync.com/client-sdks/reference/flutter), [pricing](https://powersync.com/pricing)) | Breaks "Supabase only / two outside services" rule. Reject for v1. |
| Brick (brick_offline_first_with_supabase) | Convenient but opinionated models, its own queue; less control over ordered per-group ops and history (unverified, not researched in depth) | Reject; revisit only if outbox proves too costly |

Outbox design notes: one row per mutation (`id` uuid, `entity`, `op`, `payload` JSON, `created_at`, `attempts`, `last_error`); send in order, per-row transactional RPC on server that is idempotent by client UUID; stop the queue on a permanent 4xx and surface it; mark rows "not synced yet" in UI while pending. Trigger flush on: app start, resume, connectivity change (connectivity_plus only says a network exists, so confirm by the request itself), after each local write, and a workmanager periodic job.

### Riverpod 3

| Topic | Recommendation | Source / reason |
| --- | --- | --- |
| Codegen? | **Yes, use `riverpod_generator` 4 + `@riverpod`** for Notifiers/AsyncNotifiers, plain `Provider` for trivial values | Less boilerplate, family args are typed. Resolves cleanly with build_runner 2.17 / analyzer 14 (verified). Hand-written is also fine; do not mix styles in one feature. |
| Legacy | `StateProvider` / `StateNotifierProvider` live in `flutter_riverpod/legacy.dart` in 3.x: do not use | [changelog](https://pub.dev/packages/flutter_riverpod/changelog) |
| New behaviors | Automatic retry of failing providers (configure/disable it for sync and auth providers); providers pause when not visible; errors rethrown wrapped in `ProviderException`; mutations work without codegen; offline persistence is experimental (do not use, we have Drift) | same |
| Lint | `riverpod_lint 3.2.0` works without `custom_lint` (verified) | probe |

### go_router

18.1.4 from flutter.dev, actively maintained, no deprecation notice; considered feature-complete, only bug fixes and stability ([pub.dev](https://pub.dev/packages/go_router)). Safe choice. Use `ShellRoute`/`StatefulShellRoute` for bottom tabs; `redirect` driven by an auth `Listenable`; deep links for group invites.

### Google sign-in 7.x with Supabase (verified against 7.2.0 source in pub cache and Supabase docs)

Facts: the instance is a singleton; `initialize()` must be awaited once before anything else (else `StateError`); `serverClientId` is the **Web** OAuth client ID (an Android client with the app SHA-1 must also exist in Google Cloud and be listed in Supabase Google provider settings); `initialize` accepts `nonce`; `authenticate()` returns `GoogleSignInAccount`; `account.authentication.idToken` is the ID token; access token is a separate step via `authorizationClient`. Wrong `serverClientId` gives null idToken.

```dart
final _google = GoogleSignIn.instance;
Future<void>? _init;

Future<void> initGoogle() => _init ??= _google.initialize(
      serverClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    );

Future<AuthResponse> signInWithGoogle() async {
  await initGoogle();
  final account = await _google.authenticate();          // throws GoogleSignInException on cancel
  final idToken = account.authentication.idToken;
  if (idToken == null) throw const AuthException('No Google ID token');
  // Access token is optional for Supabase unless you need Google APIs:
  final authz = await account.authorizationClient.authorizationForScopes(['email', 'profile']);
  return Supabase.instance.client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    accessToken: authz?.accessToken,
  );
}
```

Nonce: Supabase's Flutter sample passes none. Two valid choices: (a) simple: leave nonce unset and enable **"Skip nonce check"** on the Supabase Google provider (the docs say this for iOS; for Android Credential Manager, keep the same setting if sign-in fails with a nonce error, unverified); (b) strict: generate a random raw nonce, pass **SHA-256 hex** to `GoogleSignIn.instance.initialize(nonce: hashed)` and the **raw** nonce to `signInWithIdToken(nonce: raw)`. Because `initialize` is once-per-process, (b) needs the nonce created before init (per sign-in re-init is untested). Start with (a), document it. Sources: [Supabase Google guide](https://supabase.com/docs/guides/auth/social-login/auth-google), [google_sign_in README](https://pub.dev/packages/google_sign_in), [supabase-flutter PR 1240](https://github.com/supabase/supabase-flutter/pull/1240/files).

Release gotcha: add the SHA-1 of both debug and release (and Play App Signing) keys to the Android OAuth client.

### Email OTP (gotrue 2.27.3, verified from source)

```dart
await supabase.auth.signInWithOtp(email: email, shouldCreateUser: true); // sends email
final res = await supabase.auth.verifyOTP(email: email, token: code, type: OtpType.email);
// res.session / res.user
```

- Use **`OtpType.email`** for a 6-digit sign-in code (for both new and existing users). `OtpType.signup` is for confirming a signup made with a password; `magiclink` is the legacy value.
- Dashboard: edit the Magic Link / confirm email template to include `{{ .Token }}` (otherwise only a link is sent). Free-tier built-in email is heavily rate limited (a few per hour), so plan custom SMTP before launch (unverified exact numbers; check the Supabase dashboard).
- `signInWithOtp` also generates a PKCE code challenge, so verify on the same install that requested it.

### workmanager 0.10.10

| Point | Detail |
| --- | --- |
| Setup | Top-level `@pragma('vm:entry-point') callbackDispatcher`, `Workmanager().initialize(callbackDispatcher)`, then `registerPeriodicTask` / `registerOneOffTask` ([pub.dev](https://pub.dev/packages/workmanager)). Wraps Android WorkManager. |
| Reliability | Android periodic minimum is 15 minutes, execution time is not exact (Doze, battery saver, OEM killers such as Xiaomi/Oppo/Vivo are common in India). Treat as best effort catch-up only. (General WorkManager behavior, not in the fetched page.) |
| Use here | One-off "flush outbox" task with a network constraint after a local write while offline; periodic 15 min+ sync is a bonus. Primary sync stays in the foreground (start, resume, connectivity). |
| Gotchas | Background isolate needs its own Supabase init (read session from storage, no UI/providers) and its own Drift connection; use Drift isolate/`shareAcrossIsolates` or a short-lived connection to avoid two writers. Do not rely on it for reminders; use FCM push. |
| Build | Applies KGP (see warning above). |

### image_picker 1.2.4 (Android 13+)

Uses the Android system Photo Picker on Android 13+, no READ_MEDIA permissions or `requestLegacyExternalStorage` needed (scoped storage). Call `ImagePicker.retrieveLostData()` on startup (Android may kill MainActivity while picking). Avatar/receipt flow: `pickImage(source: gallery, maxWidth: 1600, imageQuality: 85)` (parameters exist on mobile; the pub page did not list them, unverified), then `flutter_image_compress` to about 200-400 KB before upload. Camera capture needs no manifest permission with the default intent. Source: [pub.dev](https://pub.dev/packages/image_picker). Backport of the picker to Android 11-12 via Play services: not confirmed on the page.

### mobile_scanner 7.5.0

| Point | Detail |
| --- | --- |
| minSdk / compileSdk | 23 / 36 (from source) |
| 16 KB pages | Changelog: 6.0.11 "Update camerax dependencies to support 16KB pages sizes". 7.x changelogs list no regression. ML Kit says recent releases support 16 KB ([ML Kit notes](https://developers.google.com/ml-kit/release-notes)). **Verify on our APK** with `zipalign -c -P 16 -v 4 app.apk` and `apkanalyzer` before release (Play requires 16 KB support for apps targeting Android 15+ since 2025-11-01). |
| ML Kit | Bundled barcode model adds about 2.4 MB per ABI, unbundled about 200 KB but depends on Google Play services download ([ML Kit paths](https://developers.google.com/ml-kit/tips/installation-paths)); mobile_scanner has had a bundled/unbundled switch since 3.5.0 and bundled is the default (unverified for 7.x). For offline-first and non-GMS phones, keep bundled. |
| Use | Scan UPI QR / group invite QR. Controller start/stop in widget lifecycle; 7.4.4 fixed crashes on quick dispose. Camera permission is requested at runtime; handle denied. |
| Alt | `qr_flutter` (4.1.0) only generates QR; scanning also possible via image picker + `MobileScannerController.analyzeImage`. |

### home_widget 0.10.0 (Android)

Widgets are native; Flutter only pushes data ([pub.dev](https://pub.dev/packages/home_widget), [Android setup](https://docs.page/abausg/home_widget/setup/android)). Steps: (1) Gradle: Jetpack Glance dependency + Compose build feature; (2) `res/xml/<widget>_info.xml` provider config; (3) a `GlanceAppWidget` whose `stateDefinition` returns `HomeWidgetGlanceStateDefinition()`, reading `currentState().preferences`; (4) a receiver extending `HomeWidgetGlanceWidgetReceiver<YourWidget>`; (5) manifest `<receiver android:exported="true">` with `APPWIDGET_UPDATE` filter and `android.appwidget.provider` meta-data. Dart side: `HomeWidget.saveWidgetData<String>('net_balance', text)` then `HomeWidget.updateWidget(name: 'YourReceiver')`. Interactive callbacks need a separate `@pragma('vm:entry-point')` background callback (not verified). Widget shows cached balance text, so mark "not synced yet" in the string. Cost: roughly 1 day of Kotlin/Compose work; schedule last. Applies KGP.

### local_auth 3.0.2

Requires: min Android SDK 24; `MainActivity` must extend **`FlutterFragmentActivity`**; `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`; app theme must be `Theme.AppCompat` or `Theme.Material` derived (the default Flutter `LaunchTheme`/`NormalTheme` Light.NoTitleBar is generally fine but test on device). Emulator biometric testing: enroll fingerprint in emulator settings, then `adb -e emu finger touch 1`. Sources: [local_auth_android README](https://pub.dev/packages/local_auth), pub cache README (verified).

### Testing

| Tool | Status 2026-11 | Recommendation |
| --- | --- | --- |
| alchemist 0.15.0 | Active (MIT) | CI goldens render all text with the Ahem square-glyph font, so output is identical on any OS; platform goldens use real fonts and differ per OS (stored in `goldens/<os>/`). **Commit only `goldens/ci/`**, run platform goldens locally only (`PlatformGoldensConfig.platforms` restricted/disabled), set `diffThreshold` small. Config in `test/flutter_test_config.dart`; tag `golden`. Windows: no extra font setup needed for CI goldens. Source: [pub.dev](https://pub.dev/packages/alchemist). Load fonts only if reading text matters (it does not for layout regression). |
| patrol 4.11.0 | Active | Requires `patrol_cli` (`dart pub global activate patrol_cli`, `patrol doctor`), `patrol:` block in pubspec (app_name, package_name), tests in `patrol_test/`, native Android test runner Gradle setup (instrumentation runner + orchestrator + `MainActivityTest`). Benefit: native dialogs (permissions, notifications shade, photo picker, airplane mode toggles). Cost: about half a day setup, slower runs, needs emulator. Source: [patrol docs](https://patrol.leancode.co/documentation) (Gradle details not retrieved). **Decision: `integration_test` for core money/sync flows (fast, stock), Patrol only for permission/notification/offline-toggle scenarios** (it already resolves, so no cost to keep as dev dep). Do not add Patrol until the first native-dialog test is needed. |
| glados 1.1.7 | Last release about 2 years ago, resolves on Dart 3.14 | Good for property tests (splits sum to total, balances sum to zero, simplify keeps net). Alternative if it breaks: hand-rolled seeded `Random` loops with `package:test`. |
| mocktail | Active | Standard for mocks, no codegen. |

## Decisions summary for PLAN / build order

1. Drop `sqlite3_flutter_libs` and `custom_lint`; keep `riverpod_lint`.
2. Android: `compileSdk 37`, `minSdk 24`, core library desugaring on (needed by flutter_local_notifications).
3. Drift + custom outbox; no PowerSync/Brick; Riverpod with codegen; go_router.
4. Google sign-in: `initialize(serverClientId: WEB_CLIENT_ID)` then `authenticate()` then `signInWithIdToken`; start with Skip-nonce; email OTP uses `OtpType.email`.
5. workmanager is best effort only; FCM is the real wake-up path.
6. Add a CI check for 16 KB alignment of the release APK (mobile_scanner, sqlite3, image compress native libs).
7. Re-run the probe after any Flutter upgrade (KGP warning on 4 plugins).

## Sources

- google_sign_in: https://pub.dev/packages/google_sign_in ; source read in pub cache (`google_sign_in-7.2.0/lib/google_sign_in.dart`, `initialize({clientId, serverClientId, nonce, hostedDomain})`)
- Supabase Google guide: https://supabase.com/docs/guides/auth/social-login/auth-google ; PR: https://github.com/supabase/supabase-flutter/pull/1240/files
- gotrue 2.27.3 source (`signInWithOtp`, `verifyOTP`, `OtpType`) in pub cache
- go_router: https://pub.dev/packages/go_router ; riverpod: https://pub.dev/packages/flutter_riverpod/changelog
- Realm/Isar: https://www.mongodb.com/docs/atlas/device-sdks/deprecation.md , https://pub.dev/documentation/isar_db/latest/
- PowerSync: https://docs.powersync.com/client-sdks/reference/flutter , https://powersync.com/pricing
- mobile_scanner: https://pub.dev/packages/mobile_scanner/changelog ; ML Kit: https://developers.google.com/ml-kit/release-notes , https://developers.google.com/ml-kit/tips/installation-paths
- workmanager: https://pub.dev/packages/workmanager ; image_picker: https://pub.dev/packages/image_picker ; local_auth: https://pub.dev/packages/local_auth
- home_widget: https://pub.dev/packages/home_widget , https://docs.page/abausg/home_widget/setup/android
- alchemist: https://pub.dev/packages/alchemist ; glados: https://pub.dev/packages/glados ; patrol: https://patrol.leancode.co/documentation
