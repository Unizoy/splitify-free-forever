# Phase 08 report — Expenses and split types (#5–#9, #13, #35)

- Date: 2026-11-22 · Branch: `phase/08-expenses-splits` · Base: `origin/phase/06-sync-engine` (stacked); `origin/phase/07-groups-members` merged in (a064050), then `origin/main` with phase 07 final (8fd7bef)
- Commits: `f7292c8..HEAD` · Status: done

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
| T7 Tests | done | widget + golden for every editor state; integration on the emulator: one expense of each split type offline → sync → server rows, `group_balances` nets and e2e-b's view equal the phone (S-087) |

## Features delivered

- #5–#9 equal, exact, percent, shares, adjustment: editor + engine + storage (`split_kind`, `split_values`, shares).
- #13 expense details: description, amount, date, category (30 keys), notes; detail screen; comments/history are
  placeholders until phase 12.
- #35 default split per group: editor, prefill, fallback to equal when members change.

## Tests

- New tests: unit/controller 57 (74 in the four application test files) · widget 88 · golden 76 (19 states × light/dark × text 1.0/2.0) · integration 2
  files (T7 offline → sync → server/other member; device UI review) · SQL 0 new (031 re-run on dev)
- Coverage (full run after the phase 07 merge, 1041 tests): overall 95.9 % · money 100 % · sync 100 % · domain 100 % ·
  data 87.6 % · application 98.0 % · presentation 95.5 %
- Test IDs now passing: TC-5..9-03, TC-5..9-04, TC-13-01, TC-13-02, TC-35-01, TC-35-02; TC-5..9-06 (device)
- Quarantined / skipped: none

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | after the merge: `dart format` 0 changed; `flutter analyze --no-fatal-infos` 0 errors / 0 warnings (infos only, repo-wide style); guards OK |
| G2 Tests | PASS | `flutter test --coverage --exclude-tags device,needs-owner,quarantine`: 1043 pass (after the main merge); `coverage_check` all floors pass |
| G3 Backend | PASS (no migration needed) | 0001–0010 on dev (`list_migrations`); `031_validation.test.sql` 20/20 on dev in BEGIN…ROLLBACK |
| G4 Build | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` (before and after the merge) |
| G5 Device | PASS | `expenses_offline_sync_test.dart` 1/1 on emulator-5554 (before and after the phase 07 merge, `PIN_HOST_IP`); UI review `ui_review_expenses_test.dart` 15 screens × light/dark/200 %, scores below; screenshots: `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-08\` |
| G6 Docs | PASS | phase boxes, test catalog, S-082..S-088, LEARNINGS, this report, PROGRESS |

### UI review scores (D-018, ≥ 8 required; light, dark and 200 % text)

Reviewed on the emulator (`ui_review_expenses_test.dart`, 15 screens × light / dark / 200 %) and in real-font goldens.

| Screen | Atlys feel | Typography | Layout | Colour | Signature | Polish | States |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Editor · Amount (keypad) | 9 | 9 | 9 | 9 | 8 | 9 | 9 |
| Editor · Paid by | 8 | 9 | 8 | 9 | 8 | 8 | 8 |
| Editor · Split (5 kinds + error) | 8 | 9 | 8 | 9 | 8 | 8 | 9 |
| Editor · Details | 8 | 9 | 8 | 9 | 8 | 8 | 8 |
| Editor · Review | 9 | 9 | 9 | 9 | 8 | 9 | 8 |
| Expense list (group Expenses tab) | 9 | 9 | 9 | 9 | 9 | 9 | 9 |
| Expense detail | 9 | 9 | 9 | 9 | 9 | 9 | 8 |
| Default split | 8 | 9 | 8 | 9 | 8 | 8 | 8 |

Fixed during review: ₹ tofu in the serif hero (S-085), amounts not right-aligned, "Y" avatar initials for "You",
year-long list captions, outline "Next" next to a pill, step labels touching at 200 %, split symbols wrapping at 200 %.
Accepted: at 200 % text the sticky bar stacks Save and Next (~20 % of the height; content scrolls) and the
StepHeader labels shrink to fit (phase 02 component). Note: the last capture run used `-Hold 12`, which is too short
for `capture_markers.ps1` — a few `-text200` files show the next screen; the review itself used the first run
(own markers, all correct) plus real-font goldens. Use the default hold (30 s).

## Decisions made (S-0xx)

S-080 split participants, S-081 default split kinds/fallback (earlier session); S-082 stepper bar and save flow;
S-083 routes and the nav "+" group picker; S-084 split-kind symbols, whole-share stepper, phase-10/14 stubs;
S-085 serif ₹ fallback; S-086 device UI review via marked integration test; S-087 T7 test design; S-088 no retry
for local-DB editor providers.

## Blockers (BLK-xxx)

None new. Environment note: on this PC's ISP the emulator's DNS blocks `*.supabase.co`; device tests need
`--dart-define=PIN_HOST_IP=<ip resolved on the PC>` (S-214 helper `integration_test/support/net_pin.dart`).

## Merge with phase 07

Merged `origin/phase/07-groups-members` (also carrying the 05/06 follow-ups): the group detail's Expenses tab now
hosts `ExpenseList`, its amber "Add expense" opens the stepper, group settings got a "Default split" row. Kept
phase 07's `syncOfflineProvider` and `AppIcons.edit` (dropped my duplicates), switched my device tests to the merged
`net_pin.dart` and `capture_markers.ps1`. Removed `test/goldens/failures/*` that the phase 07 commit had added and
git-ignored that folder. Then merged `origin/main` (phase 07 final, PR #9): the restructured group settings screen
got the "Default split" row again; `GroupExpensesTab` hosts `ExpenseList`, `_ActionBar` "Add expense" opens the
stepper. Gates re-run after that merge: format 0 changed, analyze 0 errors/warnings, guards OK, 1043 tests pass,
coverage floors pass, debug APK builds.

## Learnings and skills added or changed

Seven `[phase 08]` lines in LEARNINGS (serif ₹, Riverpod 3 family overrides + retry, PopScope vs own pops, Row
alignment, signed-in screenshots, parallel agents and sqlite3.dll, emulator DNS block). `ui-review` SKILL.md: section
on capturing signed-in screens with `UI-CAPTURE` markers + `capture_markers.ps1`.

## Owner actions

None.

## Next phase

09 — Balances, payments, activity, totals. `ExpenseList` is a plain column; phase 09 adds payment rows to it.
`ExpenseView.myNet` gives per-expense lent/borrowed; balances must use the server/local nets.
