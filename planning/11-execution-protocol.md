# Execution protocol — how a session builds one phase without asking anything

This is the contract every plan-execution session follows. The `execute-phase` skill
(`.claude/skills/execute-phase/SKILL.md`) is the step-by-step version of this document.

## 1. When it applies

A session is a **plan-execution session** when the owner says any of: "execute the plan", "continue the plan",
"next phase", "run phase NN", "build phase NN", or types `/execute-phase`. From that moment until the phase report
is pushed, everything below applies. The owner gives no further input.

Hard rules (never broken, even if a document seems to say otherwise):

1. **Never ask the owner anything** and never wait for approval. Decide using §8, log the decision, continue.
2. **One phase per session** (D-002). When the phase is shipped, stop.
3. **Git (D-001):** work only on the phase branch `phase/NN-slug`; commit and push that branch freely; never commit
   on, merge into, rebase onto-and-push, or push `main`/`master`; never force-push; never rewrite pushed history;
   never delete remote branches; never push tags (release uses a draft GitHub Release, see phase 20).
4. **Never commit secrets.** Only `secrets/*.example.json`-style templates may be committed. The guard hook blocks
   commits that contain secret files or secret-looking strings — never try to get around it.
5. **Never touch the prod Supabase project** except in phase 20, and never run destructive SQL (`drop schema`,
   `truncate`, `delete` without `where`) on dev outside a test transaction.
6. **Never break the product rules** in `docs/PLAN.md` (money as integer minor units, RLS everywhere, offline-first
   writes through the outbox, soft deletes + activity log, etc.).
7. **Never delete or rewrite** `docs/PLAN.md`, `planning/00-decisions.md` owner rows, research files, or the Atlys
   reference folder. Spec documents may only be amended by appending clearly marked "Amendment (S-0xx)" notes.
8. **Never mark a gate green that did not run.** If a check could not run, say so in the report.

## 2. Session start (preflight)

1. Read, in this order: `CLAUDE.md`, `planning/README.md`, this file, `planning/PROGRESS.md`,
   `planning/BLOCKERS.md`, `planning/LEARNINGS.md`, `planning/00-decisions.md`.
2. Environment (Windows): in PowerShell run the PATH fix from `CLAUDE.md` before any `flutter`/`dart` command; confirm
   `flutter --version` shows Flutter 3.50.x and `adb devices` works. Details: `dev-env` skill.
3. `git status`. If the tree is dirty:
   - changes belong to the phase marked `in-progress` in PROGRESS.md → keep them, continue that phase (§5);
   - untracked planning/`.claude` files from the planning session → commit them first on the phase branch with
     message `chore: add build plan` (they are part of the plan);
   - anything else → `git stash push -u -m "preflight-<date>"`, record it in the report, never drop it.
4. Re-check every **open** blocker in BLOCKERS.md (e.g. does `secrets/env.dev.json` exist now? does the Supabase MCP
   answer?). Close the ones that are resolved.

## 3. Choosing the phase

1. If a phase is `in-progress` → resume it (an earlier session was interrupted).
2. Else the **lowest-numbered** phase whose status is `todo` and whose "Depends on" phases are all `done` (or
   `done-with-blockers` where the blocker does not touch this phase) and whose owner prerequisites are met.
3. Owner-only phases (00, and checklist R inside 20) are never "executed": the session only verifies their outputs
   (files present, MCP reachable, secrets set). If verified → mark `done`. If not → log/refresh the blocker and pick
   the next phase that does not need them (phases 01–03 need no cloud at all).
4. If "run phase NN" was requested explicitly, do that phase if its dependencies are met; otherwise explain in the
   report why it could not run and do the phase rule 2 would pick.
5. If nothing is runnable (everything left is blocked on the owner), write a short report listing exactly what the
   owner must do, push nothing, stop.

## 4. Branching

```
git fetch origin --prune
PREV = branch of the most recent phase whose status is done/done-with-blockers (empty for phase 01)
if PREV is empty and origin/main has planning/        -> BASE = origin/main
if PREV is empty and origin/main lacks planning/      -> BASE = origin/docs/build-plan   (plan PR not merged yet)
elif origin/main:planning/PROGRESS.md marks PREV done -> BASE = origin/main   (owner already merged it)
else                                                  -> BASE = origin/PREV   (stack on the unmerged phase)
git switch -c phase/NN-slug BASE        # or `git switch phase/NN-slug` when resuming
```
If `origin/PREV` does not exist (never pushed), use the local branch. Record BASE in the report.
The owner merges phase branches into `main` in order, preferably with "Create a merge commit".

## 5. Doing the work

1. Write `.claude/state/execution.json` = `{"phase":"NN","branch":"phase/NN-slug","status":"in-progress",
   "started":"<iso time>","stopBlocks":0}` (git-ignored; hooks read it). Set PROGRESS.md row to `in-progress`
   and commit `chore(phase-NN): start`.
2. Read the phase file completely, then every spec section it links. Read research files only when the spec points
   there or a detail is missing.
3. Work through the phase's task list **in order**. For each task:
   - write or update the tests first when the task has test IDs (TDD for domain/money/sync/SQL work);
   - implement; keep files small and follow `02-architecture.md` folder rules;
   - run the fastest relevant checks (`flutter test <file>`, SQL test file, `deno test`) until green;
   - tick the task checkbox in the phase file (`- [x]`), update test IDs in `10-test-catalog.md`;
   - commit (`feat(<area>): <what>` — short subject, no long body) — the guard hook scans every commit.
