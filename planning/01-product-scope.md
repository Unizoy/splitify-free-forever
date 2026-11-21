# 01 — Product scope

Source of truth for *what*: `docs/PLAN.md` (34 features, 15 rules) + owner extras X1–X3 (D-009).
Behaviour per feature: `08-feature-specs.md`. This file maps scope to phases.

| Feature | Phase | Feature | Phase |
| --- | --- | --- | --- |
| B1 Sign-in & account | 05 | 17 Simplify debts | 03 (engine), 04 (SQL), 11 (UI) |
| B2 Profile | 05 | 18 Activity feed | 06 (server), 09 (UI) |
| B3 Light/dark mode | 02 | 19 Notifications | 13 |
| 1 Groups | 07 | 20 Edit history & restore | 06 (server), 12 (UI) |
| 2 Friend expenses | 11 | 21 Group totals | 09 |
| 3 Invite by code/QR | 07 | 22 CSV export | 17 |
| 4 Name-only members | 07 | 23 Reminder | 13 |
| 5–9 Split types | 03, 08 | 25 Record a payment | 09 |
| 10 Multiple payers | 03, 10 | 26 Pay via UPI | 11 |
| 11 IOU / loan | 03, 10 | 27 Offline entry | 06 (engine), 15 (polish) |
| 12 Recurring bills | 16 | 29 Receipt photo | 10 |
| 13 Expense details + comments | 08, 12 | 32 Currency conversion | 03, 14 |
| 14 Mixed currencies | 03, 14 | 33 Charts | 17 |
| 15 Group balances | 03, 04, 09 | 34 Search | 16 |
| 16 Total with a friend | 03, 11 | 35 Default split | 08 |
| X1 Import from Splitwise | 18 | X2 App lock | 18 |
| X3 Home-screen widget | 18 | | |

**Out of scope** (PLAN.md): receipt scanning/OCR, itemized split, card import/payment service, WhatsApp/SMS/email
reminders, group whiteboard, limits/ads/paid tiers, web app, iOS (later), Hindi (D-009), Play Store (D-014).

**Ideas noted for later (not built):** iOS build, Play Store listing, Hindi, F-Droid flavour without FCM,
weekly balance digest notification, trip budgets.
