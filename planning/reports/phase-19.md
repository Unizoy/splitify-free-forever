# Phase 19 report — Hardening and polish

- Date: 2026-11-22 · Branch: `phase/19-hardening` · Base: `origin/main` (01–18 + integrations PR #21 merged in)
- Commits: `59607ed..HEAD` · Status: done

## Summary

The backend is attack-tested: a 288-assertion pgTAP suite proves strangers, left members and anonymous callers
can't read or change other groups through any RPC or table, and migration 0022 closed the holes it found (padded
text, unbounded JSON, absurd dates, over-full groups, device-token floods, storage names with `..`). The app has
a privacy policy, an About & licences screen, release signing + R8, a lazily built group page, 48 dp text fields
everywhere TalkBack found small ones, and a full regression run of every automated suite.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Security | done | advisors re-checked (S-203); `190_attack` 288/288 + `191_housekeeping` 10/10 on dev; 0022 applied (payload/date/size guards, GROUP_FULL, 20 tokens per user, restrictive storage name policies, weekly `housekeeping` cron — join attempts, S-200); Edge Functions: 4 KB body cap, 8 new deno tests (53/53), send-push v3; secret scan of the whole history clean |
| T2 Privacy | done | `docs/PRIVACY.md` (data inventory, retention, deletion, third parties, payment bubble); TC-B1-06 (`024`) 29/29 on dev, TC-B1-05 deno + device delete-account run (T8) |
| T3 Accessibility | done | a11y sweep in every golden (tap targets + labels, light/dark, 1.0/2.0), token contrast pairs (existing), focus-order test, reduced-motion static test; fixes: pill text fields 48 dp (`pillInputDecoration`), split-editor amount fields 48 dp |
| T4 Visual polish | done | real-font goldens reviewed for every changed screen; person rows stack at large text (no mid-word breaks); About screen |
| T5 State audit | done | checklist below |
| T6 Release build | done | signing from `secrets/release-key.properties` → `secrets/key.properties` → debug; R8 + shrink + keep rules; compressed native libs; per-ABI + universal phone APK; `tool/build_release.ps1` (S-201) |
| T7 Docs | done | README (features, 6 WebP screenshots), CHANGELOG, self-hosting guide (`supabase/README.md`), About & licences screen |
| T8 Full regression | done (see Tests; S-209 harness fixes) | see Tests |
| S-167 group page slivers | done | `ExpenseListSliver` (S-204); perf re-run: opening a 2,000-expense group: worst build frame 264.8 → 55.4 ms, build avg 11.6 → 5.5 ms (lazy rows); raster numbers of this run are not comparable (emulator under load: load average 10.8, cold start 5.1–5.9 s vs 1.3 s in phase 15) → re-measure on an idle PC |
| S-160 real WorkManager run | done — WorkManager BackgroundWorker ran with the app in the background (one-off after the network came back + a forced job): "Worker result SUCCESS" ×2, the queued group reached the server | `tool/e2e/background_sync.ps1` |
| 18b hardening (D-025) | done (S-208): privacy/battery/overlay review passed; sign-out now switches the bubble off, Amazon shopping app off by default, PRIVACY.md section + data row; capture goldens pass the a11y sweep | |

## Tests

- New tests: SQL 298 (`190_attack` 288, `191_housekeeping` 10) · edge-fn 8 (deno) · widget/unit: a11y sweep inside
  every golden (TC-B3-04), focus order 4, reduced motion 3, About 4 + 4 goldens, app version 2, notifications
  refresh StateError · integration 1 (`background_sync_test.dart`, real WorkManager).
