# Phase 18 report — Import from Splitwise, app lock, home-screen widget

- Date: 2026-11-22 · Branch: `phase/18-extras` · Base: `origin/main` (phases 01–14 + 17 merged in)
- Commits: `8a504ba..HEAD` · Status: GATES_STATUS

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
| T3 X1 UI + server | done | File · (Group) · People · Preview · Done; entry points group settings (next to Export CSV) + Account; `import_batches` (Drift v6); 0021 trigger (S-190) |
| T4 X2 app lock | done | `local_auth` (device credential fallback), lock gate + screen, Security settings, `FLAG_SECURE` + recents channel (S-194) |
| T5 X3 widget | done | RemoteViews `BalanceWidgetSmall`/`Wide`, values from Dart via `home_widget`, Hide amounts, tap opens app (S-195) |

## Features delivered

- X1 Import from Splitwise (and from Splitify's own export, TC-22-02 / S-184).
- X2 App lock.
- X3 Home-screen widget.

## Tests

TESTS_SECTION

## Gates

GATES_TABLE

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
