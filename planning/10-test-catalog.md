# 10 — Test catalog

Generated from `08-feature-specs.md` (2026-11-21); sessions update **Status** (`todo` → `pass` / `fail` /
`needs-owner (BLK-xxx)` / `manual-opt`). New tests a session adds get the next number in the same feature and a row here.
Cross-cutting suites (sync engine, a11y, goldens of every component, migration tests) are listed in each phase file.

Total: 121 test ids (TC-18-03 golden added in phase 09; TC-19-06..09 in phase 13).

| Phase | ID | Type | Description | Status |
| --- | --- | --- | --- | --- |
| 02 | TC-B3-01 | widget | switching updates theme | pass |
| 02 | TC-B3-02 | unit | persisted value restored | pass |
| 02 | TC-B3-03 | golden | every | pass |
| 03 | TC-10-01 | unit | payer validation vectors | pass |
| 03 | TC-10-03 | unit | pairs per | pass |
| 03 | TC-11-01 | unit | IOU produces correct pair | pass |
| 03 | TC-14-01 | unit | balances never mix currencies | pass |
| 03 | TC-15-01 | unit | vectors BAL-* | pass |
| 03 | TC-16-01 | unit | across groups + direct | pass |
| 03 | TC-17-01 | unit | simplify vectors + properties | pass |
| 03 | TC-25-01 | unit | payment effect on nets/pairs | pass |
| 03 | TC-32-01 | unit | FX vectors | pass |
| 03 | TC-5..9-01 | unit | every split vector in `money_vectors.json` | pass |
| 03 | TC-5..9-02 | unit | glados property tests | pass |
| 04 | TC-14-03 | sql | group_balances returns per-currency blocks. | pass (CI db job; MCP run needs-owner BLK-001) |
| 04 | TC-15-02 | sql | parity with vectors | pass (CI db job; MCP run needs-owner BLK-001) |
| 04 | TC-17-02 | sql | parity | pass (CI db job; MCP run needs-owner BLK-001) |
| 04 | TC-32-03 | sql | cross_rate | pass (CI db job; MCP run needs-owner BLK-001) |
| 04 | TC-5..9-05 | sql | server rejects inconsistent payers/shares (`SPLIT_SUM_MISMATCH`). | pass (CI db job; MCP run needs-owner BLK-001) |
| 04 | TC-B2-05 | sql | co-member can read | pass (CI db job; MCP run needs-owner BLK-001) |
| 05 | TC-B1-01 | widget | onboarding shows both buttons and dev login only in debug | pass (`test/features/auth/presentation/auth_screens_test.dart`) |
| 05 | TC-B1-02 | unit | auth controller | pass (`sign_in_controller_test.dart`) |
| 05 | TC-B1-03 | integ | dev sign-in → home | pass (2026-11-22, dev project, `integration_test/auth_profile_test.dart`) |
| 05 | TC-B1-04 | integ | sign-out wipes local DB and token | pass (2026-11-22, `auth_profile_test.dart`: outbox pushed first, session + prefs + Drift rows gone) |
| 05 | TC-B1-05 | edge | delete-account converts memberships to name-only and deletes user | pass (deno `delete-account/handler_test.ts`; deployed v1 called live with a throwaway user 2026-11-22, `auth_profile_test.dart`) |
| 05 | TC-B1-06 | sql | deleted | pass (`supabase/tests/024_auth_profile.test.sql`, CI db job) |
| 05 | TC-B1-07 | integ | Google sign-in (only if emulator has Google account) | needs-owner (D-020: no Google client id) |
| 05 | TC-B1-08 | unit | release config has no dev login | pass (`test/core/core_test.dart`; route is `kDebugMode`-only) |
| 05 | TC-B1-09 | manual-opt | email code arrives from owner domain. | manual-opt |
| 05 | TC-B2-01 | unit | UPI regex accepts/rejects table | pass (`test/domain/profile_test.dart`) |
| 05 | TC-B2-02 | unit | UPI QR parser | pass (`test/domain/profile_test.dart`) |
| 05 | TC-B2-03 | widget | profile form | pass (`auth_screens_test.dart`) |
| 05 | TC-B2-04 | integ | edit profile persists after restart and syncs | pass (2026-11-22, `auth_profile_test.dart`: server row checked, session restored after restart, S-214) |
| 06 | TC-1-02 | sql | create via apply_mutations makes creator owner member | pass (CI db, `040_apply_mutations`) |
| 06 | TC-18-01 | sql | every mutation type writes activity | partial: group + expense ops in `040_apply_mutations`; payment add/edit/delete/restore asserted in `090_payments_activity` (phase 09, 12/12 on dev); member/comment activity not yet asserted |
| 06 | TC-27-01..10 | unit | sync engine suite (`04-sync-engine.md` §10) | pass (`test/data/sync/sync_engine_test.dart`) |
| 06 | TC-27-14 | widget+golden | "Sync & storage": status card states, Sync now, Retry/Discard, export log, settings row, Account marker; goldens light/dark × text 1.0/2.0 (synced + issues) | pass (`test/features/sync/**`, `test/data/sync/sync_repository_test.dart`, `screens_golden_test.dart`) |
| 06 | TC-27-15 | integ | A offline-creates a group + expense, reconnects; harness B joins and sees both via `pull_changes` (T7) | pass (2026-11-22, dev project, `integration_test/sync_offline_test.dart`) |
| 07 | TC-1-01 | unit | group form validation | pass (unit `invite_code_test.dart`) |
| 07 | TC-1-03 | sql | archived group rejects new expenses (`GROUP_ARCHIVED`) | pass (sql 050) |
| 07 | TC-1-04 | widget | groups grid states | pass (widget `groups_widget_test.dart`: empty, loading, list, archived, offline) |
| 07 | TC-1-05 | golden | group card variants | pass (phase 02 + phase 07 `groups_golden_test.dart` groups list light/dark, text 1.0/2.0) |
| 07 | TC-1-06 | integ | create group offline then sync | pass (2026-11-22, emulator + dev, `integration_test/groups_test.dart`) |
| 07 | TC-1-07 | sql | only creator can delete; restore works. | pass (sql 050) |
| 07 | TC-3-01 | unit | code format/normalisation (lowercase, dashes, O/0) | pass (unit + sql 050) |
| 07 | TC-3-02 | sql | preview/join/rotate/rate-limit | pass (sql 050 (dev)) |
| 07 | TC-3-03 | widget | join screen states | pass (widget `join_screen_test.dart`) |
| 07 | TC-3-04 | integ | scan QR (inject image / deep link) → join | pass (2026-11-22, injected scanner + `/join?code=` route + `authRedirect` mapping) |
| 07 | TC-3-05 | e2e | user B joins A's group by code via harness, A sees B | pass (2026-11-22, harness B claims; A's members list shows "Claimed this spot", `member_claimed` activity row) |
| 07 | TC-4-01 | sql | claim/unlink rules | pass (sql 050) |
| 07 | TC-4-02 | sql | cannot claim a linked member | pass (sql 050) |
| 07 | TC-4-03 | widget | claim picker | pass (widget `join_screen_test.dart`) |
| 07 | TC-4-04 | integ | claimed spot keeps balances | pass (2026-11-22, `group_balances` identical before/after the claim) |
| 08 | TC-13-01 | widget | form validation | pass (`expense_editor_test.dart`, `expense_editor_controller_test.dart`) |
| 08 | TC-13-02 | widget | category picker | pass (`expense_editor_test.dart`) |
| 08 | TC-35-01 | unit | fallback rules | pass (`expense_editor_controller_test.dart`, `default_split_controller_test.dart`) |
| 08 | TC-35-02 | widget | prefill. | pass (`default_split_routes_test.dart`) |
| 08 | TC-5..9-03 | widget | editor per type: live remaining, error copy, Save disabled | pass (`split_editor_test.dart`) |
| 08 | TC-5..9-04 | golden | editor per | pass (`expense_screens_golden_test.dart`, light/dark/200 %) |
| 08 | TC-5..9-06 | integ | one expense of each split type offline → sync; server rows, server balances and a second member equal the phone | pass (`integration_test/expenses_offline_sync_test.dart` on emulator-5554, dev project, 2026-11-22) |
| 09 | TC-15-03 | widget | balances tab states | pass (`test/features/balances/presentation/balances_tab_test.dart`, goldens `balances_tab_*`) |
| 09 | TC-15-04 | integ | local vs server checksum equal after sync. | pass (unit `balances_providers_test.dart` + device `integration_test/balances_week_test.dart` 2026-11-22) |
| 09 | TC-18-02 | widget | feed grouping/filters | pass (`activity_feed_test.dart`, `activity_providers_test.dart`) |
| 09 | TC-18-03 | golden | activity feed | pass (`test/goldens/balances_golden_test.dart` `balances_activity_feed_*`) |
| 09 | TC-21-01 | unit | totals exclude IOU/payments | pass (`group_totals_test.dart`, `totals_account_stats_test.dart`) |
| 09 | TC-21-02 | widget | totals tab. | pass (`totals_tab_test.dart`) |
| 09 | TC-25-02 | widget | settle-up form | pass (`settle_up_screen_test.dart`, `settle_controller_test.dart`) |
| 09 | TC-25-03 | integ | settle a week | pass (device `integration_test/balances_week_test.dart` 2026-11-22: week in Goa, 3 people, 2 payments, oracle = phone = server, all settle → 0) |
| 10 | TC-10-02 | widget | multi-payer sheet | pass |
| 10 | TC-11-02 | widget | direction toggle copy. | pass |
| 10 | TC-29-01 | unit | compression bounds (+ real compression on the device) | pass |
| 10 | TC-29-02 | sql | storage policies (member-only) — `023_storage` 24/24 + `060_file_paths` 12/12 on dev | pass |
| 10 | TC-29-03 | integ | offline photo uploads later — device `integration_test/receipts_offline_upload_test.dart` 2026-11-22 (receipt + cover uploaded after sync, B reads both via signed URLs) | pass |
| 11 | TC-16-02 | sql | my_overview friend totals. | pass (`supabase/tests/110_friends_simplify.test.sql` on dev via MCP, 17/17, 2026-11-22; device `integration_test/friends_upi_test.dart`) |
| 11 | TC-17-03 | widget | toggle + link. | pass (`test/features/groups/simplify_setting_test.dart`, goldens `friends_group_settings_simplify_*`; server `settings_changed` in 110 SQL + device) |
| 11 | TC-2-01 | sql | one direct group per user pair | pass (`110_friends_simplify.test.sql` 17/17 on dev; device run finds the same group from both sides) |
| 11 | TC-2-02 | integ | friend expense appears on both friends' pages | pass (`integration_test/friends_upi_test.dart` on emulator-5554, 2026-11-22) |
| 11 | TC-2-03 | widget | friend page states. | pass (`test/features/friends/**`, goldens `friends_friend_page_*`, `friends_friends_*`) |
| 11 | TC-26-01 | unit | link builder encoding/rounding | pass (`test/core/upi/upi_link_test.dart` + `test/fixtures/upi_vectors.json`, pre-built) |
| 11 | TC-26-02 | integ | fake UPI handler receives exact params | pass (`tool/fake_upi_app/run_upi_e2e.ps1`: logcat `FAKE_UPI` = test's `UPI-EXPECT`) |
| 11 | TC-26-03 | integ | no UPI app → fallback sheet | pass (same script, fake app uninstalled; widget part in `upi_pay_test.dart`) |
| 11 | TC-26-04 | widget | hidden for non-INR / no VPA | pass (`test/features/payments/presentation/upi_pay_test.dart`) |
| 11 | TC-26-05 | manual-opt | real UPI app on a phone. | manual-opt |
| 12 | TC-13-03 | integ | add comment offline then | pass (`integration_test/history_comments_test.dart` on emulator + dev; unit `comments_providers_test.dart`) |
| 12 | TC-13-04 | sql | comment delete only by author. | pass (`supabase/tests/060_history_comments.test.sql` on dev; widget: `comment_thread_test.dart`) |
| 12 | TC-20-01 | sql | versions written for insert/update/delete/restore/conflict | pass (`060_history_comments.test.sql` on dev, 42/42) |
| 12 | TC-20-02 | unit | diff builder | pass (`version_diff_test.dart`, prep) |
| 12 | TC-20-03 | widget | history timeline | pass (`history_screen_test.dart`, `history_providers_test.dart`, goldens `history_comments_golden_test.dart`) |
| 12 | TC-20-04 | integ | delete → restore round trip. | pass (`integration_test/history_comments_test.dart` on emulator + dev; widget `deleted_items_screen_test.dart`) |
| 13 | TC-19-01 | sql | fan-out recipients exclude actor/muted | pass (`130_notifications.test.sql` 80/80 on dev) |
| 13 | TC-19-02 | edge | send-push idempotent + token cleanup | pass (deno 45/45; deployed, live `skipped` without FCM secret) |
| 13 | TC-19-03 | widget | bell badge | pass |
| 13 | TC-19-04 | integ | notification appears in dumpsys after B adds expense | pass in-app (`integration_test/notifications_test.dart`: bell, tap opens the expense, live `push_status = skipped`) · dumpsys part needs-owner (Firebase, D-020) |
| 13 | TC-19-05 | unit | settings model. | pass |
| 13 | TC-19-06 | widget | notifications list: day groups, unread dot, mark all read, tap opens + marks read, empty/offline | pass |
| 13 | TC-19-07 | widget | notification settings: push/in-app per kind, muted groups, push banners; ToggleRow | pass |
| 13 | TC-19-08 | widget | push pre-prompt: once, only with push + permission not asked | pass |
| 13 | TC-19-09 | widget | notifications binding: token register, foreground display, tap → route | pass |
| 13 | TC-23-01 | sql | throttle + recipient | pass (pgTAP + live in the device test) |
| 13 | TC-23-02 | widget | remind button states. | pass |
| 14 | TC-14-02 | widget | multi-currency balance sections | pass (phase 09: `balances_tab_test.dart` two-currency sections; currency picker still phase 14) |
| 14 | TC-32-02 | edge | fetch-rates upsert/throttle/backfill | todo |
| 14 | TC-32-04 | widget | conversion sheet manual/auto | todo |
| 14 | TC-32-05 | unit | missing date uses previous rate. | todo |
| 15 | TC-27-13 | integ | conflict both versions in history. | todo (core already proven by phase 06 T7, `integration_test/sync_offline_test.dart`: A's older offline edit superseded, both in `record_versions`) |
| 16 | TC-12-01 | sql | generation idempotent (double run = one copy) | todo |
| 16 | TC-12-02 | sql | 31st clamp for Feb/Apr | todo |
| 16 | TC-12-03 | sql | stop/ends_on | todo |
| 16 | TC-12-04 | widget | repeat picker | todo |
| 16 | TC-12-05 | unit | next-date calculator parity with SQL. | todo |
| 16 | TC-34-01 | unit | query parser (amount detection) | todo |
| 16 | TC-34-02 | integ | search finds by each field. | todo |
| 17 | TC-22-01 | unit | CSV writer escaping, BOM, totals | todo |
| 17 | TC-33-01 | unit | aggregation | todo |
| 17 | TC-33-02 | golden | charts. | todo |
| 18 | TC-22-02 | unit | round trip with X1 importer. | todo |
| 18 | TC-X1-01 | unit | parser fixtures (quotes, BOM, multi-currency, payments, totals row, JPY) | todo |
| 18 | TC-X1-03 | widget | mapping/preview | todo |
| 18 | TC-X1-04 | integ | import 200 rows | todo |
| 18 | TC-X2-01 | unit | lock timer logic | todo |
| 18 | TC-X2-02 | integ | fingerprint via `adb -e emu finger touch`. | todo |
| 18 | TC-X3-01 | unit | widget data builder | todo |
| 18 | TC-X3-02 | integ | widget data updated after expense (read shared prefs). | todo |
