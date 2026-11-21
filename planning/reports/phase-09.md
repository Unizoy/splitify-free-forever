# Phase 09 report — Balances, payments, activity, totals (#15, #18, #21, #25)

- Date: 2026-11-22 · Branch: `phase/09-balances-payments` · Base: `origin/main` (phases 01–08, 770690a)
- Commits: `9710ba5..HEAD` · Status: done

## Summary

The core loop is complete: every group shows who owes whom per currency with a Settle button on each debt, and
"Settle up" records a payment (prefilled with what is owed, method, date, note) that works offline and syncs.
Payments show in the Expenses tab and have their own detail/edit/delete. The Groups tab glass card, the group
cards (unsettled first), the group status pill and the Account wallet show real balances; the Activity tab and a
per-group feed show every change with my unsynced ones marked. The Totals tab shows what a group spent. After
each sync the phone checks its numbers against the server's (`group_balances`, `my_overview`) and logs any
difference (server wins). A scripted "week in Goa" with three people settles to zero on the emulator.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Balances tab | done | `BalancesTab`: OverlapBanner (owed / owe / mixed / settled), per-currency sections, "Who owes whom" rows with Settle, simplified view + "Show original debts" when the group has simplify on (toggle UI is phase 11), everyone's net; Remind is phase 13 |
| T2 Settle up + payments | done | `SettleUpScreen` (`/settle`, `/payment/:id/edit`): people card with swap + picker, amount prefilled, "Pay all", ArcGauge %, method chips, DateChips, note, amber Record payment; group and home settle pickers; `PaymentRow` in the Expenses tab; `PaymentDetailScreen` with edit and delete (undo) (S-101, S-102, S-106) |
| T3 Checksum | done | `BalanceChecker` after every sync: `group_balances` (open group) and `my_overview` (overall) vs local, FNV checksum of nets + pairs + simplified; mismatch → WARNING log + server numbers shown (S-100); TC-15-04 green on the device |
| T4 Activity | done | Activity tab (all groups, day headers, filter chips, pending own changes with SyncMarker, tap → target), group feed `/groups/:id/activity` + "Recent activity" under the Expenses tab, ARB sentence for all 27 types (S-104) |
| T5 Totals | done | `TotalsTab`: This month · All time, total spent per currency (IOUs and payments excluded), my share / I paid, each person's paid · share, "See charts" → phase 17 (S-105) |
| T6 Overall balances | done | Groups home GlassCard (per-currency, status, "N groups · X people owe you", Settle up, marker), group cards + sort, group status pill, Account WalletCard + "Balances by group" sheet, Account stat cards from local data (S-103, S-105) |
| T7 Week in Goa E2E | done | `integration_test/balances_week_test.dart`: A on the app, B and C via the harness, 7 expenses (all 5 split types, 3 payers), 2 payments (one through the Settle up UI) → phone = server = independent oracle (nets + pairs) → T3 check matches → everyone settles → all zero, tab says "You're all settled" |

## Features delivered

- #15 Group balances: tab, banner, pairs/simplified, nets, Settle; status pill; overall card and wallet.
- #18 Activity feed: tab + group feed, filters, unsynced markers, navigation, 27 sentence templates.
- #21 Group totals: per currency, per person, month / all time.
- #25 Record a payment: settle up, partial payments, any method, edit / delete / restore, rows and detail.

## Tests

- New tests: unit/application/data 157 (11 files) · widget 116 (5 files) · golden 60 (`balances_golden_test.dart`,
  15 states × light/dark × text 1.0/2.0) · integration 1 (week in Goa, also the device UI review) · SQL 12
  (`090_payments_activity.test.sql`)
- Coverage: see G2 below
- Test IDs now passing: TC-15-03, TC-15-04, TC-18-02, TC-18-03 (new row), TC-21-01, TC-21-02, TC-25-02, TC-25-03,
  TC-14-02 (multi-currency sections); TC-18-01 now also asserts payment activity (still partial: member/comment)
