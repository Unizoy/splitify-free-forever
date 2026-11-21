# Money-Splitting App — Requirements & Product Plan

Nov 21, 2026 · @Alex

> Converted from `Money-Splitting App — Requirements & Product Plan.pdf` (13 pages).
> Where other docs disagree with this one, this plan wins.

## Overview

We are building a free, open-source Android app for splitting money with friends, flatmates, couples and trip groups.
It gives people Splitwise's everyday features and its most useful Pro features, with no daily limits and no ads.

- **What it is:** a shared record book. People log who paid for what; the app works out who owes whom.
  Money never moves through the app.
- **Who it's for:** groups in India first (rupees, UPI). The app also works for any single-currency group.
- **Why people would switch from Splitwise:** Splitwise's free plan now caps new expenses at about 4 a day and shows ads.
  Search, charts and default splits are Pro-only. People also can't add a friend who hasn't signed up
  (except on the website). Our app has none of these limits.
- **How settling works:** a "Pay via UPI" button opens the payer's own UPI app (GPay, PhonePe, Paytm and others)
  with the amount filled in. The payer then taps "Mark as paid".

## Decisions already made

The app is Flutter on Android, backed only by Supabase Cloud, plus two small free add-ons:
Firebase Cloud Messaging for push notifications and an exchange-rate service for currency conversion.

