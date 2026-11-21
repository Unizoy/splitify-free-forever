# Phase 08 — Expenses and split types (#5–#9, #13, #35)

- Depends on: 07 · Owner setup: 00 · Branch: `phase/08-expenses-splits`
- Goal: add/edit/delete expenses offline with all five split types, details and categories, list + detail screens,
  default split per group.
- Read first: `08-feature-specs.md` #5–9 #13 #35, `07-screens-and-flows.md` (Add expense, group detail Expenses),
  `05-money-engine.md` §4 §7, `money-rules` skill.

## Tasks

- [ ] T1 Add-expense stepper (Amount · Paid by · Split · Details · Review) with fast-path Save; amount keypad with
      expressions; currency chip (group main currency; full picker arrives phase 14 — keep the API ready).
- [ ] T2 Split editor for equal/exact/percent/shares/adjust with live footer, error copy, Save disabled on error;
      single payer picker (multi-payer in phase 10).
- [ ] T3 Details: category picker (IconChips, parent → sub, keys from feature spec), date picker (534 style),
      notes. Review sentence summary.
- [ ] T4 Expense list in group (month headers, AmountRow with "you lent/borrowed/not involved", SyncMarker),
      expense detail screen (hero band, paid/owe rows; comments/history placeholders).
- [ ] T5 Edit (reopens same editor state from `split_kind` + `split_values`), delete (soft, undo snackbar).
- [ ] T6 Default split (#35): group settings editor + prefill + fallback.
- [ ] T7 Widget + golden tests for every editor state; integration: add one expense of each split type offline,
      sync, verify server rows and balances equal local.

## Tests

TC-5..9-03, TC-5..9-04, TC-13-01, TC-13-02, TC-35-01, TC-35-02.

## Done when

All split types round-trip local → server → other user with identical shares.
