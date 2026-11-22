# Phase 19 — Hardening and polish

- Depends on: 13, 16, 17, 18 · Owner setup: 00 (`secrets/key.properties` for the release build) ·
  Branch: `phase/19-hardening`
- Goal: release quality — security, privacy, accessibility, performance, visual polish, docs, release build config.

## Tasks

- [ ] T1 Security: advisors clean; pgTAP "attack" file (non-member reads/writes via every RPC, forged member ids,
      claiming linked members, invite brute force, storage path traversal, oversized payloads); Edge Functions
      reject bad input; no secrets in repo (`git log -p | guard patterns` scan); migration 0013 for fixes + housekeeping cron.
- [ ] T2 Privacy: data inventory in `docs/PRIVACY.md` (what we store, why, retention, deletion); verify account
      deletion removes profile/photo/UPI/tokens and keeps others' balances (TC-B1-05/06 re-run).
- [ ] T3 Accessibility: TalkBack pass via semantics tests on every screen, 200 % text on every screen, contrast
      helper over all token pairs, focus order, reduced motion.
- [ ] T4 Visual polish: `ui-review` on every screen (light/dark/200 %), compare with Atlys refs, fix spacing/typo
      inconsistencies; refresh goldens deliberately.
- [ ] T5 Error/empty/loading/offline state audit for every screen (checklist in report).
- [ ] T6 Release build: `android/app/build.gradle.kts` signing config reading `../secrets/key.properties` if present
      (falls back to debug signing for CI), R8/minify + keep rules for Supabase/Firebase/json, version from pubspec,
      `flutter build apk --release --split-per-abi` and a universal APK; check size (< 40 MB universal).
- [ ] T7 Docs: README (features, screenshots from artefacts copied as small WebP into `docs/screenshots/` — only our
      app), self-hosting guide (`supabase/README.md`), CHANGELOG, About & licences screen (fonts, packages).
- [ ] T8 Full regression: every TC in `10-test-catalog.md` re-run; report counts.

## Done when

All gates green on release build; catalog has no `todo`/`fail` (only `pass`, `manual-opt`, or `needs-owner` with
open BLK).

> **Amendment (S-172, phase 16):** `0019_recurring.sql` redefined `public.apply_mutations` (routes
> `entity = 'recurring'` to `private.sync_apply_recurring`) and `public.pull_changes` (adds the
> `recurring_templates` rows). A migration that redefines either function must start from the 0019 body and keep
> those lines; `private.sync_apply_one` was not changed. Templates are a synced entity (`SyncEntity.recurring`).

> **Amendment (S-167, phase 15):** with 2,000 expenses, scrolling a group is smooth (0 missed frames in profile on the
> emulator) but the frame that opens the group page costs ~265 ms: the page is one scroll view (overlap layout), so
> the first 100 rows are built at once. Consider moving the group page to slivers (lazy rows) and re-run
> `tool/e2e/perf.ps1`. The WorkManager background sync (S-160) was only scheduled on the device in phase 15; trigger a
> real run once (`adb shell cmd jobscheduler run -f com.unizoy.splitify <job id>`) with the app closed.
