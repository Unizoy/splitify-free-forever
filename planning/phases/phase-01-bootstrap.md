# Phase 01 — Bootstrap, tooling, CI

- Depends on: — · Owner setup: none · Branch: `phase/01-bootstrap` · Features: foundation
- Goal: a runnable Flutter Android app skeleton with the final folder structure, packages, lints, env loading,
  logging, l10n, test infrastructure, verification scripts and CI — so every later phase only adds features.
- Read first: `02-architecture.md` (all), `09-testing-strategy.md`, `research/04-flutter-architecture-and-packages.md`.

## Tasks

- [ ] T1 In the repo root (PowerShell, PATH fix): `flutter create --org com.unizoy --project-name splitify
      --platforms android --android-language kotlin .` (keeps existing files). Android exactly as
      `02-architecture.md` §2: `applicationId "com.unizoy.splitify"`, label `Splitify Free Forever`, minSdk 24,
      compileSdk 37, targetSdk 36, core library desugaring, `MainActivity : FlutterFragmentActivity`.
      Expect the first Gradle build to take up to ~20 min (run it in the background and keep working).
- [ ] T2 `.gitignore`: add `.claude/state/`, `secrets/*` with `!secrets/*.example.json`, `android/app/google-services.json`
      (already covered by pattern — verify), `*.jks`. Commit `secrets/env.example.json` with placeholder keys
      (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_WEB_CLIENT_ID`, `E2E_PASSWORD`, `DEV_LOGIN`).
      Create local `secrets/env.dev.json` from the example if missing (placeholders until phase 04).
- [ ] T3 `pubspec.yaml`: exact dependency block from `02-architecture.md` §5; `analysis_options.yaml`
      (`very_good_analysis` + rules in §6); `build.yaml`; `l10n.yaml` + `lib/l10n/app_en.arb`.
- [ ] T4 Folder skeleton per `02-architecture.md` §3 (empty `README.md`-free; create the files listed there with
      minimal compiling stubs only where needed).
- [ ] T5 Core: `env.dart` (`String.fromEnvironment`, throws clear error if missing), `logger.dart` (`logging`
      package → debugPrint in debug, ring buffer for "export debug log"), global error handlers, `app.dart`
      (`ProviderScope`, `MaterialApp.router`, temporary theme), `router.dart` with a placeholder home.
- [ ] T6 Tooling: `tool/env.ps1` (PATH fix + JAVA_HOME), `tool/verify.ps1` (G1–G4, prints gate table, exit code),
      `tool/guards.dart` (rules in `.claude/skills/verify/SKILL.md` G1), `tool/coverage_check.dart` (floors from
      `09-testing-strategy.md` §4, reads `coverage/lcov.info`).
- [ ] T7 Tests: `test/flutter_test_config.dart` (font loading hook ready for phase 02), `test/support/`
      (`factories.dart`, `fakes.dart` stubs), one unit + one widget smoke test; `integration_test/app_smoke_test.dart`
      (app launches, placeholder visible).
- [ ] T8 CI: `.github/workflows/ci.yml` — `flutter` job only (`09-testing-strategy.md` §6 step 1), pinned
      Flutter 3.50.1, uses `secrets/env.example.json` for the build.
- [ ] T9 Docs: README "Development setup" (Android only — fix the "Android and web" line), CONTRIBUTING "run
      `tool/verify.ps1`", bug template platform list = Android.
- [ ] T10 Run `integration_test` on `emulator-5554`; capture `phase-01/home.png`.

## Done when

- `tool/verify.ps1` all green; `flutter test` passes; debug APK builds; integration smoke passes on the emulator.
- Branch pushed and CI green (`gh run list --branch phase/01-bootstrap --limit 1` shows success; if CI fails only
  because of the hosted runner, log it and fix in this phase).
