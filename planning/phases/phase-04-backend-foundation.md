# Phase 04 — Backend foundation

- Depends on: 03 · Owner setup: phase 00 B (Supabase project + MCP) · Branch: `phase/04-backend-foundation`
- Goal: the Supabase dev project has the core schema, RLS, money functions (parity with Dart), balances RPCs and
  storage, all proven by pgTAP; CI runs the same SQL tests against a local Supabase in Actions.
- Read first: `03-backend.md`, `05-money-engine.md` §8, `supabase-dev` skill, `research/05-supabase-fcm-fx.md`.

## Tasks

- [ ] T1 **SKIPPED (BLK-001: Supabase MCP not logged in)** Verify owner setup: `secrets/owner-inputs.json` parses; MCP `list_tables` works. Write
      `secrets/env.dev.json` (URL + publishable key from MCP, Google web client id from owner inputs, random
      `E2E_PASSWORD`, `DEV_LOGIN=true`). Missing → blocker per protocol; stop the phase as `blocked`.
- [x] T2 (Deno 2.9.8) Install Deno per `dev-env` §4 (record version).
- [x] T3 (apply-to-dev via MCP SKIPPED, BLK-001; proven in CI `db` job) Migrations 0001–0007 exactly as `03-backend.md` §8 (extensions/schemas/seq, money functions, reference
      data incl. categories from `08-feature-specs.md` #13, core tables + validation triggers + indexes, RLS +
      revokes, balances RPCs `group_balances`/`my_overview`, storage buckets + policies). Apply each via MCP.
- [x] T4 `tool/gen_sql_vectors.dart` → `supabase/tests/010_money_vectors.test.sql`; run → all pass.
- [x] T5 (run in CI; MCP run SKIPPED, BLK-001) pgTAP files: `001_schema.test.sql` (tables, RLS enabled everywhere, no client write grants),
      `020_rls_groups.test.sql`, `021_rls_expenses_payments.test.sql`, `022_rls_profiles.test.sql`,
      `023_storage.test.sql`, `030_balances.test.sql` (vectors BAL-* through `group_balances` on real rows),
      `031_validation.test.sql` (sum mismatch, foreign member, archived group). Run all via MCP.
- [ ] T6 **SKIPPED (BLK-001)** Advisors: security clean; performance warnings fixed or justified (S-decision).
- [x] T7 CI: add `db` job (setup-cli, `supabase start`, apply migrations, `supabase test db`, stale-vector check)
      and `functions` job skeleton (`supabase/functions/_shared/` with one tested helper). Add minimal
      `supabase/config.toml` needed by the CLI in CI only (no secrets).
- [x] T8 Docs: `supabase/README.md` — how to rebuild the backend in any project (rule 14): apply migrations in
      order (SQL editor or CLI), create buckets (in migrations), deploy functions, set `FCM_SERVICE_ACCOUNT_JSON`.

## Tests

TC-5..9-05, TC-14-03, TC-15-02, TC-17-02, TC-32-03, TC-B2-05 + the schema/RLS files above.

## Done when

All SQL tests pass on dev via MCP and in CI; migrations list on dev equals the repo files; advisors clean.
