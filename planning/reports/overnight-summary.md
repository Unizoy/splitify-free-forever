# Overnight build summary (2026-11-21 → 2026-11-23)

The plan sessions built phases 01–19, then added four extras the owner asked for along the way:
- the payment bubble (18b, D-025);
- real Google sign-in, email codes and push (D-026);
- motion, scrolling and type polish (D-027);
- auto-category with standard/full build flavours (D-028).

Phase 20 (release to a prod project) was left for the owner (D-023). Everything is on `main` via PRs #1–#27, each
merged with a merge commit (D-021). GitHub CI is still off (D-022).

## What the app does now

- **Accounts:** email-code and Google sign-in (Google is live, D-026), profile, sign-out, delete account.
- **Groups:**
  - Groups and members, invites by link or QR, and name-only members who can claim their place later.
  - Expenses with every split type (equal, exact, percent, shares, adjust), multiple payers, IOUs/loans and receipt
    photos.
- **Balances:**
  - Balances, totals and activity; settle up; Pay via UPI with "Mark as paid" (rupees only).
  - Simplify debts.
  - Friends: a 1:1 friend page and reminders.
- **Currencies:** conversion with saved rates; a daily Frankfurter rates cron.
- **History:** edit history with restore, and comments.
- **Notifications:** an in-app bell and FCM push (verified on the emulator).
- **Offline-first:** an outbox and automatic sync triggers (network, resume, Realtime, WorkManager); it survives
  airplane mode and an app kill.
- **Repeats and search:** recurring bills (server cron) and offline search with amount parsing.
- **Charts and export:** charts (Insights), and CSV export through the share sheet.
- **Extras:** Splitwise CSV import, app lock, and a home-screen widget.
- **Payment bubble (full flavour only):** UPI payments are caught from notifications, bank SMS shown as
  notifications, or smart capture, and a floating bubble offers **Add**.
- **Auto-category:** the editor picks a category while you type (Swiggy → Takeaway, Uber → Travel …) and learns
  from your corrections.

## Quality at the end

- **Flutter:** 3,404 tests pass, coverage 95.3 %, and analyze, format and guards are clean.
- **Other tests:**
  - pgTAP: 948 checks across 25 files on dev (phase 19).
  - Deno: 53 tests.
  - Kotlin JUnit: 13 tests.
- **Every screen** has goldens in light, dark and text 2.0.
- **Two final QA passes:**
  - 580 goldens reviewed;
  - 39 on-device defects found and fixed, including a11y, deep links, IST dates and settle-up rules.
- **Device suites passed on the emulator** (phase 19): airplane mode, a real WorkManager run, app lock, UPI with a
  fake app, and the payment bubble e2e.
- **Known flaky test:** `recurring_detail_test` fails once in a while under full-suite load (it passes alone).

## APKs

Built into `splitify-artifacts/apk/final-2026-11-23/`. All are signed with the debug key, because the main
checkout has a stale `.git/index.lock` (see below):
- `splitify-standard-*.apk`: no payment bubble. Play Protect allows it for anyone who downloads it.
- `splitify-full-*.apk`: with the bubble. Install over USB with `adb install`; Play Protect's India fraud
  protection blocks sideloaded apps that declare notification-listener or accessibility services.

Build commands: `powershell -File tool\build_release.ps1 -Flavor both` (release key from
`secrets/release-key.properties`), or `flutter build apk --release [--flavor full]`.

## Owner checklist

| # | What | Why |
|---|---|---|
| 1 | Delete the stale `splitify-free-forever\.git\index.lock` (left by a git process on 2026-11-22). Then run `tool\build_release.ps1 -Flavor both` in the main checkout for release-signed APKs. | Release-signed builds; the guard forbids sessions from deleting files in `.git`. |
| 2 | Back up `secrets/splitify-release.jks` and `secrets/release-key.properties` (password manager or a second drive). | If they are lost, users can't install updates. |
| 3 | BLK-002: check the email sign-in code on a phone (code length = `EMAIL_OTP_LENGTH`, default 6; right code signs you in; an old code is refused). | Reading the code email was refused to the agent. |
| 4 | Google consent screen: add any extra testers under Audience → Test users. Before public release, publish it with home page = the repo URL and privacy policy = `docs/PRIVACY.md` on GitHub. | It is in Testing, so only listed test users can use Google sign-in. |
| 5 | Payment bubble on a real phone: pay ₹1 with GPay, PhonePe and Paytm and note which ones show a bubble (checklist in `phase-18b.md`). Send screenshots of notifications that don't. | Real UPI apps can't run on the emulator; wording fixes go in `payment_recipes.json`. |
| 6 | Check live updates between two phones (Realtime). | This PC's DNS workaround blocks websockets on the emulator. |
| 7 | Phase 20 checklist R: create the prod Supabase project and re-run migrations 0001–0024 + functions there. | D-023. |
| 8 | Supabase custom domain or proxy. | Some Indian ISPs block `*.supabase.co`; this PC needs a DNS pin. |
| 9 | Re-enable CI: `gh workflow enable CI`. | D-022. |
| 10 | Optional: re-run `tool/e2e/perf.ps1` on an idle PC; leaked-password protection (Pro plan); prune `mutation_log` with the snippet in `supabase/README.md`. | Phase 19 notes. |
| 11 | Optional: test fixtures use the owner's first name in about 31 places. Rename them if that's not wanted in a public repo. | Final QA note. |
| 12 | Clean up leftover local folders next to the repo: `sp06`, `sp08`, `splitify-p04`, `w06`, `w07`, `wapk`, and git stashes from the early phases. | Housekeeping. |
