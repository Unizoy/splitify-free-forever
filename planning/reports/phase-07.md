# Phase 07 report — Groups, name-only members, invites

- Date: 2026-11-21 · Branch: `phase/07-groups-members` · Base: `origin/phase/06-sync-engine`
- Status: **in-progress** (stopped at the owner deadline; backend + data layer done, screens open)

## Summary

The server side of groups is live on dev: every group gets an 8-character invite code, people can preview a group
by code, join it or claim a name-only spot, reset the code, leave or be removed (only when settled), and a wrong claim
can be unlinked. Deleting a group is creator-only with a 30-day restore. The app has the matching data layer
(invite-code rules, group form rules, online-only `GroupsRemote`, repository methods). The screens are not built yet.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Migration + pgTAP | done | `0010_groups_members.sql` applied to dev; `050_groups_rpcs.test.sql` 44/44 on dev (S-070..S-072) |
| T2 Groups tab | open | data: `GroupsRepository.watchAll`, `MembersRepository.watchAllActive` ready |
| T3 Create/edit group | open | `GroupRules` (TC-1-01) + `GroupsRepository.create(ownerUserId)` ready |
| T4 Group detail shell | open | |
| T5 Group settings | open | data: `addNameOnly(tint)`, `rename`, `setArchived`, `watchDeletedBy`, `GroupsRemote.leave/removeMember/unlinkMember` |
| T6 Invite sheet | open | `InviteCode.display/link`, `GroupsRemote.rotateCode` ready |
| T7 Join flow | open | `InviteCode.parse`, `GroupsRemote.preview/join` ready |
| T8 Activity rows | done | RPCs write `member_joined/claimed/left/removed`, `group_updated` (invite reset, unlink) |

## Tests

- New: unit 2 files (`test/domain/rules/invite_code_test.dart`, `test/data/remote/groups_remote_test.dart`) · SQL 1
  file (44 assertions). Widget/golden/integration for the screens: not written (screens open).
- Passing: TC-1-01, TC-1-03, TC-1-07, TC-3-01, TC-3-02, TC-4-01, TC-4-02.
- Open: TC-1-04, TC-1-06, TC-3-03..05, TC-4-03, TC-4-04.

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | `dart format` clean, `flutter analyze` 0 errors/0 warnings (infos only, pre-existing style), guards OK |
| G2 Tests | PARTIAL | `flutter test test/domain test/data` 135 pass; full suite + coverage_check not run (deadline) |
| G3 Backend | PASS (pgTAP) | 0010 applied via MCP after 0009; 050 run in BEGIN…ROLLBACK: 44/44; advisors not run |
| G4 Build | NOT RUN | deadline |
| G5 Device | SKIPPED | deferred: emulator owned by phase-06 agent; no screens yet |
| G6 Docs | PARTIAL | T1/T8 ticked, catalog rows, S-070..S-072, LEARNINGS line, PROGRESS `in-progress` |

## Decisions made (S-0xx)

- S-070 file name `0010_groups_members.sql`; wrong codes returned as `{error}` so the try is recorded; only wrong
  tries count to the 10/hour limit.
- S-071 unlink → activity `group_updated` + `unlinked: true`; new RPC `unlink_member`.
- S-072 zero-balance and creator-only rules enforced by triggers (all write paths); group-member actions online-only.

## Notes for the next session

- The migration applied to dev has the same SQL as the file but fewer comment lines (comments trimmed in the MCP call).
- Build T2–T7 on the data layer above; the Groups screen golden needs `appDatabaseProvider` (memory DB) and
  `remoteApiProvider`/`groupsRemoteProvider` fakes once the screen reads Drift.
