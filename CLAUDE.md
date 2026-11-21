# Splitify Free Forever

Free, open-source expense-splitting app (Splitwise alternative), India-first (rupees, UPI). No limits, no ads.
Product plan: [docs/PLAN.md](docs/PLAN.md). It wins over any other doc.

## Stack

- Flutter (Dart), **Android first**. iOS later; web not planned.
- Backend: Supabase Cloud only (Postgres, Auth, Storage, Realtime, Edge Functions). Nothing Supabase runs locally.
- Add-ons: Firebase Cloud Messaging (push only), Frankfurter exchange rates (called from an Edge Function only).

## Conventions

- Default branch `main`. Branch per change; release versions are tags (`v1.0.0`), not branches.
- Public repo: run `git status` before every commit and check for secrets.
- Before committing code: `dart format .`, `flutter analyze`, `flutter test`.
- Database changes: numbered SQL files in `supabase/migrations/`. Edge Functions in `supabase/functions/`.
- Supabase URL + publishable key come from a Git-ignored file via `--dart-define-from-file`.
- Decisions: `planning/00-decisions.md` (owner decisions of 2026-11-21 close PLAN.md's open decisions).

## Building the app: the plan in `planning/`

- When the owner says **"execute the plan"** (or "continue the plan", "next phase", "run phase NN"), use the
  `execute-phase` skill and follow `planning/11-execution-protocol.md`. Build exactly **one phase**, then stop.
- **Never ask the owner anything during plan execution** — decide per the protocol, log `S-` decisions, log
  owner-only problems in `planning/BLOCKERS.md`, keep going.
- **Git exception (owner decision D-001, 2026-11-21):** in this repo, plan-execution sessions commit and push their
  phase branch (`phase/NN-slug`) **without asking**. They never commit to, merge into or push `main`, never
  force-push, never push tags. Outside plan execution follow CONTRIBUTING.md: branch from `main`, commit, push
  the branch, open a PR to `main` (owner decision 2026-11-21); never commit to or push `main` directly.
- Guard hooks in `.claude/hooks/` (wired in the git-ignored `.claude/settings.local.json`) enforce the hard limits;
  never work around them.

## Rules the app must follow

1. **Money is integer minor units** (₹100.50 = 10050 paise), always with a currency code. Never floats, in DB or Dart.
2. **Fixed rounding:** leftover units go one each to people in a fixed order, so parts sum to the total
   (₹100 ÷ 3 = 33.34 + 33.33 + 33.33).
3. **Server holds true balances** (Postgres computes them). Offline, the phone shows local balances marked "not synced yet".
   A person's per-group balances always sum to their overall balance.
4. **Never mix currencies silently.** Balances are per currency. Conversions use a rate saved with the expense
   (rate, date, source); saved rates are never recalculated.
5. **Exchange rates come from the server:** an Edge Function stores daily Frankfurter rates in a rates table.
   The user may type a rate when offline or for an unlisted currency.
6. **Offline-first from day one:** client-generated UUIDs, local change queue sent in order when online,
   last save wins, both versions kept in edit history.
7. **Row Level Security on every table.** Users only see and change groups they belong to.
8. **Members are not accounts.** Name-only members can later be claimed by a real account via invite.
9. **Nothing is lost:** deletes are soft and logged, so they can be restored. Every add, edit, delete, payment and
   reminder goes to the activity log with who and when.
10. **Notifications start from the activity log** → in-app notifications → Edge Function sends FCM push, respecting
    per-user settings. Device tokens stored per device, removed on sign-out.
11. **Any group member can add, edit and delete expenses** (D-008), with full history and restore.
12. **Simplify debts never changes what anyone owes overall.** Per currency, off by default, normal view stays available.
13. **UPI link:** `upi://pay?pa=<UPI ID>&pn=<name>&am=<amount>&cu=INR&tn=<note>`. Record a payment only when the user
    taps "Mark as paid". UPI only for rupee balances.
14. **Schema lives in the repo** (migrations + functions), so anyone can rebuild the backend in their own Supabase project.
15. **No secrets in the repo.** Only the publishable key ships in the app (from a Git-ignored file).
    `google-services.json` stays out of Git. Firebase service-account key and other secrets live only as
    Supabase Edge Function secrets.

## Windows dev environment

- Flutter SDK: `C:\src\flutter`. Emulator: `Pixel_9_API_36` (avoid Android 37 images, they crash on this GPU).
- If `flutter` fails with `'WHERE' is not recognized`, the system PATH has empty entries. In PowerShell, run first:
  `$env:Path = ((([Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')) -split ';') | ? { $_ -ne '' }) -join ';'`
- Internet drops on big downloads: use resumable downloads (`curl -C -`).
