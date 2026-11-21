# Phase 01 report — Bootstrap, tooling, CI

- Date: 2026-11-21 · Branch: `phase/01-bootstrap` · Base: `origin/docs/build-plan` (plan PR #1 not merged yet)
- CI: run 44905849569 on the second push = success (first run failed on a transient Gradle plugin-portal resolution error)
- Commits: `aa224b4..HEAD` (start, skeleton, fix, report) · Status: done

## Summary

A runnable Flutter Android app skeleton exists with the final folder structure, all §5 packages resolved, strict
lints, env loading that fails fast, logging with an in-memory ring buffer, global error handlers, English l10n,
go_router placeholder home, test infrastructure, `tool/verify.ps1` and a CI workflow. It builds a debug APK and
passes the integration smoke test on the emulator.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 flutter create + Android config | done | minSdk 24, compileSdk 37, targetSdk 36, desugaring, `FlutterFragmentActivity`, `splitify://` filter, `upi` query, `USE_BIOMETRIC`, AppCompat launch theme. First build 214 s |
| T2 .gitignore + env templates | done | `secrets/*` with `!secrets/*.example.json`; local `secrets/env.dev.json` holds placeholders |
| T3 pubspec / lints / build.yaml / l10n | done | exact §5 block; `very_good_analysis`, page width 100 |
| T4 folder skeleton | done | `.gitkeep` in empty dirs |
| T5 core | done | `env.dart`, `logger.dart`, `log_buffer.dart`, `failure.dart`, `clock.dart`, `uuid.dart` (v7), `app.dart`, `router.dart`, `bootstrap.dart` |
| T6 tooling | done | `env.ps1`, `verify.ps1`, `guards.dart`, `coverage_check.dart` |
| T7 tests | done | config hook, `support/`, 9 unit + 2 widget, 1 integration |
| T8 CI | done | `flutter` job only, Flutter 3.50.1 |
| T9 docs | done | README setup, CONTRIBUTING, bug template = Android |
| T10 emulator smoke | done | passes; screenshot below |

## Features delivered

Foundation only (no PLAN.md feature numbers).

## Tests

- New tests: unit 9 · widget 2 · golden 0 · integration 1
- Coverage: overall 93.3 % · core 92.2 % · presentation 94.7 % (floors met)
- Quarantined / skipped: none

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | format, analyze (infos only), guards clean via `tool/verify.ps1` |
| G2 Tests | PASS | 11 tests, floors met |
| G3 Backend | SKIPPED | no backend in this phase (not a blocker) |
| G4 Build | PASS | debug APK builds (24-51 s warm) |
| G5 Device | PASS | `integration_test/app_smoke_test.dart` on `emulator-5554` (passed 2 of 3 runs; the first run failed once at load, see LEARNINGS); screenshot `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-01\home.png` |
| G6 Docs | PASS | checkboxes, PROGRESS, decisions, learnings, report |

## Decisions made (S-0xx)

S-001 keep `flutter/material.dart` (deprecation info), S-002 format scope, S-003 commit generated l10n,
S-004 info lints not fatal.

## Blockers (BLK-xxx)

None.

## Learnings and skills added or changed

LEARNINGS.md: first-build time, KGP plugin warnings, `dart format .` and `build/`, heredoc/sed `\t` pitfalls,
standalone debug APK stuck on splash (use `flutter run`), integration test first-run flake, screenshots via adb, CI
Gradle plugin-resolution failure that disappeared on re-run. No new skill needed.

## Owner actions

None required. Optional: merge plan PR #1 first, then this branch.

## Next phase

02 (Design system and app shell) or 03 (Money engine); both depend only on 01. Run phase 02 on top of
`origin/phase/01-bootstrap`.
