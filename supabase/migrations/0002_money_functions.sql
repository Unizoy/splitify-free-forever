-- 0002 Money engine in SQL (planning/05-money-engine.md). Port of planning/reference/money_reference.py; must
-- reproduce every vector in money_vectors.json (supabase/tests/010_money_vectors.test.sql).
--
-- Conventions:
-- * Amounts are bigint minor units. Ratios/rates are numeric. No floating point anywhere.
-- * Members are text keys (member uuid as text) passed in FIXED ORDER (position, then id); functions never sort
--   members themselves.
-- * Errors: SQLSTATE P0001, message = error code (e.g. SUM_MISMATCH), detail = JSON data or ''.
-- * Every function is immutable and security invoker.

create or replace function money.fail(code text, data jsonb default null)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  raise exception using errcode = 'P0001', message = code, detail = coalesce(data::text, '');
end;
$$;

-- ISO 4217 minor-unit digits (05 §1): 0 and 3 lists, default 2. Mirrors lib/core/money/currencies.dart.
create or replace function money.exponent(currency text)
returns int
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
    when currency = any (array['BIF','CLP','DJF','GNF','ISK','JPY','KMF','KRW','PYG','RWF','UGX','UYI','VND',
                               'VUV','XAF','XOF','XPF']) then 0
    when currency = any (array['BHD','IQD','JOD','KWD','LYD','OMR','TND']) then 3
    else 2
  end;
$$;

create or replace function money.max_amount()
returns bigint
language sql
immutable
parallel safe
set search_path = ''
as $$ select 999999999999::bigint $$;

create or replace function money.check_amount(total bigint)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if total is null or total <= 0 then
    perform money.fail('AMOUNT_NOT_POSITIVE');
  end if;
  if total > money.max_amount() then
    perform money.fail('AMOUNT_TOO_LARGE');
  end if;
end;
$$;

-- members[i] -> amounts[i] as a jsonb object.
create or replace function money.zip(members text[], amounts bigint[])
returns jsonb
language sql
immutable
parallel safe
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(m.k, amounts[m.i]), '{}'::jsonb)
  from unnest(members) with ordinality as m(k, i);
$$;

-- ------------------------------------------------------------------ allocation