| Area | Decision |
| --- | --- |
| App framework | Flutter (Dart) |
| Backend | Supabase Cloud only: Postgres database, Auth, Storage, Realtime. Nothing Supabase-related runs on the PC. |
| Platforms | Android first. iOS later (needs a Mac). Web is not planned. |
| License | Open source; the exact license is still open (see [Open decisions](#open-decisions)) |
| Notifications | In-app bell plus push notifications to the phone through Firebase Cloud Messaging (FCM). No WhatsApp, SMS or email reminders. |
| Outside services | Two, both free: FCM (push notifications only) and an exchange-rate service (currency conversion only). UPI works by opening the user's UPI app with a link; it isn't an outside service. |
| Internet | Not always needed: expenses can be added and edited offline, and they sync automatically when the phone is back online. |
| Currency | Each group has a main currency, but any expense can be in another currency. Amounts can be converted at the exchange rate of that day. |
| Limits and ads | None |

## What's required to build it

The PC needs the Flutter and Android tools, plus one Supabase Cloud project. You've already installed Flutter and Android Studio.

### On the Windows PC

| Tool | Why | Status |
| --- | --- | --- |
| Windows Hypervisor Platform (a Windows feature) | Makes the Android emulator fast | Check it's turned on |
| Git for Windows | Version control and GitHub; Claude Code uses Git Bash | Check |
| VS Code + Flutter extension | Code editor; installs the Flutter SDK | Done |
| Flutter SDK (latest stable) | The app framework | Done |
| Android Studio + Android SDK (API 36, Build-Tools, Command-line Tools, Emulator, Platform-Tools, CMake, NDK) | Builds Android apps; provides the emulator | Done; licenses must be accepted with `flutter doctor --android-licenses` |
| Emulator or a real Android phone with USB debugging | To run the app | Check |
| Claude Code (Pro plan or higher) | The local coding session | Install with `irm https://claude.ai/install.ps1 \| iex` |

### In the cloud

| Item | Details |
| --- | --- |
| Supabase account | Free plan |
| Dev project | Name it `<app-name>-dev`, region South Asia (Mumbai). Later, a separate `<app-name>-prod` (the free plan allows 2 active projects). |
| Keys the app uses | Project URL + **publishable key** (`sb_publishable_...`). They go into the app through a Git-ignored file and `--dart-define-from-file`. The **secret key** never goes in the app or the repo. |
| Supabase Edge Functions | Small server functions running inside Supabase: one sends push notifications, one fetches daily exchange rates. Deploy them through Supabase MCP or the dashboard. If that gets awkward, add the Supabase CLI later just for deploying. |
| Firebase project (free) | Used **only** for Firebase Cloud Messaging (push notifications). Add an Android app in the Firebase console and download `google-services.json` (kept out of Git). Create a service-account key and store it **only** as a Supabase Edge Function secret. |
| Exchange rates | [Frankfurter](https://frankfurter.dev): free, no API key, daily rates including INR. Called from an Edge Function, never from the phone directly. |
| Supabase MCP (optional) | Lets Claude Code run SQL and deploy functions on the **dev** project only: `claude mcp add --transport http supabase "https://mcp.supabase.com/mcp?project_ref=<dev-project-ref>"` |
| GitHub account | Hosts the open-source repo |

**Not needed:** WSL 2, Docker Desktop, Scoop, the Supabase CLI, Node.js, a separate Java/JDK, Visual Studio 2022.
(Firebase is used only for push notifications; nothing else from Firebase.)

**Check it all works:** `flutter doctor -v` shows ✓ for Flutter, Android toolchain, Android Studio, VS Code and
Connected device. `flutter devices` lists an Android device. Running `select now();` in the Supabase SQL Editor returns the time.

## Features to build

The app has 34 features: 33 are Easy or Medium, and offline entry is Hard.
The numbers match the earlier feature review; B1–B3 are basics every app needs.

| # | Area | Feature | What it does | Effort |
| --- | --- | --- | --- | --- |
| B1 | Basics | Sign-in and account | Sign in, sign out, delete account. The method is still to be confirmed (see Open decisions). | Easy |
| B2 | Basics | Profile | Name, photo, UPI ID (used by Pay via UPI) and default currency | Easy |
| B3 | Basics | Light and dark mode | Follows the phone setting, with a manual switch | Easy |
| 1 | Groups and people | Groups | Create, rename and archive a group. Each has a name, type (trip, home, couple, other), photo and main currency. | Easy |
| 2 | Groups and people | Friend expenses | Split with one person without making a group | Easy |
| 3 | Groups and people | Invite by code or QR | Each group has an invite code and a QR code. Others enter or scan it inside the app to join. No website is needed. | Medium |
| 4 | Groups and people | Name-only members | Add someone by name before they sign up. When they join with the invite, they claim that spot and keep its history. | Easy |
| 5 | Adding expenses | Split equally | Total ÷ the people chosen | Easy |
| 6 | Adding expenses | Split by exact amounts | Each person's amount typed in; they must add up to the total | Easy |
| 7 | Adding expenses | Split by percentages | Each person's percentage; they must add up to 100% | Easy |
| 8 | Adding expenses | Split by shares | e.g. 2 shares, 1 share, 1 share | Easy |
| 9 | Adding expenses | Split by adjustment | Equal split, plus or minus a fixed amount for some people | Easy |
| 10 | Adding expenses | Multiple payers | Several people paid one bill; what each paid must add up to the total | Medium |
| 11 | Adding expenses | IOU / loan | A debt between two people with no bill, e.g. "lent ₹500" | Easy |
| 12 | Adding expenses | Recurring bills | Repeat weekly, fortnightly, monthly or yearly; the app adds the next copy automatically on its date | Medium |
| 13 | Adding expenses | Expense details | Description, date, category, note, and comments from group members | Easy |
| 14 | Adding expenses | Mixed currencies in a group | Any expense can use a different currency from the group's main one (e.g. a USD hotel in a rupee group). Balances are kept separately per currency. | Medium |
| 32 | Adding expenses | Currency conversion | Convert an expense, or a group's balances, into the main currency at that day's rate. The rate is fetched automatically, or typed in by hand when offline, and saved with the expense. | Medium |
| 29 | Adding expenses | Receipt photo | Attach one photo to an expense, compressed before upload. It uploads later if added offline. | Easy |
| 35 | Adding expenses | Default split per group | The group remembers a split (e.g. 60/40) and uses it for new expenses | Easy |
| 27 | Adding expenses | Offline entry | Add, edit and delete expenses and payments without internet. Changes are saved on the phone and sync automatically when it's back online. A clear marker shows what hasn't synced yet. | Hard |
| 15 | Balances | Group balances | Who owes whom in the group, and each person's net balance, per currency | Medium |
| 16 | Balances | Total with a friend | Your net balance with one person across all groups and friend expenses | Medium |
| 17 | Balances | Simplify debts | A group setting that shows the fewest payments needed to settle everyone (per currency, or after converting to the main currency) | Medium |
| 21 | Balances | Group totals | Total spent by the group, and by each person | Easy |
| 25 | Settling up | Record a payment | "Rahul paid me ₹500", by cash or any other method, in any currency | Easy |
| 26 | Settling up | Pay via UPI | Opens the payer's UPI app with the receiver's UPI ID, name, amount and a note filled in. The payer then marks it as paid. Rupee balances only. | Easy |
| 18 | Staying informed | Activity feed | A timeline of adds, edits, deletes and payments, per group and overall | Easy |
| 19 | Staying informed | Notifications | A bell inside the app with an unread count, plus push notifications to the phone (new expense, edit, payment, reminder, comment). Each person can turn kinds on or off. | Medium |
| 23 | Staying informed | Reminder | "Remind" sends the other person a push notification and puts a note in their bell | Easy |
| 20 | Staying informed | Edit history and restore | See each change to an expense (who, when, what), and restore deleted expenses | Medium |
| 34 | Finding and reviewing | Search | Find expenses by description, note, amount or person | Easy |
| 33 | Finding and reviewing | Simple charts | Spending by category and by month, for a group or for you, in the main currency | Medium |
| 22 | Finding and reviewing | Export | Save a group's expenses as a CSV spreadsheet file | Easy |

## Rules the app must follow

Balances must always be exact and identical on every phone. These rules keep them that way.

1. **Money is whole minor units, never decimals.** Store and calculate every amount as an integer in the currency's
   smallest unit (₹100.50 = 10050 paise), always with its currency code. Use integers in the database and in Dart.
2. **Rounding is fixed.** When an amount doesn't divide evenly, the leftover units go one each to people in a fixed
   order, so the parts always add up to the total. Example: ₹100 ÷ 3 = 33.34 + 33.33 + 33.33.
3. **The server holds the true balances.** Supabase/Postgres computes the official balances. Offline, the phone shows
   balances worked out from its local copy plus unsynced changes, marked as "not synced yet". Each person's balances
   across all groups always sum to their overall balance.
4. **Currencies are never mixed silently.** Each balance is kept per currency. A conversion uses a rate saved with the
   expense (rate, date and source), so every phone shows the same converted number. Saved rates are never recalculated later.
5. **Exchange rates come from the server.** An Edge Function fetches daily rates from Frankfurter and stores them in a
   rates table that every phone reads. When offline or for an unlisted currency, the user can type in the rate.
6. **Offline-first from day one.** Every record gets an ID created on the phone (a UUID). Changes go into a queue on the
   phone and are sent in order once online. If two people edit the same expense, the later save wins, and both versions
   stay in the edit history. Design the data layer this way from the start, even though the full offline polish comes
   later in the build order.
7. **Every table is protected by Row Level Security.** People can only see and change groups they belong to.
8. **Members are not accounts.** A group member can be a name only. A member can later be linked to a real account when
   that person joins with the invite.
9. **Nothing is lost.** Deleting an expense hides it and logs the deletion, so it can be restored. Every add, edit,
   delete, payment and reminder is written to the activity log with who and when.
10. **Notifications start from the activity log.** A new activity entry creates in-app notifications for the people
    involved. An Edge Function then sends the matching push notifications through FCM, respecting each person's
    notification settings. Device tokens are stored per device and removed on sign-out.
11. **Who can change what:** any group member can add expenses. Editing and deleting is still to be decided (see Open decisions).
12. **Simplify debts never changes what anyone owes overall.** It only changes who pays whom, it works per currency, and
    it's off by default. The normal view stays available.
13. **The UPI link uses the standard format:** `upi://pay?pa=<UPI ID>&pn=<name>&am=<amount>&cu=INR&tn=<note>`.
    The app can't confirm a payment went through, so a payment is recorded only when the user taps "Mark as paid".
    UPI is shown only for rupee balances.
14. **The schema lives in the repo.** Every database change is a numbered SQL file in `supabase/migrations/`, and Edge
    Function code lives in `supabase/functions/`. Both are committed to Git, then applied to the dev project, so anyone
    can rebuild the backend in their own Supabase project.
15. **No secrets in the repo.** Only the publishable key ships in the app, loaded from a Git-ignored file.
    `google-services.json` stays out of Git. The Firebase service-account key and any other secrets live only as
    Supabase Edge Function secrets.

## Main screens and user flows

After sign-in, Home has four tabs. Most of the work happens inside a group, and a friend's page offers the same actions.

**Screen map — four tabs lead everywhere; most work happens inside a group**

```
                              Home (after you sign in)
        ┌────────────────┬───────────────┴───────────────┬────────────────────┐
     Groups           Friends                        Activity              Account
  groups and       balance per friend           feed, bell, reminders   profile and settings
   balances              │
        │                │ same actions for a friend
        ▼                ▼
  ┌─────────────── Inside a group (or with a friend) ───────────────┐
  │ Expenses          Add expense       Settle up        Invite, settings   │
  │ list, balances,   split types,      record or pay    code/QR,           │
  │ charts            photo             via UPI          default split      │
  └──────────────────────────────────────────────────────────────────┘
```

The three most common flows:

1. **Add an expense:** Group → Add expense → amount, currency, who paid, who shares, split type → Save.
   This works offline; the expense syncs later.
2. **Settle up:** Group or friend → Settle up → pick the person → Pay via UPI (opens their UPI app) → Mark as paid.
   Or record a cash payment.
3. **Join a group:** Groups → Join → enter the code or scan the QR → claim your name-only spot, or join as a new member.

## Out of scope

These features are left out on purpose; any of them can be added later.

| Feature | Why it's out |
| --- | --- |
| Receipt scanning (reading a photo automatically) | Hard, and unreliable on Indian receipts. A receipt photo can still be attached (#29). |
| Itemized bill split | Slow to type in without scanning; "exact amounts" (#6) covers most cases |
| Card purchase import, Splitwise-style payment service or debit card | US only, and needs a banking partner |
| WhatsApp, SMS or email reminders | Not wanted. Reminders use push notifications and the in-app bell. |
| Group notes ("whiteboard") | Rarely used; people already keep notes in their WhatsApp group |
| Daily limits, ads, paid tiers, Trip Pass, early access | The app is free with no limits, so there's nothing to build |
| Web app and iOS | Later. iOS needs a Mac. |

## Suggested build order

Build it in 8 milestones. Each one ends with a working app on a real phone, so mistakes show up early.
Claude Code can refine the order when it plans the code.

1. **Foundation:** create the Flutter project and connect the Supabase dev project. Set up the migrations folder, the
   offline-ready local data layer and sync queue (rule 6), sign-in (B1), profile (B2) and light/dark mode (B3).
   - Done when: you can sign in on the phone and edit your profile.
2. **Core loop:** groups (1), name-only members (4), invite by code/QR (3), adding an expense with the five split types
   (5–9), expense details (13), group balances (15), recording a payment (25) and the activity feed (18).
   - Done when: a real group can track a week of expenses and settle up.
3. **More ways to split and settle:** multiple payers (10), IOU (11), friend expenses (2), total with a friend (16),
   simplify debts (17), Pay via UPI (26), default split (35), group totals (21) and receipt photos (29).
4. **Trust and notifications:** edit history and restore (20), the in-app bell plus push notifications through FCM (19),
   reminders (23) and comments.
5. **Currencies:** mixed currencies in a group (14), and conversion using the exchange-rate Edge Function (32).
6. **Offline polish:** full offline add/edit/delete (27), sync conflict handling, "not synced" markers, and testing in airplane mode.
7. **Extras:** recurring bills (12), search (34), charts (33) and CSV export (22).
8. **Release:** create the prod Supabase project, publish to Play Store internal testing, and write the README and
   license for the open-source repo.

## Open decisions

Six choices are still open. Until they're decided, Claude Code should use the defaults shown here.

- [ ] **App name.** Default: a placeholder name, changed before release.
- [ ] **Sign-in method.** Default: Google sign-in (one tap on Android, free; needs a Google Cloud OAuth client).
      Alternative: a code sent by email. Phone-number codes cost money for every SMS.
- [x] **Open-source license.** MIT (like Spliit and SplitPro) or AGPL-3.0 (keeps hosted copies open). Default: MIT.
      *Decided 2026-11-21: MIT, copyright Unizoy.*
- [ ] **Who can edit or delete expenses.** Anyone in the group (like Splitwise), only the person who added it, or the
      creator plus group admins. Default: anyone, with the full edit history.
- [ ] **Starting categories.** Default: Food, Groceries, Travel, Rent, Utilities, Shopping, Entertainment, Other.
- [ ] **Public hosting later.** A hosted version for everyone (Supabase Pro is about US$25/month) or self-hosting only.
      This can wait until release.

## How to hand this to Claude Code

Export this doc as Markdown, save it in the project folder, and ask Claude Code to write the technical plan before any code.

1. Click this doc's name → **Export** → **Markdown**. Save it as `C:\dev\<app-name>\docs\PLAN.md`, next to `SETUP.md`
   and `RESEARCH.md` from earlier. Where they disagree, `PLAN.md` wins, because `RESEARCH.md` was written before the
   feature list was final.
2. Open a terminal in `C:\dev\<app-name>`, run `claude`, and paste the prompt below.
3. Review the technical plan it writes, answer its questions, then let it build milestone by milestone.

```
Read docs/PLAN.md (the product plan) and docs/SETUP.md. Don't write app code yet.
1. Check my setup: run flutter doctor -v and flutter devices, and tell me what to fix.
2. Ask me about any "Open decisions" you need answered. Otherwise, use the defaults listed there.
3. Write docs/TECH_PLAN.md covering: architecture and state management; the
   offline-first local database and sync queue; the Supabase schema and Row Level
   Security policies as numbered SQL migrations; the Edge Functions (push
   notifications via FCM, daily exchange rates); the folder structure and packages;
   and a task list for each milestone in "Suggested build order", with "done when" checks.
4. Create a short CLAUDE.md with the project's conventions and the
   "Rules the app must follow" from PLAN.md.
Follow every rule in PLAN.md. Wait for my OK before starting milestone 1.
```

## References

- Splitwise Pro features · Splitwise review, 2026 (Money Crashers) · Splitwise App Store listing
- Google Pay India: split an expense · Paytm Split Bills · UPI link parameters (Google Pay India docs)
- Supabase push notifications with FCM · Supabase MCP · Supabase API keys · [Frankfurter exchange rates](https://frankfurter.dev)
- Flutter Android setup · Claude Code setup
