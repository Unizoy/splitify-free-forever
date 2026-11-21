# Phase 03 — Money engine (pure Dart)

- Depends on: 01 · Owner setup: none · Branch: `phase/03-money-engine` · Features: core of #5–#11, #14–#17, #21,
  #25, #32
- Goal: `lib/core/money/` implementing `05-money-engine.md` exactly, proven by the shared vectors and property
  tests, plus formatter and amount-expression input.
- Read first: `05-money-engine.md`, `planning/reference/money_reference.py`, `money-rules` skill.

## Tasks

- [x] T1 Copy `planning/reference/money_vectors.json` → `test/fixtures/money_vectors.json`; write
      `test/core/money/vectors_test.dart` that runs every vector by `op` (split, check_payers, balances, convert,
      convert_expense, cross_rate) — red first.
- [x] T2 `currency.dart`, `currencies.dart` (ISO table: code, exponent, symbol, name; at least all currencies the
      Frankfurter v2 list contains), `money.dart` (value type, arithmetic only within the same currency, throws
      otherwise).
- [x] T3 `allocation.dart` (equal, ratio/Hamilton with fixed-order ties, using `BigInt`/`Rational` for quotas),
      `split.dart` (5 kinds + payers check, sealed `MoneyError` with codes and data), `balances.dart` (nets,
      expense pairs, pairwise, simplify), `fx.dart` (convert with explicit half-away rounding via `Decimal`,
      convertExpense, crossRate).
- [x] T4 Property tests (glados): parts sum; equal ≡ ratio with equal weights; simplify keeps nets and ≤ n−1
      transfers; pairwise nets equal nets; convert monotonic; split independent of map iteration order.
- [x] T5 `money_formatter.dart` (en_IN grouping, symbols, hide `.00` mode, signed display) +
      `amount_expression.dart` (digits . + − × ÷, Decimal evaluation, exponent-aware rounding, errors) with tests.
- [x] T6 Coverage of `lib/core/money` = 100 %.

## Tests

TC-5..9-01, TC-5..9-02, TC-10-01, TC-10-03, TC-11-01, TC-14-01, TC-15-01, TC-16-01, TC-17-01, TC-25-01, TC-32-01.

## Done when

All 52 vectors pass in Dart; property tests pass with ≥ 500 runs each; guards show no `double`/`num` in
`lib/core/money`.