- Full regression (T8):
  - `flutter test` (all unit/widget/golden, after merging 18b): **3,088 passed, 0 failed**; coverage overall 95.3 %
    (presentation 95.3 · core 97.1 · data 93.8 · sync 99.5 · application 95.4 · domain 98.2 · money 100), all floors PASS.
  - pgTAP on dev, every file: 25 files, **948 assertions passed** after 0024 (incl. `190_attack` 288, `230_capture` 14 after
    0023); `031_validation` test 11 failed since phase 14 → fixed by 0024 (20/20).
  - deno (LF copy): fmt + lint clean, **53/53**.
  - Device (emulator-5554, dev project, DNS pin): auth_profile, groups, sync_offline, expenses_offline_sync,
    balances_week, history_comments, currencies, receipts_offline_upload, recurring_search, notifications,
    extras_import_widget, app_smoke — **12/12 pass** (3 needed harness fixes, S-209); airplane e2e A1–A3, K1–K2, C1
    **pass** (K1 is killed on purpose); background_sync W1 **pass** ×2; perf drive pass (numbers above);
    app lock TC-X2-02 **pass** (after a resume-wait fix), fake UPI TC-26-02 + TC-26-03 **pass**, payment bubble
    e2e (18b `capture_e2e.ps1`: TC-X4-02…07, 23 checks + integration test) **pass** after the S-208 change.
  - Not re-run: `ui_review_*` and `scenarios/*` (screen-holding capture harnesses, no assertions; their screens are
    covered by goldens + real-font review); manual-only: TC-B1-09 (email from the owner domain), TC-26-05 (real UPI
    app), real-phone payment-bubble checklist (18b report).
- Quarantined / skipped: none new.

## T4 — UI review (real-font goldens + emulator screenshots)

Every golden screen/state was re-rendered with real fonts (`PLATFORM_GOLDENS=1`) for the files this phase touched,
and the a11y sweep checked all of them. Scores (Atlys feel · type · layout · colour · signature · polish · states):

| Screen | Light | Dark | 200 % | Notes |
| --- | --- | --- | --- | --- |
| About & licences (new) | 9·9·9·9·9·9·9 | 9·9·9·9·9·9·9 | 9·9·9·9·9·8·9 | cover hero + glass brand card + overlap sheet, dashed rows |
| Expense detail (split rows) | 9·9·9·9·9·9·9 | 9 | 9 (was 7: "Meht a" broke mid-word) | amounts stack under names at large text |
| Comment composer / search / friends search | 9·9·9·9·8·9·9 | 9 | 9 | fields 48 dp, text centred |
| Split editor amount fields | 9·9·9·9·8·9·9 | 9 | 9 | 48 dp |
| Groups home (device, offline) | 9·9·9·9·9·9·9 | 9 | — | wallet card + marker + offline banner |
| Sync & storage (device, offline) | 9·9·9·9·8·9·9 | 9 | — | |
| Payment bubble screens (18b goldens) | 9·9·9·9·8·9·9 | 9 | 9 | settings / add screen / sheet / hero pill real-font goldens; device bubble light, dark and 200 % (`phase-18b\bubble-*`) |

## T5 — error / empty / loading / offline state audit

