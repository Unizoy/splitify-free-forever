# Final integration QA — Splitwise parity (D-034) on `feat/simple-add-expense`

- Date: 2026-11-28 · Branch: `feat/simple-add-expense` (D-032 single-screen add expense + D-033 minimal pass +
  D-034 WP-D, WP-A, WP-B, WP-C) · Decisions S-400..S-419 · Migration `0027_deleted_targets` (DEV)
- Defect log with screenshots: `splitify-artifacts\final-qa-d034\defects.md`

## Gates (merged tree)

| Gate | Result | Evidence |
| --- | --- | --- |
| Format | PASS | `dart format --set-exit-if-changed lib test integration_test tool`: 0 changed |
| Analyze | PASS | `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings (infos only) |
| Guards | PASS | `dart run tool/guards.dart`: OK |
| Flutter tests | PASS | full suite in 4 chunks, `--concurrency=2`, `--coverage`: 4,008 passed, 0 failed (c1 core/data/ui 1,164 · c2 features a–f 1,022 · c3 features g–z 903 · c4 goldens 919) |
| Coverage | PASS | chunks merged per line: overall 95.5 %, money 100 %, sync 99.5 %, domain 97.8 %, core 97.4 %, application 95.2 %, presentation 95.1 %, data 94.4 % |
| pgTAP (DEV) | PASS | all 27 files before 0027: 1,035/1,035 (incl. 250_friend_codes 27, 260_group_extras 60); after 0027: 270_deleted_targets 10/10, 130 80/80, 090 12/12, 060 42/42; `list_migrations` ends 0025, 0026, 0027 |
| Advisors | PASS | security: no ERROR; WARN only the known "authenticated can execute SECURITY DEFINER RPC" and leaked-password protection (Auth setting) |
| Edge Functions | PASS | `deno fmt --check` (LF copy) clean, `deno lint` clean, `deno test` 53 passed |
| Kotlin unit tests | SKIPPED | none remain (`android/app/src/test` does not exist since D-030) |
| Debug APK | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` (174.5 MB) |
