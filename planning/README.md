# Splitify build plan

The complete, phase-by-phase plan to build **Splitify Free Forever** (`docs/PLAN.md`) with autonomous Claude Code
sessions. Written 2026-11-21 after owner Q&A and research.

## How the owner uses it

1. Once: do `phases/phase-00-owner-setup.md` (≈ 60–75 min). Phases 01–03 can already run before it is finished.
2. Open a new Claude Code session in this repo and say **"execute the plan"**. The session builds the next phase,
   tests everything, pushes branch `phase/NN-…`, writes `reports/phase-NN.md`, and stops. No questions, no prompts.
3. Repeat step 2 for each phase. Merge the phase branches into `main` in order whenever you like
   ("Create a merge commit"). Check `PROGRESS.md` and `BLOCKERS.md` any time.
4. Before phase 20: do checklist R in `phases/phase-20-release.md` (prod project). Then publish the draft release.

## How a session uses it

`11-execution-protocol.md` (contract) + skill `execute-phase` (checklist). Hard rules: never ask, one phase, never
touch `main`, never commit secrets, never break PLAN.md rules.

## Files

| File | What |
| --- | --- |
| `00-decisions.md` | Every decision (owner D-, technical T-, session S-) — wins over other plan docs |
| `01-product-scope.md` | Features → phases, out of scope |
| `02-architecture.md` | App architecture, folders, packages, config |
| `03-backend.md` | Supabase schema, RLS, RPCs, jobs, Edge Functions, migration plan |
| `04-sync-engine.md` | Offline-first protocol |
| `05-money-engine.md` | Money rules and algorithms (+ `reference/money_reference.py`, `reference/money_vectors.json`) |
| `06-design-system.md` | Atlys-inspired tokens, typography, components, covers |
| `07-screens-and-flows.md` | Routes, screen layouts, flows |
| `08-feature-specs.md` | Behaviour, edge cases, copy, test ids per feature |
| `09-testing-strategy.md` | Test layers, tools, harness, coverage, CI |
| `10-test-catalog.md` | Every test id with phase and status |
| `11-execution-protocol.md` | How sessions run unattended |
| `phases/phase-NN-*.md` | Tasks (checkboxes = live state), tests, done-when |
| `PROGRESS.md`, `BLOCKERS.md`, `LEARNINGS.md` | Live state, owner-only problems, accumulated know-how |
| `reports/` | One report per finished phase |
| `research/` | Evidence behind the decisions |
| `templates/` | Phase report template |

Skills (`.claude/skills/`): `execute-phase`, `verify`, `ship-phase`, `capture-learning`, `dev-env`, `emulator-e2e`,
`ui-review`, `supabase-dev`, `money-rules`, `offline-sync-rules`. Guard hooks: `.claude/hooks/` (configured in the
git-ignored `.claude/settings.local.json`; template `.claude/settings.local.example.json`).
