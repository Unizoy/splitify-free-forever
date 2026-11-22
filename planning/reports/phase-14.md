# Phase 14 report — Mixed currencies and conversion (#14, #32)

- Date: 2026-11-22 · Branch: `phase/14-currencies` · Base: `origin/main` (phases 01–09); phases 10 and 13 merged in
  on the way (`5d90d4f`, `57d3fcb`)
- Commits: `4a08723..HEAD` · Status: GATES_STATUS

## Summary

Expenses and payments can now be in any of 160 currencies: the amount screen and Settle up have a currency chip
that opens a searchable picker (group currency first, then recently used ones). Balances, totals and friend totals
stay per currency. A record in another currency shows "Convert to INR" on its detail screen: the sheet fills in the
Frankfurter rate for the record's date from the phone's rate cache (works offline; an earlier day is used and named
when the exact one is missing), or takes a typed rate; the rate, date, source and converted amounts are saved with
the record and never recalculated. The group Balances tab gets "By currency | In INR": records still without a rate
are listed with "Convert all at their dates' rates", then everything shows in INR, with "Simplify in INR". The server
fetches Frankfurter rates twice a day (pg_cron → pg_net → `fetch-rates`, deployed) and checks every saved conversion.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Migration | done | `0017_fx.sql` (S-099 number, applied to dev): `fx_rates` + RLS read-only, 5 missing currency codes, Frankfurter flags from `/v2/currencies`, `check_fx` trigger, `private.settings`, two cron jobs (S-150, S-151, S-152); pgTAP `140_fx.test.sql` 22/22 |
| T2 `fetch-rates` | done | Pre-built function deployed via MCP (`verify_jwt` false); dev `project_url` set; first run backfilled 4,561 rows (159 currencies, 2026-10-22..11-21); the 01:15 UTC cron run succeeded and was throttled as designed; deno fmt/lint/test 45/45 (fmt on an LF copy, see LEARNINGS) |
| T3 Client rate cache + FxService | done | Drift `fx_rates` (schema v5), `FxRatesRemote` (`rate::text`), `FxRatesRepository` (cursor, 6 h throttle, 90-day first pull, on-demand days for old records), refresh after each sync (`FxRatesKeeper`), pre-built `FxService` reused (S-153) |
| T4 Picker + per-currency sections | done | Picker sheet (search, group currency, recent, all) on the expense editor and Settle up; balances/totals/friend totals were already per currency (S-154, S-157) |
| T5 Conversion sheet + "Show balances in INR" | done | Detail rows, sheet (auto/fallback/manual, Use Frankfurter rate, Remove), edits keep the saved rate (S-151), "By currency / In INR" toggle, missing list, Convert all (S-155) |
| T6 Simplify after converting | done | On the converted nets, only when everything is converted, link "Simplify in INR" / "Show original debts" (S-156) |

## Features delivered

- #14 Mixed currencies in a group: currency picker on expenses and payments; per-currency sections everywhere.
- #32 Currency conversion: server rates (Frankfurter v2, twice daily), offline rate cache, conversion sheet with saved
  rate/date/source, "Show balances in INR" + "Convert all", simplify after converting.

## Tests

- New tests: unit/widget ≈ 250 (6 data/domain files, 7 currency presentation files, editor/settle fx tests), golden 56
  (`currency_golden_test.dart`, 14 scenarios × light/dark × 1.0/2.0), SQL 22 (`140_fx.test.sql`), integration 1
  (`integration_test/currencies_test.dart`), edge-fn 45 (pre-built, re-run).
- Coverage: COVERAGE_LINE
- Test IDs now passing: TC-14-02, TC-14-04, TC-14-05, TC-32-02, TC-32-04, TC-32-05, TC-32-06, TC-32-07, TC-32-08,
  TC-17-04, TC-32-09 (device) — see `10-test-catalog.md`.

## Gates

GATES_TABLE

## Decisions made (S-0xx)

S-150 migration 0017 + currency parity · S-151 saved conversion follows edits, server `check_fx` · S-152 cron via
`private.settings` · S-153 Drift rate cache v5 outside the change feed · S-154 picker · S-155 conversion UI, no Settle
in the converted view · S-156 simplify after converting · S-157 symbols Inter can't draw show the code · S-158
`fx_rate` precision in pulled rows · S-159 `http` MockClient in one test.

## Blockers (BLK-xxx)

None new.

## Learnings and skills added or changed

LEARNINGS: Frankfurter v2 shapes, MCP "declined" for unguarded UPDATE/DELETE, deno fmt on CRLF checkouts, Drift in
widget tests (`runAsync`), root-navigator sheets and ProviderScope overrides, glyph check for currency symbols,
renumbering Drift versions across parallel phases, one-line `for` toggles, shared `private.settings`.

## Owner actions

- Optional: each new Supabase project needs `insert into private.settings (key, value) values ('project_url',
  'https://<ref>.supabase.co')` once (dev is done; prod in phase 20) — without it the rate cron does nothing.
- Users on ISPs that block `*.supabase.co` need a Supabase custom domain/proxy before release (coordinator note).

## Next phase

15 — Offline polish (depends on 10, 11, 12, 14). The rate cache refreshes after syncs only while the signed-in shell
is up; phase 15's connectivity/resume triggers will make it refresh on reconnect too.
