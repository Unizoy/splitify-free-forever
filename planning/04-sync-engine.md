# 04 — Offline-first sync engine (rule 6)

Custom outbox over Drift + two Supabase RPCs. No third-party sync service (PowerSync/Electric would be a new
outside service; Brick hides too much for our LWW + history rules) — decision T-004.

## 1. Data flow

```
UI ──watch()──► Repositories ──read──► Drift (local truth for display)
                     │ write (one transaction)
                     ├─► local tables (row marked pending)
                     └─► outbox (ordered mutation)
SyncEngine: push outbox in order ─► apply_mutations ─► server
            pull pages ◄────────── pull_changes ◄──── server (seq cursors)
Triggers to sync: app start/resume, connectivity regained, Realtime "changed" nudge on group:<id>/user:<uid>,
after every local write (debounced 1 s), pull-to-refresh, WorkManager periodic (15 min, network constraint).
```
UI never calls Supabase directly (guard script enforces: Supabase imports only in `lib/data/remote/`).

## 2. Local database (Drift)

- Mirror tables for: profiles (co-members), groups, group_members, expenses, payments, comments,
  recurring_templates, activity, notifications, notification_settings, currencies, categories, fx_rates.
  Columns as server, money as `int`, jsonb as `TEXT` JSON; plus `sync_state` (`synced`/`pending`/`failed`).
- Derived table `expense_parts(expense_id, group_id, member_id, currency, paid, owed, fx_paid, fx_owed)`
  maintained in the same transaction as expense writes/pulls — makes local balance queries plain SQL sums.
- `outbox(seq INTEGER PK AUTOINCREMENT, mutation_id TEXT unique, entity, op, record_id, group_id, payload TEXT,
  client_updated_at, created_at, attempts, last_error, status ('queued'|'in_flight'|'failed'))`.
- `sync_cursors(scope TEXT pk  -- 'group:<id>' | 'user', seq INTEGER)`, `sync_meta(key, value)` (server time offset,
  last full sync, schema version).
- FTS5 virtual table `expense_search(description, notes, member_names, amount_text)` for offline search (#34).
- Drift schema version + step-by-step migrations with tests (`drift_dev` schema dumps in `drift_schemas/`).

## 3. Push

1. Take up to 50 `queued` mutations in `seq` order (a `failed` one blocks only mutations for the same record).
2. `apply_mutations([{mutation_id, entity, op: upsert|delete|restore, id, group_id, base_seq,
   client_updated_at, source, data}])`.
3. Server, per mutation, in order, one transaction per mutation:
   - `mutation_id` already in `mutation_log` → return stored result (`duplicate`) — safe retries.
   - not a member of `group_id` (or creating a group: creator becomes owner member) → `rejected NOT_MEMBER`.
   - validate (`08-feature-specs.md` rules + money checks) → `rejected <CODE>` on failure.
   - **Last-write-wins:** `t = least(client_updated_at, now())`. Row missing → insert. Row exists and
     `t >= row.client_updated_at` → update (`applied`). Older → keep current row, store the incoming version in
     `record_versions` with op `conflict_lost` (`superseded`). Both versions are always in history.
   - write `record_versions`, `activity` (suppressed per row when `source='import'`; one summary instead).
4. Client: `applied`/`duplicate` → delete outbox item, keep row `pending` until the pull brings its `seq`;
   `superseded` → delete item, pull will overwrite the row, show a one-time snackbar "Someone else's newer edit was
   kept — your version is in history"; `rejected` → mark item and row `failed` (Sync issues screen: edit, retry or
   discard); network/5xx → exponential backoff 2 s → 5 min with jitter, `attempts++`.
5. Client time: `client_updated_at = DateTime.now().toUtc() + serverOffset` (offset measured from `server_time` in
   every RPC response), so wrong phone clocks don't decide conflicts.

## 4. Pull

- Request: cursors for every known group + `user` scope. Server adds groups the user joined (cursor 0) and reports
  groups the user lost access to (client deletes them locally).
- Response pages ≤ 500 rows; client applies each page in one transaction: upsert rows by `id` **unless** the local
  row has a queued outbox mutation (pending local edits win locally until pushed), rebuild `expense_parts` for
  touched expenses, update FTS rows, advance cursors **after** the page is stored. Repeat while `has_more`.
- Soft-deleted rows arrive with `deleted_at` (tombstones) and are hidden by queries, kept for restore/history.
- First sync after sign-in shows the `StackedCardsLoader`.

## 5. Balances shown on the phone (rule 3)

Local balances = money engine over local rows (synced + pending). If any contributing row is `pending`/`failed`,
balance widgets show the `SyncMarker` ("not synced yet"). After a pull with no pending rows, the client compares a
local checksum (nets per currency) with `group_balances()`; mismatch → server values shown, diagnostic logged.

## 6. Files (receipts, avatars, covers)

`pending_uploads(id, bucket, local_path, remote_path, record_id, attempts)`. Pick → compress (JPEG q80, max 1600 px,
≤ 500 KB) → copy into app documents dir → record gets `receipt_path` immediately (remote path decided client-side)
→ uploader sends when online (after the record's mutation is applied) → on success delete local copy (keep a
thumbnail cache). Viewing uses the local file when present, else a signed URL (cached).

## 7. Sessions and accounts

- Offline start works with the persisted Supabase session; token refresh failures while offline are ignored until
  online. A 401 on push → refresh once → if still 401, sign the user out **without** deleting the local database
  (outbox kept; same user signing in again resumes sync; a different user → local DB wiped first).
- Sign-out: push outbox (best effort, 10 s) → unregister device token → wipe local DB + secure storage.

## 8. Background

`workmanager` periodic task (15 min, requires network) and one-off task on connectivity change: opens the database,
runs push then pull, exits; never shows UI. Same engine class as foreground (shared isolate-safe code).

## 9. Diagnostics

Account → "Sync & storage": last sync time, queued/failed counts, list of failed mutations with error and actions,
"Sync now", "Export debug log" (share sheet, no tokens/PII beyond ids).

## 10. Tests (must exist before features build on it — phase 06)

Fake `RemoteApi` with scripted responses + fake clock: ordering, idempotent retries, LWW both directions, clock
skew offset, pagination, tombstones, kill-mid-page recovery, rejected/poison handling, auth expiry, group access
loss. Integration (dev project, two users): A offline edits + B online edits same expense → later save wins, both
in history; airplane-mode e2e on the emulator (phase 15).
