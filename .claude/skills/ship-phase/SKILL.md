---
name: ship-phase
description: Finishes a Splitify plan phase — writes the phase report, updates PROGRESS/BLOCKERS/LEARNINGS, captures new skills, commits and pushes the phase branch. Use at the end of every plan-execution session, or when a phase must stop early because it is blocked.
---

# Ship the current phase

Run only on the phase branch (`git rev-parse --abbrev-ref HEAD` must start with `phase/`).

1. **Final quick verify** — run the `verify` skill in quick mode (format, analyze, unit/widget tests). If anything
   fails, fix it before continuing. If the phase is being stopped as `blocked`, still make sure the branch builds.
2. **Status** — decide: `done` (all gates green), `done-with-blockers` (only gates that depend on an open `BLK-`
   were skipped), or `blocked` (core of the phase could not be built).
3. **PROGRESS.md** — set the row's Status, Branch, Finished (YYYY-MM-DD), Last commit (short SHA, filled after the
   final commit is made: amend nothing, just update in the report commit using `git rev-parse --short HEAD` of the
   previous commit), Report link; set "Current phase" to none.
4. **Report** — copy `planning/templates/phase-report.md` to `planning/reports/phase-NN.md` and fill every section
   with facts from this session (test counts from the test run output, gate results, screenshots folder
   `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-NN\`).
5. **Test catalog** — every test ID the phase touched shows its status in `planning/10-test-catalog.md`.
6. **Blockers** — new ones added, resolved ones moved to Closed with the date.
7. **Learnings and skills** — run the `capture-learning` skill.
8. **Commit and push**
   ```
   git add -A
   git status --short          # read it: nothing from secrets/, no keystores, no google-services.json
   git commit -m "docs(phase-NN): report and progress"
   git push -u origin phase/NN-slug
   ```
   The guard hook blocks secrets and pushes to main; if it blocks, fix the cause — never work around it.
9. **Marker** — set `.claude/state/execution.json` `status` to `shipped` (or `blocked`).
10. **Reply** to the owner (≤15 lines): what now works, gates, branch name, owner actions (say "none" if none),
    next phase. Then stop.
