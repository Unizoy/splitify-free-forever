# Phase 15 report — Offline polish (#27)

- Date: 2026-11-22 · Branch: `phase/15-offline-polish` · Base: `origin/main` (phases 01–14); phase 17 merged in
  (`83e4931`)
- Commits: `8bd01fd..HEAD` · Status: DRAFT

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
| T5 Airplane e2e TC-27-11 (+ phase 10 receipts offline) | TBD | |
| T6 Kill mid-push TC-27-12 | TBD | |
| T7 Performance | TBD | |

## Features delivered

- #27 Offline entry: automatic sync triggers, background sync, offline audit, Sync & storage complete, conflict UX.
- #29 Receipt photos: waiting/failed uploads visible and retryable; real airplane-mode run (T5).

## Tests

- New: unit/widget ~45 (sync binding, background port, session expiry, repository owner/uploads/waiting, remote
  error mapping, sync texts, uploads card, Edit, Groups card marker, delete-account offline, list paging) · golden
  12 (`sync_storage_uploads`, `sync_storage_skipped` light/dark × 1.0/2.0; `sync_storage_issues` updated) ·
  integration 2 files (`offline_airplane_test.dart` 6 stages, `perf_test.dart`).
- TBD

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | TBD | |
| G2 Tests | TBD | |
| G3 Backend | N/A | no migration (0018 unused), no Edge Function change |
| G4 Build | TBD | |
| G5 Device | TBD | |
| G6 Docs | TBD | |

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
