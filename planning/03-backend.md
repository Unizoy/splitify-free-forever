# 03 — Backend (Supabase): schema, security, RPCs, jobs, functions

Research: `research/05-supabase-fcm-fx.md`. Product rules 3–10, 14, 15 apply everywhere.

## 1. Principles

- **Writes only through RPCs** (`security definer`, explicit membership + validation checks, `set search_path = ''`).
  Clients get `select` (RLS-filtered) on app tables and **no** direct insert/update/delete. One write path = one
  place for validation, last-write-wins, edit history and activity log.
- **RLS on every table** (rule 7) — even tables only RPCs write. Policies use `(select auth.uid())` and the helper
  `private.is_member(group_id)`; every policy column is indexed. `private` schema is not exposed by the API.
- **Soft deletes** (`deleted_at`, `deleted_by`) for every user-visible record (rule 9); hard deletes only for
  housekeeping tables.
- **Change feed:** one global sequence `public.sync_seq`; every synced row has `seq bigint` set by a `BEFORE
  INSERT OR UPDATE` trigger (`private.bump_seq`). Pull = "rows of my groups with `seq` > my cursor".
- **IDs:** UUID v7 generated on the phone (rule 6); server accepts them as given (rejects duplicates owned by
  another group).
- **Migrations:** `supabase/migrations/NNNN_name.sql` (4-digit, never edited after being applied to dev; fixes go in
  a new file). Applied with MCP `apply_migration`; names must match files. No secret values in migrations.
- Keys: app uses the **publishable** key only; Edge Functions use the built-in `SUPABASE_SECRET_KEYS` (`default`)
  env. Legacy anon/service_role keys are never used.

## 2. Tables

Common columns for synced tables (written by RPCs, never trusted from the client except where noted):
`id uuid pk` (client), `group_id uuid` (scope), `created_at timestamptz default now()`, `created_by uuid`
(auth user), `updated_at timestamptz`, `updated_by uuid`, `client_updated_at timestamptz` (client save time,
clamped to server `now()`), `deleted_at timestamptz`, `deleted_by uuid`, `seq bigint not null`.

