---
name: execute-phase
description: Builds the next phase of the Splitify plan end to end without asking the owner anything. Use when the owner says "execute the plan", "continue the plan", "next phase", "run phase NN", "build phase NN", "resume", or types /execute-phase.
argument-hint: "[phase number, optional]"
---

# Execute one phase of the Splitify build plan

You are a plan-execution session. The full contract is `planning/11-execution-protocol.md`; this is the
checklist. **Never ask the owner a question, never wait for approval, one phase per session.**

## 0. Load context (in this order)

1. `CLAUDE.md` → `planning/README.md` → `planning/11-execution-protocol.md` → `planning/PROGRESS.md` →
   `planning/BLOCKERS.md` → `planning/LEARNINGS.md` → `planning/00-decisions.md`.
2. Run the `dev-env` skill preflight (PATH fix, Flutter version, adb, emulator status).
3. Check the guard hooks are active: `.claude/settings.local.json` must reference `.claude/hooks/guard.ps1`,
   `guard-mcp.ps1`, `session-start.ps1`, `stop-check.ps1`. If it is missing, recreate it from
   `.claude/settings.local.example.json` (copy, then fix absolute paths) and note it in the report.

## 1. Pick the phase

- `$ARGUMENTS` names a phase → use it if its dependencies (PROGRESS.md "Depends on") are done; otherwise explain
  in the report and fall back to the rule below.
- A phase marked `in-progress` → resume it.
- Otherwise the lowest `todo` phase whose dependencies are `done`/`done-with-blockers` and whose owner setup exists.
- Owner setup check (needed from phase 04): `secrets/owner-inputs.json` exists and parses; the Supabase MCP answers
  `list_tables`. Google client id, Resend, `secrets/google-services.json` and the release key are **optional**
  (D-020 dummy mode): if missing, build the feature behind its config check with fakes — never a blocker. Missing → add/refresh a `BLK-` entry in `planning/BLOCKERS.md` with the exact phase-00 step, then pick the
  next phase that doesn't need it. If nothing is runnable, write a short report saying exactly what the owner must
  do and stop.

## 2. Branch (never main)

```
git fetch origin --prune
```
- `PREV` = branch of the latest finished phase in PROGRESS.md.
- If `git show origin/main:planning/PROGRESS.md` marks PREV as done → base `origin/main`; else base `origin/PREV`
  (or local PREV if never pushed); phase 01 bases on `origin/main` — unless `origin/main` has no
  `planning/PROGRESS.md` yet (plan PR not merged), then on `origin/docs/build-plan`.
- `git switch -c phase/NN-slug <base>` (or `git switch phase/NN-slug` when resuming).
- If untracked plan files (`planning/`, `.claude/`) exist from the planning session, commit them first:
  `chore: add build plan`.

## 3. Start marker

Write `.claude/state/execution.json`:
```json
{"phase":"NN","branch":"phase/NN-slug","status":"in-progress","started":"<ISO time>","sessionId":"${CLAUDE_SESSION_ID}","stopBlocks":0}
```
Set the PROGRESS.md row to `in-progress`, update "Current phase", commit `chore(phase-NN): start`.

## 4. Build

1. Read the whole phase file `planning/phases/phase-NN-*.md` and every spec section it links.
2. For each unticked task, in order:
   - tests first for domain/money/sync/SQL work (test IDs from the phase file / `planning/10-test-catalog.md`);
   - implement following `planning/02-architecture.md`;
   - run the narrowest checks until green (`flutter test test/path`, SQL file via `supabase-dev` skill, `deno test`);
   - tick the task box in the phase file, mark its test IDs in `planning/10-test-catalog.md`;
   - commit with a short conventional subject (`feat(groups): invite by code`), pushing every few commits.
3. Save tokens (D-019): hand test authoring to the `test-writer` sub-agent (Sonnet) with task + TC ids + files;
   hand test/gate runs to `test-runner` (Haiku) and act on its short summary. You write app/UI code and judge UI.
   UI is top priority (D-018): every touched screen passes `ui-review` with ≥ 8/10 per rubric line.
4. Use the topic skills when relevant: `money-rules`, `offline-sync-rules`, `supabase-dev`, `emulator-e2e`,
   `ui-review`, `dev-env`.
5. Missing spec detail → decide per protocol §8, log `S-0xx` in `planning/00-decisions.md`, continue.
6. Owner-only gap → protocol §7 (blocker entry + honest workaround), continue with other tasks.

## 5. Gates

Run the `verify` skill in full mode. Fix and re-run until G1–G6 pass, or mark gates that truly cannot run as
`SKIPPED (BLK-xxx)`. Never claim a gate passed that did not run.

## 6. Ship and stop

Run the `ship-phase` skill (report, PROGRESS, learnings/skills, final commit, push, marker → `shipped`).
Then reply to the owner in at most ~15 lines: what works now, gate results, branch, owner actions (if any) and the
next phase. Stop — do not start another phase.
