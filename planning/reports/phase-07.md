# Phase 07 report — Groups, name-only members, invites

- Date: 2026-11-22 · Branch: `phase/07-groups-members` · Base: `origin/main` (merged again with the 05/06 follow-up, `b1e57d0`)
- Commits: `5e6a369..HEAD` · Status: **done**

## Summary

The Groups tab is real: a 2-column grid of generated group covers (unsynced dot, archived section, offline note,
empty state with New / Join). People can create and edit groups offline (name, type, main currency, cover preview),
open a group (cover hero, avatar stack, Expenses · Balances · Totals tabs, sticky Add expense / Settle up), manage
members (add name-only with a colour, rename, unlink a wrong claim, remove / leave when settled), archive, delete
(creator, restorable for 30 days from Account → Deleted groups), and invite with a QR + `ABCD-EFGH` code. Others join by
typing or scanning the code (or the `splitify://join?code=` link), see a preview, and claim their name-only spot or
join as new.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Migration + pgTAP | done | `0010_groups_members.sql` on dev; `050_groups_rpcs.test.sql` 44/44 (S-070..S-072) |
| T2 Groups tab | done | `groups_home_screen.dart`; one sync on open (S-075); balances placeholder until 09 (S-076) |
| T3 Create/edit group | done | `group_form_screen.dart`; photo covers move to phase 10's uploader (S-073) |
| T4 Group detail shell | done | `group_detail_screen.dart` + `group_tabs.dart` (Expenses slot for 08's `ExpenseList`) |
| T5 Group settings | done | `group_settings_screen.dart`, `deleted_groups_screen.dart`, Account settings row |
| T6 Invite sheet | done | `invite_sheet.dart` (QR in dashed ring, copy, share text per spec, reset with confirm) (S-074) |
| T7 Join flow | done | `join_screen.dart` (enter / scan / deep link, preview, claim carousel, errors) (S-078) |
| T8 Activity rows | done | written by the 0010 RPCs |

## Features delivered

- #1 Groups: create/edit/archive/delete/restore, Groups tab grid — done (balance amounts arrive in phase 09).
- #3 Invite by code or QR: sheet, share, reset, join by code/QR/deep link, preview, errors — done.
- #4 Name-only members: add with tint, rename, claim on join, unlink, remove/leave with the balance rule — done.

## Tests

- New tests: unit 2 files (earlier) · widget 2 files (`groups_widget_test.dart`, `join_screen_test.dart`, 60 tests) ·
  golden 32 (`groups_golden_test.dart`, 8 screens × light/dark × text 1.0/2.0) + 4 updated · integration 2
  (`integration_test/groups_test.dart`) + UI review scenario · SQL 1 file (44 assertions).
- Coverage: overall 94.6 % · presentation 94.2 % · application 94.8 % · data 87.3 % · domain 100 % (all floors pass)
- Test IDs passing: TC-1-01, 1-03, 1-04, 1-05, 1-07, TC-3-01, 3-02, 3-03, TC-4-01, 4-02, 4-03 · device: TC-1-06, TC-3-04, TC-3-05, TC-4-04 (+ the phase E2E scenario)
- Skipped: none.

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | `dart format` clean; `flutter analyze` 0 errors / 0 warnings (infos only, repo-wide style); `tool/guards.dart` OK |
| G2 Tests | PASS | 764 tests; `flutter test --coverage --concurrency=1 --exclude-tags device,needs-owner,quarantine`; `coverage_check` |
| G3 Backend | PASS | 0010 applied after 0001–0009 (`list_migrations`); pgTAP 050 44/44 in BEGIN…ROLLBACK; advisors: security has no ERROR — 6 WARN 0029 on the 0010 RPCs (accepted, S-066), INFO `join_attempts` RLS-no-policy (intended: only SECURITY DEFINER RPCs touch it), leaked-password protection is an owner Auth setting; performance INFO only, none from 0010 |
| G4 Build | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` |
| G5 Device | PASS | `integration_test/groups_test.dart` 2/2 on emulator-5554 against dev (`PIN_HOST_IP`, S-214); UI review ≥ 8/10 on every line (below); screenshots: `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-07\` |
| G6 Docs | PASS | T2–T7 ticked, catalog rows, S-073..S-079, LEARNINGS, amendments (phases 07, 09, 10), PROGRESS |

## UI review (D-018, ui-review rubric; emulator light / dark / 200 %)

Captured on the emulator from `integration_test/scenarios/groups_review_test.dart` (sample data) with
`capture_markers.ps1`: 15 states × light / dark / 200 % in `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-07\`.
Compared with Atlys 438 (grid, hero, glass), 455 (cover hero, dashed circle), 532 (centred question + options),
602 (avatar carousel, underline fields, black CTA), 614 (settings rows, sheets), 712 (folder tabs, sticky bar).

| Screen (light + dark, 1.0 + 2.0) | Atlys feel | Type | Layout | Colour | Signature | Polish | States |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Groups tab (list, archived, empty, offline) | 9 | 9 | 8 | 9 | 9 | 8 | 9 |
| New / edit group | 9 | 9 | 9 | 9 | 8 | 9 | 9 |
| Group detail (+ archived, unsynced) | 9 | 9 | 9 | 9 | 9 | 8 | 9 |
| Invite sheet | 9 | 9 | 9 | 9 | 9 | 9 | 9 |
| Group settings, add member, member actions | 8 | 9 | 9 | 9 | 8 | 9 | 9 |
| Join (enter, claim, archived) | 9 | 9 | 9 | 9 | 9 | 9 | 9 |
| Deleted groups | 8 | 9 | 9 | 9 | 8 | 9 | 9 |

Fixed during the review: "Settle up" wrapping (own action bar), type tiles and deleted rows at 200 % (one per row /
button below), join preview duplicated name (banner without name, centred), join CTA moved to a sticky bar (was below
the fold), invite code kept on one line, "MEMBERS · 4" breaking inside the word (wrapping label row), status-bar icons
invisible when a white sheet scrolls under them (`OverlapSheet` now sets the bar style), bottom safe area on the form,
settings and deleted pages, "Archived" label on cards and pill, ambiguous link icon on name-only rows removed,
FolderTabs sizing label swallowing taps. Accepted: FolderTabs shrinks the active label at 200 % (phase 02 component);
balance placeholders until phase 09; avatar-stack initials overlap by design (438).

## Decisions made (S-0xx)

- S-070..S-072 (backend, earlier session).
- S-073 photo covers → phase 10 uploader · S-074 invite = sheet, deep link mapped in `authRedirect` ·
  S-075 Groups tab / online-only actions trigger a sync · S-076 balance placeholders + Expenses tab slot ·
  S-077 member tint honoured by avatars · S-078 explicit claim choice, unsynced member removal via outbox ·
  S-079 device tests: switched-off `RemoteApi` for offline, harness user B, injected QR scanner.

## Blockers (BLK-xxx)

None new. Device tests need `PIN_HOST_IP` on this PC (S-214, ISP DNS block of `*.supabase.co`).

## Learnings and skills added or changed

LEARNINGS: Phosphor code-point lookup, invisible sizing child swallowing taps (`FolderTabs` fix), Riverpod 3 `misc.dart`
exports, Drift memory DB teardown in widget tests, stuck `flutter_tester.exe`.

## Owner actions

None required. Optional: try Groups → New / Join on a phone build once a Supabase custom domain exists (ISP DNS).

## Next phase

08 — Expenses and split types: replace `GroupExpensesTab`'s body in `lib/features/groups/presentation/group_tabs.dart`
with `ExpenseList(groupId)` and wire `group-add-expense` in `_ActionBar` (`group_detail_screen.dart`). Phase 09 replaces
the balance placeholders listed in its amendment.
