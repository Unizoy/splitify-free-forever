# Phase 12 — Edit history, restore, comments (#20, #13 comments)

- Depends on: 09 · Owner setup: 00 · Branch: `phase/12-history-comments`
- Read first: `08-feature-specs.md` #20 #13, `03-backend.md` (`record_versions`, comments).

## Tasks

- [x] T1 History screen for expenses and payments: timeline from `record_versions` (pulled + cached), field diff
      builder (description, amount, currency, date, category, payers, shares, split type, notes, receipt),
      conflict versions labelled "Not applied (a newer edit won)".
- [x] T2 Deleted items view per group + restore (op `restore`), activity `*_restored`.
- [x] T3 Comments on expense/payment detail: thread, composer (636 style), offline queue, author-only delete,
      BlobBackground empty state; activity `comment_added`.
- [x] T4 pgTAP: versions for every op incl. `conflict_lost`; comment delete only by author.

## Tests

TC-20-01…04, TC-13-03, TC-13-04.

Pre-built (branch prep/history-diff): T1 diff builder only, no UI — `lib/features/history/domain/version_diff.dart`
(`buildHistory(kind, versions)` → `HistoryEntry` per version: op create/update/delete/restore/conflictLost, who/when,
`deleted`, `muted` for `conflict_lost`, `FieldChange`s with `Money`/UTC date/member-id values and per-member changes
for payers/shares/split values), tests `test/features/history/domain/version_diff_test.dart` (TC-20-02, 100 % lines).
Still to do for T1: pull + Drift cache of `record_versions` (no Drift mirror exists yet), the screen. Decisions S-096..S-098.
