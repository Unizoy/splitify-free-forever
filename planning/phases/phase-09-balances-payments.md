# Phase 09 — Balances, payments, activity, totals (#15, #18, #21, #25)

- Depends on: 08 · Owner setup: 00 · Branch: `phase/09-balances-payments`
- Goal: the core loop is complete — PLAN.md milestone 2 "a real group can track a week of expenses and settle up".
- Read first: `08-feature-specs.md` #15 #18 #21 #25, `07-screens-and-flows.md` (Balances, Settle up, Activity),
  `05-money-engine.md` §5.

## Tasks

- [x] T1 Balances tab: OverlapBanner summary, per-currency sections, nets, who-owes-whom (pairs; simplified view
      wired in phase 11), row actions Settle (Remind arrives phase 13).
- [x] T2 Settle up screen (record payment: person/direction, prefilled amount, method chips, date, note, ArcGauge,
      amber CTA) + payments in expense list + payment detail/edit/delete.
- [x] T3 Local vs server balance checksum after sync (`group_balances`) with mismatch logging.
- [x] T4 Activity tab (all groups, day groups, filter chips, own unsynced items with SyncMarker) + group feed
      section; tap navigates to target; ARB sentence templates for every activity type.
- [x] T5 Totals tab (#21): total spent per currency excluding IOU/payments, per person paid/share, this month/all.
- [x] T6 Groups home GlassCard + Account WalletCard use real overall balances (`my_overview` online, local when
      offline with SyncMarker).
- [x] T7 E2E "week in Goa": scripted 7 days × 3 people (A on app, B and C via harness) with mixed split types and
      2 payments → balances and simplified-off pairs equal the oracle (compute expected with
      `planning/reference/money_reference.py` logic in the test) → everyone settles → all zero.

## Tests

TC-15-03, 15-04, TC-18-02, 18-03, TC-21-01, 21-02, TC-25-02, 25-03.

## Done when

Week scenario green on the emulator; screens pass `ui-review`.

> **Amendment (S-076, phase 07):** placeholders to replace: Groups tab hero ₹0 + "All settled" and card status
> "Settled" (`groups_home_screen.dart`), group detail StatusPill + Balances/Totals tabs (`group_detail_screen.dart`,
> `group_tabs.dart`), "Settle up" button (key `group-settle`). Card sort "unsettled first" needs the balances too.
