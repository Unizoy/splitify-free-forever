# 05 — Money engine

Exact rules for every amount in the app. Oracle: `planning/reference/money_reference.py`; its output
`planning/reference/money_vectors.json` (52 vectors) is the **contract**: the Dart engine (phase 03) and the
Postgres functions (phase 04) must reproduce every vector exactly. Regenerate with
`python planning/reference/money_reference.py > planning/reference/money_vectors.json` (never hand-edit).

## 1. Representation

- `Money = (int minor, String currency)`. Dart `int` (64-bit on Android), Postgres `bigint`. **No `double`/`num`
  for amounts anywhere** (guard script fails the build).
- Currency exponent from ISO 4217: default 2; **0** for BIF CLP DJF GNF ISK JPY KMF KRW PYG RWF UGX UYI VND VUV XAF
  XOF XPF; **3** for BHD IQD JOD KWD LYD OMR TND. Table lives in `lib/core/money/currencies.dart` and
  `public.currencies` (code, exponent, symbol, name, frankfurter bool).
- Amount bounds: every expense/payment total `1 … 999_999_999_999` minor units. No zero or negative totals
  (a refund is entered as an expense paid by the person who got the refund, or as a payment).
- Ratios: percentages in **basis points** (`int`, 10000 = 100 %, input allows 2 decimals); shares in
  **thousandths** (`int`, 1500 = 1.5 shares, input allows 3 decimals). Exchange rates are **decimal strings**
  (≤ 10 decimal places, > 0), Dart `package:decimal`, Postgres `numeric(24,10)`.

## 2. Fixed order

Every allocation takes members in the **fixed order** = `group_members.position` ascending, then member `id`.
`position` is assigned when the member is created (max+1) and never changes. Callers must pass members sorted;
the engine never sorts by name or amount itself.

## 3. Allocation

- **Equal** (`allocate_equal`): `base = total ~/ n`, `rem = total % n`; the first `rem` members (fixed order) get
  `base + 1`. ₹100 ÷ 3 → 33.34, 33.33, 33.33 (rule 2).
- **Ratio** (`allocate_ratio`, used by percent, shares, conversions): largest remainder (Hamilton). Floor each exact
  quota `total × w / Σw`; hand the leftover units one each in order of largest fractional remainder, ties by fixed
  order. Zero weights always get 0. (Decision T-010: this is rule 2's "fixed order", with the order determined by
  remainders first — it keeps every share within one unit of exact. For equal weights it equals the equal split.)
- Parts always sum to the total (asserted in tests and by DB constraint triggers).

## 4. Split types (`split(total, kind, members, values)`)

| Kind | Input | Rule | Errors (code → UI text) |
| --- | --- | --- | --- |
| equal | members | §3 equal | `NO_PARTICIPANTS` → "Pick at least one person" |
| exact | minor units per member | must sum to total; 0 allowed | `SUM_MISMATCH{remaining}` → "₹x left" / "₹x over"; `NEGATIVE_SHARE` |
| percent | basis points per member | Σ = 10000; ratio allocation | `PERCENT_SUM_MISMATCH{remaining_bps}` → "x % left"; `PERCENT_OUT_OF_RANGE` |
| shares | thousandths per member | Σ > 0; ratio allocation | `NO_SHARES` → "Give someone at least one share"; `NEGATIVE_SHARE` |
| adjust | signed minor-unit adjustment per member (default 0) | `rest = total − Σadj ≥ 0`, equal-split `rest` over all members, add adjustment | `ADJUSTMENTS_EXCEED_TOTAL{over}`; `NEGATIVE_SHARE` → "x's share can't go below ₹0" |

Common: `AMOUNT_NOT_POSITIVE`, `AMOUNT_TOO_LARGE`. Members with a 0 share stay listed (they were chosen) but owe 0.
The split editor recomputes live; Save is disabled while any error exists. Stored data is always the **resulting
minor-unit shares** plus `split_kind` and the raw `split_values` (so editing reopens the same editor state).

