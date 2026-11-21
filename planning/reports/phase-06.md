# Phase 06 report — Local database and sync engine

- Date: 2026-11-21 · Branch: `phase/06-sync-engine` · Base: `origin/phase/04-backend-foundation`
- Commits: `bdcf1cf..HEAD` (3 commits) · Status: done-with-blockers (BLK-001), T5 still open

## Summary

The offline-first data layer now exists. Writes go to the local Drift database and the outbox in one
transaction. The sync engine pushes the outbox in order through `apply_mutations` and pulls pages through
`pull_changes`, which advances the cursors. Conflicts are settled on the server: the last save wins and both
versions stay in `record_versions`. None of this has been run against a live project yet (BLK-001); the SQL is
proven by pgTAP in CI and the client by unit tests against a scripted fake server.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Migration + pgTAP | done | `0009_sync.sql` (S-040), `040_apply_mutations` (35), `041_pull_changes` (29), green in CI `db` |
| T2 Drift | done | `schema.drift` (S-041), DAOs, schema v1 dump and verifier test |
| T3 RemoteApi / engine | done (glue open) | engine, queue, applier, server clock, triggers, Supabase API + Realtime nudges; connectivity/workmanager glue open (S-046) |
| T4 Repositories | done | groups, members, expenses, payments, comments + Riverpod providers (DB opened lazily, no bootstrap change) |
| T5 Sync status + screen | open | not built in the time budget (S-046) |
| T6 Unit suite | done | TC-27-01…10 + engine details, writes, remote mapping |
| T7 Integration (dev project) | SKIPPED (BLK-001) | no dev project / key |

## Features delivered

Rule 6 (offline-first) foundation: client UUIDs, ordered outbox, idempotent retries, last save wins with history,
tombstones, lost access. No user-facing screen yet.

## Tests

- New tests: unit 24 · SQL 64 assertions (2 files)
- Coverage: overall 94.5 % · sync 99.6 % · data 98.3 % · application 100 %
- Test IDs now passing: TC-27-01…10, TC-1-02; TC-18-01 partial (member/payment/comment activity not asserted yet)
- Skipped: T7 integration (BLK-001)

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | format, analyze (0 errors/warnings), guards OK |
| G2 Tests | PASS | 388 tests, coverage floors pass |
| G3 Backend | PASS (CI run 44926580278, commit bdcf1cf) | `supabase test db` green before the owner disabled CI on 2026-11-21; dev project SKIPPED (BLK-001) |
| G4 Build | not verified | local debug build stopped by the owner's time limit; CI disabled by owner 2026-11-21 |
| G5 Device | SKIPPED | no screen in this phase yet; T7 blocked |
| G6 Docs | PASS | this report, PROGRESS, decisions S-040…S-046, LEARNINGS |

## Decisions made (S-0xx)

S-040 migration number 0009 (phase 07 → 0010), S-041 Drift in SQL and a generic row codec, S-042 Realtime guarded in
CI, S-043 mutation_log keeps only applied/superseded results, S-044 fx_rate arrives as a JSON number, S-045 gap
between seq order and commit order, S-046 platform glue and T5 still open.

## Blockers (BLK-xxx)

BLK-001 (no Supabase dev project / MCP / publishable key): T7 and the live check of `SupabaseRemoteApi`/`SupabaseNudges`.

## Learnings and skills added or changed

Five `[phase 06]` lines in LEARNINGS (Drift generic writes, `.drift` + FTS5, generated schema helpers, build_runner
rewriting files, records and collection equality).

## Owner actions

None new. BLK-001 is still open.

## Next phase

Finish T5 (sync status providers, `SyncMarker` wiring, "Sync & storage" screen) and the S-046 glue after phase 05 is
merged. Then phase 07 uses migration `0010_group_rpcs.sql`.
