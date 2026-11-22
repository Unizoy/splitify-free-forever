# Phase 14 — Mixed currencies and conversion (#14, #32)

- Depends on: 09 · Owner setup: 00 · Branch: `phase/14-currencies`
- Read first: `05-money-engine.md` §6, `08-feature-specs.md` #14 #32, `03-backend.md` §6 (`fetch-rates`),
  `research/05` §9 (Frankfurter v2).

## Tasks

- [x] T1 Migration 0011: `fx_rates`, `currencies.frankfurter` flags from `/v2/currencies` (type `currency`),
      cron `fetch-rates` (pg_net → function).
- [x] T2 `fetch-rates` Edge Function: GET `https://api.frankfurter.dev/v2/rates?base=EUR` (verify exact v2 path and
      response shape first with `curl`, record in LEARNINGS), upsert by (date, currency), throttle 6 h, 30-day
      backfill on empty table; deno tests with mocked fetch; deploy (`verify_jwt` false); run once.
- [x] T3 Client rates cache (pulled table) + `FxService` (rate for date with previous-day fallback, cross rate).
- [x] T4 Currency picker (search, recent, group main on top) on expenses and payments; per-currency sections in
      lists, balances, totals, friend totals.
- [x] T5 Conversion sheet on foreign-currency records: auto rate (source + date shown) or manual; save fx fields
      (converted total + parts via money engine); "Show balances in INR" view + "Convert all" with missing list.
- [x] T6 Simplify "after converting to main currency" option (enabled only when all records converted).

## Tests

TC-14-02, TC-32-02, TC-32-04, TC-32-05 (+ re-run TC-32-01/03 parity).

Pre-built (phase 06 session, branch prep/edge-functions): `supabase/functions/fetch-rates/{index,rates,rates_test}.ts`, `supabase/functions/_shared/admin_client.ts`; deploy + table DDL still in this phase.

Pre-built (branch prep/fx-service): T3 `FxService` logic in `lib/features/currency/domain/fx_service.dart` (`RatesSource` interface, rate for date with previous-date fallback, cross rate via `crossRate`, typed manual-rate result, `manualRate` via `parseRate`; S-093..S-095) + tests `test/features/currency/domain/fx_service_test.dart` (100 % lines). Drift rates table, pull and UI still in this phase.

Amendment (S-150..S-156, phase 14 session 2026-11-22): migration is `0017_fx.sql` (S-099), not 0011; it also adds
the app's missing currency codes, the saved-conversion check trigger and `private.settings` (`if not exists`, shared
with phase 13's 0016). Drift rate cache is schema v3. Frankfurter v2 shape re-checked with curl 2026-11-22 (see
LEARNINGS). Converted view has no Settle buttons (S-155).
