# Phase 15 report — Offline polish (#27)

- Date: 2026-11-22 · Branch: `phase/15-offline-polish` · Base: `origin/main` (phases 01–14); phase 17 merged in
  (`83e4931`)
- Commits: `8bd01fd..HEAD` · Status: done

## Summary

The app now syncs by itself: when the phone gets a network back, when it returns to the foreground, when Realtime
says a group changed, at start, and through WorkManager in the background (every 15 minutes, and once as soon as a
network is there when the app is closed with changes waiting). A session that the server still rejects after one
refresh signs the person out without losing their unsent changes; a different account signing in on the same phone
gets a clean database. "Sync & storage" lets people open a refused change to fix it (Edit), retry or discard it, and
shows photos waiting to upload (skipped ones can be retried). When someone else's newer edit wins, a one-time
snackbar says so and the edit history shows both versions. Group cards on the Groups tab now carry the "not synced
yet" marker when any of the group's records is pending. Long group lists show 100 records at a time ("Show N older").

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| S-046 amendment | done | `SyncBinding` (connectivity, resume, Realtime topics per group, start), WorkManager periodic + one-off, worker → app port, 401 → sign-out keeping data, owner check (S-160, S-161) |
| T1 Write-path audit | done | Every user write → `LocalWriter` → outbox; online-only actions listed and all say "Needs internet"; delete account checks the network first (S-162) |
| T2 Marker audit | done | Groups home cards now marked for any pending row of the group (one query); everything else was already marked (S-162) |
| T3 Sync & storage | done | Edit / Retry / Discard for refused changes, Photos section (waiting / retrying / skipped + Retry), debug log lists uploads (S-163) |
| T4 Conflict UX | done | Snackbar from `SyncBinding` (S-164); history already shows the losing version (phase 12) |
| T5 Airplane e2e TC-27-11 (+ phase 10 receipts offline) | done | `tool/e2e/airplane.ps1` + `integration_test/offline_airplane_test.dart` A1–A3, real airplane mode and a real app kill: 5 expenses (one with a receipt photo, real compression), edit, delete, payment, comment offline → killed → relaunched offline with all 9 changes, the photo and the markers → airplane mode off → synced by the connectivity trigger in 6.4 s (no "Sync now"), photo uploaded after its row, user B saw exactly the phone's rows (deleted one as a tombstone) and downloaded the receipt; markers gone (S-165) |
| T6 Kill mid-push TC-27-12 | done | K1–K2: 300 changes, killed with 250 queued while the server already had 100 (one batch acknowledged, one applied but never acknowledged); relaunch → 300 rows, 300 `insert` versions, server order = phone order. An earlier run killed with the first batch in flight (300 queued, server 50) and was checked by SQL: same result |
| T7 Performance | done (numbers) | 2,000 expenses, emulator x86_64, profile: flinging the list 55 frames, build p90 6.5 ms, raster p90 6.8 ms, 0 missed frames (60 fps); ledger load + balances median 31 ms (max 35, cold 59) — target < 200 ms met; a local write until the balances include it 229 ms; release cold start 1.23–1.55 s (median 1.34 s) to the first screen, 4.6 s on the first launch after install (dex/AOT setup) — target < 2.5 s met. Hot spot fixed: the group list built every row of every record (S-167, pages of 100). Still open: the frame that opens a 2,000-expense group costs ~265 ms (page + 100 rows at once) — acceptable on the emulator, phase 19 can move the page to slivers. Cold start was measured signed out (the perf drive uninstalls the app) |

## Features delivered

- #27 Offline entry: automatic sync triggers, background sync, offline audit, Sync & storage complete, conflict UX.
- #29 Receipt photos: waiting/failed uploads visible and retryable; real airplane-mode run (T5).

## Tests

- New: unit/widget ~45 (sync binding, background port, session expiry, repository owner/uploads/waiting, remote
  error mapping, sync texts, uploads card, Edit, Groups card marker, delete-account offline, list paging) · golden
  8 new (`sync_storage_uploads`, `sync_storage_skipped` light/dark × 1.0/2.0) + 2 updated (`sync_storage_issues`) ·
  integration/e2e 2 files (`offline_airplane_test.dart` 6 stages, `perf_test.dart` + `test_driver/perf_driver.dart`).
- Coverage: overall 96.6 % · sync 99.5 % · data 93.3 % · domain 100 % · money 100 % (all floors met).
- Test IDs now passing: TC-27-11, TC-27-12, TC-27-13 (device), TC-27-16..19 (unit/widget/golden), TC-27-20 measured.
- Quarantined / skipped: none. WorkManager runs were not triggered on the device (only scheduled); the worker path is
  covered by `background_sync_test.dart` (port round trip) and shares the foreground engine wiring.

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | `dart format --set-exit-if-changed` 0 changes; `flutter analyze --no-fatal-infos` 0 errors / 0 warnings (infos only); `dart run tool/guards.dart` OK |
| G2 Tests | PASS | `flutter test --coverage --exclude-tags device,needs-owner,quarantine`: 2,526 passed, 0 failed; coverage overall 96.6 %, sync 99.5 % (floor 95), data 93.3 %, domain 100 %, money 100 %, application 97.1 %, presentation 96.4 %, core 96.6 % |
| G3 Backend | N/A | no migration (0018 unused), no Edge Function change |
| G4 Build | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` (also every e2e stage and the release x64 build for cold start) |
| G5 Device | PASS | emulator-5554 + dev project with `PIN_HOST_IP`: `tool/e2e/airplane.ps1` A1–A3, K1–K2, C1 all green; `tool/e2e/perf.ps1` numbers; UI review of the new states (Sync & storage photos/Edit, group card marker, conflict snackbar, history) on device light/dark + goldens light/dark × 1.0/2.0 — every rubric line ≥ 8. Screenshots: `splitify-artifacts\phase-15\` (`airplane-*`, `conflict-*`, `perf-cold-start.png`) |
| G6 Docs | PASS | phase boxes, decisions S-160..167, test catalog TC-27-11..20, LEARNINGS, PROGRESS, phase 19 amendment |

## Decisions made (S-0xx)

S-160 sync triggers + background sync design · S-161 401 sign-out keeps data, owner check, offline refresh ·
S-162 offline audit results · S-163 Sync & storage Edit + photos · S-164 superseded snackbar · S-165 staged airplane
e2e · S-166 `flutter_driver` dev dependency · S-167 paged group expense list.

## Blockers (BLK-xxx)

None new.

## Learnings and skills added or changed

See LEARNINGS `[phase 15]`: `flutter test` uninstalls the app after integration runs (`--no-uninstall`), airplane
mode driving from the PC, container disposal vs. in-flight Drift batches, gotrue auto refresh in background
isolates, shell widgets in widget tests.

## Owner actions

- Optional, before release: users on ISPs that block `*.supabase.co` need a Supabase custom domain or proxy.

## Next phase

16 (Recurring bills and search) — rebase onto this branch: Drift unchanged (v5), no migration used.
