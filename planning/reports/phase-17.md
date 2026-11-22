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
- Coverage: GATE_COVERAGE
- Test IDs now passing: TC-33-01, TC-33-02, TC-22-01
- Moved: TC-22-02 → phase 18 (needs the X1 importer, S-184)

## Gates

GATES_TABLE

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
