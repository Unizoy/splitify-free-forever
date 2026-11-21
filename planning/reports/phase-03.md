# Phase 03 report — Money engine (pure Dart)

- Date: 2026-11-21 · Branch: `phase/03-money-engine` · Base: `origin/phase/02-design-system` (02 not merged yet)
- Commits: `5dad6d6..HEAD` · Status: done
- Built by two parallel sub-agents on disjoint files (owner asked for parallel work, 2026-11-21); the main session
  wrote the shared `Currency` contract first, then verified, ran the gates and shipped.

## Summary

`lib/core/money/` now implements `05-money-engine.md` exactly: integer minor-unit `Money`, the five split kinds
with fixed-order rounding, payer checks, balances (nets, who-owes-whom, simplify, friend totals), currency
conversion with saved-rate semantics and cross rates, a 160-currency table, the ₹ formatter with Indian grouping
and the keypad amount expression (`450+120`). All 52 shared vectors pass; property tests prove the invariants.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Vectors | done | `test/fixtures/money_vectors.json` (byte-identical copy, checked by a test), `vectors_test.dart` runs all 52 by `op` |
| T2 Currency + Money | done | `currency.dart`, `currencies.dart` (160 codes, 159 Frankfurter), `money.dart` (same-currency arithmetic, `CURRENCY_MISMATCH`) |
| T3 Engine | done | `allocation.dart` (equal, Hamilton with exact BigInt quotas), `split.dart`, `balances.dart`, `fx.dart`, sealed `money_error.dart` (20 codes) |
| T4 Properties | done | 9 glados properties × 500 runs; non-vacuity checked by a deliberately broken allocator |
| T5 Formatter + input | done | `money_formatter.dart` (en_IN grouping on digit strings, U+2212 minus, list/detail modes, `plain()`), `amount_expression.dart` (exact fractions, one half-away rounding) |
| T6 Coverage | done | `lib/core/money` 100 % lines |

## Features delivered

Engine for #5–#11 (split kinds, payers, IOU), #14–#17 (per-currency balances, friend totals, simplify), #21, #25
(payment effect), #32 (conversion). No UI changes in this phase (phase 02 placeholders still show the ARB `₹0`;
phases 07–09 switch to `MoneyFormatter`).

## Tests

- `flutter test`: 364 tests (phase 02 had 146). New: vectors (52), 9 properties × 500 runs, unit tests for money,
  allocation, split, balances (incl. IOU, payments, friend totals, mixed currencies), fx, currencies (14),
  formatter (16), amount expression (25).
- Coverage: money 100 % · core 93.0 % · application 100 % · presentation 92.7 % · overall 93.8 %
- Test IDs now passing: TC-5..9-01, TC-5..9-02, TC-10-01, TC-10-03, TC-11-01, TC-14-01, TC-15-01, TC-16-01,
  TC-17-01, TC-25-01, TC-32-01
- Quarantined / skipped: none

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | format 0 changes, analyze 0 errors / 0 warnings (infos only), `guards: OK` (no `double`/`num` in money) |
| G2 Tests | PASS | 364 passed; floors: money 100 %, core 93.0 %, overall 93.8 % |
| G3 Backend | N/A | pure Dart phase |
| G4 Build | PASS | debug APK 74 s |
| G5 Device | PASS | `app_smoke_test.dart` 1/1 on emulator-5554 (no screens changed → no UI review needed) |
| G6 Docs | PASS | phase ticks, PROGRESS, catalog, S-016…S-019, BLK-001, LEARNINGS, this report |

## Decisions made (S-0xx)

S-016 exact cross rate, fixed 10-decimal text, reject > 10-decimal rates · S-017 Dart-only guards (per-member cap,
unknown/duplicate members, self-payment, zero converted total, currency mismatch) · S-018 formatter design ·
S-019 currency table scope/symbols and amount-input error codes.

## Blockers (BLK-xxx)

- BLK-001 (new): Supabase MCP not available to execution sessions → phase 04+ cannot apply/verify on the dev
  project. Owner steps in `planning/BLOCKERS.md`.

## Learnings and skills added or changed

4 entries in `planning/LEARNINGS.md` (const-constructor coverage, parallel agents on disjoint files, oracle
`__pycache__`, Postgres division precision for cross rates). No skill changes.

## Owner actions

- Recommended: BLK-001 — log the Supabase MCP in (`claude` → `/mcp` → supabase → Authenticate) so phase 04 can be
  applied to the dev project and phases 05+ can run.

## Next phase

04 Backend foundation (running in parallel on `phase/04-backend-foundation`, verified in CI; dev-project steps
wait for BLK-001). SQL money functions must match this engine, including S-016's cross-rate rule.