- Quarantined / skipped: none

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | GATE_G1 | `dart format --set-exit-if-changed lib test integration_test tool`; `flutter analyze --no-fatal-infos` 0 errors / 0 warnings; `dart run tool/guards.dart` OK |
| G2 Tests | GATE_G2 | `flutter test --coverage --exclude-tags device,needs-owner,quarantine --concurrency=1`; `dart run tool/coverage_check.dart` |
| G3 Backend | PASS (no migration) | 0012 not needed (S-107); dev migrations 0001–0010, 0013, 0015 present (other phases); `090_payments_activity` 12/12 on dev in BEGIN…ROLLBACK; security advisors: no new findings (existing SECURITY DEFINER RPC warnings are the intended API, leaked-password protection is an owner setting) |
| G4 Build | GATE_G4 | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` |
| G5 Device | PASS | `balances_week_test.dart` on emulator-5554 (`PIN_HOST_IP`): 1/1 (35 s), again 1/1 as the capture run (`UI_HOLD=30`, 11 screens × light/dark/200 %) GATE_G5_RECAPTURE; screenshots `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-09\` |
| G6 Docs | PASS | phase boxes, test catalog, S-100..S-107, LEARNINGS, this report, PROGRESS |

### UI review scores (D-018, ≥ 8 required; light, dark and 200 % text, real data on the emulator + real-font goldens)

| Screen | Atlys feel | Typography | Layout | Colour | Signature | Polish | States |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Group · Balances tab | 9 | 9 | 9 | 9 | 9 | 9 | 9 |
| Group · Totals tab | 8 | 9 | 9 | 9 | 8 | 8 | 8 |
| Group · Expenses with payments + recent activity | 9 | 9 | 9 | 9 | 9 | 9 | 9 |
| Group hero status pill | 9 | 9 | 8 | 9 | 9 | 8 | 9 |
| Settle up (gauge / nothing owed) | 9 | 9 | 9 | 9 | 9 | 8 | 9 |
| Settle pickers (group, home) | 8 | 9 | 9 | 9 | 8 | 9 | 9 |
| Payment detail | 9 | 9 | 9 | 9 | 9 | 9 | 8 |
| Activity tab / group feed | 8 | 9 | 9 | 9 | 8 | 9 | 9 |
| Groups home (glass card, cards) | 9 | 9 | 9 | 9 | 9 | 9 | 9 |
| Account (wallet, stats, breakdown) | 9 | 9 | 8 | 9 | 9 | 8 | 8 |

Fixed during review: "You owes Rahul" (new `balYouOwePerson`), own activity avatar showed "Y" (now the member's
initials), overlapping pair-avatar initials, stat-grid amounts breaking mid-number and touching the next column
(FittedBox + column gap in `StatGrid`), Totals "Your share" breaking mid-number at 200 %, the hero status pill
ballooning at 200 % (clamped to the serif scale 1.6), "You recorded a payment from you to Asha" → "You paid Asha",
settle amount field not following swap / person changes. Accepted: the ArcGauge knob is a short bar (phase 02
component, matches 646); at 200 % the sticky bar stacks Add expense and Settle up (phase 07 behaviour).

## Decisions made (S-0xx)

S-100 balance display + after-sync check; S-101 routes and group feed placement; S-102 settle-up form and pickers;
S-103 multi-currency statuses and ordering; S-104 activity sentences, pending items, filters, taps; S-105 totals
and account stats; S-106 payment rows and detail; S-107 no migration.

## Blockers (BLK-xxx)

None.

## Learnings and skills added or changed

Six `[phase 09]` lines in LEARNINGS (heredoc edits → scratchpad scripts, Drift multi-table watch, the two
`currentUserIdProvider`s, pgTAP role + temp-table grant, notifier-driven text fields, the multi-user money E2E
pattern that doubles as the device UI review).

## Owner actions

None. (Known from earlier phases: users on ISPs that block `*.supabase.co` need a custom domain/proxy before release.)

## Next phase

10 — Multiple payers, IOU, receipt photos (10, 11 and 12 can follow in parallel). Notes for them: payments are
rows in `ExpenseList` (`PaymentRow`) and `groupPaymentViewsProvider`; balances come from
`groupBalancesProvider` / `myBalancesProvider` (local + server check); totals already skip `kind = 'iou'`;
phase 11 wires the simplify toggle (the Balances tab already honours `simplify_debts` and has "Show original
debts"), UPI on the Settle up screen, and Celebration; phase 12 replaces the history/comments placeholders on
the payment detail; phase 13 adds Remind to `TransferRow`.
