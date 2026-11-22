# Phase 19 report — Hardening and polish

- Date: 2026-11-22 · Branch: `phase/19-hardening` · Base: `origin/main` (01–18 + integrations PR #21 merged in)
- Commits: `59607ed..HEAD` · Status: {{STATUS}}

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
| T4 Visual polish | {{T4}} | real-font goldens reviewed for every changed screen; person rows stack at large text (no mid-word breaks); About screen |
| T5 State audit | done | checklist below |
| T6 Release build | done | signing from `secrets/release-key.properties` → `secrets/key.properties` → debug; R8 + shrink + keep rules; compressed native libs; per-ABI + universal phone APK; `tool/build_release.ps1` (S-201) |
| T7 Docs | done | README (features, 6 WebP screenshots), CHANGELOG, self-hosting guide (`supabase/README.md`), About & licences screen |
| T8 Full regression | {{T8}} | see Tests |
| S-167 group page slivers | done | `ExpenseListSliver` (S-204); perf re-run: {{PERF}} |
| S-160 real WorkManager run | {{WM}} | `tool/e2e/background_sync.ps1` |
| 18b hardening (D-025) | {{18B}} | |

## Tests

{{TESTS}}

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

{{GATES}}

## Decisions made (S-0xx)

S-200 housekeeping scope · S-201 release build · S-202 migration 0024 (check_fx) · S-203 advisors · S-204 group
page slivers · S-205 a11y sweep · S-206 About & privacy URL · S-207 Edge Function body cap{{MOREDEC}}

## Blockers (BLK-xxx)

None new.

## Learnings and skills added or changed

LEARNINGS phase 19 lines (MCP declines bulk deletes, regprocedure, tapify fix, heredoc backslashes, background
agents blocking, a11y sweep + pill fields, APK size, real-clock waits). `supabase-dev/scripts/tapify.py` fixed;
new `tool/e2e/run_suite.ps1`, `tool/e2e/background_sync.ps1`, `tool/build_release.ps1`.

## Owner actions

{{OWNER}}

## Next phase

20 — Release (owner checklist R first: prod project). Build with `tool/build_release.ps1` in the main checkout.
