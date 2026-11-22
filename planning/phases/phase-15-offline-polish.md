# Phase 15 — Offline polish (#27)

- Depends on: 10, 11, 12, 14 · Owner setup: 00 · Branch: `phase/15-offline-polish`
- Goal: prove and polish offline behaviour across every feature built so far.
- Read first: `04-sync-engine.md`, `08-feature-specs.md` #27, `emulator-e2e` skill §5.

## Tasks

- [ ] T1 Audit every write path: goes through outbox; online-only actions show "This needs internet".
- [ ] T2 Audit every balance/list/card: SyncMarker on pending/failed data; Groups/Account totals marked.
- [ ] T3 Sync & storage screen complete: failed mutations with Edit / Retry / Discard, export debug log.
- [ ] T4 Conflict UX: superseded snackbar, history shows both versions (TC-27-13).
- [ ] T5 `tool/e2e/airplane.ps1` helpers; E2E TC-27-11: airplane mode → add 5 expenses, edit 1, delete 1, record a
      payment, add a comment → kill app → relaunch offline (data still there, markers on) → online → all synced,
      harness B sees exact server state, markers cleared.
- [ ] T6 TC-27-12: force-stop during a 300-mutation push → relaunch → no duplicates, order kept.
- [ ] T7 Performance: seed 2,000 expenses in one group (harness) → list scroll 60 fps in profile mode
      (`flutter drive --profile` timeline summary), balance recompute < 200 ms, cold start < 2.5 s on emulator;
      fix hot spots (indexes, isolates for big recomputes).

## Tests

TC-27-11…13 + performance numbers recorded in the report.

> **Amendment (S-046, 2026-11-22):** phase 06 left the automatic sync triggers unbuilt: connectivity watcher
> (`connectivity_plus` → `SyncTriggers.online`), app-resume trigger, Realtime `ChangeNudges.watchGroups` for the
> user's groups, the `workmanager` periodic/one-off task, and sign-out on a second 401 (`SyncEngine.onSignedOut`).
> Build them here if no earlier phase has. Device tests reach the dev project only with `PIN_HOST_IP` (S-214).

> **Amendment (S-113/S-114, phase 10):** photo uploads (`pending_uploads`) run inside every sync (`afterPush`), so the
> S-046 triggers and the WorkManager job also upload photos. Still open for this phase: show waiting/failed uploads
> (`pending_uploads`, attempts ≥ 8 = skipped) on "Sync & storage", and the real airplane-mode run of the phase 10
> receipt scenario (`integration_test/receipts_offline_upload_test.dart` switches the remotes off instead, S-119).
