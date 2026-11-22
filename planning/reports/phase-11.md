# Phase 11 report — Friends, simplify debts, Pay via UPI

- Date: 2026-11-22 · Branch: `phase/11-friends-simplify-upi` · Base: `origin/main` (phases 01–09; phases 10, 12, 13 and 14
  merged in on the way)
- Commits: `5382659..` (see `git log origin/main..phase/11-friends-simplify-upi`) · Status: done

## Summary

The Friends tab lists everyone you share a group with and the total with each of them per currency (search, amber
"Add friend expense": pick a friend or add someone new who has no account). Each friend has a page with the total,
what every shared group shows between you, every shared expense, payment and loan across groups, and Settle up /
Add expense / Record a loan (Invite for a name-only friend), with Remind on each group where they owe you. Groups can turn on Simplify debts (logged as a settings
change). When you owe someone in rupees who has a UPI ID, Settle up offers "Pay ₹x via UPI": it opens the UPI app,
asks "Did the payment go through?" and records a UPI payment only on "Mark as paid", with copy / QR fallbacks; a
payment that settles a person plays the "all settled" celebration.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 `find_or_create_direct_group` + friend totals | done | migration `0014_friends_simplify.sql` applied to dev; pgTAP `110_friends_simplify.test.sql` 17/17 (TC-2-01, TC-16-02, T3) |
| T2 Friends tab + friend page + add friend expense | done | `lib/features/friends/**`, route `/friends/:key` (S-120, S-121, S-125) |
| T3 Simplify toggle + Balances switch + `settings_changed` | done | settings row (`simplify_setting.dart`); Balances tab switch/"Show original debts" existed (phase 09); server triggers + feed sentences (S-122) |
| T4 UPI | done | builder pre-built; `<queries>` already in the manifest; launcher, return sheet, fallbacks, QR, visibility rules (S-123) |
| T5 `tool/fake_upi_app` | done | Java app + `build.ps1` + `run_upi_e2e.ps1`; installed and uninstalled paths green (S-126) |
| T6 Celebration | done | `settled_celebration.dart` (S-124) |

## Features delivered

- #2 Friend expenses: direct groups (online once for a linked friend, offline for a name-only friend), friend page.
- #16 Total with a friend: `friendTotals` over shared + direct groups, equal to the server's `my_overview`.
- #17 Simplify debts: per-group toggle with the spec help text, `settings_changed` activity.
- #26 Pay via UPI: link, launch, "Did the payment go through?", Mark as paid (method `upi`), fallbacks, hidden for
  non-INR / no UPI ID / name-only payee / when I am not the payer / edits.
- #11 (phase 10 amendment S-116): "Record a loan" from the friend page.

## Tests

- New tests: unit 67 · widget 87 · golden 9 scenarios × 4 variants (36 CI images) · integration 1 (two modes) ·
  SQL 1 file (17 assertions) · e2e: `tool/fake_upi_app/run_upi_e2e.ps1`
- Coverage (after merging phase 14): overall 96.7 % · domain 100 % · money 100 % · sync 100 % · core 96.6 % · data 92.8 % · application 97.2 %
- Test IDs now passing: TC-2-01, TC-2-02, TC-2-03, TC-16-02, TC-17-03, TC-26-01 (pre-built), TC-26-02, TC-26-03,
  TC-26-04, plus TC-23-02's friend-page part (Remind on group rows). TC-26-05 stays manual-opt (real UPI app on a phone; no phone, D-005).
