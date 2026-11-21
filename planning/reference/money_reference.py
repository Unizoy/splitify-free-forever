"""Reference implementation (oracle) of Splitify's money math.

Spec: planning/05-money-engine.md. The Dart engine (phase 03) and the Postgres functions (phase 04) must
produce exactly the outputs in money_vectors.json, which this script generates:

    python planning/reference/money_reference.py > planning/reference/money_vectors.json

Rules: integers only (minor units); Fraction/Decimal only for ratios and FX; ties broken by the fixed member
order (the order of the `members` list = member position, then member id).
"""
from __future__ import annotations

import json
import sys
from decimal import Decimal, ROUND_HALF_UP
from fractions import Fraction

# ISO 4217 minor-unit exponents that differ from the default of 2.
EXPONENTS = {
    **{c: 0 for c in "BIF CLP DJF GNF ISK JPY KMF KRW PYG RWF UGX UYI VND VUV XAF XOF XPF".split()},
    **{c: 3 for c in "BHD IQD JOD KWD LYD OMR TND".split()},
}
MAX_AMOUNT = 999_999_999_999  # minor units per amount (≈ ₹9,999 crore)


class MoneyError(Exception):
    def __init__(self, code: str, **data):
        super().__init__(code)
        self.code, self.data = code, data


def exponent(currency: str) -> int:
    return EXPONENTS.get(currency, 2)


def check_amount(total: int) -> None:
    if not isinstance(total, int) or total <= 0:
        raise MoneyError("AMOUNT_NOT_POSITIVE")
    if total > MAX_AMOUNT:
        raise MoneyError("AMOUNT_TOO_LARGE")


# ---------------------------------------------------------------- allocation
def allocate_equal(total: int, members: list[str]) -> dict[str, int]:
    """Equal split: leftover units go one each to members in fixed order."""
    if not members:
        raise MoneyError("NO_PARTICIPANTS")
    base, rem = divmod(total, len(members))
    return {m: base + (1 if i < rem else 0) for i, m in enumerate(members)}


