---
name: verify
description: Runs Splitify's quality gates G1–G6 (format, analyze, guard scripts, unit/widget/golden tests with coverage, SQL/pgTAP tests via Supabase MCP, Edge Function tests, APK build, emulator integration tests, UI review, docs) and reports pass/fail per gate. Use before every phase is shipped, after big changes, when asked to "run the tests", "check everything", "verify", or before committing risky work. Quick mode = G1 + G2 only.
argument-hint: "[quick|full]"
---

# Verify (quality gates)

Default is **full**. `quick` runs G1 and G2 only. Always run from the repo root, PowerShell, PATH fix first
(see `dev-env`). From phase 01 on, `tool/verify.ps1` wraps G1–G4; if it exists use it, otherwise run the commands
below. Record each gate's result and evidence for the phase report. Never report a gate as passed if it did not run.

## G1 Static

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze --no-fatal-infos          # must print "No issues found!" (warnings/errors fail)
dart run tool/guards.dart                  # money + sync + secret + style guards (phase 01)
```
`tool/guards.dart` fails when: `double`/`num` types appear in money code (`lib/core/money/**`, `**/domain/**`
amounts), Supabase client is used outside `lib/data/remote/**`, `print(` appears in `lib/`, a hard-coded
`sb_`/JWT-looking string appears, or a user-facing string literal appears in a widget outside `l10n`.

## G2 Tests

```powershell
flutter test --coverage --exclude-tags quarantine,needs-owner,device
dart run tool/coverage_check.dart          # floors from planning/09-testing-strategy.md
```
Golden tests run as part of `flutter test` (fonts bundled, see testing strategy). When a golden changes on
purpose: `flutter test --update-goldens <file>`, then open the new PNGs with the Read tool and check them against
`planning/06-design-system.md` before committing.

## G3 Backend (from phase 04)

Use the `supabase-dev` skill:
1. Every `supabase/tests/**/*.sql` file → run through `mcp__supabase__execute_sql`, wrapped in
   `BEGIN; … ROLLBACK;`, and check the TAP output has no `not ok`.
2. `mcp__supabase__get_advisors` for `security` and `performance`: no security ERROR/WARN; performance WARNs
   either fixed or logged as `S-` decisions with reasons.
3. Edge Functions: `deno test -A supabase/functions` (Deno per `dev-env`), plus `deno lint` and `deno fmt --check`.
4. Migrations on dev match the repo: `list_migrations` names = files in `supabase/migrations/`.

## G4 Build

```powershell
flutter build apk --debug --dart-define-from-file=secrets/env.dev.json
```
From phase 19 also `flutter build apk --release ...` with the release signing config. Note the APK size.

## G5 Device

Use the `emulator-e2e` skill: install the debug build, run `integration_test/` (or Patrol) suites tagged for this
phase, run the phase's e2e scenario from its phase file, then the `ui-review` skill for every screen the phase
touched (light, dark, text scale 2.0). Screenshots go to
`C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-NN\`.

## G6 Docs

Phase checkboxes ticked; `planning/PROGRESS.md`, `planning/10-test-catalog.md`, `planning/00-decisions.md`
(S-entries), `planning/BLOCKERS.md`, `planning/LEARNINGS.md` updated; report written (`ship-phase`).

## Output

Produce a table: Gate | PASS/FAIL/SKIPPED (BLK-xxx) | evidence (counts, coverage %, durations). Fix failures and
re-run before shipping. A flaky test (fails then passes without changes) must be fixed, not ignored.