| Table | Key columns (beyond common) | Notes |
| --- | --- | --- |
| `currencies` | `code char(3) pk`, `exponent smallint`, `name`, `symbol`, `frankfurter bool` | seeded; read-only |
| `categories` | `key text pk`, `parent_key`, `name`, `icon`, `color`, `sort` | seeded (list in `08-feature-specs.md`); read-only |
| `profiles` | `id uuid pk → auth.users`, `display_name text 1..50`, `avatar_path`, `upi_id` (regex `^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z0-9.\-]{1,63}$`), `default_currency`, `deleted_at`, `seq` | created by trigger on `auth.users` insert (name from Google metadata or email prefix). Visible to self and co-members. |
| `groups` | `name 1..60`, `type` (`trip`/`home`/`couple`/`other`/`direct`), `main_currency`, `cover_kind` (`generated`/`photo`), `cover_path`, `simplify_debts bool default false`, `default_split jsonb`, `invite_code text unique`, `invite_rotated_at`, `archived_at` | `direct` = friend expenses (#2): exactly two members, hidden from Groups tab, shown on Friends tab; `direct_key text unique` = sorted pair of user ids when both are users. |
| `group_members` | `user_id uuid null` (null = name-only), `display_name 1..50`, `position int`, `role` (`owner`/`member`), `status` (`active`/`left`/`removed`), `claimed_at`, `tint smallint` | unique `(group_id,user_id)` where user_id not null; unique `(group_id, position)`; name shown = profile name if linked else display_name. |
| `expenses` | `kind` (`expense`/`iou`), `description 1..120`, `notes ≤1000`, `category`, `date date`, `currency`, `total bigint 1..999999999999`, `payers jsonb {member_id: minor}`, `shares jsonb {member_id: minor}`, `split_kind`, `split_values jsonb`, `fx_rate numeric(24,10)`, `fx_rate_date`, `fx_source`, `fx_currency`, `fx_total`, `fx_payers jsonb`, `fx_shares jsonb`, `receipt_path`, `recurring_id`, `source` (`app`/`recurring`/`import`) | trigger validates: Σpayers = Σshares = total, members belong to group, fx parts sum to fx_total (money engine spec). |
| `payments` | `from_member`, `to_member` (≠), `amount`, `currency`, `date`, `method` (`cash`/`upi`/`bank`/`other`), `note ≤200`, fx columns as expenses (single amount `fx_amount`) | #25, #26 |
| `comments` | `target_type` (`expense`/`payment`), `target_id`, `body 1..1000` | #13 |
| `recurring_templates` | `interval` (`weekly`/`fortnightly`/`monthly`/`yearly`), `anchor_date`, `next_date`, `ends_on`, `active`, `template jsonb` (expense fields) | #12 |
| `activity` | `actor_user_id`, `actor_member_id`, `type` (list in `08-feature-specs.md` §Activity), `target_type`, `target_id`, `data jsonb` (description, amounts, currency, involved member ids, changed fields), `created_at`, `seq` | written only inside RPCs/jobs (rule 9); never deleted |
| `record_versions` | `id bigserial`, `table_name`, `record_id`, `group_id`, `op` (`insert`/`update`/`delete`/`restore`/`conflict_lost`), `snapshot jsonb`, `changed_by`, `changed_at`, `client_updated_at`, `seq` | edit history (#20); both LWW versions kept (rule 6) |
| `notifications` | `user_id`, `group_id`, `activity_id`, `kind`, `title`, `body`, `data jsonb` (route), `read_at`, `push_status` (`pending`/`sent`/`skipped`/`failed`), `seq` | in-app bell (#19); per-recipient |
| `notification_settings` | `user_id pk`, `kinds jsonb` (`{kind:{push:bool,inapp:bool}}`), `muted_group_ids uuid[]` | defaults all on |
| `device_tokens` | `id`, `user_id`, `token text unique`, `platform`, `app_version`, `last_seen_at` | removed on sign-out (rule 10) |
| `fx_rates` | `pk (date, currency)`, `rate numeric(24,10)` (per 1 EUR), `source`, `fetched_at` | read-only for users |
| `mutation_log` | `mutation_id uuid pk`, `user_id`, `received_at`, `result jsonb` | idempotency; pruned after 30 days |
| `join_attempts` | `user_id`, `at` | rate limit (10/hour) |

Indexes: `(group_id, seq)` on every synced table; `group_members(user_id, status)`; `expenses(group_id, date)`;
GIN on `expenses.shares`/`payers` (`jsonb_path_ops`) for member queries; `notifications(user_id, seq)`;
`activity(group_id, seq)`.

## 3. Row Level Security

```sql
create function private.is_member(g uuid) returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.group_members m
       where m.group_id = g and m.user_id = (select auth.uid()) and m.status = 'active' and m.deleted_at is null) $$;
```
- Group-scoped tables (`groups`, `group_members`, `expenses`, `payments`, `comments`, `recurring_templates`,
  `activity`, `record_versions`): `select using (private.is_member(group_id))` (`groups` uses `id`).
- `profiles`: select self or `private.shares_group(id)`; no client writes (RPC `update_profile`).
- `notifications`, `notification_settings`, `device_tokens`: `user_id = (select auth.uid())`.
- `currencies`, `categories`, `fx_rates`: select for `authenticated`.
- `mutation_log`, `join_attempts`: no policies (RPC only).
- Revoke `insert, update, delete` on all app tables from `anon, authenticated`.
- Storage buckets (created by SQL `insert into storage.buckets`): `receipts` (private; path
  `<group_id>/<expense_id>/<uuid>.jpg`; read/write if member of folder[1]), `group-covers` (private; same rule),
  `avatars` (private; path `<user_id>/<uuid>.jpg`; write own folder; read self or shares a group). Max 5 MB, MIME
  `image/jpeg|image/webp`.
- Realtime: private broadcast topics `group:<id>` and `user:<uid>`; policy on `realtime.messages` allows select
  when the topic's id passes `is_member` / equals `auth.uid()`.
- Tests: for every table, pgTAP proves member can read, non-member can't, left member can't, writes outside RPCs
  fail, name-only claim can't hijack a linked member.

## 4. RPCs (all `security definer`, `set search_path = ''`, `auth.uid()` required)

| RPC | Purpose |
| --- | --- |
| `apply_mutations(batch jsonb) → jsonb` | Offline write path (spec in `04-sync-engine.md` §3). Per mutation: idempotency via `mutation_log`; membership; validation (money engine rules re-checked in SQL); last-write-wins on `client_updated_at`; writes row + `record_versions` + `activity` (+ notifications via trigger). Returns per-mutation `applied`/`superseded`/`duplicate`/`rejected{code}` and `server_time`. |
| `pull_changes(cursors jsonb, since_user_seq bigint, page_size int default 500) → jsonb` | Rows per table with `seq > cursor` for each of my groups (new groups start at 0), plus my profile/co-member profiles, notifications, settings; `next_cursors`, `has_more`, `server_time`. |
| `group_balances(group_id) → jsonb` | Per currency: nets, pairs (simplify off), simplified; plus converted view when all records have saved fx. Uses `money.*`. |
| `my_overview() → jsonb` | Per currency totals across groups + per-friend totals (#16) + per-group summaries. |
| `preview_join(code) → jsonb` | Rate-limited; returns group name/type/cover + unclaimed name-only members. |
| `join_group(code, claim_member_id uuid null) → jsonb` | Join as new member or claim a name-only spot (#3, #4); writes activity; idempotent if already a member. |
| `rotate_invite_code(group_id)` | Any member; old code stops working. |
| `leave_group(group_id)` / `remove_member(group_id, member_id)` | Only when that member's nets are 0 in every currency (Splitwise rule); `rejected NONZERO_BALANCE` otherwise. |
| `update_profile(...)`, `upsert_notification_settings(...)` | Self only. |
| `register_device(token, app_version)` / `unregister_device(token)` | Rule 10. |
| `mark_notifications_read(ids uuid[] or all)` | Bell. |
| `send_reminder(group_id, to_member_id)` | #23: activity `reminder_sent` → notification to that member's user (if linked). Throttle: 1 per pair per 24 h. |
| `find_or_create_direct_group(friend_user_id or name)` | Friend expenses (#2). |

Every RPC that changes data writes `activity` with actor and time.

## 5. Notification pipeline (rule 10)

`activity` insert → trigger `private.fanout_notifications()` → one `notifications` row per involved linked member
(not the actor, not muted group, kind enabled in-app) → trigger `private.queue_push()` → if push enabled for that
kind: `net.http_post(<project_url>/functions/v1/send-push, body {notification_id})`. The project URL comes from
`private.settings` (key/value table filled by phase 13 with the dev URL; no secrets).
`send-push` (verify_jwt **false**) is idempotent: loads the notification with the secret key, sends only if
`push_status = 'pending'`, marks `sent`/`failed`, deletes tokens on `UNREGISTERED`. Calling it twice or by a
stranger can't send anything new.

## 6. Scheduled jobs (pg_cron, UTC)

| Job | Schedule | What |
| --- | --- | --- |
| `fetch-rates` | `15 1 * * *` and `15 13 * * *` | `net.http_post` to Edge Function `fetch-rates` (verify_jwt false; no-op if fetched < 6 h ago). Function calls `https://api.frankfurter.dev/v2/rates?base=EUR` (v2: 160+ currencies incl. INR, AED, SAR, VND, LKR, NPR, BDT), upserts `fx_rates(date,currency)`. First run backfills 30 days. |
| `generate-recurring` | `40 18 * * *` (00:10 IST) | Pure SQL: for each active template with `next_date <= (now() at time zone 'Asia/Kolkata')::date`, insert expense with deterministic id `uuid(md5(template_id||date))` (idempotent), `source='recurring'`, activity `expense_added` (actor = template creator, data.recurring=true); advance `next_date` (month-end clamp: anchor 31 → last day of shorter months). |
| `housekeeping` | `0 20 * * 0` | prune `mutation_log` > 30 d, `join_attempts` > 1 d, `cron.job_run_details` > 14 d. |

## 7. Edge Functions (`supabase/functions/`, Deno, deployed via MCP `deploy_edge_function`)

| Function | verify_jwt | Does |
| --- | --- | --- |
| `send-push` | false | §5. FCM HTTP v1: OAuth token from `FCM_SERVICE_ACCOUNT_JSON` (owner-set secret) signed with Web Crypto RS256 (no npm deps), cached 50 min; message `{token, notification:{title,body}, data:{route}, android:{priority:'high', notification:{channel_id}}}`. |
| `fetch-rates` | false | §6. |
| `delete-account` | true | Caller from JWT only. Turns each membership into a name-only member (keeps display name + " (left)" suffix so others' history stays readable), clears profile (name "Deleted user", avatar, UPI), deletes device tokens + avatar files, then `auth.admin.deleteUser`. Balances of others unchanged. |

Shared code in `supabase/functions/_shared/` (`fcm.ts`, `admin_client.ts`, `cors.ts`). Tests with `deno test`
mocking `fetch`. Secrets: only `FCM_SERVICE_ACCOUNT_JSON` (owner, phase 00).

## 8. Migration plan

| File | Phase | Content |
| --- | --- | --- |
| `0001_extensions_and_schemas.sql` | 04 | `pgcrypto`, `pg_net`, `pg_cron`, `pgtap` (schema `extensions`); schemas `private`, `money`; `sync_seq`; `bump_seq()` |
| `0002_money_functions.sql` | 04 | `money.*` per `05-money-engine.md` |
| `0003_reference_data.sql` | 04 | `currencies`, `categories` + seed |
| `0004_core_tables.sql` | 04 | profiles (+ auth trigger), groups, group_members, expenses, payments, comments, activity, record_versions, mutation_log, join_attempts, validation triggers, indexes |
| `0005_rls.sql` | 04 | helpers, policies, revokes |
| `0006_balances.sql` | 04 | `group_balances`, `my_overview` |
| `0007_storage.sql` | 04 | buckets + storage policies |
| `0008_sync_rpcs.sql` | 06 | `apply_mutations`, `pull_changes`, realtime topic policies + broadcast trigger |
| `0009_group_rpcs.sql` | 07 | join/preview/rotate/leave/remove, direct groups |
| `0010_notifications.sql` | 13 | notifications, settings, device tokens, fanout, push queue, reminder RPC, `private.settings` |
| `0011_fx.sql` | 14 | `fx_rates`, cron `fetch-rates` |
| `0012_recurring.sql` | 16 | templates, cron `generate-recurring` |
| `0013_housekeeping_and_hardening.sql` | 19 | housekeeping cron, advisor fixes |

Tests live in `supabase/tests/NNN_*.test.sql` (pgTAP, each file `begin; select plan(n); … select * from finish(); rollback;`),
run through MCP `execute_sql`. Users for RLS tests are created inside the transaction
(`insert into auth.users …`) and impersonated with `set local role authenticated;
set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';`.

## 9. Free-plan realities

Limits: 500 MB DB, 1 GB storage, 5 GB egress, 50k MAU, 500k function calls, 2 M realtime messages, 200 concurrent
realtime connections. **Projects pause after 7 days of inactivity and have no backups** — dev pausing is fine (owner
restores from dashboard; sessions log a blocker). Schema and functions are in Git, so any project can be rebuilt
(rule 14). The release phase README tells the owner to move prod to the Pro plan (backups, no pausing) once the app
has real users.
