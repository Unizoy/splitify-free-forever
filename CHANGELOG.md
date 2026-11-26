# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions are git tags (for example `v1.0.0`), not branches.

## [0.2.0] - 2026-11-26

### Removed

- **Payment bubble** (and with it "Payments to add", the Account row and its settings screen). It will come back
  later in a separate release. There is now one Android build: the app asks for no accessibility,
  notification-access, "display over other apps" or SMS permission. Payments the bubble had kept on the phone are
  deleted when you update.

## [1.0.0] - Unreleased

### Added

- **Sign-in** with Google or a one-time email code.
- **Groups and people**: groups with covers, name-only members, invite codes, claiming a name-only member from a
  real account, and friends.
- **Expenses**: five split types, multiple payers, loans, receipt photos, categories and notes.
- **Balances**: balances per currency, an optional simplify-debts view per currency, settle up, and Pay via UPI
  (a payment is recorded only when you tap "Mark as paid").
- **Offline-first sync**: works offline, a local change queue sent in order, "not synced yet" markers, last save
  wins with both versions kept.
- **History and comments**: edit history, restore of deleted items, and comments on expenses and payments.
- **Notifications**: in-app notifications from the activity log, push notifications, per-user settings and
  payment reminders.
- **Currencies**: many currencies, daily exchange rates from the server, rates saved with each expense, and a
  typed rate when offline.
- **Repeating expenses**: copies added automatically by the server.
- **Search**, **charts** (insights) and **CSV export**.
- **Splitwise import** from CSV.
- **App lock** with biometrics or the device PIN.
- **Home-screen widget** with a balance summary.
- **Automatic categories**: the description picks the category ("Swiggy" → Takeaway), and a category you pick by
  hand is remembered on the phone.
- **Backend** in `supabase/`: migrations, three Edge Functions and SQL tests, so anyone can self-host.
- A privacy policy in `docs/PRIVACY.md`.

### Security

- Row Level Security on every table.
- An attack test suite (`supabase/tests/190_attack.test.sql`) and payload size limits.
- Storage object name checks and per-user folder rules.
- Only the publishable key ships in the app.
