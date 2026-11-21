---
name: offline-sync-rules
description: Rules for Splitify's offline-first data layer — repositories, Drift tables, outbox mutations, pull/push, conflicts, "not synced yet" markers, uploads. Use before adding or changing any feature that reads or writes data, a Drift table/migration, an RPC used by sync, or when sync tests fail.
---

# Offline-first rules (checklist)

Spec: `planning/04-sync-engine.md` (client) + `planning/03-backend.md` §4 (server RPCs).

1. UI → controller → repository → Drift. Widgets never import Supabase; only `lib/data/remote/` does (guard).
2. A user write = one Drift transaction that updates the local row (`sync_state = pending`) **and** appends an
   outbox mutation (`mutation_id` = new UUID v7, `client_updated_at` = now + server offset). No direct RPC writes
   from features (exceptions: join group, rotate invite, delete account, register device — online-only actions
   that show "needs internet").
3. IDs are UUID v7 generated on the phone. Never wait for the server to assign ids.
4. Reads are streams (`watch`) from Drift so pulls update the UI automatically.
5. New synced table ⇒ server: `seq` + `bump_seq` trigger + RLS + included in `pull_changes` + handled in
   `apply_mutations`; client: Drift table + mapper + pull applier + outbox handler + tests (push, pull, conflict,
   tombstone). Bump the Drift schema version with a migration test.
6. Deletes are soft (`deleted_at`); restore is an `op: restore` mutation. Lists filter `deleted_at is null`.
7. Conflicts: last save wins by `client_updated_at` (server-clamped); the loser is kept in `record_versions`.
   Never "merge" fields silently.
8. Any widget showing data derived from pending/failed rows shows the `SyncMarker`.
9. Online-only actions check connectivity first and show "This needs internet" instead of failing.
10. Tests use `FakeRemoteApi` + `FakeClock` + in-memory Drift; e2e uses airplane mode via `emulator-e2e`.
