---
name: capture-learning
description: Records what a Splitify session learned — gotchas, working commands, fixes — in planning/LEARNINGS.md, and creates or improves project skills in .claude/skills when a procedure repeats. Use at the end of every phase (ship-phase calls it) and right after solving a non-obvious problem.
---

# Capture learnings and grow the skills

The owner wants the build to get better with every phase: each session leaves the next one smarter.

## 1. Learnings (always)

Append to the right section of `planning/LEARNINGS.md`, one line each:
`- [phase NN] <topic>: <what went wrong or was surprising> → <what works>`

Record: commands that needed special flags on this Windows PC, package/version quirks, Supabase/MCP behaviour,
flaky-test causes and fixes, emulator tricks, analyzer rules that bit, anything that took more than ~10 minutes.
Do not record things already in the specs.

## 2. Skills (when it pays off)

Create or update a skill under `.claude/skills/<kebab-name>/SKILL.md` when any of these is true:

- the same multi-step procedure was done twice in this or earlier phases (check LEARNINGS.md);
- a procedure took long to discover and will be needed again (e.g. "regenerate Drift code after a schema change",
  "reset the emulator's network after airplane-mode tests", "deploy an Edge Function and tail its logs");
- an existing skill was wrong or incomplete — fix it in place.

Rules for skills:

- Frontmatter: `name` (kebab-case, = folder name) and a `description` that says **what it does and when to use it**
  with concrete trigger words. Optional: `argument-hint`, `allowed-tools`, `disable-model-invocation`.
- Body: numbered steps with exact commands for this PC (PowerShell PATH fix first for Flutter), expected output,
  and what to do when a step fails. Keep under ~200 lines; put long references in a sibling file.
- Helper scripts go next to the skill (`scripts/`), must be idempotent, and must not contain secrets.
- Never weaken the guard hooks, the execution protocol or the product rules through a skill.
- Mention every new or changed skill in the phase report ("Learnings and skills").

## 3. Plan feedback

If a later phase file is now wrong (renamed file, changed API, better approach), append an
"Amendment (S-0xx)" note to that phase file and log the S-decision — never silently rewrite the spec.
