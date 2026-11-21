# Phase 11 — Friends, total with a friend, simplify debts, Pay via UPI (#2, #16, #17, #26)

- Depends on: 09 · Owner setup: 00 · Branch: `phase/11-friends-simplify-upi`
- Read first: `08-feature-specs.md` #2 #16 #17 #26, `05-money-engine.md` §5, `research/06-upi-release-ci.md`
  (UPI reality + fake handler manifest).

## Tasks

- [ ] T1 Server: `find_or_create_direct_group` (unique pair; name-only friend allowed) — pgTAP; `my_overview`
      friend totals verified (TC-16-02).
- [ ] T2 Friends tab (list with per-currency totals, search) and friend page (header, shared items across groups,
      Add expense / Settle up actions); add friend expense flow.
- [ ] T3 Simplify toggle in group settings + Balances view switch + "Show original debts"; `settings_changed`
      activity.
- [ ] T4 UPI: `UpiLinkBuilder` (encoding, 2-dp amount, note ≤ 50 chars) unit-tested; `<queries>` for scheme
      `upi`; launch chooser; return → "Did the payment go through?" sheet → Mark as paid (payment method `upi`);
      fallbacks: copy UPI ID, copy amount, UPI QR sheet; hidden for non-INR or receiver without UPI ID.
- [ ] T5 `tool/fake_upi_app/` minimal Flutter (or Kotlin) debug app, package `dev.splitify.fakeupi`, intent-filter
      `upi://pay`, logs URI with tag `FAKE_UPI` and shows it; build script; integration test asserts params; test
      the "no UPI app" path after uninstalling it.
- [ ] T6 Celebration animation on settling a person to zero.

## Tests

TC-2-01…03, TC-16-02, TC-17-03, TC-26-01…05.

## Done when

Fake-UPI integration green; friend totals equal sum of group pairs in all test fixtures.

Pre-built (phase 06 session, branch prep/upi-recurrence): `lib/core/upi/upi_link.dart`, `test/fixtures/upi_vectors.json`, `test/core/upi/upi_link_test.dart` (T4 builder only; `<queries>`, launch and sheets still to do).
