# Phase 18 report — Import from Splitwise, app lock, home-screen widget

- Date: 2026-11-22 · Branch: `phase/18-extras` · Base: `origin/main` (01–14, then 17, 15 and 16 merged in during the phase)
- Commits: `8a504ba..HEAD` · Status: done

## Summary

People can bring a Splitwise group over: pick the "Export as spreadsheet" CSV (or a Splitify export), match each
person to a member / a new name-only member / skip, check a preview with the file's own "Total balance" rows, and
import — offline too, through the normal outbox, with one "imported expenses from Splitwise" entry in the activity
feed instead of hundreds, and a "Delete this import" undo. Splitify can be locked with the phone's fingerprint or
screen lock (1/5/15 minutes, always on start, hidden in recents), and a 2×2 / 4×2 home-screen widget shows the overall
balance, "Updated … ago" or "Not synced yet", with a "Hide amounts" option.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 X1 parser | done (pre-built) | + public cell helpers, Notes column, Splitify-format reader (`import_csv.dart`) |
| T2 X1 reconstruction | done (pre-built) | + notes pass-through, D-016 keys kept, payment notes |
| T3 X1 UI + server | done | File · (Group) · People · Preview · Done; entry points group settings (next to Export CSV) + Account; `import_batches` (Drift **v7**, after phase 16's v6); 0021 trigger (S-190) |
| T4 X2 app lock | done | `local_auth` (device credential fallback), lock gate + screen, Security settings, `FLAG_SECURE` + recents channel (S-194) |
| T5 X3 widget | done | RemoteViews `BalanceWidgetSmall`/`Wide`, values from Dart via `home_widget` (also after phase 15's WorkManager syncs), Hide amounts, tap opens app (S-195) |

## Features delivered

- X1 Import from Splitwise (and from Splitify's own export, TC-22-02 / S-184).
- X2 App lock.
- X3 Home-screen widget.

## Tests

- New tests: unit ~120 (import reader/mapping/rows/repository incl. TC-22-02 round trip, lock policy + controller,
  widget data + sync, activity import rows, device-auth/window seams, Drift v6 migration) · widget 4 (TC-X1-03 full
  flow) · golden 44 (11 scenarios × light/dark × 1.0/2.0) · integration 2 (`extras_import_widget_test.dart`,
  `app_lock_test.dart`) · SQL 13 (`supabase/tests/180_import.test.sql`)
- Coverage: overall 95.7 % · presentation 95.3 · core 97.0 · application 95.4 · data 94.1 · sync 99.5 · domain 98.5 · money 100 (all floors PASS)
- Test IDs now passing: TC-X1-01…04, TC-22-02, TC-X2-01, TC-X2-02 (device PIN instead of a fingerprint), TC-X3-01, TC-X3-02
- Quarantined / skipped: `app_lock_test.dart` is skipped unless `LOCK_E2E=true` (needs the host script that types the PIN)

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | `dart format --set-exit-if-changed` 0 changes, `flutter analyze --no-fatal-infos` 0 errors/warnings, `dart run tool/guards.dart` OK |
| G2 Tests | PASS | full suite after merging main (15, 16, 17): 2880 passed; the 8 phase-14 expense-detail goldens failed on `main`'s missing phase-16 repeat-rule override (`noRepeat('e2')` added in `currency_golden_test.dart`, file re-run 56/56); `tool/coverage_check.dart` all floors PASS |
| G3 Backend | PASS | 0021 dry-run + pgTAP `180_import.test.sql` 13/13 in one rolled-back transaction, then `apply_migration`; re-checked after phase 16's 0019 (8/8 core assertions); security advisors unchanged (no new findings); no Edge Function touched (deno SKIPPED, n/a) |
| G4 Build | G4_RESULT | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` |
| G5 Device | PASS | emulator-5554 (lock held 15:43–16:30): `extras_import_widget_test.dart` PASS (TC-X1-04, TC-X3-02, incl. Delete this import); `run_lock_e2e.ps1` PASS (TC-X2-02: PIN unlock on start, re-lock after background + 2 min, FLAG_SECURE on the window, PIN cleared); widget pinned on the home screen light/dark (first run showed "Can't load widget" → `<View>` spacers fixed, re-run renders). Screens: `splitify-artifacts\phase-18\` (import-*-light/dark/text200, widget-home-*). UI review ≥ 8/10 on every rubric line: import 9, lock screen 8, security 8, widget settings 8, home widget 8 (known nit: after a theme switch the status colour follows the next redraw) |
| G6 Docs | PASS | tasks ticked, test catalog, S-190…S-195, LEARNINGS (+8 lines), emulator-e2e skill (PIN procedure), PROGRESS, this report |

## Decisions made (S-0xx)

S-190 import logging/undo through a split_values note + 0021 trigger and a local batch table · S-191 mapping and skip
rules · S-192 reading Splitify's own export · S-193 file step, limits and entry points · S-194 app lock behaviour ·
S-195 RemoteViews widget with Dart-computed values.

## Blockers (BLK-xxx)

None new.

## Learnings and skills added or changed

Six lines in `planning/LEARNINGS.md` (summary-activity trigger pattern, Dart escapes through scripts, heredoc batches,
home_widget Int/Long, FLAG_SECURE vs screencap, Celebration sizing / StickyActionBar secondary width).
`tool/e2e/run_lock_e2e.ps1` drives TC-X2-02 (device PIN on, answers prompts, PIN off).

## Owner actions

- Optional: none for this phase. (Release note from the coordinator still stands: users on ISPs that block
  `supabase.co` need a Supabase custom domain or proxy before release.)

## Next phase

19 — Hardening and polish (depends on 13, 16, 17, 18). Phases 15/16 merge before it; the Drift version of this phase
(v6) must be renumbered if one of them also bumped it (keep every `if (from < N)` step).