| Screen | Empty | Loading | Error | Offline / unsynced |
| --- | --- | --- | --- | --- |
| Groups home | ✓ (golden `screen_groups`) | ✓ stacked-cards loader | ✓ widget test | ✓ card marker, wallet marker |
| Group detail · Expenses | ✓ `expense_expense_list_empty` | ✓ `expense_expense_list_loading` | ✓ load-error state | ✓ row markers, group marker |
| Group detail · Balances / Totals | ✓ `balances_tab_empty` | ✓ | ✓ | ✓ "not synced yet" (rule 3) |
| Expense editor / detail | n/a | ✓ | ✓ validation copy | ✓ `expense_expense_detail_unsynced` |
| Friends / friend page | ✓ `friends_friends_empty` | ✓ | ✓ | ✓ markers |
| Activity / notifications | ✓ `notifications_empty` | ✓ | ✓ | ✓ offline banner (widget tests) |
| Search | ✓ `search_idle`, `search_no_matches` | ✓ | n/a (local) | works offline (FTS) |
| Insights | ✓ `insights_empty`, `insights_no_groups` | ✓ | n/a (local) | local data |
| Sync & storage | ✓ synced | ✓ syncing | ✓ issues / refused | ✓ offline, uploads waiting/skipped |
| History / deleted items | ✓ `history_pending_empty`, `history_deleted_items_empty` | ✓ | ✓ | ✓ `history_offline` |
| Import | ✓ file step | ✓ | ✓ `phase18_import_file_error` | ✓ offline import through the outbox |
| Settle up / UPI | ✓ `balances_settle_up_nothing_owed` | ✓ | ✓ no UPI app sheet | ✓ marker |
| Account / profile / delete | n/a | ✓ | ✓ | ✓ delete says "Needs internet" |
| Join / invite | n/a | ✓ | ✓ wrong code, rate limit | ✓ "needs internet" |
| About | n/a | n/a | ✓ link failed snackbar | static |

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | `dart format --set-exit-if-changed` clean, `flutter analyze` 0 errors/warnings (infos only), `dart run tool/guards.dart` OK, history secret scan clean |
| G2 Tests | PASS | 3,088 passed; coverage 95.3 % (all floors) |
| G3 Backend | PASS | 0022 + 0024 applied on dev; pgTAP 25 files 948/948 after 0024; advisors: no new finding (S-203); deno 53/53; send-push v3 deployed |
| G4 Build | PASS | debug APK; release split-per-ABI 30.0 / 33.4 / 35.6 MB (arm32 / arm64 / x86_64, before native-lib compression), universal phone APK **31.9 MB** (< 40 MB), signed with a throwaway key from `secrets/key.properties` (apksigner: CN=Throwaway Test; key deleted after), debug-key fallback verified (CN=Android Debug) |
| G5 Device | PASS | see T8 list; screenshots `…\splitify-artifacts\phase-19\` (airplane-*, conflict-*), logs `it-*.log`, `background-sync*.txt`, `perf-drive.log` |
| G6 Docs | PASS | phase boxes, PROGRESS, catalog (TC-SEC-01…03, TC-B3-04…07, TC-REL-01, TC-27-21/22), decisions S-200…S-209, LEARNINGS, this report |

## Decisions made (S-0xx)

S-200 housekeeping scope · S-201 release build · S-202 migration 0024 (check_fx) · S-203 advisors · S-204 group
page slivers · S-205 a11y sweep · S-206 About & privacy URL · S-207 Edge Function body cap · S-208 payment-bubble hardening · S-209 regression harness fixes

## Blockers (BLK-xxx)

None new.

## Learnings and skills added or changed

LEARNINGS phase 19 lines (MCP declines bulk deletes, regprocedure, tapify fix, heredoc backslashes, background
agents blocking, a11y sweep + pill fields, APK size, real-clock waits). `supabase-dev/scripts/tapify.py` fixed;
new `tool/e2e/run_suite.ps1`, `tool/e2e/background_sync.ps1`, `tool/build_release.ps1`.

## Owner actions

- **Release signing (needed for Google sign-in on release builds):** register the release key's SHA-1 (from
  `secrets/splitify-release.jks`) for the Android OAuth client in Google Cloud and in the Firebase app; until then
  Google sign-in works only on debug-key builds.
- **OAuth consent screen:** home page `https://github.com/Unizoy/splitify-free-forever`, privacy policy
  `https://github.com/Unizoy/splitify-free-forever/blob/main/docs/PRIVACY.md`.
- Optional: Supabase Auth → enable leaked-password protection (Pro plan; only the debug dev login uses passwords).
- Optional: run the housekeeping snippet in `supabase/README.md` now and then (mutation log, cron history; S-200).
- Before release: users on ISPs that block `*.supabase.co` need a Supabase custom domain/proxy.
- Re-measure performance on an idle PC (`tool/e2e/perf.ps1 -Phase 19`).

## Next phase

20 — Release (owner checklist R first: prod project). Build with `tool/build_release.ps1` in the main checkout.