4. Push the branch at least every few commits and always before long-running steps (backup):
   `git push -u origin phase/NN-slug`.
5. Use sub-agents for independent parallel work (e.g. one writes golden tests while another fixes SQL tests) only
   when they touch disjoint files; review their diffs before committing.

## 6. Gates (all must pass before the phase is done)

Run the `verify` skill. It runs and reports:

| Gate | What | Pass condition |
| --- | --- | --- |
| G1 Static | `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, money/sync guard scripts, secret scan | 0 format diffs, 0 analyzer errors/warnings, guards clean |
| G2 Tests | `flutter test` (unit, widget, golden) with coverage | all pass; coverage floors in `09-testing-strategy.md` |
| G3 Backend | SQL/pgTAP files via Supabase MCP inside `BEGIN … ROLLBACK`; `get_advisors` (security + performance); `deno test` for Edge Functions | all pass; no security advisor ERROR/WARN |
| G4 Build | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` (and `--release` from phase 19) | builds |
| G5 Device | integration tests on the emulator + the phase's e2e scenario + `ui-review` screenshots (light, dark, 200 % text) | all pass, UI checklist ticked |
| G6 Docs | phase checkboxes, PROGRESS.md, test catalog, decisions, blockers, learnings, phase report | complete |

Gates that cannot run because of an owner blocker are marked `SKIPPED (BLK-xxx)` — never `PASS`. A phase with
skipped gates ends as `done-with-blockers`, and the first session after the blocker is closed re-runs them.

Failure policy: fix and re-run. A test that fails intermittently twice is a **flake**: fix the cause; quarantining
(`@Tags(['quarantine'])` + BLOCKERS entry) is allowed only for tests that depend on outside services.

## 7. Blockers

A blocker is something only the owner or the outside world can fix (missing credentials, account setup, an
outage). Spec gaps are **not** blockers (see §8). On a blocker:

1. Append `BLK-NNN` to `planning/BLOCKERS.md`: phase, what is missing, exact owner steps (copy from the phase-00
   checklist where possible), the workaround applied, how the next session can detect it is fixed.
2. Apply a workaround that keeps the code honest: feature flag off, fake/stub implementation behind the same
   interface, tests tagged `needs-owner`. Never hard-code fake credentials.
3. Continue with every task that does not need the missing thing.
4. If the phase's core cannot be done, end the phase as `blocked`, ship what exists (§9), and stop.

## 8. Deciding without asking

When something is unspecified or two documents disagree, choose in this order:
`docs/PLAN.md` rules → `00-decisions.md` → spec docs → the phase file → research recommendations →
how Splitwise behaves → the simplest option that keeps all tests meaningful.
Record it as `S-0xx` in `00-decisions.md` (date, phase, decision, reason, rejected alternatives) and mention it in
the phase report. If a later phase's spec is affected, append an "Amendment (S-0xx)" note to that phase file.

## 9. Shipping a phase

Run the `ship-phase` skill:

1. Update `planning/PROGRESS.md` (status `done` / `done-with-blockers` / `blocked`, date, branch, last commit).
2. Write `planning/reports/phase-NN.md` from `planning/templates/phase-report.md`.
3. Run `capture-learning`: add gotchas to `planning/LEARNINGS.md`; create or improve a skill under
   `.claude/skills/` when a procedure was needed twice or took a long time to figure out.
4. Final `verify` (quick mode) → commit `docs(phase-NN): report` → `git push -u origin phase/NN-slug`.
5. Set `.claude/state/execution.json` status to `shipped`.
6. Final message to the owner (short): what was built, gate results, branch name, owner actions (if any, all
   optional unless a blocker), the next phase.

Screenshots and other bulky artefacts go **outside the repo** in
`C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-NN\` and are only referenced in the report.

## 10. Interrupted sessions

If a session ends mid-phase (usage limit, crash), the next session finds `in-progress` in PROGRESS.md and in
`.claude/state/execution.json`, switches to the phase branch, reads `git log BASE..HEAD`, the ticked checkboxes and
any draft report, re-runs the tests of the last ticked task, and continues with the first unticked task.

## 11a. UI first, tokens second (D-018, D-019)

- **UI quality outranks everything except correctness.** Any phase that adds or changes screens runs the
  `ui-review` skill and must reach ≥ 8/10 on every rubric line for every touched screen, comparing against the
  Atlys reference images. Iterate until it does; record scores in the report.
- **Token economy:** delegate test authoring to the `test-writer` sub-agent (Sonnet) and test/gate runs + log triage
  to `test-runner` (Haiku); use Explore for wide searches. The main session writes app/UI code and judges visuals.
  Read only the spec sections a task needs, never re-read files already in context, keep tool output short
  (`--reporter compact`, `Select-String` the failures), keep reports brief.

## 11. Quality bar (applies to every line of code)

- Money only through the money engine (`05-money-engine.md`); never `double`/`num` for amounts.
- Every write goes through a repository → local DB → outbox (`04-sync-engine.md`); UI never calls Supabase directly.
- Every table: RLS on, policies tested with pgTAP for member / non-member / name-only-claim cases.
- Every screen: light + dark, text scale 200 %, TalkBack labels, 48 dp touch targets, empty/loading/error/offline
  states, golden test.
- Every user-visible string in ARB files. Rupee amounts formatted with Indian grouping.
- No new outside service beyond Supabase, FCM, Frankfurter, Resend (SMTP via Supabase Auth only).
- No `print`; use the logger. No secrets in logs.
- Dependencies: only from the package table in `02-architecture.md`; adding one requires an `S-0xx` decision with
  maintenance/licence check.
