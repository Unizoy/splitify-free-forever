-- 0006 Balances RPCs (planning/03-backend.md §4, 05-money-engine.md §5-6, rule 3: the server holds true balances).
--
-- group_balances(group_id) ->
--   { group_id, main_currency, simplify_debts,
--     currencies: { "<CUR>": { nets: {member_id: minor}, pairs: [[debtor, creditor, minor]],
--                              simplified: [[debtor, creditor, minor]] } },      -- one block per currency, never mixed
--     converted: null | { currency: main, nets, pairs, simplified },              -- only when records use another
--     unconverted: [{type, id}] }                                                -- currency; null while any lacks fx
-- my_overview() ->
--   { totals: {"<CUR>": minor}, groups: [{group_id, name, type, member_id, simplify_debts, balances: {CUR: minor}}],
--     friends: [{user_id, member_id, group_id, name, balances: {CUR: minor}}] }   -- positive = they owe me

-- Fixed member order of a group: position, then id (05 §2). Includes left/removed members (history).
create or replace function private.member_order(p_group uuid)
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(m.id::text order by m.position, m.id), '{}'::text[])
  from public.group_members m
  where m.group_id = p_group;
$$;

create or replace function private.balance_block(p_order text[], p_expenses jsonb, p_payments jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_nets jsonb := money.nets(p_order, p_expenses, p_payments);
begin
  return jsonb_build_object(
    'nets', v_nets,
    'pairs', money.pairwise(p_order, p_expenses, p_payments),
    'simplified', money.simplify(p_order, v_nets));
end;
$$;

-- Balances of one group, no permission check (callers check).
create or replace function private.group_balances(p_group uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_group record;
  v_order text[] := private.member_order(p_group);
  v_cur text;
  v_blocks jsonb := '{}'::jsonb;
  v_exp jsonb;
  v_pay jsonb;
  v_multi boolean;
  v_unconverted jsonb;
  v_converted jsonb := null;
begin
  select g.id, g.main_currency::text as main_currency, g.simplify_debts into v_group
  from public.groups g where g.id = p_group;

  for v_cur in
    select e.currency::text from public.expenses e where e.group_id = p_group and e.deleted_at is null
    union
    select p.currency::text from public.payments p where p.group_id = p_group and p.deleted_at is null
    order by 1
  loop
    select coalesce(jsonb_agg(jsonb_build_object('paid', e.payers, 'shares', e.shares)), '[]'::jsonb) into v_exp
    from public.expenses e
    where e.group_id = p_group and e.deleted_at is null and e.currency = v_cur;
    select coalesce(jsonb_agg(jsonb_build_object('from', p.from_member, 'to', p.to_member, 'amount', p.amount)),
                    '[]'::jsonb) into v_pay
    from public.payments p
    where p.group_id = p_group and p.deleted_at is null and p.currency = v_cur;
    v_blocks := v_blocks || jsonb_build_object(v_cur, private.balance_block(v_order, v_exp, v_pay));
  end loop;

  -- Converted view in the main currency: uses only the conversions saved on each record (rule 4).
  v_multi := exists (select 1 from jsonb_object_keys(v_blocks) as k where k <> v_group.main_currency);
  if v_multi then
    select coalesce(jsonb_agg(u.item order by u.item ->> 'type', u.item ->> 'id'), '[]'::jsonb) into v_unconverted
    from (
      select jsonb_build_object('type', 'expense', 'id', e.id) as item
      from public.expenses e
      where e.group_id = p_group and e.deleted_at is null and e.currency <> v_group.main_currency
        and (e.fx_currency is distinct from v_group.main_currency::bpchar or e.fx_total is null)
      union all
      select jsonb_build_object('type', 'payment', 'id', p.id)
      from public.payments p
      where p.group_id = p_group and p.deleted_at is null and p.currency <> v_group.main_currency
        and (p.fx_currency is distinct from v_group.main_currency::bpchar or p.fx_amount is null)
    ) as u;
    if v_unconverted = '[]'::jsonb then
      select coalesce(jsonb_agg(jsonb_build_object(
               'paid', case when e.currency = v_group.main_currency then e.payers else e.fx_payers end,
               'shares', case when e.currency = v_group.main_currency then e.shares else e.fx_shares end)),
             '[]'::jsonb) into v_exp
      from public.expenses e
      where e.group_id = p_group and e.deleted_at is null;
      select coalesce(jsonb_agg(jsonb_build_object(
               'from', p.from_member, 'to', p.to_member,
               'amount', case when p.currency = v_group.main_currency then p.amount else p.fx_amount end)),
             '[]'::jsonb) into v_pay
      from public.payments p
      where p.group_id = p_group and p.deleted_at is null;
      v_converted := jsonb_build_object('currency', v_group.main_currency)
                     || private.balance_block(v_order, v_exp, v_pay);
    end if;
  else
    v_unconverted := '[]'::jsonb;
  end if;

  return jsonb_build_object(
    'group_id', p_group,
    'main_currency', v_group.main_currency,
    'simplify_debts', v_group.simplify_debts,
    'currencies', v_blocks,
    'converted', v_converted,
    'unconverted', v_unconverted);
end;
$$;

create or replace function public.group_balances(group_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'NOT_AUTHENTICATED';
  end if;
  if not private.is_member(group_balances.group_id) then
    raise exception using errcode = '42501', message = 'NOT_MEMBER';
  end if;
  return private.group_balances(group_balances.group_id);
end;
$$;

create or replace function public.my_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_m record;
  v_b jsonb;
  v_cur text;
  v_block jsonb;
  v_mine bigint;
  v_balances jsonb;
  v_totals jsonb := '{}'::jsonb;
  v_groups jsonb := '[]'::jsonb;
  v_friends jsonb := '{}'::jsonb;
  v_t jsonb;
  v_other uuid;
  v_signed bigint;
  v_other_user uuid;
  v_key text;
  v_name text;
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'NOT_AUTHENTICATED';
  end if;

  for v_m in
    select m.id as member_id, g.id as group_id, g.name, g.type, g.simplify_debts
    from public.group_members m
    join public.groups g on g.id = m.group_id
    where m.user_id = v_uid and m.status = 'active' and m.deleted_at is null and g.deleted_at is null
    order by g.created_at, g.id
  loop
    v_b := private.group_balances(v_m.group_id);
    v_balances := '{}'::jsonb;
    for v_cur, v_block in select * from jsonb_each(v_b -> 'currencies') loop
      v_mine := coalesce((v_block -> 'nets' ->> v_m.member_id::text)::bigint, 0);
      v_balances := v_balances || jsonb_build_object(v_cur, v_mine);
      v_totals := v_totals || jsonb_build_object(v_cur, coalesce((v_totals ->> v_cur)::bigint, 0) + v_mine);

      -- What this group's screen shows between me and each other person (05 §5 "Total with a friend").
      for v_t in
        select x from jsonb_array_elements(
          case when v_m.simplify_debts then v_block -> 'simplified' else v_block -> 'pairs' end) as x
      loop
        if (v_t ->> 0)::uuid = v_m.member_id then
          v_other := (v_t ->> 1)::uuid;
          v_signed := -(v_t ->> 2)::bigint;          -- I owe them
        elsif (v_t ->> 1)::uuid = v_m.member_id then
          v_other := (v_t ->> 0)::uuid;
          v_signed := (v_t ->> 2)::bigint;           -- they owe me
        else
          continue;
        end if;
        select m.user_id, coalesce(p.display_name, m.display_name) into v_other_user, v_name
        from public.group_members m
        left join public.profiles p on p.id = m.user_id
        where m.id = v_other;
        v_key := coalesce('u:' || v_other_user::text, 'm:' || v_other::text);
        if not v_friends ? v_key then
          v_friends := v_friends || jsonb_build_object(v_key, jsonb_build_object(
            'user_id', v_other_user,
            'member_id', case when v_other_user is null then v_other end,
            'group_id', case when v_other_user is null then v_m.group_id end,
            'name', v_name,
            'balances', '{}'::jsonb));
        end if;
        v_friends := jsonb_set(v_friends, array[v_key, 'balances', v_cur],
          to_jsonb(coalesce((v_friends -> v_key -> 'balances' ->> v_cur)::bigint, 0) + v_signed));
      end loop;
    end loop;

    v_groups := v_groups || jsonb_build_array(jsonb_build_object(
      'group_id', v_m.group_id,
      'name', v_m.name,
      'type', v_m.type,
      'member_id', v_m.member_id,
      'simplify_debts', v_m.simplify_debts,
      'balances', v_balances));
  end loop;

  return jsonb_build_object(
    'totals', v_totals,
    'groups', v_groups,
    'friends', (select coalesce(jsonb_agg(f.value order by f.key), '[]'::jsonb) from jsonb_each(v_friends) as f));
end;
$$;

revoke all on function private.member_order(uuid) from public, anon, authenticated;
revoke all on function private.balance_block(text[], jsonb, jsonb) from public, anon, authenticated;
revoke all on function private.group_balances(uuid) from public, anon, authenticated;
revoke all on function public.group_balances(uuid) from public, anon;
revoke all on function public.my_overview() from public, anon;
grant execute on function public.group_balances(uuid) to authenticated;
grant execute on function public.my_overview() to authenticated;
