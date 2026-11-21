# Phase 04 report — Backend foundation

- Date: 2026-11-21 · Branch: `phase/04-backend-foundation` · Base: `phase/03-money-engine` (worktree
  `..\splitify-p04`, built in parallel with phase 03 at the owner's request; phase 03 merged in before shipping)
- Commits: `67ccd57..HEAD` (8 phase commits + merge of phase 03 + report) · Status: **done** (BLK-001 closed 2026-11-21)

## Summary

The whole Supabase backend now exists as code in the repo and is proven by pgTAP: schemas, money functions that
reproduce all 52 shared vectors (parity with the Dart engine), reference data (currencies, categories), core
tables with validation triggers and indexes, RLS on every table with all client writes revoked, the
`group_balances`/`my_overview` RPCs and private storage buckets. GitHub Actions now runs a `db` job (local
Supabase in Docker → migrations → 189 pgTAP assertions) and a `functions` job (Deno fmt/lint/test). Not yet done:
applying it to the owner's dev project and the advisors, because the Supabase MCP is not connected (BLK-001).

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Owner setup + `secrets/env.dev.json` | done 2026-11-21 | URL + publishable key from MCP, Google web client id from owner inputs (S-068) |
| T2 Deno | done | 2.9.8, per-user `%USERPROFILE%\.deno\bin` |
| T3 Migrations 0001–0007 | done | applied to dev via MCP 2026-11-21; 0005 default privileges rewritten (S-065) |
| T4 `tool/gen_sql_vectors.dart` | done | generates `010_money_vectors.test.sql` + `030_balances.test.sql`; CI stale check |
| T5 pgTAP files | done (CI) | 9 files, 189 assertions, all pass on Postgres 17 in CI |
| T6 Advisors | done | security: lint 0029 WARNs accepted (S-066); performance: INFO only, not fixed (S-067) |
| T7 CI `db` + `functions` jobs | done | runs 44920553533 (all green) |
| T8 `supabase/README.md` | done | rebuild-anywhere guide (PLAN rule 14) |

## Features delivered

Server side of rules 3, 7, 9, 14 foundations: official balances in Postgres, RLS everywhere, soft-delete/audit
columns, schema reproducible from the repo.

## Tests

- pgTAP (CI `db` job): 001_schema 32 · 010_money_vectors 52 · 011_money_guards 7 · 020_rls_groups 17 ·
  021_rls_expenses_payments 15 · 022_rls_profiles 11 · 023_storage 13 · 030_balances 22 · 031_validation 20 = 189
- Deno: `_shared/http_test.ts` 5 tests
- Flutter suite after merging phase 03: 365 passed; coverage money 100 % · core 93.0 % · overall 93.8 %
- Test IDs: TC-14-03, TC-15-02, TC-17-02, TC-32-03, TC-5..9-05, TC-B2-05 = pass in CI; MCP run on dev needs-owner
  (BLK-001). Also exercised early: TC-16-02 (my_overview friend totals), TC-1-03 (archived group rejects edits) —
  catalog rows left to their phases.

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | format 0 changes, analyze 0 errors/warnings, guards OK |
| G2 Tests | PASS | 365 Flutter tests; floors met |
| G3 Backend | PASS | CI run 44920553533 (`db` 189/189); PASS on dev 2026-11-21: 0001–0009 applied via MCP, 12 pgTAP files 282/282, advisors: 0 ERROR, 12 WARN lint 0029 accepted (S-066), perf INFO only (S-067) |
| G4 Build | PASS | flutter job green in CI (debug APK); no Dart app changes in this phase |
| G5 Device | N/A | no app/screens changed |
| G6 Docs | PASS | phase ticks, PROGRESS, catalog, S-020…S-029, LEARNINGS, this report |

## Decisions made (S-0xx)

S-020 SQL error convention (P0001, message = code, detail = JSON) + one `is()` per vector · S-021 generator also
builds 030, runs with plain Dart in CI · S-022 4-digit migration names, pg_cron in `pg_catalog` · S-023
`group_balances`/`my_overview` JSON shapes, non-members → 42501 · S-024 validation codes, archived groups reject
writes · S-025 seed contents · S-026 audit columns without FKs, UPI regex split for Postgres repeat limit · S-027
default-privilege revokes · S-028 first shared Edge Function helper · S-029 Dart-parity guards in SQL (S-016/017).

## Blockers (BLK-xxx)

- BLK-001 (closed 2026-11-21): Supabase MCP was not connected → T1, apply-to-dev, dev pgTAP run and advisors skipped. Next session
  after the fix: apply 0001–0007 with `apply_migration` (names = files), run the 9 test files via `execute_sql`
  in `BEGIN … ROLLBACK`, run advisors, write `secrets/env.dev.json`, then mark this phase `done`.

## Learnings and skills added or changed

- LEARNINGS: Supabase CLI v2 rejects `[inbucket]` in `config.toml`; Postgres regex repeat counts max 255; Deno
  2.9.8 install path; parallel phases via git worktree + merge.
- No skill changes (the `supabase-dev` skill's MCP steps are still the path once BLK-001 is fixed).

## Owner actions

- **Needed for phase 05+:** BLK-001 — connect the Supabase MCP (`claude` in the repo → `/mcp` → supabase →
  Authenticate). Then say "execute the plan": the next session finishes phase 04 on dev first.

## Next phase

05 Auth, profile, account — blocked until BLK-001 is fixed (needs the dev project through MCP).
