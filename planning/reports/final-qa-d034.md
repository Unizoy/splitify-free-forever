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
| Flutter tests | PASS | full suite in 4 chunks, `--concurrency=2`, `--coverage`, run twice: 4,008 passed / 0 failed at the start, **4,013 passed / 0 failed** on the final tree (c1 core/data/ui 1,164 · c2 features a–f 1,025 · c3 features g–z 905 · c4 goldens 919). The known flaky tests were made deterministic (S-408) and did not fail in either run |
| Coverage | PASS | chunks merged per line: overall 95.5 %, money 100 %, sync 99.5 %, domain 97.8 %, core 97.4 %, application 95.2 %, presentation 95.1 %, data 94.4 % |
| pgTAP (DEV) | PASS | all 27 files before 0027: 1,035/1,035 (incl. 250_friend_codes 27, 260_group_extras 60); after 0027: 270_deleted_targets 10/10, 130 80/80, 090 12/12, 060 42/42; `list_migrations` ends 0025, 0026, 0027 |
| Advisors | PASS | security: no ERROR; WARN only the known "authenticated can execute SECURITY DEFINER RPC" and leaked-password protection (Auth setting) |
| Edge Functions | PASS | `deno fmt --check` (LF copy) clean, `deno lint` clean, `deno test` 53 passed |
| Kotlin unit tests | SKIPPED | none remain (`android/app/src/test` does not exist since D-030) |
| Debug APK | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` (174.5 MB) |

## Device tests (emulator-5554, `com.unizoy.splitify.qa`, `--no-uninstall`, DEV, DNS pin)

`adb shell pm list packages` before and after every runner: only `com.unizoy.splitify.qa` (+ Splitwise, untouched;
the fake UPI app comes and goes with the UPI runner). The owner's `com.unizoy.splitify` was not installed during
the run (reinstalled at the end).

| File / runner | Result |
| --- | --- |
| `d034_a_test` (capture_d034_a: two-person, itemize, real OCR, restore) | PASS |
| `d034_b_test` (capture_d034_b: friend code deep link, batch settle offline→online, restore, batch UPI to the fake UPI app, share reminder) | PASS |
| `d034_c_test` (capture_d034_c: lines, trip dates, notes offline → e2e-b, trip-end nudge on DEV via MCP, filter restart, settled history, group search) | PASS (after a test fix: it read the router's base location after a push) |
| `d034_d_test` (capture_d034_d: search, your data zip, totals month, trends, real airplane mode) | PASS |
| `minimal_entry_capture_test`, `minimal_entry_test`, `minimal_groups_test`, `minimal_pay_test`, `simple_expense_test` | PASS |
| `friends_upi_test`, `minimal_pay_upi_test` (run_upi_e2e: fake UPI app got the exact link; "No UPI app" path) | PASS (both paths each) |
| `app_smoke_test` | PASS (after a test fix: start signed out; keep the test's error handler) |
| `auth_profile_test` | PASS (after test fix: no Account gear; and app fix S-412) |
| `balances_week_test` | PASS (after test fix: method chip → sheet) |
| `recurring_search_test` | PASS (after test fix: preferences for recent searches) |
| `scenarios/sync_storage_review_test` | PASS (after test fix: no Account gear) |
| `auto_category_test`, `currencies_test`, `expenses_offline_sync_test`, `extras_import_widget_test`, `groups_test` (2), `history_comments_test`, `notifications_test`, `receipts_offline_upload_test`, `sync_offline_test`, `ui_review_expenses/history/insights/phase10_test`, `scenarios/groups_review_test` | PASS (`ui_review_phase10` passed on re-run: the first run hung behind a share sheet another test left open) |
| `offline_airplane_test` (airplane.ps1 stages A1 A2 A3 K1 K2 C1; K1 is killed mid-push by design) | PASS |
| `background_sync_test` (real WorkManager: `Worker result SUCCESS … BackgroundWorker`) | PASS |
| `app_lock_test` (run_lock_e2e: device PIN, FLAG_SECURE) | PASS |
| `perf_test`, `perf_screens_test` (flutter drive --profile) | PASS (numbers in `final-qa-d034/device/run-perf.log`, `run-flutter.log`) |

## Leftovers fixed (tests first)

| Leftover | Fix | Test |
| --- | --- | --- |
| Tab bar overflow at 320 dp | compact capsule bar (S-400); Groups small-phone golden added | `capsule_nav_bar_test.dart` (7), `d034c_groups_filtered_*_small` |
| New trip group logged "created" + "updated" | dates/reminder in the one create (S-401) | `group_extras_widget_test.dart` |
| Bell opened the group for a deleted expense | migration **0027_deleted_targets** (DEV): target = the record, old rows moved over (S-406) | `270_deleted_targets.test.sql` 10/10 |
| Account tab avatar showed initials | saved photo (S-402) | `auth_screens_test.dart` |
| Initials took digits | letters only (S-403) | `avatar_initials_test.dart` (15) |
| Friend-code link lost at sign-in | kept like invites (S-404) | `welcome_screen_test.dart` (2) |
| Batch settle = one transaction per payment | `LocalWriter.writeAll` / `saveAll`: one transaction (S-405) | `settle_all_controller_test.dart` (failing first) |
| x86_64/x86 libraries in the universal APK | `abiFilters` from `--target-platform` (S-407) | APK listings |

## Defects found in this QA and fixed

D1 two different "deleted" pages → one look, one Restore (S-410) · D2 Restore offered in archived groups (S-410) ·
D3 new payments dated "Yesterday" and "this month" = UTC month before 05:30 IST (S-413) · D4 exchange-rate refresh
crashed on a closed database at sign-in (S-412) · D5 "Search expenses" tooltip (S-414) · T1 seven drifted device
tests (S-411) · T2 device tooling (S-415). Details and minor observations (not changed): `splitify-artifacts\final-qa-d034\defects.md`.

## APK sizes (release, signed with the debug key here)

| APK | Before | After |
| --- | --- | --- |
| Universal phone APK (`--target-platform android-arm,android-arm64`) | 48,020,887 B (45.8 MB) — carried 6 x86_64 libraries (17.7 MB raw, 7.0 MB compressed) | 41,049,952 B (39.15 MB), arm64-v8a + armeabi-v7a only; passes `build_release.ps1`'s 40 MB check again |
| arm64-v8a split (`--split-per-abi`) | 24,813,566 B (23.66 MB) | 24,814,802 B (23.67 MB) (splits unchanged; x86_64 split 24.3 MB still built for the emulator) |

## Owner's emulator and preview APK

- Emulator Private DNS set to `dns.google` (`private_dns_mode hostname`), so normal builds reach Supabase.
- The owner's production app reinstalled from `splitify-artifacts\apk\prod-0.2.0\splitify-x86_64.apk` (SHA-256
  matches `SHA256SUMS.txt`; `com.unizoy.splitify` 0.2.0, versionCode 4003), opened to the welcome screen, not signed
  in, left installed (`final-qa-d034\prod-welcome.png`). `com.unizoy.splitify.qa` and Splitwise stay installed.
- Preview APK: `splitify-artifacts\apk\preview-d034-qa-arm64.apk` — `com.unizoy.splitify.qa`, versionName 0.2.0,
  versionCode 3, arm64-v8a only, DEV, 24,812,174 B (23.66 MB; the same command gave 36.99 MB before S-407),
  SHA-256 7d9b7b821d69e351774c2b8c43e885c52acaeb0d23f6fe380cd0ab57d18da3d5.

## Screenshots

`splitify-artifacts\screenshots\final-d034-<screen>-{light,dark}.png`: 34 screens × light + dark, plus 3 light-only (notes while typing, items editor scrolled, reminder sent) (groups home,
filter sheet, group page with who-owes-whom and trip/notes chips, notes, settings, edit group with trip dates and
reminders, Totals month, settle sheet, record payment, add expense, paid-by/split sheet, items editor, receipt
sheet, friends, friend page, settle sheet with "Everything with", settle everything + breakdown, add friend, my
code, add by code, activity, notifications, account, settings list, your data, insights trends, search, search from
a group, deleted expense, deleted payment, itemized expense). Font 2.0 and extra screens:
`splitify-artifacts\final-qa-d034\font2-*.png`, `walk-*.png`.

## Owner actions / open

- Apply migrations **0025, 0026 and 0027** to production with the D-034 release (DEV only here).
- Not changed (minor, see defects.md O1–O5): "1.23" lit with "By items", items error kept after leaving the sheet,
  filter sheet style, small two-currency amounts on group cards, first-word names in item chips.