- Quarantined / skipped: none.

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | format (lib test integration_test tool) 0 changes; `flutter analyze --no-fatal-infos` 0 errors/warnings; `dart run tool/guards.dart` OK |
| G2 Tests | PASS | `flutter test --coverage --exclude-tags device,needs-owner,quarantine --concurrency=1`: 2367 passed, 0 failed after merging phase 14 (4 `settle_up_upi` goldens re-recorded for phase 14's currency chip); `tool/coverage_check.dart` all floors PASS |
| G3 Backend | PASS | 0014 applied via MCP (after 0010; 0013/0015 already there); pgTAP 110 17/17 on dev in a rolled-back transaction; security advisor: no new kinds (the SECURITY DEFINER RPC warning is by design, T-013; leaked-password protection is an owner setting); no Edge Functions touched |
| G4 Build | PASS | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` |
| G5 Device | PASS | `run_upi_e2e.ps1` on emulator-5554 (last run after merging phase 13; phase 14 touched Settle up only by the currency chip, covered by widget tests): installed path (TC-2-02, TC-26-02: logcat `FAKE_UPI` = `upi://pay?pa=e2e.b@okaxis&pn=E2E%20B&am=300.00&cu=INR&tn=Splitify%3A%20E2E%20Friends%20…`, Mark as paid → UPI payment on the server, `settings_changed` on the server) and absent path (TC-26-03) green; UI review screenshots light/dark/200 % in `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-11\` |
| G6 Docs | PASS | phase ticks, test catalog rows, S-120…S-126, LEARNINGS, emulator-e2e skill §9, phase 13 amendment, this report, PROGRESS |

### UI review (D-018, device captures + real-font goldens)

| Screen | Atlys feel | Typography | Layout | Colour | Signature | Polish | States |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Friends tab (438 + 646) | 9 | 9 | 9 | 9 | 9 (hero, search pill, overlap sheet, capsule nav) | 9 | 9 (skeleton, empty, no match, unsynced) |
| Friend page (542) | 9 | 9 | 8 | 9 | 9 (hero avatar, pill, overlap sheet, sticky bar) | 8 | 9 (not found, settled, empty items) |
| Settle up + UPI bar (712) | 9 | 9 | 9 | 9 | 8 | 9 | 9 (hidden/visible rules) |
| UPI return / no-app / QR sheets | 9 | 9 | 9 | 9 | 8 (serif sheet title, dashed QR ring) | 9 | 9 |
| Group settings simplify row (614) | 8 | 9 | 8 | 9 | 8 | 8 | 9 |
| Settled celebration | 9 | 9 | 9 | 9 | 9 | 9 | 9 (reduced motion = final frame) |

Fixed during review: the UPI bar's side-by-side "Record payment" wrapped at 360 dp → stacked with a quiet
"Record without UPI"; the return sheet said "You paid …" before anything was paid → "To …"; the friend pill
stretched across the hero → centred. After the phase 13 merge the device run found the celebration's
timer popping a route that was already gone → it now pops only while its own route is current (widget test
`settled_celebration_test.dart`), and the e2e waits for the fake UPI app to hand back before "Mark as paid".

## Decisions made (S-0xx)

S-120 direct groups (RPC for linked friends, outbox for name-only) · S-121 friends model and `/friends/:key` ·
S-122 `settings_changed` by triggers · S-123 Pay via UPI rules and layout · S-124 celebration rule · S-125 friend
page content (Remind = phase 13's `RemindButton` on "By group" rows, added after merging phase 13) · S-126 fake UPI app and host-side logcat check.

## Blockers (BLK-xxx)

None.

## Learnings and skills added or changed

LEARNINGS: MCP declines `drop trigger`; pgTAP `tap(t text, id serial)`; triggers instead of redefining
`sync_apply_one`; no `android/gradlew` in fresh worktrees; PowerShell + flutter.bat stderr; host-side logcat check;
commit a sub-agent's partial work. Skill `emulator-e2e` §9 rewritten for the real fake-UPI tooling.

## Owner actions

- Optional (TC-26-05): try "Pay via UPI" on a real phone with GPay/PhonePe/Paytm; some apps refuse P2P links — the
  copy / QR fallbacks cover that.
- Not a blocker: users on ISPs that block `supabase.co` need a Supabase custom domain/proxy before release.

## Next phase

14 (Currencies and conversion) / 15 (Offline polish) per PROGRESS. Phase 13 is merged into this branch; Remind
on the friend page already uses its `RemindButton`.
