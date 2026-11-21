---
name: supabase-dev
description: Works with Splitify's Supabase DEV project through the Supabase MCP server — create numbered migrations, apply them, run pgTAP/RLS test files in rolled-back transactions, check advisors, create storage buckets via SQL, deploy and test Edge Functions, read logs. Use for any database, RLS, RPC, cron, storage or Edge Function work, "new migration", "run the SQL tests", "deploy the function".
---

# Supabase (dev project) via MCP

Spec: `planning/03-backend.md`. Research: `planning/research/05-supabase-fcm-fx.md`. The MCP server `supabase` is
scoped to the **dev** project (`project_ref` in its URL), so tools take no project id. The prod server
(`supabase-prod`) exists only in phase 20 and the guard hook blocks it otherwise.

## Migrations

1. Next number = highest `supabase/migrations/NNNN_*.sql` + 1. Create `supabase/migrations/NNNN_short_name.sql`.
   Never edit a file that was already applied — write a new one.
2. Write idempotent-where-reasonable SQL; every new table: `alter table … enable row level security;` + policies +
   revokes (`03-backend.md` §1, §3). Functions: `security definer` only when needed, always
   `set search_path = ''`, fully-qualified names.
3. Apply: `mcp__supabase__apply_migration` with `name` = file name without `.sql` and `query` = file content.
4. Check: `mcp__supabase__list_migrations` matches the files; `mcp__supabase__get_advisors` (`security`, then
   `performance`) — fix every security ERROR/WARN in a follow-up migration.
5. Regenerate client artefacts if needed (Drift tables are hand-written to match; update them in the same commit).
Use `execute_sql` only for reads, tests and one-off data checks — never for schema changes.

## SQL tests (pgTAP)

- Files: `supabase/tests/NNN_name.test.sql`, each:
  ```sql
  begin;
  select plan(5);
  -- arrange: users (insert into auth.users (id, email) values (...)), groups via the RPCs
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';
  select is( (select count(*) from public.expenses), 3::bigint, 'member sees group expenses');
  select * from finish();
  rollback;
  ```
- Run each file's full content with `mcp__supabase__execute_sql`. Pass = no row starting with `not ok` and the
  plan count matches. The guard allows destructive statements only inside `begin … rollback`.
- `pgtap` is enabled by migration 0001 (schema `extensions`); call functions unqualified after
  `set local search_path = public, extensions;` if needed.
- Money parity: run `dart run tool/gen_sql_vectors.dart` first so `010_money_vectors.test.sql` is fresh.

## Storage

No MCP tool creates buckets: do it in a migration:
`insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values (...) on conflict do nothing;`
then policies on `storage.objects`.

## Edge Functions

- Code in `supabase/functions/<name>/index.ts` + `_shared/`. Test locally: `deno test -A supabase/functions`
  (install Deno with `dev-env` §4), `deno lint`, `deno fmt --check`.
- Deploy: `mcp__supabase__deploy_edge_function` with `name`, `entrypoint_path: "index.ts"`, `verify_jwt` per
  `03-backend.md` §7, and `files` = every file the function imports (including `_shared/*`), contents as strings.
- Logs: `mcp__supabase__get_logs` (service `edge-function`). Secrets: the only custom secret is
  `FCM_SERVICE_ACCOUNT_JSON`, set by the owner (phase 00 E.4). MCP can register a secret name but not its value —
  never try to put secret values in code, SQL or chat.

## Project facts

- Get URL/publishable key: `mcp__supabase__get_project_url`, `mcp__supabase__get_publishable_keys` → write
  `secrets/env.dev.json` (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_WEB_CLIENT_ID` from
  `secrets/owner-inputs.json`, `E2E_PASSWORD` random once). File is git-ignored.
- Free plan: the project pauses after 7 days idle. If MCP calls fail with a paused/unavailable project, add a
  blocker ("Owner: Supabase dashboard → project → Restore") and continue with local-only work.