def allocate_ratio(total: int, weights: list[tuple[str, int]]) -> dict[str, int]:
    """Largest-remainder (Hamilton). Ties -> fixed order. Zero weights always get 0."""
    w_sum = sum(w for _, w in weights)
    if w_sum <= 0 or any(w < 0 for _, w in weights):
        raise MoneyError("INVALID_WEIGHTS")
    quotas = [Fraction(total * w, w_sum) for _, w in weights]
    floors = [q.numerator // q.denominator for q in quotas]
    left = total - sum(floors)
    order = sorted(range(len(weights)), key=lambda i: (-(quotas[i] - floors[i]), i))
    for i in order[:left]:
        floors[i] += 1
    return {weights[i][0]: floors[i] for i in range(len(weights))}


# ---------------------------------------------------------------- split types
def split(total: int, kind: str, members: list[str], values: dict[str, int] | None = None) -> dict[str, int]:
    """members = chosen participants in fixed order. values per kind:
    equal: none · exact: minor units · percent: basis points (10000 = 100 %) ·
    shares: thousandths of a share (1500 = 1.5) · adjust: signed minor-unit adjustment per member (missing = 0)."""
    check_amount(total)
    if not members:
        raise MoneyError("NO_PARTICIPANTS")
    values = values or {}
    if kind == "equal":
        return allocate_equal(total, members)
    if kind == "exact":
        amounts = {m: values.get(m, 0) for m in members}
        if any(a < 0 for a in amounts.values()):
            raise MoneyError("NEGATIVE_SHARE")
        diff = total - sum(amounts.values())
        if diff != 0:
            raise MoneyError("SUM_MISMATCH", remaining=diff)
        return amounts
    if kind == "percent":
        bps = {m: values.get(m, 0) for m in members}
        if any(b < 0 or b > 10000 for b in bps.values()):
            raise MoneyError("PERCENT_OUT_OF_RANGE")
        if sum(bps.values()) != 10000:
            raise MoneyError("PERCENT_SUM_MISMATCH", remaining_bps=10000 - sum(bps.values()))
        return allocate_ratio(total, [(m, bps[m]) for m in members])
    if kind == "shares":
        sh = {m: values.get(m, 0) for m in members}
        if any(s < 0 for s in sh.values()):
            raise MoneyError("NEGATIVE_SHARE")
        if sum(sh.values()) == 0:
            raise MoneyError("NO_SHARES")
        return allocate_ratio(total, [(m, sh[m]) for m in members])
    if kind == "adjust":
        adj = {m: values.get(m, 0) for m in members}
        rest = total - sum(adj.values())
        if rest < 0:
            raise MoneyError("ADJUSTMENTS_EXCEED_TOTAL", over=-rest)
        eq = allocate_equal(rest, members)
        out = {m: eq[m] + adj[m] for m in members}
        if any(v < 0 for v in out.values()):
            raise MoneyError("NEGATIVE_SHARE")
        return out
    raise MoneyError("UNKNOWN_SPLIT")


def check_payers(total: int, paid: dict[str, int]) -> None:
    if not paid or any(v < 0 for v in paid.values()):
        raise MoneyError("INVALID_PAYERS")
    diff = total - sum(paid.values())
    if diff != 0:
        raise MoneyError("PAYERS_SUM_MISMATCH", remaining=diff)


# ---------------------------------------------------------------- balances
def nets(order: list[str], expenses: list[dict], payments: list[dict]) -> dict[str, int]:
    """Net per member for ONE currency. Positive = is owed. expenses: {paid:{}, shares:{}}; payments: {from,to,amount}."""
    n = {m: 0 for m in order}
    for e in expenses:
        for m, v in e["paid"].items():
            n[m] += v
        for m, v in e["shares"].items():
            n[m] -= v
    for p in payments:
        n[p["from"]] += p["amount"]
        n[p["to"]] -= p["amount"]
    return n


def expense_pairs(order: list[str], paid: dict[str, int], shares: dict[str, int]) -> list[tuple[str, str, int]]:
    """Who owes whom for one expense: per-expense nets, matched debtor->creditor in fixed order (north-west
    corner). Exact (no rounding); with a single payer every participant simply owes the payer their share."""
    net = {m: paid.get(m, 0) - shares.get(m, 0) for m in order if m in paid or m in shares}
    debtors = [[m, -v] for m, v in net.items() if v < 0]
    creditors = [[m, v] for m, v in net.items() if v > 0]
    out, i, j = [], 0, 0
    while i < len(debtors) and j < len(creditors):
        x = min(debtors[i][1], creditors[j][1])
        out.append((debtors[i][0], creditors[j][0], x))
        debtors[i][1] -= x
        creditors[j][1] -= x
        if debtors[i][1] == 0:
            i += 1
        if creditors[j][1] == 0:
            j += 1
    return out


def pairwise(order: list[str], expenses: list[dict], payments: list[dict]) -> list[tuple[str, str, int]]:
    """Aggregated 'original debts' (simplify OFF): list of (debtor, creditor, amount>0) in fixed order."""
    idx = {m: i for i, m in enumerate(order)}
    acc: dict[tuple[str, str], int] = {}

    def add(a: str, b: str, x: int) -> None:  # a owes b x
        key = (a, b) if idx[a] < idx[b] else (b, a)
        acc[key] = acc.get(key, 0) + (x if key == (a, b) else -x)

    for e in expenses:
        for d, c, x in expense_pairs(order, e["paid"], e["shares"]):
            add(d, c, x)
    for p in payments:  # paying reduces what `from` owes `to`
        add(p["from"], p["to"], -p["amount"])
    out = []
    for (a, b), v in sorted(acc.items(), key=lambda kv: (idx[kv[0][0]], idx[kv[0][1]])):
        if v > 0:
            out.append((a, b, v))
        elif v < 0:
            out.append((b, a, -v))
    return out


def simplify(order: list[str], net: dict[str, int]) -> list[tuple[str, str, int]]:
    """Fewest-payments heuristic, deterministic: (1) exact opposites in fixed order, (2) greedy largest debtor ->
    largest creditor, ties by fixed order. Never changes anyone's net; at most n-1 transfers."""
    if sum(net.values()) != 0:
        raise MoneyError("NETS_DO_NOT_SUM_TO_ZERO")
    bal = {m: net.get(m, 0) for m in order}
    idx = {m: i for i, m in enumerate(order)}
    out = []
    for d in order:
        if bal[d] < 0:
            for c in order:
                if bal[c] > 0 and bal[c] == -bal[d]:
                    out.append((d, c, bal[c]))
                    bal[d], bal[c] = 0, 0
                    break
    while any(v != 0 for v in bal.values()):
        c = min((m for m in order if bal[m] > 0), key=lambda m: (-bal[m], idx[m]))
        d = min((m for m in order if bal[m] < 0), key=lambda m: (bal[m], idx[m]))
        x = min(bal[c], -bal[d])
        out.append((d, c, x))
        bal[c] -= x
        bal[d] += x
    return out


# ---------------------------------------------------------------- currency conversion
def round_half_away(v: Decimal) -> int:
    return int(v.quantize(Decimal(1), rounding=ROUND_HALF_UP))


def convert(amount: int, frm: str, to: str, rate: str) -> int:
    """rate = how many major units of `to` one major unit of `frm` buys, as a decimal string (≤ 10 decimals)."""
    r = Decimal(rate)
    if r <= 0:
        raise MoneyError("INVALID_RATE")
    return round_half_away(Decimal(amount) * r * (Decimal(10) ** (exponent(to) - exponent(frm))))


def convert_expense(total: int, frm: str, to: str, rate: str, paid: dict[str, int], shares: dict[str, int],
                    order: list[str]) -> dict:
    """Convert the total, then re-allocate payers and shares by their original amounts (Hamilton), so parts sum."""
    t = convert(total, frm, to, rate)
    p = allocate_ratio(t, [(m, paid[m]) for m in order if m in paid])
    s = allocate_ratio(t, [(m, shares[m]) for m in order if m in shares])
    return {"total": t, "paid": p, "shares": s}


def cross_rate(eur_rates: dict[str, str], frm: str, to: str) -> str:
    """Frankfurter stores EUR-based rates. Cross rate rounded half-away to 10 decimals, as a string."""
    a = Decimal(1) if frm == "EUR" else Decimal(eur_rates[frm])
    b = Decimal(1) if to == "EUR" else Decimal(eur_rates[to])
    return str((b / a).quantize(Decimal("0.0000000001"), rounding=ROUND_HALF_UP))


# ---------------------------------------------------------------- vectors
def vectors() -> list[dict]:
    V: list[dict] = []

    def case(cid: str, op: str, inp: dict, fn):
        try:
            out = {"ok": fn()}
        except MoneyError as e:
            out = {"error": e.code, **({"data": e.data} if e.data else {})}
        V.append({"id": cid, "op": op, "input": inp, "expected": out})

    ABC = ["A", "B", "C"]
    sp = lambda cid, total, kind, members, values=None: case(
        cid, "split", {"total": total, "kind": kind, "members": members, "values": values or {}},
        lambda: split(total, kind, members, values))
    sp("SPLIT-EQ-01", 10000, "equal", ABC)                       # ₹100 / 3 -> 33.34, 33.33, 33.33
    sp("SPLIT-EQ-02", 1, "equal", ABC)                           # 1 paisa / 3
    sp("SPLIT-EQ-03", 2, "equal", ABC)
    sp("SPLIT-EQ-04", 10000, "equal", ["A"])
    sp("SPLIT-EQ-05", 10001, "equal", ["A", "B"])
    sp("SPLIT-EQ-06", 100000, "equal", [f"M{i:03d}" for i in range(100)])
    sp("SPLIT-EQ-07", 99999, "equal", [f"M{i:03d}" for i in range(100)])
    sp("SPLIT-EQ-08", 0, "equal", ABC)                           # error
    sp("SPLIT-EQ-09", 10000, "equal", [])                        # error
    sp("SPLIT-EQ-10", MAX_AMOUNT + 1, "equal", ABC)              # error
    sp("SPLIT-EX-01", 10000, "exact", ABC, {"A": 5000, "B": 3000, "C": 2000})
    sp("SPLIT-EX-02", 10000, "exact", ABC, {"A": 5000, "B": 3000, "C": 1000})   # remaining 1000
    sp("SPLIT-EX-03", 10000, "exact", ABC, {"A": 10000, "B": 0, "C": 0})
    sp("SPLIT-EX-04", 10000, "exact", ABC, {"A": 11000, "B": -1000, "C": 0})    # negative
    sp("SPLIT-PC-01", 10000, "percent", ABC, {"A": 3333, "B": 3333, "C": 3334})
    sp("SPLIT-PC-02", 10001, "percent", ABC, {"A": 5000, "B": 2500, "C": 2500})
    sp("SPLIT-PC-03", 999, "percent", ABC, {"A": 3333, "B": 3333, "C": 3334})
    sp("SPLIT-PC-04", 10000, "percent", ABC, {"A": 5000, "B": 5000, "C": 1})    # sum != 100 %
    sp("SPLIT-PC-05", 10000, "percent", ABC, {"A": 10000, "B": 0, "C": 0})
    sp("SPLIT-SH-01", 10000, "shares", ABC, {"A": 2000, "B": 1000, "C": 1000})
    sp("SPLIT-SH-02", 10000, "shares", ABC, {"A": 1500, "B": 1000, "C": 500})
    sp("SPLIT-SH-03", 100, "shares", ABC, {"A": 1000, "B": 1000, "C": 1000})
    sp("SPLIT-SH-04", 10000, "shares", ABC, {"A": 0, "B": 0, "C": 0})           # error
    sp("SPLIT-SH-05", 7, "shares", ["A", "B"], {"A": 1, "B": 2})
    sp("SPLIT-AD-01", 10000, "adjust", ABC, {"A": 1000})
    sp("SPLIT-AD-02", 10000, "adjust", ABC, {"A": 2000, "B": -500})
    sp("SPLIT-AD-03", 10000, "adjust", ABC, {"A": 12000})        # exceeds total
    sp("SPLIT-AD-04", 10000, "adjust", ABC, {"A": 9000, "B": -5000})  # negative share for B
    sp("SPLIT-AD-05", 3000, "adjust", ["A", "B"], {"A": 1})
    sp("SPLIT-JPY-01", 1000, "equal", ABC)                       # ¥1000 / 3
    sp("SPLIT-KWD-01", 10000, "equal", ABC)                      # 10.000 KWD / 3

    case("PAYERS-01", "check_payers", {"total": 10000, "paid": {"A": 6000, "B": 4000}},
         lambda: check_payers(10000, {"A": 6000, "B": 4000}) or True)
    case("PAYERS-02", "check_payers", {"total": 10000, "paid": {"A": 6000, "B": 3000}},
         lambda: check_payers(10000, {"A": 6000, "B": 3000}) or True)

    def pw(cid, order, exps, pays):
        case(cid, "balances", {"order": order, "expenses": exps, "payments": pays},
             lambda: {"nets": nets(order, exps, pays),
                      "pairs": [list(t) for t in pairwise(order, exps, pays)],
                      "simplified": [list(t) for t in simplify(order, nets(order, exps, pays))]})
    pw("BAL-01", ABC, [{"paid": {"A": 9000}, "shares": {"A": 3000, "B": 3000, "C": 3000}}], [])
    pw("BAL-02", ABC, [{"paid": {"A": 9000}, "shares": {"A": 3000, "B": 3000, "C": 3000}}],
       [{"from": "B", "to": "A", "amount": 3000}])
    pw("BAL-03", ABC, [{"paid": {"A": 6000, "B": 4000}, "shares": {"A": 5000, "B": 5000}}], [])
    pw("BAL-04", ABC, [{"paid": {"A": 3000}, "shares": {"B": 3000}},
                       {"paid": {"B": 3000}, "shares": {"C": 3000}},
                       {"paid": {"C": 3000}, "shares": {"A": 3000}}], [])   # cycle -> all settled
    pw("BAL-05", ["A", "B", "C", "D"], [{"paid": {"A": 10000}, "shares": {"B": 10000}},
                                       {"paid": {"B": 10000}, "shares": {"C": 10000}},
                                       {"paid": {"D": 5000}, "shares": {"A": 5000}}], [])
    pw("BAL-06", ["A", "B", "C", "D", "E"],
       [{"paid": {"A": 5000, "B": 2000}, "shares": {"A": 1400, "B": 1400, "C": 1400, "D": 1400, "E": 1400}},
        {"paid": {"C": 2500}, "shares": {"D": 1250, "E": 1250}}], [])
    pw("BAL-07", ABC, [{"paid": {"A": 10000}, "shares": {"A": 3334, "B": 3333, "C": 3333}}],
       [{"from": "B", "to": "A", "amount": 5000}])                                   # overpayment flips debt
    pw("BAL-08", ["A", "B"], [{"paid": {"A": 50000}, "shares": {"B": 50000}}], [])   # IOU: A lent B ₹500

    def conv(cid, amt, frm, to, rate):
        case(cid, "convert", {"amount": amt, "from": frm, "to": to, "rate": rate}, lambda: convert(amt, frm, to, rate))
    conv("FX-01", 1000, "USD", "INR", "83.1234")        # $10.00 -> ₹831.23
    conv("FX-02", 1005, "USD", "INR", "83.5")           # 839.175 -> half away -> 83918
    conv("FX-03", 100000, "INR", "USD", "0.0120300000")
    conv("FX-04", 1000, "JPY", "INR", "0.5561")         # ¥1000 -> ₹556.10
    conv("FX-05", 12345, "INR", "JPY", "1.7982")        # ₹123.45 -> ¥222 (exp 0)
    conv("FX-06", 1500, "KWD", "INR", "271.25")         # 1.500 KWD -> ₹406.88 (exp 3 -> 2)
    conv("FX-07", 1, "USD", "INR", "0.5")               # 0.5 paisa -> 1 (half away)
    conv("FX-08", 1000, "USD", "INR", "0")              # error
    case("FX-EXP-01", "convert_expense",
         {"total": 1000, "from": "USD", "to": "INR", "rate": "83.1234", "order": ABC,
          "paid": {"A": 1000}, "shares": {"A": 334, "B": 333, "C": 333}},
         lambda: convert_expense(1000, "USD", "INR", "83.1234", {"A": 1000}, {"A": 334, "B": 333, "C": 333}, ABC))
    case("FX-CROSS-01", "cross_rate", {"eur_rates": {"INR": "97.12", "USD": "1.0834"}, "from": "USD", "to": "INR"},
         lambda: cross_rate({"INR": "97.12", "USD": "1.0834"}, "USD", "INR"))
    case("FX-CROSS-02", "cross_rate", {"eur_rates": {"INR": "97.12"}, "from": "EUR", "to": "INR"},
         lambda: cross_rate({"INR": "97.12"}, "EUR", "INR"))
    return V


if __name__ == "__main__":
    vs = vectors()
    # Self-checks on every successful split/balance vector.
    for v in vs:
        ok = v["expected"].get("ok")
        if v["op"] == "split" and ok is not None:
            assert sum(ok.values()) == v["input"]["total"], v["id"]
        if v["op"] == "balances":
            assert sum(ok["nets"].values()) == 0, v["id"]
            after = dict.fromkeys(v["input"]["order"], 0)
            for d, c, x in ok["simplified"]:
                after[d] -= x
                after[c] += x
            assert after == ok["nets"], v["id"] + " simplify must keep nets"
            assert len(ok["simplified"]) <= max(0, len(v["input"]["order"]) - 1), v["id"]
    json.dump({"version": 1, "spec": "planning/05-money-engine.md", "vectors": vs}, sys.stdout, indent=1,
              ensure_ascii=False)
    print(f"\n{len(vs)} vectors OK", file=sys.stderr)
