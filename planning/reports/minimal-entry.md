# D-033 minimal pass — home, entry points, navigation shell, account & settings

- Date: 2026-11-27 · Branch: `feat/minimal-entry` · Base: `origin/feat/simple-add-expense` (D-032)
- Status: done · Decisions: S-340..S-349 · No PR/merge (the coordinator merges into `feat/simple-add-expense`)

## Summary

The + of the tab bar opens the one-screen editor at once; "With you and" on the editor picks the group or friend
(recent groups with covers, friends, search, a new name-only friend) and keeps what was typed; a group page opens it
with its group picked. Every hero page gets a hero-coloured band under the status bar once it scrolls (light icons
in both themes), also when its rows are slivers. The Account tab is the settings list itself (no gear, no
accordions); Appearance and the home-screen widget are sheets; Notification settings and Security are grouped
cards. Activity has one line of filter chips and compact rows; search picks a custom date range in one sheet; the
group page lost its duplicate empty-state "Add expense".

## Changes outside this area (call sites)

- `lib/features/expenses/application/expense_draft.dart`, `expense_editor_controller.dart`: no-group draft,
  `EditorProblem.group`, `pickGroup`, `carriedFrom` (needed by the picker).
- `lib/features/expenses/presentation/expense_routes.dart`: `startAddExpense` opens `/expense/new`.
- `lib/features/expenses/presentation/expense_list.dart`: empty state without its own Add button.
- `lib/app/app_route.dart`: every page in a `HeroScrim` (only shows on pages with a hero `OverlapColumn`).

## Tests

- Unit/widget: `default_split_routes_test.dart` (failing first on the old sheet), `expense_editor_controller_test.dart`
  (With you and), `with_picker_test.dart`, `test/ui/hero_scrim_test.dart`, settings/sign-out/sync/appearance tests,
  activity filters, search date range, empty list.
- Goldens: `expense_editor_*` (+unpicked, picker, picker search), `minimal_entry_*` (scrolled heroes, Activity,
  settings list, notifications, security, appearance; light/dark, text 2.0, 360×640, a11y guidelines in each).
- Device (emulator-5554, DEV, `.qa` build): `integration_test/minimal_entry_test.dart`; screenshots
  `splitify-artifacts/screenshots/minimal-entry-{before,after}-*.png` via `tool/e2e/capture_minimal_entry.ps1`.

## Not done / open

- The Friends tab's own "Add friend expense" button (friends area) still picks a friend in a sheet first (S-348).
