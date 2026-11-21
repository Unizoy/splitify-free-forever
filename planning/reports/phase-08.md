# Phase 08 report - Expenses and split types (PARTIAL)

- Date: 2026-11-21 · Branch: `phase/08-expenses-splits` · Base: `phase/06-sync-engine` (c902a76, stacked; phase 07 built in parallel)
- Status: in-progress - stopped at the owner deadline (~20 min). Logic layer done and green; screens not built.

## Summary

The expense editor's brain exists and is tested: split drafts for all five split types (equal, exact, percent,
shares, adjust) with live remaining/over values and engine error codes, the add/edit draft with validation and the
repository row, the editor controller (new from group default split / reopen saved expense), list/detail view
providers, delete/restore actions and the default-split controller. No screens, routes or ARB strings yet.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Add-expense stepper | open | `ExpenseEditorController` (`expenseEditorProvider((groupId:, expenseId:))`) ready; screen + keypad not built |
| T2 Split editor | logic done, UI open | `SplitDraft` (switch keeps chosen people, values reset per 05 §4), `check(total)` -> `SplitReady`/`SplitInvalid(code, amount)` |
| T3 Details | logic done, UI open | `ExpenseCategories` (30 keys, parent -> sub, last-used suggested), date/notes in draft |
| T4 Expense list + detail | providers done, UI open | `groupExpenseViewsProvider(groupId)`, `expenseViewProvider(id)`, `ExpenseView.myNet/involved/unsynced` |
| T5 Edit / delete | logic done, UI open | edit reopens from `split_kind` + `split_values` + shares keys; `ExpenseActions.delete/restore` (soft) |
| T6 Default split | logic done, UI open | `DefaultSplit` decode/resolve/fallback, `DefaultSplitController.save()` -> groups repository |
| T7 Tests | partial | unit only; widget/golden for editor states open; device integration SKIPPED (deferred, emulator busy) |

## Tests

- New: unit 24 (`test/core/money/scaled_input_test.dart`, `test/features/expenses/application/split_draft_test.dart`), all pass.
- Logic for TC-5..9-03, TC-13-01, TC-35-01 covered at unit level; TC-5..9-04, TC-13-02, TC-35-02 (widget/golden) open.
- Controller tests with in-memory Drift (editor build/save, default split save) not written yet.

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS for new files (format, guards OK, 0 analyzer errors/warnings on touched paths) | full-repo analyze not re-run |
| G2 Tests | PARTIAL | new unit tests pass; full `flutter test` + coverage_check NOT run |
| G3 Backend | not needed | no migration (none added) |
| G4 Build | NOT RUN | |
| G5 Device | SKIPPED | emulator owned by another agent |
| G6 Docs | partial | this report, PROGRESS row, S-080/S-081, learnings |

## Decisions made

S-080 split participants model; S-081 default split kinds and fallback.

## Next session (resume phase 08)

1. Screens in `lib/features/expenses/presentation/`: stepper `/expense/new?group=` and `/expense/:id/edit`
   (StepHeader, amount keypad -> `AmountExpression`, OptionTile payer, SegmentedPill split row, IconChip categories),
   `ExpenseList(groupId)` widget for phase 07's group detail, `/expense/:id` detail, default-split screen.
2. Routes additive in `router.dart` (one spread line + import); ARB keys inserted near the top of `app_en.arb` to
   avoid conflicts with phase 07's appended keys.
3. Controller tests, widget + golden tests (light/dark/2.0), full gates, then tick boxes.
