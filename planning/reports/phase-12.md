# Phase 12 report — Edit history, restore, comments (#20, #13 comments)

- Date: 2026-11-22 · Branch: `phase/12-history-comments` · Base: `origin/main` (phases 01–08); `origin/phase/09-balances-payments` merged in for payment history/comments
- Commits: `b3c3934..HEAD` · Status: done

## Summary

Every expense and payment now has an "Edit history": a timeline, newest first, of who added, edited, deleted or
restored it and exactly what changed (amount, description, date, category, who paid, each person's share, split
type, notes, receipt; payments: amount, from/to, method, date, note). Edits that lost a conflict stay visible, muted
and labelled "Not applied (a newer edit won)". Group settings → "Deleted items" lists the group's deleted expenses
and payments; any member can restore one. Expense and payment details have a comment thread with a chat-style
composer; comments work offline and only their author can delete them (enforced on the server).

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 History screen | done | `HistoryScreen` (`/expense/:id/history`, `/payment/:id/history`); versions fetched per record and cached in Drift `record_versions` (schema v2, S-130); pre-built diff builder reused; timeline cards with old → new diffs, per-member split rows, conflict versions muted (S-133); pending / offline / empty / not-found states |
| T2 Deleted items + restore | done | `DeletedItemsScreen` (`/groups/:id/deleted`) from group settings; restore = outbox `restore` → server `*_restored` activity + `restore` version (S-134) |
| T3 Comments | done | `CommentThread` + `CommentComposer` on expense and payment detail; outbox writes (offline queue), author-only delete (UI + server), BlobBackground empty state, read-only when archived (S-132); activity `comment_added` from `apply_mutations` |
| T4 pgTAP | done | `supabase/tests/060_history_comments.test.sql` 42/42 on dev: versions for insert/update/delete/restore/conflict_lost (expense + payment), restored activity, member-only RLS, comment author guard (`0015_history_comments.sql`, S-131) |

## Features delivered

- #20 Edit history and restore: history timeline for expenses and payments, deleted items with restore, undo on delete (phase 08) now backed by the same restore path.
- #13 comments: thread + composer on expense and payment details, offline-first, author-only delete; "Edited by … on …" line on expense detail (S-135).

## Tests

- New tests: unit/application 76 · widget 32 + fixed phase-08 detail tests · golden 28 (7 states × light/dark × text 1.0/2.0) + regenerated expense detail and group settings goldens · integration 2 files (TC-13-03 + TC-20-04 round trip on dev; device UI review) · SQL 1 file (42 assertions) · migration v1 → v2
- Coverage: see Gates (G2)
- Test IDs now passing: TC-13-03, TC-13-04, TC-20-01, TC-20-02, TC-20-03, TC-20-04
- Quarantined / skipped: none

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | | |
| G2 Tests | | |
| G3 Backend | | |
| G4 Build | | |
| G5 Device | | screenshots: `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-12\` |
| G6 Docs | | |

## UI review (≥ 8/10 every line)

Device captures (light / dark / text 200 %) in `splitify-artifacts\phase-12\` for history-timeline, history-offline,
deleted-items, deleted-items-empty, expense-comments; real-font goldens (`PLATFORM_GOLDENS=1`) for the same plus
history-payment, history-pending-empty and payment-detail-comments. Compared with Atlys 646 (history rows: caps
label, value right, dashed dividers, muted card) and 636 (comments: blob empty state, pill field, round send).

| Screen | Atlys feel | Type | Layout | Colour | Signature | Polish | States |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Edit history | 8 | 9 | 9 | 9 | 8 | 8 | 9 |
| Deleted items | 8 | 9 | 8 | 9 | 8 | 8 | 9 |
| Comments (expense + payment detail) | 9 | 9 | 9 | 9 | 9 | 8 | 9 |

Fixed during review: per-member diffs right-aligned (Wrap needed full width), "Deleted by you" lower-case.
Accepted: the conflict dot is low-contrast on purpose (muted version); the dark-mode status-bar icons in the device
captures follow the system bar timing of the capture script, not the screen (AppBar overlay style is per theme).

## Decisions made (S-0xx)

- S-130 history fetched per record + Drift cache (no `pull_changes` change) · S-131 comment author trigger ·
  S-132 comment thread/composer layout (no `+`) · S-133 history card content rules · S-134 Deleted items entry +
  restore rules · S-135 "Edited by" line.

## Blockers (BLK-xxx)

None.

## Learnings and skills added or changed

- LEARNINGS: PowerShell backticks in `python -c`, Drift schema-bump recipe, postgrest `.order` default, Wrap spaceBetween width, per-record fetch pattern.

## Owner actions

None required. (Reminder from the coordinator: users on ISPs that block `supabase.co` need a Supabase custom
domain/proxy before release.)

## Next phase

13 — Notifications and reminders (comment notifications start from `comment_added` activity).
