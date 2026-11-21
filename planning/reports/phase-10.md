# Phase 10 report — Multiple payers, IOU, receipt photos (#10, #11, #29)

- Date: 2026-11-22 · Branch: `phase/10-payers-iou-receipts` · Base: `origin/main` (phases 01–08); `origin/phase/09-balances-payments` merged in while 09 was still in progress (c2f188d) — see "Next phase"
- Commits: `2555fae..HEAD` · Status: done

## Summary

An expense can now be paid by several people: "Multiple people" on the Paid-by step takes an amount per person
with a live "₹400 left / over / covered" line, and the review reads "Paid by **you and Asha**". "Record a loan"
(group hero) saves "I lent / I borrowed" as an IOU that shows a LOAN tag in lists, Lent by / Borrowed by on the
detail, and never counts as spending. Every expense can carry one receipt photo (camera or the Android photo
picker), compressed on the phone, saved offline and uploaded by a queue once the expense is on the server; the
detail shows it with a full-screen zoomable viewer (replace / remove). Groups can use a photo cover the same way.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Multiple payers | done | `ExpenseDraft` payer API (`withMultiplePayers`, `payersCheck`, …), `PayerAmounts` card, sticky-bar footer, review sentence + list captions (S-115) |
| T2 IOU | done | `LoanScreen` `/loan/new?group=&with=`, `/loan/:id/edit`; group hero action; LOAN tag + loan icon in lists; loan detail; excluded from totals (phase 09's `group_totals.dart`, TC-21-01 green after the merge) and from the last-category suggestion (S-116); friend-page entry is phase 11's (amendment) |
| T3 Receipts | done | picker + compression (S-110, S-111), `MediaFiles` + `pending_uploads` + `UploadQueue` in the engine's `afterPush` (S-113, S-114), receipt field, detail card, viewer (S-117), signed-URL cache; group cover photos (S-073 amendment) |
| T4 Storage tests | done | `023_storage.test.sql` 24/24, new `060_file_paths.test.sql` 12/12 for migration `0013_file_paths.sql` (S-112, S-118) |

## Features delivered

- #10 Multiple payers: editor, validation, storage (`payers` with only people who paid), captions, review sentence.
- #11 IOU / loan: form, list tag, detail, edit; spending totals and charts already skip `kind = 'iou'`.
- #29 Receipt photo: pick (camera / photo picker), compress, offline queue, upload after the record syncs, local
  thumbnail, full-screen viewer, replace / remove, signed URLs; group photo covers.

## Tests

- New tests: unit/data ≈ 110 (media files, remote, upload queue, media repository, afterPush, compression,
  payers, loans, receipts in the controller) · widget ≈ 80 (loan screen, receipt widgets, loans in lists, photo
  widgets, cover photo) · golden 48 (12 states × light/dark × text 1.0/2.0) + refreshed expense/group goldens ·
  SQL 2 files (24 + 12) · integration 2 (e2e receipts/loan/cover; UI review captures)
- Coverage: see Gates (G2)
- Test IDs now passing: TC-10-02, TC-11-02, TC-29-01, TC-29-02, TC-29-03
- Quarantined / skipped: none

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | format clean, analyze 0 errors/warnings, guards OK |
| G2 Tests | (filled at ship) | |
| G3 Backend | PASS | `0013_file_paths` applied to dev; pgTAP `023` 24/24, `060` 12/12; security advisors: no new findings (only the accepted RPC/`join_attempts`/leaked-password items) |
| G4 Build | (filled at ship) | |
| G5 Device | PASS | `integration_test/receipts_offline_upload_test.dart` on emulator-5554 (2026-11-22, PIN_HOST_IP): real compression 3000×2000 → 1599×1066, 314,616 B (thumb 480×320); offline expense paid by me + Asha with receipt, loan and cover photo queued; online sync pushed rows, uploaded 2 photos, server rows match (payers, kind iou), user B (claimed Asha) fetched receipt and cover via signed URLs. UI review captures (9 screens × light/dark/200 %) in `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-10\` |
| G6 Docs | PASS | phase ticks, decisions S-110..S-119, catalog, learnings, amendments to phases 11 and 15 |

## UI review (D-018, rubric ≥ 8 on every line, light and dark)

Device captures (`capture_markers.ps1`, light / dark / 200 %) in `splitify-artifacts\phase-10\` plus real-font
goldens (`test/goldens/goldens/windows/phase10_*`, `photo_covers_*`). Compared with Atlys 532 (option tiles,
stepper), 534 (segmented pill), 455/712 (photo hero, sheet).

| Screen | Atlys feel | Type | Layout | Colour | Signature | Polish | States |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Paid by · Multiple people (card + footer) | 9 | 9 | 8 | 9 | 8 | 8 | 9 |
| Review "Paid by you and Asha" | 9 | 9 | 9 | 9 | 8 | 9 | 8 |
| Details · receipt tile / photo row | 8 | 9 | 9 | 9 | 9 (dashed) | 8 | 9 |
| Record a loan (lent / borrowed / no others) | 9 | 9 | 8 | 9 | 9 (serif + pill) | 8 | 9 |
| Expense list with LOAN tag / receipt badge | 9 | 9 | 9 | 9 | 8 | 8 | 8 |
| Loan detail / receipt detail | 9 | 9 | 8 | 9 | 9 (hero + sheet) | 8 | 9 |
| Photo viewer | 8 | 8 | 9 | 9 | 8 | 9 | 8 |
| Group form photo cover, photo hero + card | 9 | 9 | 8 | 9 | 9 | 8 | 8 |

Fixed during review: photo viewer drew in an 88 px strip (Stack sizing); loan direction pill broke "I borrowe-d" at
200 % (clamped, icons dropped at large text); loan keypad hid the form at 200 % (collapsible keypad with Done; with the keypad up at large text the subtitle steps aside and the Done bar is clamped like the keypad);
payer card opened below the fold (scrolls into view). Accepted: at 200 % the step header labels and the
pre-existing person rows of the expense detail ("Rahul Meht a") wrap — phase 08 components, noted for phase 19.

## Decisions made (S-0xx)

S-110 photo picker packages · S-111 compression ladder · S-112 path checks (0013) · S-113 upload queue in
`afterPush` · S-114 local photo files + signed-URL cache · S-115 multi-payer UX · S-116 loan form · S-117 receipt UI ·
S-118 storage delete tests · S-119 e2e offline switches.

## Blockers (BLK-xxx)

None.

## Learnings and skills added or changed

- `planning/LEARNINGS.md` phase 10 lines (storage delete guard, pgTAP wrapper, compress scaling, file images in
  goldens, Stack sizing, path_provider in tests, sheet timing, merging an in-progress sibling).
- `.claude/skills/supabase-dev/scripts/tapify.py` + SKILL.md step: wraps a pgTAP file for MCP `execute_sql`.

## Owner actions

None required. (Reminder from the coordinator: users on ISPs that block `supabase.co` need a Supabase custom
domain or proxy before release — photo downloads use the same host.)

## Next phase

Phase 11 (friends, simplify, UPI): add "Record a loan" on friend pages with `ExpenseRoutes.addLoan(directGroupId,
withMember:)`. Phase 09 was merged in while still in progress; when 09 lands on `main`, merge `origin/main` here
again (expect golden conflicts in groups/expense goldens: take main's, then regenerate).
