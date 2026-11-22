# Phase 19 — Hardening and polish

- Depends on: 13, 16, 17, 18, 18b · Owner setup: 00 (`secrets/key.properties` for the release build) ·
  Branch: `phase/19-hardening`
- Goal: release quality — security, privacy, accessibility, performance, visual polish, docs, release build config.

## Tasks

- [x] T1 Security: advisors clean; pgTAP "attack" file (non-member reads/writes via every RPC, forged member ids,
      claiming linked members, invite brute force, storage path traversal, oversized payloads); Edge Functions
      reject bad input; no secrets in repo (`git log -p | guard patterns` scan); migration 0013 for fixes + housekeeping cron.
- [x] T2 Privacy: data inventory in `docs/PRIVACY.md` (what we store, why, retention, deletion); verify account
      deletion removes profile/photo/UPI/tokens and keeps others' balances (TC-B1-05/06 re-run).
- [x] T3 Accessibility: TalkBack pass via semantics tests on every screen, 200 % text on every screen, contrast
      helper over all token pairs, focus order, reduced motion.
- [ ] T4 Visual polish: `ui-review` on every screen (light/dark/200 %), compare with Atlys refs, fix spacing/typo
      inconsistencies; refresh goldens deliberately.
- [x] T5 Error/empty/loading/offline state audit for every screen (checklist in report).
- [x] T6 Release build: `android/app/build.gradle.kts` signing config reading `../secrets/key.properties` if present
      (falls back to debug signing for CI), R8/minify + keep rules for Supabase/Firebase/json, version from pubspec,
      `flutter build apk --release --split-per-abi` and a universal APK; check size (< 40 MB universal).
- [x] T7 Docs: README (features, screenshots from artefacts copied as small WebP into `docs/screenshots/` — only our
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

> **Amendment (D-025, 2026-11-22):** also harden phase 18b's payment bubble: privacy review of the notification
> listener / accessibility service (allow-list only, no raw text stored, PIN fields never read), battery check,
> overlay never blocks the UPI app's Pay/PIN buttons, and its strings/goldens in the final polish.

## Amendment (S-226, phase 18b)

Migration 0023 redefines `public.apply_mutations` (0019 body + `source = 'capture'` expense mutations →
`private.sync_apply_capture`). If this phase redefines `apply_mutations` again, keep both the `recurring` and the
`capture` dispatch lines. Also audit the payment-bubble feature (X4): services off by default, no raw text stored.

> **Done (phase 19, S-208):** the D-025 / S-226 amendments — payment-bubble privacy review (allow-list before any
> read, parsed fields only, PIN never read), battery (event-driven, no polling/foreground service), overlay (right
> edge, hidden on PIN screens, never over the bottom Pay button); hardening: sign-out switches the feature off,
> Amazon's shopping app starts off; its goldens pass the a11y sweep; `docs/PRIVACY.md` has the section. 0022/0024
> do not touch `apply_mutations` (0023's capture dispatch stays). S-167 slivers (S-204) and the real WorkManager run
> (S-160, `tool/e2e/background_sync.ps1`) are done.

