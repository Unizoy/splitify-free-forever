# Phase 16 — Recurring bills and search (#12, #34)

- Depends on: 15 · Owner setup: 00 · Branch: `phase/16-recurring-search`
- Read first: `08-feature-specs.md` #12 #34, `03-backend.md` §6.

## Tasks

- [ ] T1 Shared next-date rules: `recurring_vectors.json` (weekly, fortnightly, monthly with 29/30/31 anchors
      across Feb/leap years, yearly Feb 29) consumed by Dart and pgTAP.
- [ ] T2 Migration 0012: `recurring_templates` (synced entity in `apply_mutations`/`pull_changes`), SQL generator
      function + cron `generate-recurring` (Asia/Kolkata date, deterministic ids, activity, month-end clamp).
      pgTAP: idempotent double run, clamp, ends_on, stop.
- [ ] T3 Repeat picker on expense details + template edit (future copies) + "Stop repeating"; recurring badge on
      generated copies; offline creation of templates syncs.
- [ ] T4 Search: fill FTS table on writes/pulls (description, notes, member names, amount text in plain and
      grouped forms), query parser (amount detection), filters (group, person, date range, category), results
      screen; works offline.

## Tests

TC-12-01…05, TC-34-01…02.

Pre-built (phase 06 session, branch prep/upi-recurrence): `lib/domain/rules/recurrence.dart`, `test/fixtures/recurring_vectors.json`, `test/domain/rules/recurrence_test.dart` (T1 Dart side; pgTAP from the same vectors in T2).
