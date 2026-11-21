# Phase 12 report — Edit history, restore, comments (#20, #13 comments)

- Date: 2026-11-22 · Branch: `phase/12-history-comments` · Base: `origin/main` (phases 01–08); `origin/phase/09-balances-payments` merged in twice (055599d, 99daefb) for payment history/comments — merge phase 09 into main first
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
- Coverage (full run on the merged branch): overall 96.4 % · money 100 % · sync 100 % · domain 100 % · data 90.3 % · application 99.1 % · presentation 95.9 %
- Test IDs now passing: TC-13-03, TC-13-04, TC-20-01, TC-20-02, TC-20-03, TC-20-04
- Quarantined / skipped: none

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | `dart format --set-exit-if-changed` 0 changes; `flutter analyze --no-fatal-infos` 0 errors/warnings; `dart run tool/guards.dart` OK |
| G2 Tests | PASS | 1521 tests: 1519 passed in the full run + `stable_hash_test.dart` failed to load once under load (rerun: 2/2 pass); coverage overall 96.4 %, money 100, sync 100, domain 100, core 96.6, data 90.3, application 99.1, presentation 95.9 (all floors met); `flutter test --coverage --exclude-tags device,needs-owner,quarantine --concurrency=1` + `tool/coverage_check.dart` |
| G3 Backend | PASS | `0015_history_comments` applied on dev; `060_history_comments.test.sql` 42/42 (rolled back); advisors: nothing new (12 SECURITY DEFINER WARNs accepted in S-066, leaked-password protection is an owner dashboard setting); no Edge Function touched (deno SKIPPED: not needed) |
| G4 Build | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` |
| G5 Device | PASS | `integration_test/history_comments_test.dart` on emulator-5554 (TC-13-03 + TC-20-04; run before and after the phase 09 merge); UI review `integration_test/ui_review_history_test.dart`, 18 shots in `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-12\` |
| G6 Docs | PASS | phase file ticked, PROGRESS, test catalog, S-130..S-135, LEARNINGS, this report |

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
Accepted: the conflict dot is low-contrast on purpose (muted version). One dark device capture caught the status bar
before it switched to light icons (capture timing; the payment-comments dark capture shows it correctly).

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
