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
| 05 | TC-B1-07 | integ | Google sign-in (only if emulator has Google account) | pass (2026-11-22, D-026, real Google on emulator-5554: Credential Manager sheet → account → `auth.identities` provider google → Groups; restart keeps the session; sign-out → welcome; `planning/reports/integrations.md`) |
| 05 | TC-B1-08 | unit | release config has no dev login | pass (`test/core/core_test.dart`; route is `kDebugMode`-only) |
| 05 | TC-B1-09 | manual-opt | email code arrives from owner domain. | partial (2026-11-22: `/otp` 200 through the owner's Gmail SMTP; reading the code in the emulator's Gmail was refused by the permission system → code entry + OTP length needs-owner BLK-002) |
| int | TC-B1-10 | widget+device | wrong or used code → Supabase `otp_expired` → "wrong or has expired" copy, counts as a try, boxes emptied and red; offline keeps digits | pass (`auth_screens_test.dart`, `auth_repository_test.dart`, golden `screen_sign_in_code_wrong_*`; device: 403 `otp_expired` seen live) |
| int | TC-B1-11 | unit+widget+golden | `EMAIL_OTP_LENGTH` 6–10 (else 6) drives boxes, title, semantics and auto-verify | pass (`core_test.dart`, `auth_screens_test.dart`, golden `screen_sign_in_code_8_*`) |
| int | TC-B1-12 | unit+widget | Credential Manager errors → AuthFailure (no endless spinner); sign-out clears the Google credential; spinner on the Google button | pass (`auth_repository_test.dart`, `auth_screens_test.dart`) |
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
| 08 | TC-13-01 | widget | form validation (one screen since D-032) | pass (`expense_editor_test.dart`, `expense_editor_bugs_test.dart`, `expense_editor_controller_test.dart`) |
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
| 13 | TC-19-04 | integ | notification appears in dumpsys after B adds expense | pass in-app (`integration_test/notifications_test.dart`) · dumpsys part pass (2026-11-22, D-026: real FCM push in `dumpsys notification`, channel per kind; TC-19-10) |
| int | TC-19-10 | device | real push end to end: permission after pre-prompt → token saved per device → B joins / adds expense / reminds → send-push `sent, delivered 1` (FCM 200) → shown in foreground (local), background and killed (system tray) → tap opens the expense / the group's Balances tab; sign-out removes the token | pass (2026-11-22, `planning/reports/integrations.md`) |
| 13 | TC-19-05 | unit | settings model. | pass |
| 13 | TC-19-06 | widget | notifications list: day groups, unread dot, mark all read, tap opens + marks read, empty/offline | pass |
| 13 | TC-19-07 | widget | notification settings: push/in-app per kind, muted groups, push banners; ToggleRow | pass |
| 13 | TC-19-08 | widget | push pre-prompt: once, only with push + permission not asked | pass |
| 13 | TC-19-09 | widget | notifications binding: token register, foreground display, tap → route | pass |
| 13 | TC-23-01 | sql | throttle + recipient | pass (pgTAP + live in the device test) |
| 13 | TC-23-02 | widget | remind button states. | pass |
| 14 | TC-14-02 | widget | multi-currency balance sections | pass (phase 09 `balances_tab_test.dart`; phase 14 goldens `currency_balances_by_currency_*`) |
| 14 | TC-14-04 | widget | currency picker: group currency first, recent, search, pick (editor + Settle up chips) | pass (`currency_picker_test.dart`, `expense_editor_test.dart`, `settle_up_screen_test.dart`) |
| 14 | TC-14-05 | sql | fx_rates RLS/keys, currency parity, saved-conversion checks, fetch-rates cron wiring | pass (`140_fx.test.sql`, 22/22 on dev via MCP) |
| 14 | TC-32-02 | edge | fetch-rates upsert/throttle/backfill | pass (`fetch-rates/rates_test.ts`, deno 45/45; live: backfill 4,561 rows, 01:15 cron run throttled) |
| 14 | TC-32-04 | widget | conversion sheet manual/auto | pass (`conversion_sheet_test.dart`, `conversion_tile_test.dart`, `fx_copy_test.dart`, goldens `currency_convert_*`) |
| 14 | TC-32-05 | unit | missing date uses previous rate. | pass (`fx_service_test.dart`, `conversion_actions_test.dart`) |
| 14 | TC-32-06 | unit | rates cache refresh/throttle/paging + Convert all at each record date | pass (`fx_rates_repository_test.dart`, `conversion_actions_test.dart`, `converted_balances_test.dart`) |
| 14 | TC-32-07 | widget | "Show balances in INR": missing list, Convert all, converted nets | pass (`converted_balances_view_test.dart`, goldens `currency_balances_in_inr_*`) |
| 14 | TC-32-08 | unit | edits keep the saved rate and re-convert; new currency drops the conversion | pass (`expense_editor_fx_test.dart`, `settle_controller_test.dart`, `conversion_test.dart`) |
| 14 | TC-17-04 | unit | simplify after converting to the main currency (converted nets) | pass (`converted_balances_test.dart`, `converted_balances_view_test.dart`) |
| 14 | TC-32-09 | integ | USD expense offline → convert at cached rate → server fx columns + INR view | pass (`integration_test/currencies_test.dart` on emulator-5554 + dev, 57 s: picker, cached-rate conversion with the rates server off, server fx_rate = independent cross rate, Convert all, INR nets = oracle) |
| 15 | TC-27-11 | e2e | real airplane mode: 5 expenses (1 with receipt photo), edit, delete, payment, comment → app killed → relaunch offline (data + markers kept) → network on → automatic sync, B sees exact server state, markers cleared | pass (2026-11-22, emulator-5554 + dev, real airplane mode: A1–A3 of `integration_test/offline_airplane_test.dart` via `tool/e2e/airplane.ps1`; 9 changes + 1 receipt survived the kill, synced 6.4 s after airplane mode off without "Sync now", B saw 5 expenses incl. the deleted one, the payment, the comment and the receipt JPEG) |
| 15 | TC-27-12 | e2e | force-stop during a 300-change push → relaunch → no duplicates, order kept | pass (K1–K2: killed with 250 of 300 queued while the server already had 100 — one batch acknowledged, one applied but not acknowledged; relaunch → 300 rows, 300 `insert` versions, server seq order = phone order) |
| 15 | TC-27-13 | integ | conflict: snackbar + history shows both versions | pass (C1 on the emulator: snackbar shown, history shows "Not applied (a newer edit won)" with A's version under B's; core also in phase 06 `sync_offline_test.dart`) |
| 15 | TC-27-16 | widget | SyncBinding triggers: start, network regained, resume, Realtime nudge, group topics, pause → WorkManager one-off, superseded snackbar | pass (`test/features/sync/presentation/sync_binding_test.dart`) |
| 15 | TC-27-17 | unit | worker ↔ app sync port; second 401 → session-expired handler; offline refresh = NetworkException; owner check wipes another account's data | pass (`background_sync_test.dart`, `session_expired_provider_test.dart`, `supabase_remote_api_test.dart`, `sync_repository_test.dart`) |
| 15 | TC-27-18 | widget+golden | Sync & storage: Edit (route per entity), photos waiting/retrying/skipped + Retry; goldens light/dark × 1.0/2.0 | pass (`sync_uploads_edit_test.dart`, `sync_texts_test.dart`, `screens_golden_test.dart`) |
| 15 | TC-27-19 | widget | Groups card marked for any pending row of the group; delete account offline says "Needs internet"; long expense list pages by 100 | pass (`groups_home_unsynced_marker_test.dart`, `delete_account_offline_test.dart`, `auth_screens_test.dart`, `expense_list_detail_test.dart`) |
| 15 | TC-27-20 | perf | 2,000 expenses: list scroll frame times (profile), balance recompute, cold start | measured (2026-11-22, emulator x86_64, profile: scroll 55 frames build p90 6.5 ms / raster p90 6.8 ms, 0 missed; open-group frame 265 ms; ledger load + balances median 31 ms; write → balances 229 ms; release cold start 1.23–1.55 s to the first screen, 4.6 s first launch after install; `integration_test/perf_test.dart`, `tool/e2e/perf.ps1`) |
| 16 | TC-12-01 | sql | generation idempotent (double run = one copy) | pass — supabase/tests/151_recurring.test.sql (dev, 49/49) |
| 16 | TC-12-02 | sql | 31st clamp for Feb/Apr | pass — 151_recurring + 150_recurring_vectors (dev) |
| 16 | TC-12-03 | sql | stop/ends_on | pass — 151_recurring (dev) |
| 16 | TC-12-04 | widget | repeat picker | pass — test/features/recurring/repeat_picker_test.dart + goldens recurring_search_golden_test |
| 16 | TC-12-05 | unit | next-date calculator parity with SQL. | pass — test/domain/rules/recurrence_test.dart = supabase/tests/150_recurring_vectors.test.sql (52 vectors, dev), test/tool/gen_recurring_sql_test.dart |
| 16 | TC-34-01 | unit | query parser (amount detection) | pass — test/domain/rules/search_query_test.dart |
| 16 | TC-34-02 | integ | search finds by each field. | pass — integration_test/recurring_search_test.dart (+ test/data/repositories/search_repository_test.dart) |
| 17 | TC-22-01 | unit | CSV writer escaping, BOM, totals | pass (domain + Drift mapping, share-sheet flow) |
| 17 | TC-33-01 | unit | aggregation | pass (domain + ledger mapping, Group/Me, saved conversions) |
| 17 | TC-33-02 | golden | charts. | pass (8 screens × light/dark × 1.0/2.0 + widget tests) |
| 18 | TC-22-02 | unit | round trip with X1 importer. | pass (`import_csv_test.dart`: export → parseImportCsv → reconstruct, nets equal, S-192) |
| 18 | TC-X1-01 | unit | parser fixtures (quotes, BOM, multi-currency, payments, totals row, JPY) | pass (pre-built parser tests + Splitify-format reader) |
| 18 | TC-X1-02 | unit | reconstruction keeps nets equal to the file | pass (pre-built + mapping/skip + import rows + repository tests) |
| 18 | TC-X1-03 | widget | mapping/preview | pass (`import_screen_test.dart` full flow on memory Drift + 11 golden scenarios × light/dark × 1.0/2.0) |
| 18 | TC-X1-04 | integ | import 200 rows | pass (`extras_import_widget_test.dart` on emulator: 200 rows offline through the screens → sync → server rows/source, one `import_completed`, balances = file totals; Delete this import → rows soft-deleted, one undone entry; pgTAP `180_import.test.sql` 13/13) |
| 18 | TC-X2-01 | unit | lock timer logic | pass (`lock_policy_test.dart`, `app_lock_controller_test.dart`) |
| 18 | TC-X2-02 | integ | fingerprint via `adb -e emu finger touch`. | pass with the device PIN instead of a fingerprint (`app_lock_test.dart` + `tool/e2e/run_lock_e2e.ps1`: locked on start, PIN unlock, home + 2 min → locked again, FLAG_SECURE seen on the window, PIN cleared) |
| 18 | TC-X3-01 | unit | widget data builder | pass (`widget_data_test.dart`, `home_widget_sync_test.dart`) |
| 18 | TC-X3-02 | integ | widget data updated after expense (read shared prefs). | pass (same device test: `pending` = "Not synced yet" after the local import, cleared after sync; `status/line1/line2` equal the app's values; widget pinned and screenshotted) |
| 18b | TC-X4-01 | unit | parser vectors (68 shared: 38 debits across UPI apps, 9 banks and cards, 25 ignore cases, 5 screen stages) in Kotlin and Dart | pass (`android/app/src/testFull/.../PaymentParserTest.kt` via `gradlew :app:testDebugUnitTest`; `test/features/capture/recipes_vectors_test.dart`). Not on main since D-030 (2026-11-26): the tests live on branch `feature/payment-bubble`. |
| 18b | TC-X4-02 | unit + integ | dedup (same ref; no-ref notification + bank SMS within 10 min merge; dismissed/imported still block) | pass (`CaptureStoreTest.kt`, `capture_repository_test.dart`; device: notification + bank SMS of the same payment = one capture). Not on main since D-030 (2026-11-26): the tests live on branch `feature/payment-bubble`. |
| 18b | TC-X4-03 | e2e | UPI app notification → bubble with amount + payee | pass (emulator, `tool/e2e/capture_e2e.ps1` + `integration_test/capture_bubble_test.dart`: fake UPI notification → expanded bubble ₹420 to Neha Gupta). Not on main since D-030 (2026-11-26): the tests live on branch `feature/payment-bubble`. |
| 18b | TC-X4-04 | e2e | bank SMS (`adb emu sms send`) → bubble | pass (SBI-format SMS via Google Messages → bubble ₹99 to Chai Point). Not on main since D-030 (2026-11-26): the tests live on branch `feature/payment-bubble`. |
| 18b | TC-X4-05 | e2e | smart capture: pay screen → "Splitting this?", PIN screen → hidden, success → expanded | pass (fake UPI `FlowActivity`; PIN field never read). Not on main since D-030 (2026-11-26): the tests live on branch `feature/payment-bubble`. |
| 18b | TC-X4-06 | unit + e2e | Add → prefilled editor → Save → server row `source = 'capture'` | pass (`capture_editor_test.dart`, pgTAP `230_capture.test.sql` 14/14 on dev; device: bubble Add → capture screen → group → editor ₹99 "Chai Point" → save → dev row `source=capture`, total 9900). Not on main since D-030 (2026-11-26): the tests live on branch `feature/payment-bubble`. |
| 18b | TC-X4-07 | unit + e2e | credit / OTP / promo / request / failure / future / spoofed sender give no bubble | pass (vectors; device: OTP, credit, promo, request, failed alerts → logged ignores, no bubble). Not on main since D-030 (2026-11-26): the tests live on branch `feature/payment-bubble`. |
| 18b | TC-X4-08 | widget + golden | settings: off by default, sources, live access states + Grant, restricted-settings guide, per-app switches, sample bubble | pass (`capture_settings_screen_test.dart`, `capture_golden_test.dart` light/dark/text 2.0). Not on main since D-030 (2026-11-26): the tests live on branch `feature/payment-bubble`. |
| 19 | TC-SEC-01 | sql | attack suite: non-member / stranger / left member / anon via every RPC and table, forged member ids and created_by, moving records between groups, claiming linked members, join rate limit, storage name tricks, oversized payloads (`190_attack`) | pass (dev, 288/288, with 0022) |
| 19 | TC-SEC-02 | sql | housekeeping job prunes join attempts, keeps the rest, only cron can run it (`191_housekeeping`) | pass (dev, 10/10) |
| 19 | TC-SEC-03 | edge | Edge Functions refuse wrong methods, missing/foreign JWTs, empty/non-JSON/oversized bodies, malformed ids | pass (deno 53/53 on an LF copy; send-push v3 deployed) |
| 19 | TC-B3-04 | widget | a11y sweep: Android tap-target + labelled-tap-target guidelines on every golden screen/state, light/dark, text 1.0/2.0 (`golden_support.dart expectA11y`) | pass |
| 19 | TC-B3-05 | unit | reduced motion: every AnimationController checks `motion.reduced`, implicit animations use motion tokens (`test/a11y/reduced_motion_test.dart`) | pass |
| 19 | TC-B3-06 | widget | focus order: TalkBack traversal goes top to bottom on welcome, sign in, appearance, about (`test/a11y/focus_order_test.dart`) | pass |
| 19 | TC-B3-07 | widget+golden | About & licences: links open, failed link says the URL, licence page; goldens light/dark × 1.0/2.0 | pass (`about_screen_test.dart`, `screen_about_*`) |
| 19 | TC-REL-01 | build | release APKs: signed with the key file (throwaway key verified with apksigner), R8, per-ABI + universal phone APK < 40 MB, debug-key fallback | pass (universal phone APK 31.9 MB; apksigner CN=Throwaway Test, fallback CN=Android Debug) |
| 19 | TC-27-21 | perf | group page as slivers: open + scroll a 2,000-expense group (`tool/e2e/perf.ps1`) | measured (worst build frame on open 264.8 → 55.4 ms; raster/cold start not comparable on the loaded PC, re-measure) |
| 19 | TC-27-22 | e2e | real WorkManager run: change queued offline, app in the background, jobs forced → outbox sent, server has it (`tool/e2e/background_sync.ps1`) | pass (BackgroundWorker "Worker result SUCCESS" ×2, server row) |
| QA motion | TC-QM-01 | widget | `Pressable` press-in/spring-back, quick tap shows the whole press, long press + keyboard activate, inert without callbacks, reduced motion; `AppIconButton` and `PillButton` press (`test/ui/components/motion_test.dart`) | pass |
| QA motion | TC-QM-02 | widget | count-up in integer minor units, no count across currencies or when reduced; first-load entrance (first 8 rows, scope only); `FadeIn`; tab fade-through keeps state; shared-axis push/pop; shimmer settles; glass card paints the pre-blurred snapshot and retakes it on resize (`motion_test.dart`) | pass |
| QA motion | TC-QM-03 | perf | Groups, group page, Activity, friend page: open + identical scroll script, before (main) vs after, profile on the emulator (`integration_test/perf_screens_test.dart`) | measured (planning/reports/qa-motion-polish.md) |
| X5 | TC-X5-01 | unit | auto-category keyword file + matcher: 208 description vectors (owner's brands and words, Hindi in Devanagari, UPI IDs, mixed texts, word boundaries, no match → null), normalising, ranking (length > tier > position), file checks (known categories, no duplicate phrase, < 50 KB, version) | pass (`test/domain/rules/category_suggester_test.dart`, 224 tests) |
| X5 | TC-X5-02 | unit | learning: lessons only for overrides (≤ 8 words), learned beats the file at equal length, per-user SharedPreferences store (newest last, max 300, damaged value, sign-out key) | pass (`category_suggester_test.dart`, `test/data/local/category_memory_test.dart`) |
| X5 | TC-X5-03 | unit | editor controller: new expense follows the description and falls back to the group's last category, manual pick sticks and is learned on save, saved expense never changes, no keyword list → no change; imports only fill uncategorised rows | pass (`auto_category_test.dart`, `import_plan_test.dart`; the capture prefill case left main with the bubble, D-030) |
| X5 | TC-X5-04 | widget + golden | editor: chip follows typing after 250 ms with "Auto" tag and screen-reader label, tap → Details, manual pick sticks, edit never changes, Save/Next apply a pending suggestion; goldens `expense_editor_{amount_auto,details_auto}` light/dark × text 1.0/2.0 | pass (`auto_category_editor_test.dart`, `expense_screens_golden_test.dart`) |
| X5 | TC-X5-05 | widget + unit | ~~flavours~~ replaced by D-030: one build without the bubble; old `splitify://capture` and `/account/payment-bubble` links show the friendly unknown-link page | pass (`test/features/final_qa/final_qa_device_test.dart` "an old payment-bubble link shows the friendly page") |
| X5 | TC-X5-06 | build | the APK (one build since D-030) declares no BIND_NOTIFICATION_LISTENER_SERVICE / BIND_ACCESSIBILITY_SERVICE / SYSTEM_ALERT_WINDOW / SMS (aapt2 `dump permissions` + `dump xmltree`) | pass (release arm64 build 2026-11-26, `tool/build_release.ps1` check on every APK) |
| X5 | TC-X5-07 | e2e | emulator: real editor, typing "Swiggy" letter by letter → Takeaway + Auto after the pause, "Uber to the airport" → Cab & auto, chip opens Details, manual pick sticks; (2026-11-23, before D-030: `standard` and `full` x64 release APKs installed over each other in place) | pass (`integration_test/auto_category_test.dart` via `capture_markers.ps1`; screenshots + dumpsys in `splitify-artifacts\phase-x5\`) |
| Welcome | TC-W-01 | widget | D-029 welcome: preview (2 covers + glass ₹2,450), headline, chips, actions, no dashed circle; preview hidden from screen readers; same light theme in dark mode; entrance done ≤ 350 ms then idle float; reduced motion static (settles); no overflow at 320×568, 360×640 (1.0/2.0), 412×915 (1.3/2.0), 480×1066, landscape | pass (`test/features/onboarding/welcome_screen_test.dart`) |
| Welcome | TC-W-02 | widget + unit | Get started pushes sign-in with the shared-axis move (welcome stays below), back pops; S-283 invite signed out → sign-in ("…then we open your invite") → email code → profile → `/join`; invite link `/join?code=` signed out → Google → profile → `/join?code=…` (preview looked up); `authRedirect` with a kept join | pass (`welcome_screen_test.dart`, `test/app/app_test.dart`) |
| Welcome | TC-W-03 | golden | welcome light/dark × text 1.0/2.0 (`screens_golden_test.dart`), small phone 360×640 and text 1.3 (`test/goldens/welcome_golden_test.dart`); real-font review | pass |
| Welcome | TC-W-04 | e2e | emulator: welcome light, dark, text 2.0 from a release preview build (S-287); splash colour | pass (2026-11-24, emulator-5554, release x64 preview build; `splitify-artifacts/screenshots/welcome-v2-*.png`; `planning/reports/ui-welcome-redesign.md`) |
| Welcome | TC-W-05 | widget + e2e | S-288 transitions: every GoRoute is an `AppRoute` and the shell a page; push 280 ms / pop 240 ms shared axis with the tabs shifting under it; reduced motion has no transition; group card cover flies into the group page; emulator: push into a group, an expense, group settings and back all animate (cover and icon heroes fly) | pass (`test/app/app_route_test.dart`; `splitify-artifacts/screenshots/transition-*.png`) |
| D-032 | TC-D32-01 | widget | Bug regressions, failing first on the 5-step editor: only one keyboard (description = text keyboard, amount = number keyboard, no custom pad even with a 300 dp inset; Save/toolbar above the keyboard); an empty description keeps and shows the amount and Save asks for a description, then saves it; digits typed into the description make Save say "Enter an amount" (`expense_editor_bugs_test.dart`) | pass |
| D-032 | TC-D32-02 | unit | `ExpenseDraft.firstProblem` order (description → amount → paid/split → notes → repeat), `amountMissing`, integer minor units per currency (INR/JPY/KWD), equal-split leftovers in fixed order, every draft change keeps the typed amount, friend (`direct`) groups, `AmountInput.accept`, the pill text and its live line (`expense_draft_editor_test.dart`) | pass |
| D-032 | TC-D32-03 | widget | One-screen editor flows: layout, autofocus + keyboard types, typing → minor units, decimals/paste rules, zero/too large, currency change re-checks, titles + offline, loading/missing; Save paths (equal split default, app-bar Save, both errors, refused save, payers/split/notes/repeat problems open their sheet); Paid by · split sheet (payer, multiple payers live footer, prefilled, kind wording, invalid split); toolbar (date sheet today/yesterday/calendar/labels, notes, receipt, repeat); category picker; edit keeps values and category; discard confirm (back + system back); values survive rotation, pause/resume and every sheet; TalkBack labels (`expense_editor_test.dart`, `split_editor_test.dart`, `auto_category_editor_test.dart`, `receipt_widgets_test.dart`, `recurring_editor_test.dart`, `default_split_routes_test.dart`) | pass |
| D-032 | TC-D32-04 | golden | `expense_editor_golden_test.dart`: empty, filled (auto), sheet shares / exact left / payers, validation error, edit with several payers, friend, edit future copies — light/dark × text 1.0/2.0 + small phone 360×640; receipt and repeat sheets in `phase10_golden_test.dart` / `recurring_search_golden_test.dart`; real-font review | pass |
| D-032 | TC-D32-05 | e2e | emulator, DEV: group page → Add expense → empty, Save errors, real text keyboard on the description and real number keyboard on the amount (no pad), filled, shares split in the sheet, date picker, Save → list shows ₹1,250.50 and "You are owed ₹625.25"; server row and `group_balances` = phone (`integration_test/simple_expense_test.dart` via `tool/e2e/capture_simple_expense.ps1`, side-by-side `.qa` build, S-310) | pass (2026-11-27, emulator-5554; `splitify-artifacts/screenshots/simple-expense-*.png`) |
| D-033 pay | TC-D33-PAY-01 | unit | Bug first (S-325): a settle link with someone who left but still owes / an unknown id / the same person twice; `settleSuggestions` per currency, mine first, biggest first; prefill of what is owed per currency (INR/USD/JPY, typed amounts kept); swap; `canPayByUpi` / `upiLinkFor`; `settledWith` needs every currency square; loan notes + currency in the row and back on edit (`settle_controller_test.dart`, `upi_pay_test.dart`, `loan_editor_controller_test.dart`) | pass |
| D-033 pay | TC-D33-PAY-02 | widget | Record a payment on one screen: prefill, number keyboard (no pad), all / part / more / nothing-owed pill + "Pay all", swap and person sheets, typed amount kept, inline amount errors + focus, method / date / note sheets and button labels, note too long reopens its sheet, save → closes + snackbar + short celebration (tap skips, none for part / edit / dollars still owed), discard question (back + system back, edit copy), edit, offline marker, text 2.0, not found / loading; Pay via UPI only for INR + UPI ID + payer me + new, Mark as paid / Not yet / no app, fallbacks in the UPI sheets; pickers: rows, order, currency headings, one balance opens at once, settled, loading, Groups home (`settle_up_screen_test.dart`, `upi_pay_test.dart`) | pass |
| D-033 pay | TC-D33-PAY-03 | widget | Record a loan on one screen: amount focused on the number keyboard, what-for text keyboard, paste/decimals, who sheet (direction, pick closes, Done), Save errors (amount → focus; nobody → sheet with error), typed amount kept, notes / date / currency chips, discard question, between two others, no other member, not a member / missing, text 2.0 (`loan_screen_test.dart`); default split sheet: values, Save waits for 100 %, save + snackbar closes, refused save, kinds, zero shares, missing group, keyboard inset (`default_split_routes_test.dart`) | pass |
| D-033 pay | TC-D33-PAY-04 | golden | `minimal_pay_golden_test.dart`: Record a payment all / part / more / nothing owed (offline) / Pay via UPI / edit / error, method sheet, Settle up sheet (two currencies), payment detail (+ unsynced), loan new / filled / borrowed / between others / error / who sheet, default split sheet — light/dark × text 1.0/2.0 + small phone 360×640; real-font review; old settle/loan/detail goldens refreshed | pass |
| D-033 pay | TC-D33-PAY-05 | e2e | emulator, DEV, `.qa` build: Settle up sheet (mine first) → Record a payment prefilled ₹400, real number keyboard (no pad), part ₹150, discard question, method sheet, note → Record cash payment → server row + `group_balances`; compact payment detail + edit; settle the rest → celebration → my net 0; loan "I lent Rahul ₹500" → IOU row on the server; group settings → default split sheet (shares) → server (`integration_test/minimal_pay_test.dart` via `tool/e2e/capture_minimal_pay.ps1`) | pass (2026-11-27, emulator-5554; `splitify-artifacts/screenshots/minimal-pay-after-*.png`) |
| D-033 pay | TC-D33-PAY-06 | e2e | Pay via UPI on the one screen with `tool/fake_upi_app`: one balance → Record a payment at once, "Pay ₹300 via UPI", the fake app receives exactly the expected link (host compares `UPI-EXPECT` with logcat `FAKE_UPI`), nothing recorded before Mark as paid, then a UPI row on the server + celebration; no-app path: "No UPI app found" with fallbacks, Not yet records nothing (`integration_test/minimal_pay_upi_test.dart` via `run_upi_e2e.ps1 -Test minimal_pay_upi_test` / `capture_minimal_pay.ps1`, `.qa` build). `friends_upi_test.dart` fails earlier, at its friend-page step (TC-2-02, not payments) | pass (2026-11-27, emulator-5554) |
| D-033 | TC-D33-01 | widget | Entry (failing first on the old sheet): the + opens the editor at once — no group → nobody picked, one group → picked, several → no which-group sheet (`default_split_routes_test.dart`); "With you and": dashed chooser + 4 suggestions, a suggestion keeps the typed description/amount, Save without a group shows "Choose who this is with" and opens the picker, the pill opens the picker, search narrows groups and friends, a friend without our group, a new name becomes a friend, a chosen currency stays, a group page preselects its group (checked, selected semantics), a saved expense's chip is read-only (`with_picker_test.dart`) | pass |
| D-033 | TC-D33-02 | unit | Unpicked draft (no people, profile currency, `EditorProblem.group` first), `pickGroup` keeps description/amount/notes and takes the group's people, payer, split; picked category kept; currency follows the group unless chosen; saved expenses stay in their group; a picked group saves with the right total (`expense_editor_controller_test.dart`) | pass |
| D-033 | TC-D33-03 | widget | Status bar: hero-coloured band with light icons once scrolled (light and dark), 8 dp fade, slivers after the hero (band stays, column leaves it to the scrim), Groups home / group page / Activity (`test/ui/hero_scrim_test.dart`, `final_qa_device_test.dart` S-255 rows) | pass |
| D-033 | TC-D33-04 | widget | Settings on Account: no gear, profile row, sign out asks then wipes and redirects (`auth_screens_test.dart`), Sync & storage row (`sync_storage_screen_test.dart`), Appearance sheet switches and saves, old `/account/appearance` link lands on Account (`appearance_screen_test.dart`), Security focus order (`focus_order_test.dart`); Activity filters one line (`activity_feed_test.dart`); search date range in one sheet (`search_screen_test.dart`); empty expense list without a second Add (`expense_list_detail_test.dart`, `groups_widget_test.dart`) | pass |
| D-033 | TC-D33-05 | golden | `expense_editor_golden_test.dart` (+ unpicked, picker, picker search) and `minimal_entry_golden_test.dart` (Groups home / group page / Activity scrolled, Activity, Account settings list, Notification settings, Security, Appearance sheet) light/dark × text 1.0/2.0 + 360×640, a11y guidelines in every state; widget sheet in `phase18_golden_test.dart`; real-font review | pass |
| D-033 | TC-D33-06 | e2e | emulator, DEV, `.qa` build: + → editor (no sheet), type first, picker search → test group, Save → row synced with the right group and total; Account: Appearance sheet Dark/System, Notifications page, Security page, widget sheet Hide amounts on/off, Sign out asks (cancelled), Delete account asks for DELETE (`integration_test/minimal_entry_test.dart`); before/after screenshots (`minimal_entry_capture_test.dart`, `tool/e2e/capture_minimal_entry.ps1`) | see report |
