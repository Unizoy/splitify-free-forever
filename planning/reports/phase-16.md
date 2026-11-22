# Phase 16 report — Recurring bills and search

- Date: 2026-11-22 · Branch: `phase/16-recurring-search` · Base: `origin/main` (phases 01–14; 17 merged in on the way)
- Commits: `97bce1b..HEAD` · Status: GATES_STATUS

## Summary

Any expense can now repeat (every week / 2 weeks / month / year, optional end date), offline: the repeat rule is a
synced record, and a nightly server job (00:10 IST) adds each copy as a normal expense with a deterministic id, so
a double run never duplicates and a 31st falls back to the month's last day. A repeating expense shows "Repeats ·
Every month" with Edit future copies / Stop repeating / Repeat again; copies carry a "Repeats" tag. A new search
screen (Groups and Activity heroes) finds expenses offline by description, notes, people and amount ("1,200",
"₹1,200.50"), with group, person, date and category filters.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 next-date rules shared by Dart and SQL | done | pre-built Dart rules + fixture; `tool/gen_recurring_sql.dart` → `150_recurring_vectors.test.sql` (52 vectors) |
| T2 migration + generator + cron | done | `0019_recurring.sql` (S-099 number) applied to dev; `151_recurring.test.sql` 49/49 |
| T3 repeat picker, future copies, Stop repeating, badge, offline sync | done | Drift v6 `recurring_templates`, `SyncEntity.recurring`, editor template mode, detail sheet |
| T4 offline search | done | FTS5 index kept in the write/pull transactions, parser, repository, `/search` screen |

## Features delivered

- #12 Recurring bills: create/edit/stop/resume offline; server copies with activity + notifications; month-end clamp; catch-up ≤ 31 per run.
- #34 Search: description, notes, member + profile names, amounts in any grouping, filters; works offline; SyncMarker on pending rows.

## Tests

- New tests: unit/data ~98 (parser 14, index 16, search repo 23, recurring repo 18, generator 3, controller 24) · widget 60 (repeat picker 8, editor 17, detail 14, search 17, activity 4) · golden 36 (9 scenes × light/dark × text 1.0/2.0) · integration 1 · SQL 101 (52 vectors + 49 behaviour) · migration 1
- Coverage: COVERAGE
- Test IDs now passing: TC-12-01, TC-12-02, TC-12-03, TC-12-04, TC-12-05, TC-34-01, TC-34-02
- Quarantined / skipped: none

## Gates

GATES_TABLE

## Decisions made (S-0xx)

S-170 data model (`expense_id`, template fields) · S-171 server-owned `next_date`, no back-fill · S-172 dispatch in
`apply_mutations` + `pull_changes` (later redefinitions must keep it) · S-173 generator rules · S-174 repeat UX ·
S-175 FTS index · S-176 query rules · S-177 search screen · S-178 Drift v6 · S-179 device test design · S-215
(coordinator) phases 16/18 in parallel with 15.

## Blockers (BLK-xxx)

None new.

## Learnings and skills added or changed

7 LEARNINGS lines (entity dispatch pattern, combined pgTAP dry run needs one plan, plpgsql `next`, FTS rebuild in
a Drift step + `schemaAt` seeding, `.first` hang in widget actions, Flutter `SearchController` name clash, PowerShell
.NET relative paths). No new skill.

## Owner actions

- None required. Optional: check a copy appears after 00:10 IST tomorrow for a template due then (cron `generate-recurring` is scheduled on dev).
- Reminder (not a blocker for dev): users on ISPs that block `*.supabase.co` need a Supabase custom domain/proxy before release.

## Next phase

19 (hardening) after 15 and 18 merge. Phase 18/19 migrations that redefine `apply_mutations` or `pull_changes`
must keep the 0019 lines (amendments added to their phase files).
