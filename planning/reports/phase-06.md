# Phase 06 report — Local database and sync engine

- Date: 2026-11-21 · Branch: `phase/06-sync-engine` · Base: `origin/phase/04-backend-foundation`
- Commits: `bdcf1cf..HEAD` · Status: **done** (2026-11-22 follow-up: T5 + T7 finished; S-046 platform glue moved to phase 15)

## Summary

The offline-first data layer now exists. Writes go to the local Drift database and the outbox in one
transaction. The sync engine pushes the outbox in order through `apply_mutations` and pulls pages through
`pull_changes`, which advances the cursors. Conflicts are settled on the server: the last save wins and both
versions stay in `record_versions`. The SQL is proven by pgTAP (CI and dev), the client by unit tests against a
scripted fake server, and since 2026-11-22 end to end on the dev project (T7). Account → "Sync & storage" shows the
state and lets people retry or discard refused changes.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Migration + pgTAP | done | `0009_sync.sql` (S-040), `040_apply_mutations` (35), `041_pull_changes` (29), green in CI `db` |
| T2 Drift | done | `schema.drift` (S-041), DAOs, schema v1 dump and verifier test |
| T3 RemoteApi / engine | done (glue open) | engine, queue, applier, server clock, triggers, Supabase API + Realtime nudges; automatic triggers (connectivity, resume, Realtime start, workmanager) moved to phase 15 (Amendment S-046) |
| T4 Repositories | done | groups, members, expenses, payments, comments + Riverpod providers (DB opened lazily, no bootstrap change) |
| T5 Sync status + screen | done (2026-11-22) | `SyncRepository` + `syncStatusProvider`/`syncIssuesProvider`/`anyUnsyncedProvider`/`groupUnsyncedProvider`, "Sync & storage" `/account/sync` (S-212), marker under the Account wallet (S-213) |
| T6 Unit suite | done | TC-27-01…10 + engine details, writes, remote mapping |
| T7 Integration (dev project) | done (2026-11-22) | `integration_test/sync_offline_test.dart` on emulator-5554: A offline group + expense → reconnect → B joins + sees both via `pull_changes`; A's older offline edit superseded, `record_versions` = insert, update, conflict_lost (S-211) |

## Features delivered

Rule 6 (offline-first) foundation: client UUIDs, ordered outbox, idempotent retries, last save wins with history,
tombstones, lost access. "Sync & storage" diagnostics screen (04 §9) and the rule 3 marker on the Account wallet.

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
| G3 Backend | PASS (CI run 44926580278; dev 2026-11-21: 0009 applied, 040 35/35, 041 29/29) | `supabase test db` green before the owner disabled CI on 2026-11-21; dev project SKIPPED (BLK-001) |
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

None new. BLK-001 closed 2026-11-21.

## Next phase

07 Groups, members, invites (migration `0010_groups_members`, already on dev). Group cards can use
`groupUnsyncedProvider`. Automatic sync triggers (S-046 glue) are carried by the phase 15 Amendment unless an
earlier phase needs them.

## Merge sanity 2026-11-21 (05 + 06 + 3 prep branches)

pub get OK; analyze 0 errors/warnings (infos only); guards OK; format 0 changed; `flutter test` (no device/needs-owner/quarantine) 635 passed. No fixes needed. Not run this session: coverage_check, debug APK, device T7, T5 screen (owner deadline).

## Follow-up 2026-11-22 (T5, T7, phase 05 wiring)

- **T5:** "Sync & storage" screen (status card, Sync now, Needs attention cards with Retry/Discard + confirm, Export
  debug log via share sheet), settings row with live value, `SyncMarker` under the Account wallet. Goldens light/dark
  × text 1.0/2.0 for synced and issues states (16 CI goldens), real-font review OK.
- **Sign-out (phase 05 note):** `AccountActions.signOut/deleteAccount` push the outbox first (10 s best effort) and
  `LocalWipe` now wipes the Drift DB (S-210). `remoteApiProvider` defaults to an offline-like API and bootstrap
  injects the Supabase one via `appOverrides()` (S-069).
- **T7:** passes on the dev project (see table). Needs `PIN_HOST_IP` on this PC: the ISP DNS-blocks `*.supabase.co`
  for plain DNS (S-214, LEARNINGS).
- **Fixes found on the device:** main `AndroidManifest.xml` lacked INTERNET (release APKs could not reach Supabase);
  `CapsuleNavBar` spring overshoot overflowed by 1–2 px while tabs swap (now clipped, goldens unchanged).

### UI review (emulator, debug run via `capture_markers.ps1`; screenshots in `splitify-artifacts\phase-06\`)

| Screen | Atlys feel | Type | Layout | Colour | Signature | Polish | States |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Sync & storage (synced) light/dark | 8 | 9 | 9 | 9 | 8 | 9 | 9 |
| Sync & storage (issues) light/dark/200 % | 8 | 9 | 9 | 9 | 8 | 8 | 9 |

Accepted: sub-page style like Appearance/Delete account (no hero); `PillButton` icon does not scale with text
(component behaviour, phase 02).

### Gates (follow-up)

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | format 0 changed, analyze 0 errors/warnings, guards OK |
| G2 Tests | PASS | 661 tests (`--concurrency=1`; parallel runs hit "Connection closed before test suite loaded" under PC load), coverage overall 94.4 % · sync 100 % · data 87.4 % · application 97.5 % · presentation 93.4 % |
| G3 Backend | PASS (no SQL/function change) | live RPCs exercised by T7; security advisors unchanged (S-066 WARNs, leaked-password protection = owner setting) |
| G4 Build | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` |
| G5 Device | PASS | `sync_offline_test.dart` 1/1, `sync_storage_review_test.dart` 1/1 + screenshots, UI scores ≥ 8 |
| G6 Docs | PASS | phase ticks, catalog (TC-27-14/15), S-069 + S-210..S-214, LEARNINGS, skills (emulator-e2e, ui-review script) |
