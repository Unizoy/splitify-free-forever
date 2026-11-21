# Phase 07 — Groups, name-only members, invites (#1, #3, #4)

- Depends on: 06 · Owner setup: 00 · Branch: `phase/07-groups-members`
- Goal: create/edit/archive/delete groups with generated covers, add name-only members, invite by code/QR, join and
  claim spots; the real Groups tab.
- Read first: `08-feature-specs.md` #1 #3 #4 + cross-cutting, `07-screens-and-flows.md` (Groups home, group detail,
  join), `03-backend.md` §4.

## Tasks

- [ ] T1 Migration 0009: `preview_join`, `join_group`, `rotate_invite_code`, `leave_group`, `remove_member`,
      unlink claim, invite code generation (Crockford base32, unique), rate limit. pgTAP `050_groups_rpcs.test.sql`.
- [ ] T2 Groups tab: hero + GlassCard (overall placeholder until phase 09), group grid with GroupCoverCard,
      archived section, empty state, Join/New buttons.
- [ ] T3 Create/edit group screen (name, type OptionTiles, currency picker, cover generated/photo upload).
- [ ] T4 Group detail shell: cover hero, status pill, avatar stack, FolderTabs (Expenses list placeholder,
      Balances placeholder, Totals placeholder), settings route.
- [ ] T5 Group settings: members list (add name-only with tint, rename, remove/leave with balance check,
      unlink claim), invite, archive/unarchive, delete (creator) + Account → Deleted groups restore.
- [ ] T6 Invite sheet: QR (`qr_flutter`) in dashed circle, code `ABCD-EFGH`, share sheet text, reset code.
- [ ] T7 Join flow: enter code / scan (`mobile_scanner`, camera permission just-in-time) / deep link
      `splitify://join?code=` → preview → claim carousel or "I'm new here" → open group. Online-only.
- [ ] T8 Activity rows for group events written by RPCs/mutations (feed UI comes in phase 09).

## Tests

TC-1-01, 1-03, 1-04, 1-06, 1-07, TC-3-01…05, TC-4-01…04; goldens for new screens.

## E2E scenario

A creates "e2e-Goa" (trip) offline → online sync → shares code → harness B previews and claims name-only "Rahul"
→ A's member list shows Rahul linked.
