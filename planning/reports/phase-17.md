# Phase 17 report — Charts and CSV export (#33, #22)

- Date: 2026-11-22 · Branch: `phase/17-charts-export` · Base: `origin/main` (phases 01–10, 12–14); phase 11 merged
  in before shipping
- Commits: `fa8be91..HEAD` · Status: done

## Summary

A new **Insights** screen (from the Account "Your spending" card and the group Totals tab "See charts") shows where
the money goes: Group / Me pill, a group picker (Me also offers "All groups and friends"), a donut by category with
full-width legend chips (tap a chip or slice to see its amount and share), and 12 month bars (tap a bar for that
month). Everything is in one main currency; records in other currencies count through their saved conversion, the
rest are left out with a note ("1 expense in another currency is left out…"). Empty, all-unconverted, no-groups,
loading and error states are covered. **Export CSV** (Group settings and the Totals tab) builds the group's CSV on the
phone (works offline: every expense, loan and payment, deleted ones flagged, per-currency totals, BOM) and opens the
Android share sheet with `splitify-<group>-<date>.csv`.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Aggregations | done | Pre-built domain (S-090) + ledger mapping `insights_providers.dart` (Drift rows → `InsightExpense`, my member ids, picker, default group, main currency, 12 local months) (S-180) |
| T2 Insights screen | done | `/insights?mode=&group=`; SegmentedPill, picker sheet, fl_chart donut + legend chips, month bars with per-bar tap targets, states; DotMatrixCard + Totals link wired (S-181, S-182) |
| T3 CSV export | done | Pre-built writer (S-091, S-092) + `ExportReads.loadExport` (deleted rows too), `csvOfExport`, `GroupExporter`, share_plus sharer, settings + Totals rows (S-183) |

## Features delivered

- #33 Simple charts: donut by category + 12-month bars, Group or Me, main currency via saved conversions,
  unconverted records excluded with a note.
- #22 Export (CSV): Group settings / Totals → share sheet; TC-22-02 round trip moves to phase 18 with the importer
  (S-184).

## Tests

- New tests: unit/widget 90 (`insights_providers_test`, `group_export_test`, `insights_screen_test`,
  `insights_routes_test`, `export_action_test`, totals tab update) · golden 32 (`insights_golden_test.dart`: 8
  scenarios × light/dark × 1.0/2.0) + 2 regenerated (Totals tab) · integration 1 (`ui_review_insights_test.dart`)
- Coverage: overall 96.7 % · money 100 % · sync 100 % · domain 100 % · data 92.9 % · application 97.2 % ·
  presentation 96.6 % (new files: insights_providers/export_reads 100 %, group_export 91.8 %, insights screen 100 %,
  charts 97 %)
- Test IDs now passing: TC-33-01, TC-33-02, TC-22-01
- Moved: TC-22-02 → phase 18 (needs the X1 importer, S-184)

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | `dart format` 0 changes (480 files), `flutter analyze` 0 errors/warnings (infos only, as on main), guards OK |
| G2 Tests | PASS | full suite after the phase 11 merge: 2,467 passed + the 3 merge casualties fixed and re-run green (2 phase 11 group-settings goldens regenerated for the Export row, 1 lazy-list scroll in `groups_widget_test`); `coverage_check` all floors PASS |
| G3 Backend | N/A | no migration, RPC or Edge Function in this phase (S-185) |
| G4 Build | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` |
| G5 Device | PASS | `integration_test/ui_review_insights_test.dart` on emulator-5554 (with the lock): 9 screens × light/dark/200 % + real share sheet opened with `splitify-goa-trip-….csv`; screenshots `splitify-artifacts\phase-17\` |
| G6 Docs | PASS | phase ticks, test catalog, S-180..185, phase 18 amendment, LEARNINGS, PROGRESS, this report |

UI review (ui-review rubric, light and dark, emulator + real-font goldens): Insights 9/10 (hierarchy: serif title,
caps labels, white cards with hairline border; donut in category colours; legend chips never cut at 200 %; bars
with soft track, selected month solid), picker sheet 9/10, empty/convert/no-groups states 8/10 (plain EmptyState,
no action button), Totals links 9/10, Group settings row 9/10. Every tap target ≥ 48 dp and labelled (bars carry
"November 2026: ₹5,500").

## Decisions made (S-0xx)

S-180 Insights scopes and main currency · S-181 legend chips as full-width pills, bar tap overlay · S-182 integer
percentages, doubles only for chart geometry · S-183 CSV export entry points, cells, file name, share sheet only ·
S-184 TC-22-02 with phase 18 (amendment in its phase file) · S-185 no migration / no Drift change (0020 unused).

## Blockers (BLK-xxx)

None.

## Learnings and skills added or changed

Five LEARNINGS lines (alchemist tall-frame taps, FittedBox + maxLines clipping, sheet goldens, accessible fl_chart
bars, share_plus in-memory files).

## Owner actions

None required. Optional: open Account → "Your spending" and a group's Totals → "See charts" / "Export CSV" to try it.

## Next phase

18 (Splitwise import, app lock, home widget): its importer should also read this export (S-184 amendment) and own
TC-22-02.