-- Equal split of `total` into n parts: leftover units go one each to the first members in fixed order.
create or replace function money.equal_parts(total bigint, n int)
returns bigint[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  base bigint;
  rem bigint;
begin
  if n is null or n < 1 then
    perform money.fail('NO_PARTICIPANTS');
  end if;
  base := floor(total::numeric / n)::bigint;   -- floor division (Python divmod)
  rem := total - base * n;
  return array(select base + case when i <= rem then 1 else 0 end from generate_series(1, n) as i order by i);
end;
$$;

create or replace function money.allocate_equal(total bigint, members text[])
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
begin
  if coalesce(cardinality(members), 0) = 0 then
    perform money.fail('NO_PARTICIPANTS');
  end if;
  return money.zip(members, money.equal_parts(total, cardinality(members)));
end;
$$;

-- Largest remainder (Hamilton): floor each exact quota total*w/sum(w); leftover units one each by largest
-- fractional remainder, ties by fixed order. Zero weights get 0. Exact integer arithmetic (numeric).
create or replace function money.ratio_parts(total bigint, weights bigint[])
returns bigint[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  n int := coalesce(cardinality(weights), 0);
  w_sum numeric := 0;
  floors bigint[] := '{}';
  rems numeric[] := '{}';
  num numeric;
  q numeric;
  r numeric;
  left_units bigint;
  ord int[];
  i int;
begin
  if n = 0 then
    perform money.fail('INVALID_WEIGHTS');
  end if;
  for i in 1..n loop
    if weights[i] is null or weights[i] < 0 then
      perform money.fail('INVALID_WEIGHTS');
    end if;
    w_sum := w_sum + weights[i];
  end loop;
  if w_sum <= 0 then
    perform money.fail('INVALID_WEIGHTS');
  end if;
  for i in 1..n loop
    num := total::numeric * weights[i];
    q := div(num, w_sum);           -- truncates toward zero
    r := mod(num, w_sum);
    if r < 0 then                   -- floor for negative quotas
      q := q - 1;
      r := r + w_sum;
    end if;
    floors := floors || q::bigint;
    rems := rems || r;              -- same denominator for all, so remainders compare directly
  end loop;
  left_units := total - (select sum(f) from unnest(floors) as f);
  ord := array(select t.i::int from unnest(rems) with ordinality as t(r, i) order by t.r desc, t.i);
  for i in 1..left_units loop
    floors[ord[i]] := floors[ord[i]] + 1;
  end loop;
  return floors;
end;
$$;

create or replace function money.allocate_ratio(total bigint, members text[], weights bigint[])
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
begin
  if coalesce(cardinality(members), 0) <> coalesce(cardinality(weights), 0) then
    perform money.fail('INVALID_WEIGHTS');
  end if;
  return money.zip(members, money.ratio_parts(total, weights));
end;
$$;

-- ------------------------------------------------------------------ split types (05 §4)

-- members = chosen participants in fixed order. vals per kind: equal: none · exact: minor units ·
-- percent: basis points (10000 = 100 %) · shares: thousandths (1500 = 1.5) · adjust: signed minor units.
create or replace function money.split(total bigint, kind text, members text[], vals jsonb default '{}')
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  n int := coalesce(cardinality(members), 0);
  v bigint[];
  s numeric;
  rest bigint;
  eq bigint[];
  out_parts bigint[];
begin
  perform money.check_amount(total);
  if n = 0 then
    perform money.fail('NO_PARTICIPANTS');
  end if;
  vals := coalesce(vals, '{}'::jsonb);
  v := array(select coalesce((vals ->> m.k)::bigint, 0) from unnest(members) with ordinality as m(k, i) order by m.i);
  s := (select coalesce(sum(x), 0) from unnest(v) as x);

  case kind
    when 'equal' then
      return money.allocate_equal(total, members);
    when 'exact' then
      if exists (select 1 from unnest(v) as x where x < 0) then
        perform money.fail('NEGATIVE_SHARE');
      end if;
      if total - s <> 0 then
        perform money.fail('SUM_MISMATCH', jsonb_build_object('remaining', total - s));
      end if;
      return money.zip(members, v);
    when 'percent' then
      if exists (select 1 from unnest(v) as x where x < 0 or x > 10000) then
        perform money.fail('PERCENT_OUT_OF_RANGE');
      end if;
      if s <> 10000 then
        perform money.fail('PERCENT_SUM_MISMATCH', jsonb_build_object('remaining_bps', 10000 - s));
      end if;
      return money.allocate_ratio(total, members, v);
    when 'shares' then
      if exists (select 1 from unnest(v) as x where x < 0) then
        perform money.fail('NEGATIVE_SHARE');
      end if;
      if s = 0 then
        perform money.fail('NO_SHARES');
      end if;
      return money.allocate_ratio(total, members, v);
    when 'adjust' then
      rest := total - s;
      if rest < 0 then
        perform money.fail('ADJUSTMENTS_EXCEED_TOTAL', jsonb_build_object('over', -rest));
      end if;
      eq := money.equal_parts(rest, n);
      out_parts := array(select eq[i] + v[i] from generate_series(1, n) as i order by i);
      if exists (select 1 from unnest(out_parts) as x where x < 0) then
        perform money.fail('NEGATIVE_SHARE');
      end if;
      return money.zip(members, out_parts);
    else
      perform money.fail('UNKNOWN_SPLIT');
  end case;
  return null;
end;
$$;

-- Payers: each >= 0, at least one, sum = total.
create or replace function money.check_payers(total bigint, paid jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  s numeric;
begin
  if paid is null or jsonb_typeof(paid) <> 'object' or paid = '{}'::jsonb
     or exists (select 1 from jsonb_each_text(paid) as e where e.value::bigint < 0) then
    perform money.fail('INVALID_PAYERS');
  end if;
  s := (select sum(e.value::bigint) from jsonb_each_text(paid) as e);
  if total - s <> 0 then
    perform money.fail('PAYERS_SUM_MISMATCH', jsonb_build_object('remaining', total - s));
  end if;
  return true;
end;
$$;

-- ------------------------------------------------------------------ balances (05 §5), one currency at a time
-- expenses: jsonb array of {"paid": {member: minor}, "shares": {member: minor}}
-- payments: jsonb array of {"from": member, "to": member, "amount": minor}

create or replace function money.member_index(member_order text[], member text)
returns int
language plpgsql
immutable
set search_path = ''
as $$
declare
  i int := array_position(member_order, member);
begin
  if i is null then
    perform money.fail('UNKNOWN_MEMBER', jsonb_build_object('member', member));
  end if;
  return i;
end;
$$;

-- Net per member. Positive = is owed.
create or replace function money.nets(member_order text[], expenses jsonb, payments jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  n int := coalesce(cardinality(member_order), 0);
  bal bigint[] := array_fill(0::bigint, array[n]);
  e jsonb;
  p jsonb;
  kv record;
  i int;
begin
  for e in select x from jsonb_array_elements(coalesce(expenses, '[]'::jsonb)) as x loop
    for kv in select * from jsonb_each_text(coalesce(e -> 'paid', '{}'::jsonb)) loop
      i := money.member_index(member_order, kv.key);
      bal[i] := bal[i] + kv.value::bigint;
    end loop;
    for kv in select * from jsonb_each_text(coalesce(e -> 'shares', '{}'::jsonb)) loop
      i := money.member_index(member_order, kv.key);
      bal[i] := bal[i] - kv.value::bigint;
    end loop;
  end loop;
  for p in select x from jsonb_array_elements(coalesce(payments, '[]'::jsonb)) as x loop
    i := money.member_index(member_order, p ->> 'from');
    bal[i] := bal[i] + (p ->> 'amount')::bigint;
    i := money.member_index(member_order, p ->> 'to');
    bal[i] := bal[i] - (p ->> 'amount')::bigint;
  end loop;
  return money.zip(member_order, bal);
end;
$$;

-- "Original debts" (simplify OFF): per expense, per-expense nets matched debtor -> creditor in fixed order
-- (north-west corner, exact); summed per pair; payments reduce what `from` owes `to`.
-- Returns [[debtor, creditor, amount > 0], ...] ordered by the pair's fixed order.
create or replace function money.pairwise(member_order text[], expenses jsonb, payments jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  n int := coalesce(cardinality(member_order), 0);
  acc bigint[] := array_fill(0::bigint, array[n * n]);   -- acc[(a-1)*n+b], a < b: amount a owes b
  net bigint[];
  deb int[];
  drem bigint[];
  cred int[];
  crem bigint[];
  di int;
  ci int;
  a int;
  b int;
  x bigint;
  v bigint;
  e jsonb;
  p jsonb;
  kv record;
  i int;
  j int;
  out_pairs jsonb := '[]'::jsonb;
begin
  for e in select y from jsonb_array_elements(coalesce(expenses, '[]'::jsonb)) as y loop
    net := array_fill(0::bigint, array[n]);
    for kv in select * from jsonb_each_text(coalesce(e -> 'paid', '{}'::jsonb)) loop
      i := money.member_index(member_order, kv.key);
      net[i] := net[i] + kv.value::bigint;
    end loop;
    for kv in select * from jsonb_each_text(coalesce(e -> 'shares', '{}'::jsonb)) loop
      i := money.member_index(member_order, kv.key);
      net[i] := net[i] - kv.value::bigint;
    end loop;
    deb := '{}'; drem := '{}'; cred := '{}'; crem := '{}';
    for i in 1..n loop
      if net[i] < 0 then
        deb := deb || i; drem := drem || -net[i];
      elsif net[i] > 0 then
        cred := cred || i; crem := crem || net[i];
      end if;
    end loop;
    di := 1; ci := 1;
    while di <= cardinality(deb) and ci <= cardinality(cred) loop
      x := least(drem[di], crem[ci]);
      a := deb[di]; b := cred[ci];
      if a < b then
        acc[(a - 1) * n + b] := acc[(a - 1) * n + b] + x;
      else
        acc[(b - 1) * n + a] := acc[(b - 1) * n + a] - x;
      end if;
      drem[di] := drem[di] - x;
      crem[ci] := crem[ci] - x;
      if drem[di] = 0 then di := di + 1; end if;
      if crem[ci] = 0 then ci := ci + 1; end if;
    end loop;
  end loop;
  for p in select y from jsonb_array_elements(coalesce(payments, '[]'::jsonb)) as y loop
    a := money.member_index(member_order, p ->> 'from');
    b := money.member_index(member_order, p ->> 'to');
    x := -(p ->> 'amount')::bigint;            -- paying reduces what `from` owes `to`
    if a < b then
      acc[(a - 1) * n + b] := acc[(a - 1) * n + b] + x;
    elsif a > b then
      acc[(b - 1) * n + a] := acc[(b - 1) * n + a] - x;
    end if;
  end loop;
  for i in 1..n loop
    for j in (i + 1)..n loop
      v := acc[(i - 1) * n + j];
      if v > 0 then
        out_pairs := out_pairs || jsonb_build_array(jsonb_build_array(member_order[i], member_order[j], v));
      elsif v < 0 then
        out_pairs := out_pairs || jsonb_build_array(jsonb_build_array(member_order[j], member_order[i], -v));
      end if;
    end loop;
  end loop;
  return out_pairs;
end;
$$;

-- Simplify debts (05 §5, rule 12): (1) exact opposites in fixed order, (2) greedy largest debtor -> largest
-- creditor, ties by fixed order. Never changes a net; at most n-1 transfers. Returns [[debtor, creditor, x], ...].
create or replace function money.simplify(member_order text[], nets jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  n int := coalesce(cardinality(member_order), 0);
  bal bigint[];
  out_transfers jsonb := '[]'::jsonb;
  c int;
  d int;
  i int;
  x bigint;
begin
  if coalesce((select sum(e.value::numeric) from jsonb_each_text(coalesce(nets, '{}'::jsonb)) as e), 0) <> 0 then
    perform money.fail('NETS_DO_NOT_SUM_TO_ZERO');
  end if;
  bal := array(select coalesce((nets ->> m.k)::bigint, 0) from unnest(member_order) with ordinality as m(k, o)
               order by m.o);
  for d in 1..n loop
    if bal[d] < 0 then
      for c in 1..n loop
        if bal[c] > 0 and bal[c] = -bal[d] then
          out_transfers := out_transfers
            || jsonb_build_array(jsonb_build_array(member_order[d], member_order[c], bal[c]));
          bal[d] := 0;
          bal[c] := 0;
          exit;
        end if;
      end loop;
    end if;
  end loop;
  loop
    c := 0;
    d := 0;
    for i in 1..n loop
      if bal[i] > 0 and (c = 0 or bal[i] > bal[c]) then c := i; end if;
      if bal[i] < 0 and (d = 0 or bal[i] < bal[d]) then d := i; end if;
    end loop;
    exit when c = 0 or d = 0;
    x := least(bal[c], -bal[d]);
    out_transfers := out_transfers || jsonb_build_array(jsonb_build_array(member_order[d], member_order[c], x));
    bal[c] := bal[c] - x;
    bal[d] := bal[d] + x;
  end loop;
  return out_transfers;
end;
$$;

-- ------------------------------------------------------------------ currency conversion (05 §6)

-- sign(v) * floor(|v| + 1/2), written out so Dart and SQL cannot differ.
create or replace function money.round_half_away(v numeric)
returns bigint
language sql
immutable
parallel safe
set search_path = ''
as $$ select (sign(v) * floor(abs(v) + 0.5))::bigint $$;

-- rate = major units of `to_currency` per one major unit of `from_currency` (decimal, > 0).
create or replace function money.convert(amount bigint, from_currency text, to_currency text, rate numeric)
returns bigint
language plpgsql
immutable
set search_path = ''
as $$
begin
  if rate is null or rate <= 0 then
    perform money.fail('INVALID_RATE');
  end if;
  return money.round_half_away(
    amount::numeric * rate * power(10::numeric, money.exponent(to_currency) - money.exponent(from_currency)));
end;
$$;

-- Convert the total, then re-allocate payers and shares by their original amounts (Hamilton) so parts sum.
create or replace function money.convert_expense(
  total bigint, from_currency text, to_currency text, rate numeric,
  member_order text[], paid jsonb, shares jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  t bigint := money.convert(total, from_currency, to_currency, rate);
  pm text[];
  pw bigint[];
  sm text[];
  sw bigint[];
begin
  pm := array(select m.k from unnest(member_order) with ordinality as m(k, o) where paid ? m.k order by m.o);
  pw := array(select (paid ->> x)::bigint from unnest(pm) with ordinality as u(x, o) order by u.o);
  sm := array(select m.k from unnest(member_order) with ordinality as m(k, o) where shares ? m.k order by m.o);
  sw := array(select (shares ->> x)::bigint from unnest(sm) with ordinality as u(x, o) order by u.o);
  return jsonb_build_object('total', t, 'paid', money.allocate_ratio(t, pm, pw),
                            'shares', money.allocate_ratio(t, sm, sw));
end;
$$;

-- Cross rate from two EUR-based rates: eur_to / eur_from, rounded half away from zero to 10 decimals (exact).
create or replace function money.cross_rate(eur_from numeric, eur_to numeric)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  k int;
  num numeric;
  den numeric;
  q numeric;
  r numeric;
begin
  if eur_from is null or eur_to is null or eur_from <= 0 or eur_to <= 0 then
    perform money.fail('INVALID_RATE');
  end if;
  k := greatest(scale(eur_from), scale(eur_to));
  num := eur_to * power(10::numeric, k) * power(10::numeric, 10);   -- integer-valued
  den := eur_from * power(10::numeric, k);                          -- integer-valued
  q := div(num, den);
  r := mod(num, den);
  if 2 * r >= den then
    q := q + 1;
  end if;
  return round(q / power(10::numeric, 10), 10);
end;
$$;

-- Same, from a {currency: rate-per-EUR} map (Frankfurter, EUR base). EUR itself is 1.
create or replace function money.cross_rate(eur_rates jsonb, from_currency text, to_currency text)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  a numeric := case when from_currency = 'EUR' then 1 else (eur_rates ->> from_currency)::numeric end;
  b numeric := case when to_currency = 'EUR' then 1 else (eur_rates ->> to_currency)::numeric end;
begin
  if a is null then
    perform money.fail('RATE_NOT_FOUND', jsonb_build_object('currency', from_currency));
  end if;
  if b is null then
    perform money.fail('RATE_NOT_FOUND', jsonb_build_object('currency', to_currency));
  end if;
  return money.cross_rate(a, b);
end;
$$;

-- The money schema is internal: RPCs (security definer) call it; clients never do.
revoke all on all functions in schema money from public, anon, authenticated;
