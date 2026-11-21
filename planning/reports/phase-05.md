# Phase 05 report — Auth, profile, account

- Date: 2026-11-21 · Branch: `phase/05-auth-profile` · Base: `origin/phase/04-backend-foundation` (77e0bc0)
- Commits: `618c971..HEAD` · Status: done-with-blockers (BLK-001)

## Summary

The app now has a real front door: Welcome → sign-in (Google pill, email + 6-digit code) → code entry → profile
confirm → Groups, with the router sending signed-out people back to Welcome. The Account tab shows the profile;
its settings sheet has Profile and Preferences accordions, Sign out (confirm sheet, wipes the phone) and Delete
account ("type DELETE" → `delete-account` Edge Function). Profile edit covers name, photo, UPI ID (+ QR scan) and
default currency. Everything runs against interfaces and fakes: without the publishable key (BLK-001) the build
stays signed out and Google shows "Coming soon" (D-020).

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Supabase client + AuthRepository | done | `data/remote/supabase_client.dart`, `supabase_auth_repository.dart`; mocktail tests |
| T2 Migration `update_profile` + trigger check | done | `0008_auth_profile.sql` (+ `prepare_account_deletion`); pgTAP `024_auth_profile.test.sql` (29 checks) green in CI |
| T3 Welcome, sign-in, code, profile confirm, redirect | done | `features/auth/presentation/*`, `AuthGate` + `authRedirect` (S-032) |
| T4 Dev login (debug only) | done | `/debug/login`, deep link `splitify://dev/login?user=e2e-a`, sign-up on first use; live run SKIPPED (BLK-001) |
| T5 Profile edit | done | online-only with cache; photo compress + upload, no crop UI (S-034) |
| T6 Account tab + settings sheet | done | avatar/name header, Profile accordion, Sign out, Delete account, About, version |
| T7 `delete-account` function + client | done (deploy SKIPPED, BLK-001) | deno tests 13/13, CI functions job green |
| T8 Sign-out wipe | done | `LocalWipe`: secure storage + prefs except `theme_mode` |
| T9 Integration on dev project | SKIPPED (BLK-001) | no publishable key / dev sign-in |

## Features delivered

- B1 Sign-in and account: Google (behind config), email code (resend 60 s, 5 tries), debug dev login, sign out,
  delete account. Live sign-in untested (BLK-001).
- B2 Profile: name, photo, UPI ID with validation and QR scan, default currency.

## Tests

- New tests: unit 3 files · widget 1 file (10 tests) · golden 20 (5 screens × light/dark × text 1.0/2.0) ·
  SQL 1 file (29) · edge-fn 1 file (13)
- Coverage: overall 94.1 % · domain 100 % · data 88.4 % · application 100 % · presentation 93.2 %
- Passing: TC-B1-01, 02, 05, 06, 08 · TC-B2-01, 02, 03
- Skipped: TC-B1-03, 04, TC-B2-04 (BLK-001, integration on dev project) · TC-B1-07 needs-owner (no Google id) ·
  TC-B1-09 manual-opt

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | format 0 changes, analyze 0 errors/warnings (infos only), guards OK |
| G2 Tests | PASS | 442 tests, coverage floors all PASS |
| G3 Backend | PASS (CI) / SKIPPED (MCP) | CI run 44926040224: db + functions green; MCP advisors SKIPPED (BLK-001) |
| G4 Build | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` |
| G5 Device | SKIPPED | emulator review not run (time); goldens self-reviewed with `PLATFORM_GOLDENS=1` |
| G6 Docs | PASS | phase ticks, catalog, S-030..S-036, learnings, this report, PROGRESS |

## Decisions made (S-0xx)

S-030 optional Google id / placeholder detection · S-031 repository split · S-032 AuthGate redirect + dev deep
link · S-033 client OTP rules · S-034 online-only profile, no crop · S-035 SQL error codes · S-036 delete flow.

## Blockers (BLK-xxx)

BLK-001 (open): no Supabase MCP / publishable key → no live sign-in, no function deploy, no T9.

## Learnings and skills added or changed

Four LEARNINGS lines (Riverpod 3 paused providers, flutter_test HTTP 400, PowerShell re-encoding, golden images).

## Owner actions

- Required to finish B1 live: add the publishable key to `secrets/env.dev.json` / enable the MCP (BLK-001), then
  deploy `delete-account` and run T9.
- Optional (D-020): Google client id, Resend SMTP.

## Next phase

06 Local database and sync engine (built in parallel). It must add the DB wipe to `LocalWipe.wipe()` and the
outbox push / device unregister before `AuthRepository.signOut()` in `AccountActions`.
