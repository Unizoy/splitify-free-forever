# Phase 06 — Local database and sync engine (rule 6)

- Depends on: 04, 05 · Owner setup: 00 · Branch: `phase/06-sync-engine`
- Goal: the offline-first data layer every feature uses: Drift mirror, outbox, `apply_mutations`, `pull_changes`,
  Realtime nudges, background sync, sync diagnostics — proven before any feature screen depends on it.
- Read first: `04-sync-engine.md` (all), `03-backend.md` §2–4, `offline-sync-rules` skill.

## Tasks

- [ ] T1 Migration 0008: `apply_mutations` (entities: group, member, expense, payment, comment; ops upsert/delete/
      restore; idempotency; LWW with clamped `client_updated_at`; `record_versions`; `activity`), `pull_changes`
      (cursors, new/lost groups, paging), broadcast trigger to `group:<id>` / `user:<uid>`, realtime policies.
      pgTAP: `040_apply_mutations.test.sql` (applied/duplicate/superseded/rejected, history rows, activity rows),
      `041_pull_changes.test.sql` (cursor, paging, tombstones, lost access).
- [ ] T2 Drift: tables per `04-sync-engine.md` §2 (+ `expense_parts`, `outbox`, `sync_cursors`, `sync_meta`,
      `pending_uploads`, FTS table created now, filled in phase 16), DAOs, schema v1 dump + migration test harness.
- [ ] T3 `RemoteApi` (only place calling RPCs), `SyncEngine` (push → pull loop, backoff, server-time offset, single
      flight), `MutationQueue`, `PullApplier`, connectivity watcher, Realtime subscriber, `workmanager` callback.
- [ ] T4 Repositories (read streams + write-with-outbox) for groups, members, expenses, payments, comments; Riverpod
      providers.
- [ ] T5 Sync status providers + `SyncMarker` wiring + basic "Sync & storage" screen (§9).
- [ ] T6 Unit suite TC-27-01…10 with `FakeRemoteApi`/`FakeClock`: ordering, idempotent retry, LWW both ways, clock
      offset, paging, tombstones, kill mid-page, rejected/poison, 401 handling, lost group access.
- [ ] T7 Integration (dev project): user A (app) offline-creates a group + expense, reconnects; harness user B
      edits the same expense earlier/later → expected winner, both versions in `record_versions`.

## Tests

TC-27-01…10, TC-1-02, TC-18-01 + SQL files above.

## Done when

Sync suite green, integration test green, coverage `lib/data/sync` ≥ 95 %.
