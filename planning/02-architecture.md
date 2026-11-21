# 02 — App architecture

Research: `research/04-flutter-architecture-and-packages.md`. Decisions referenced as T-0xx in `00-decisions.md`.

## 1. Shape

```
lib/
  main.dart → bootstrap (env, logging, error handlers, Drift, Supabase, Firebase, theme mode) → App
  presentation (screens, widgets)  ──watch──►  application (Riverpod controllers/notifiers)
                                                   │
                                          domain (pure Dart: entities, money engine, rules)
                                                   │
  data: repositories ─► local (Drift DAOs) + outbox ─► sync engine ─► remote (RemoteApi = Supabase RPCs)
```
- **Riverpod 3** (with `riverpod_annotation` codegen) for DI + state (T-002). Controllers are `AsyncNotifier`s;
  repositories/services are plain providers. No `setState` business logic in widgets.
- **go_router** with typed route helpers, `StatefulShellRoute.indexedStack` for the 4 tabs, auth redirect (T-003).
- **Drift** for the local database (T-001), custom outbox sync (T-004, `04-sync-engine.md`).
- **freezed** + `json_serializable` for entities/DTOs (T-005). Errors: sealed `Failure` types; repositories return
  values or throw typed failures caught in controllers → UI states.
- Pure Dart money engine `lib/core/money` (`05-money-engine.md`).

## 2. Configuration and environments

- `--dart-define-from-file=secrets/env.dev.json` (git-ignored; template `secrets/env.example.json` committed):
  `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_WEB_CLIENT_ID`, `DEV_LOGIN` (`true` only in dev), `E2E_PASSWORD`
  (tests only). Prod: `secrets/env.prod.json` (phase 20).
- `lib/core/config/env.dart` reads them with `String.fromEnvironment`/`bool.fromEnvironment`; missing values fail
  fast at startup with a readable error.
- Android (verified by a real build, research 04): `applicationId com.unizoy.splitify`, label "Splitify Free
  Forever", **`minSdk 24`** (local_auth needs 24), **`compileSdk 37`** (flutter_local_notifications needs the 37
  platform jar — Gradle downloads it; the *emulator* stays API 36), `targetSdk 36`, **core library desugaring on**
  (`isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")`),
  Kotlin DSL, `MainActivity : FlutterFragmentActivity`, AppCompat-based launch theme, edge-to-edge, deep-link scheme
  `splitify://`, `<queries>` for `upi` scheme, `USE_BIOMETRIC` permission. Release signing from
  `secrets/key.properties` (phase 19). First Gradle build can take ~20 min (downloads); later 35–140 s.

## 3. Folder structure

```
lib/
  main.dart
  app/            app.dart, router.dart, bootstrap.dart, shell/ (CapsuleNavBar host)
  core/
    config/       env.dart
    money/        (see 05-money-engine.md §8)
    logging/      logger.dart, log_buffer.dart
    errors/       failure.dart
    time/         clock.dart (injectable), server_time_offset.dart
    utils/        uuid.dart (v7), result helpers
  domain/         entities/ (group, member, expense, payment, comment, activity, notification, profile, fx_rate,
                  recurring_template), rules/ (permissions, validation)
  data/
    local/        database.dart (Drift), tables/, daos/, migrations/
    remote/       supabase_client.dart, remote_api.dart, dto/   ← the ONLY place importing supabase
    sync/         sync_engine.dart, mutation_queue.dart, pull_applier.dart, realtime_listener.dart,
                  background_sync.dart, uploads.dart
    repositories/ groups_repository.dart, expenses_repository.dart, payments_repository.dart, …
  features/       <feature>/{application,presentation}/ for: auth, onboarding, groups, members, invites,
                  expenses, splits, balances, settle_up, friends, activity, notifications, history, comments,
                  currency, recurring, search, insights, export, import_splitwise, app_lock, widget, account, sync
  ui/
    theme/        tokens, theme builder, context extensions
    components/   design-system widgets (06-design-system.md §6)
    painters/     covers, dashed, noise, dot matrix, gauge
  l10n/           app_en.arb (all user-facing strings)
test/             mirrors lib/ + fixtures/, support/, goldens/
integration_test/ app_smoke_test.dart, scenarios/, support/harness.dart
supabase/         migrations/, tests/, functions/{_shared,send-push,fetch-rates,delete-account}/, README.md
tool/             env.ps1, verify.ps1, guards.dart, coverage_check.dart, gen_sql_vectors.dart, e2e/, fake_upi_app/
assets/           fonts/ (+LICENSES/), brand/
drift_schemas/    schema dumps for migration tests
```
Rules: features may import `core`, `domain`, `data/repositories`, `ui`; never `data/remote` or `data/local`
directly. Files ≤ ~300 lines; widgets split into private sub-widgets.

## 4. Cross-cutting

- **Logging:** `logging` package; `Logger('sync')` etc.; debug → console, always → in-memory ring buffer (2,000
  lines) for "Export debug log"; never log tokens, emails, UPI IDs or amounts with names together.
- **Errors:** `FlutterError.onError` + `PlatformDispatcher.instance.onError` → logger; UI shows friendly copy.
  No crash-reporting service (no extra outside services).
- **Time:** all business dates are local `date`; timestamps UTC; injectable `Clock` for tests.
- **IDs:** UUID v7 (`uuid` package).
- **Images:** `cached_network_image` for signed URLs; covers from `CoverCache`.
- **Accessibility:** semantics on all custom painters/components; text scaling respected; reduced motion.
- **Localisation:** `flutter gen-l10n`, English only now (D-009), no string literals in widgets (guard).

## 5. Packages

Resolved together on Flutter 3.50.1 / Dart 3.14.0 on 2026-11-21 (research 04). Use these constraints; let
`flutter pub get` pick patch versions. **Not** used: `custom_lint` (conflicts with build_runner 2.17),
`sqlite3_flutter_libs` (obsolete; sqlite comes via `drift_flutter`).

```yaml
environment:
  sdk: ^3.14.0
dependencies:
  flutter: {sdk: flutter}
  flutter_localizations: {sdk: flutter}
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
  flutter_test: {sdk: flutter}
  integration_test: {sdk: flutter}
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

Planned additions, each verified (resolve + build) by the phase that needs it and logged as an `S-` decision:
`phosphor_flutter` (icons, phase 02; fallback Material Symbols Rounded), `flutter_launcher_icons` and
`flutter_native_splash` (dev, phase 02), `cached_network_image` (phase 07), `image_cropper` only if crop is not
doable with the picker (phase 05). Kotlin Gradle Plugin deprecation warnings from `flutter_image_compress`,
`home_widget`, `patrol`, `workmanager` are known and harmless today — log, don't fix.
Google sign-in (7.2): `await GoogleSignIn.instance.initialize(serverClientId: Env.googleWebClientId)` once, then
`authenticate()` → `authentication.idToken` → `supabase.auth.signInWithIdToken(provider: OAuthProvider.google,
idToken: …)`; no nonce (Supabase Google provider has "Skip nonce checks" ON — T-008).

## 6. Lints

`very_good_analysis` base + `prefer_final_locals`, `avoid_print` (error), `public_member_api_docs` off,
`lines_longer_than_80_chars` off (format width 100: `formatter: page_width: 100` in `analysis_options.yaml`).
Generated files (`*.g.dart`, `*.freezed.dart`) excluded from analysis and coverage.
