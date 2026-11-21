# Phase 08 report — Expenses and split types (#5–#9, #13, #35)

- Date: 2026-11-22 · Branch: `phase/08-expenses-splits` · Base: `origin/phase/06-sync-engine` (stacked; phase 07 merged in)
- Commits: `f7292c8..HEAD` · Status: STATUS_PLACEHOLDER

## Summary

People can now add an expense in one screen: type the amount on the keypad (sums like `450+120` work), a
description, and Save — you paid, split by the group's default. The five-step editor (Amount · Paid by · Split ·
Details · Review) covers all five split types with a live footer and friendly errors, categories, date and notes.
The group's Expenses tab lists expenses by month with "you lent / you borrowed / not involved" and the "not synced
yet" marker; the detail screen shows who paid and who owes, with edit and delete (undo). Groups can set a default
split. Everything works offline and syncs.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Add-expense stepper | done | `ExpenseEditorScreen` (`/expense/new?group=`, `/expense/:id/edit`), StepHeader (tappable steps), keypad on `AmountExpression` (`KeypadInput`), currency chip (group currency; picker → phase 14), fast-path Save on every step (S-082), "saved offline" pill |
| T2 Split editor | done | `SplitKindPicker` `= · 1.23 · % · 1:2 · ±` (S-084), `SplitMemberRows` per kind, live footer in the sticky bar, Save disabled on error; single payer picker ("Multiple people" → phase 10) |
| T3 Details | done | `CategoryPicker` (8 parents → subs), Today / Yesterday / calendar sheet (534), notes; Review sentence "Paid by **you** and split **equally between 3 people**" with tappable parts |
| T4 List + detail | done | `ExpenseList(groupId)` (month headers, AmountRow, SyncMarker, empty / loading / error), `ExpenseDetailScreen` (cover hero, serif amount, paid / split rows, details, history + comments placeholders) |
| T5 Edit / delete | done | edit reopens the same editor state; delete is soft with an Undo snackbar (restore) |
| T6 Default split | done | `DefaultSplitScreen` (`/groups/:id/default-split`, equal / percent / shares), prefill + fallback (S-081) |
| T7 Tests | T7_PLACEHOLDER | |

## Features delivered

- #5–#9 equal, exact, percent, shares, adjustment: editor + engine + storage (`split_kind`, `split_values`, shares).
- #13 expense details: description, amount, date, category (30 keys), notes; detail screen; comments/history are
  placeholders until phase 12.
- #35 default split per group: editor, prefill, fallback to equal when members change.

## Tests

- New tests: unit/controller 74 · widget 88 · golden 76 (19 states × light/dark × text 1.0/2.0) · integration 2
  files (T7 sync, device UI review) · SQL 0 new (031 re-run on dev)
- Coverage (full run): overall 95.8 % · money 100 % · sync 100 % · domain 100 % · data 85.0 % · application 99.8 % ·
  presentation 95.2 %
- Test IDs now passing: TC-5..9-03, TC-5..9-04, TC-13-01, TC-13-02, TC-35-01, TC-35-02; TC-5..9-06 TC6_PLACEHOLDER
- Quarantined / skipped: none

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | `dart format` clean; `flutter analyze` 0 errors / 0 warnings (infos only, repo-wide style); guards OK |
| G2 Tests | PASS | `flutter test --coverage --exclude-tags device,needs-owner,quarantine`: all pass; `coverage_check` all floors pass |
| G3 Backend | PASS (no migration needed) | 0001–0010 on dev (`list_migrations`); `031_validation.test.sql` 20/20 on dev in BEGIN…ROLLBACK |
| G4 Build | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` |
| G5 Device | G5_PLACEHOLDER | screenshots: `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-08\` |
| G6 Docs | PASS | phase boxes, test catalog, S-082..S-088, LEARNINGS, this report, PROGRESS |

### UI review scores (D-018, ≥ 8 required; light, dark and 200 % text)

SCORES_PLACEHOLDER

## Decisions made (S-0xx)

S-080 split participants, S-081 default split kinds/fallback (earlier session); S-082 stepper bar and save flow;
S-083 routes and the nav "+" group picker; S-084 split-kind symbols, whole-share stepper, phase-10/14 stubs;
S-085 serif ₹ fallback; S-086 device UI review via marked integration test; S-087 T7 test design; S-088 no retry
for local-DB editor providers.

## Blockers (BLK-xxx)

None new.

## Learnings and skills added or changed

Six `[phase 08]` lines in LEARNINGS (serif ₹, Riverpod 3 family overrides + retry, PopScope vs own pops, Row
alignment, signed-in screenshots, parallel agents and sqlite3.dll). `ui-review` skill: new
`scripts/capture_marked.ps1` + SKILL.md section for signed-in screens.

## Owner actions

None.

## Next phase

09 — Balances, payments, activity, totals. `ExpenseList` is a plain column; phase 09 adds payment rows to it.
`ExpenseView.myNet` gives per-expense lent/borrowed; balances must use the server/local nets.