**Payers:** `paid` per member, each ≥ 0, Σ = total (`PAYERS_SUM_MISMATCH{remaining}`). Default one payer = the
current user's member. **IOU / loan:** expense with `kind = 'iou'`, payer = lender, one share = borrower × total;
excluded from spending totals/charts. **Default split (#35):** group stores `{kind, values}`; new expenses start
from it when its members are still active, else fall back to equal.

## 5. Balances (per group, per currency — never mixed)

- **Net:** `net(m) = Σ paid(m) − Σ share(m) + Σ payments sent(m) − Σ payments received(m)`. Positive = is owed.
  Invariants: Σ nets in a group per currency = 0; a user's overall balance per currency = Σ over their groups
  (friend pages included) — rule 3.
- **Who owes whom (simplify OFF):** for each expense, take per-expense nets `paid − share`, match debtors to
  creditors in fixed order (north-west corner; exact, no rounding; single payer ⇒ everyone owes the payer their
  share). Sum per pair across expenses; payments reduce what `from` owes `to`; show the net per pair
  (`pairwise` in the oracle). A cycle can show non-zero pairs while all nets are 0 — that is correct
  "original debts" behaviour; turning simplify on removes them.
- **Simplify debts (#17, rule 12):** from the nets: (1) settle exact opposites in fixed order, (2) repeatedly move
  `min(largest credit, largest debt)` from the largest debtor to the largest creditor, ties by fixed order.
  Never changes any net; ≤ n−1 transfers; deterministic. May pair people who never shared an expense (same as
  Splitwise) — the UI says so in the toggle's help text. Off by default, per group, per currency; the normal view
  is one tap away.
- **Total with a friend (#16):** Σ over shared groups of what the group screen shows between the two people
  (simplified transfers if that group has simplify on, else pairwise) + their friend (direct) group. Per currency.
- **Server vs phone (rule 3):** Postgres computes official balances with the same algorithms
  (`public.group_balances(group_id)` returns nets, pairs, simplified per currency). The phone computes the same
  locally from its database for instant/offline display; rows from unsynced changes mark the result
  "not synced yet". When server and local results differ after sync, the server wins and the mismatch is logged
  (sync diagnostics) — it indicates a bug.

## 6. Currency conversion (#14, #32, rules 4–5)

- `convert(amount, from, to, rate)` = `round_half_away_from_zero(amount × rate × 10^(exp(to) − exp(from)))`.
  Implement rounding explicitly (sign × floor(|v| + ½)) in both Dart and SQL so they can't differ.
- **Converting an expense:** convert the total, then re-allocate payers and shares by their original amounts with
  the ratio allocation (so parts still sum). Saved with the expense: `fx_rate`, `fx_rate_date`, `fx_source`
  (`frankfurter` | `manual`), `fx_to_currency`, and the converted total/parts. Never recomputed later.
- **Rates:** the server stores Frankfurter's EUR-based daily rates; cross rate `rate(A→B) = eur[B] / eur[A]`
  rounded half-away to 10 decimals (`cross_rate`). The phone caches the latest rates table for offline use; when a
  date's rate is missing it uses the most recent earlier date and says so; unlisted currency or no cache ⇒ manual
  rate entry ("1 USD = ___ INR").
- **Group balances "in main currency" view:** every record in another currency must have a saved conversion; the
  view lists records without one and offers "Convert all at their dates' rates" (fetches/saves per record).
  Simplify "after converting" runs on these converted nets.

## 7. Formatting and input

- Display via `MoneyFormatter`: `intl` `en_IN` grouping for all currencies (₹1,00,000.50), currency symbol from the
  table, minus sign before the symbol (−₹500). Hide `.00` for whole amounts in lists and cards; show full
  precision on detail screens and in CSV.
- Input: custom amount keypad (digits, `.`, ⌫, and `+ − × ÷` for quick sums like `450+120`); evaluated with
  `Decimal`, result rounded half-away to the currency exponent; reject more decimals than the exponent allows;
  ignore commas, spaces and currency symbols when pasting. Max 999,999,999,999 minor units.

## 8. Code layout

- Dart: `lib/core/money/` → `currency.dart`, `currencies.dart`, `money.dart`, `allocation.dart`, `split.dart`,
  `balances.dart` (nets, pairwise, simplify), `fx.dart`, `money_formatter.dart`, `amount_expression.dart`,
  `money_error.dart` (sealed error types with the codes above). Pure Dart, no Flutter imports.
- SQL: `supabase/migrations/*_money_functions.sql` → `money.allocate_equal`, `money.allocate_ratio`,
  `money.split`, `money.convert`, `money.cross_rate`, `money.nets`, `money.pairwise`, `money.simplify`
  (schema `money`, `immutable`, `security invoker`).
- Tests: `test/core/money/vectors_test.dart` loads `test/fixtures/money_vectors.json` (copy of the planning file);
  property tests (glados) for: parts sum to total; result independent of everything except fixed order; equal ⇔
  ratio with equal weights; simplify keeps nets and gives ≤ n−1 transfers; conversion monotonic in amount.
  SQL: `tool/gen_sql_vectors.dart` turns the same JSON into `supabase/tests/money_vectors.test.sql` (pgTAP
  `is()` per vector).
