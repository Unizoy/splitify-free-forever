-- Phase 11 (0014): one direct group per pair of accounts (TC-2-01), friend totals in my_overview equal the sum of
-- what each shared group shows, with and without simplify (TC-16-02), and the settings_changed activity (T3).
begin;
select plan(17);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000011a1', 'p11-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000011b1', 'p11-b@splitify.test', '{"full_name": "Bina"}'),
  ('00000000-0000-4000-8000-0000000011c1', 'p11-c@splitify.test', '{"full_name": "Chirag"}'),
  ('00000000-0000-4000-8000-0000000011d1', 'p11-d@splitify.test', '{"full_name": "Dev"}');

-- G1 "Goa": A, B, C. A paid 9000 split three ways; C paid 3000 for B only.
-- Pairs: B->A 3000, C->A 3000, B->C 3000. Nets: A +6000, B -6000, C 0. Simplified: B->A 6000.
insert into public.groups (id, name) values ('11110000-0000-4000-8000-000000000001', 'P11 Goa');
insert into public.group_members (id, group_id, user_id, display_name, position) values
  ('21110000-0000-4000-8000-0000000000a1', '11110000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000011a1', 'Asha', 0),
  ('21110000-0000-4000-8000-0000000000b1', '11110000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000011b1', 'Bina', 1),
  ('21110000-0000-4000-8000-0000000000c1', '11110000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000011c1', 'Chirag', 2);
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares) values
  ('31110000-0000-4000-8000-000000000001', '11110000-0000-4000-8000-000000000001', 'Villa', '2026-11-20',
   'INR', 9000, '{"21110000-0000-4000-8000-0000000000a1": 9000}',
   '{"21110000-0000-4000-8000-0000000000a1": 3000, "21110000-0000-4000-8000-0000000000b1": 3000,
     "21110000-0000-4000-8000-0000000000c1": 3000}'),
  ('31110000-0000-4000-8000-000000000002', '11110000-0000-4000-8000-000000000001', 'Scooter', '2026-11-20',
   'INR', 3000, '{"21110000-0000-4000-8000-0000000000c1": 3000}',
   '{"21110000-0000-4000-8000-0000000000b1": 3000}');

create temp table res (k text primary key, v jsonb);
grant all on res to authenticated;
create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000011' || p || '","role":"authenticated"}', true);
$$;
create function pg_temp.friend_inr(p_user text) returns bigint language sql as $$
  select (f -> 'balances' ->> 'INR')::bigint
  from jsonb_array_elements(public.my_overview() -> 'friends') f
  where f ->> 'user_id' = '00000000-0000-4000-8000-0000000011' || p_user;
$$;

-- TC-2-01: A starts a friend expense with B; repeats and B's own call find the same group.
select pg_temp.as_user('a1');
insert into res values ('ab', public.find_or_create_direct_group('00000000-0000-4000-8000-0000000011b1'));
select is((select v ->> 'status' from res where k = 'ab'), 'created', 'TC-2-01 the first call creates the group');
select is(
  (select row(g.type, g.direct_key, g.name)::text from public.groups g
   where g.id = (select (v ->> 'group_id')::uuid from res where k = 'ab')),
  row('direct', '00000000-0000-4000-8000-0000000011a1:00000000-0000-4000-8000-0000000011b1',
      'Asha & Bina')::text,
  'it is a hidden direct group keyed by the sorted pair of accounts');
select is(
  (select array_agg(row(m.user_id, m.role, m.position)::text order by m.position) from public.group_members m
   where m.group_id = (select (v ->> 'group_id')::uuid from res where k = 'ab')),
  array[row('00000000-0000-4000-8000-0000000011a1'::uuid, 'owner', 0)::text,
        row('00000000-0000-4000-8000-0000000011b1'::uuid, 'member', 1)::text],
  'exactly two linked members: the caller (owner) and the friend');
select is(
  (select count(*)::int from public.activity a
   where a.group_id = (select (v ->> 'group_id')::uuid from res where k = 'ab')
     and a.type = 'group_created' and a.actor_user_id = '00000000-0000-4000-8000-0000000011a1'
     and (a.data ->> 'direct')::boolean),
  1,
  'creating it writes group_created activity (rule 9)');
select is(
  public.find_or_create_direct_group('00000000-0000-4000-8000-0000000011b1') ->> 'group_id',
  (select v ->> 'group_id' from res where k = 'ab'),
  'TC-2-01 a second call finds the same group');
select pg_temp.as_user('b1');
insert into res values ('ba', public.find_or_create_direct_group('00000000-0000-4000-8000-0000000011a1'));
select is(
  (select row(v ->> 'status', v ->> 'group_id', v ->> 'member_id')::text from res where k = 'ba'),
  row('found', (select v ->> 'group_id' from res where k = 'ab'),
      (select v ->> 'my_member_id' from res where k = 'ab'))::text,
  'TC-2-01 the friend finds the same group, with the caller as their friend member');
select is(
  (select count(*)::int from public.groups g
   where g.type = 'direct' and g.deleted_at is null and exists (
     select 1 from public.group_members m where m.group_id = g.id
       and m.user_id = '00000000-0000-4000-8000-0000000011a1')
     and exists (
     select 1 from public.group_members m where m.group_id = g.id
       and m.user_id = '00000000-0000-4000-8000-0000000011b1')),
  1,
  'TC-2-01 one direct group per pair of accounts');

-- RLS: the friend sees the direct group; an outsider does not.
set local role authenticated;
select is(
  (select count(*)::int from public.groups where id = (select (v ->> 'group_id')::uuid from res where k = 'ab')),
  1,
  'the friend can read the direct group');
select pg_temp.as_user('d1');
select is(
  (select count(*)::int from public.groups where id = (select (v ->> 'group_id')::uuid from res where k = 'ab')),
  0,
  'someone else cannot');
select throws_ok($$select public.find_or_create_direct_group('00000000-0000-4000-8000-0000000011a1')$$,
  'P0001', 'NOT_FRIEND', 'only people who share a group can start a direct group');
select pg_temp.as_user('a1');
select throws_ok($$select public.find_or_create_direct_group('00000000-0000-4000-8000-0000000011a1')$$,
  'P0001', 'INVALID_FRIEND', 'not with yourself');
reset role;

-- B paid 2000 in the direct group, split equally: A owes B 1000 there.
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares)
select '31110000-0000-4000-8000-000000000003', (v ->> 'group_id')::uuid, 'Lunch', '2026-11-21', 'INR', 2000,
       jsonb_build_object(v ->> 'member_id', 2000),
       jsonb_build_object(v ->> 'my_member_id', 1000, v ->> 'member_id', 1000)
from res where k = 'ab';

-- TC-16-02: total with B = G1 pairs (B owes A 3000) + direct (A owes B 1000) = 2000; C: C owes A 3000.
select pg_temp.as_user('a1');
select is(pg_temp.friend_inr('b1'), 2000::bigint, 'TC-16-02 friend total = sum of group pairs + direct group');
select is(pg_temp.friend_inr('c1'), 3000::bigint, 'TC-16-02 a friend from one group only');

-- T3: A turns simplify on in G1 → settings_changed; G1 now shows B->A 6000, so B's total is 6000 - 1000.
select is(
  public.apply_mutations(jsonb_build_array(jsonb_build_object(
    'mutation_id', '51110000-0000-4000-8000-000000000001', 'entity', 'group', 'op', 'upsert',
    'id', '11110000-0000-4000-8000-000000000001', 'group_id', '11110000-0000-4000-8000-000000000001',
    'client_updated_at', now(), 'source', 'app', 'data', '{"simplify_debts": true}'::jsonb)))
    -> 'results' -> 0 ->> 'status',
  'applied',
  'a member turns simplify debts on');
select is(
  (select row(a.type, a.data ->> 'setting', a.data ->> 'simplify_debts')::text from public.activity a
   where a.group_id = '11110000-0000-4000-8000-000000000001' order by a.seq desc limit 1),
  row('settings_changed', 'simplify_debts', 'true')::text,
  'T3 the toggle is logged as settings_changed with the new value');
select is(
  row(pg_temp.friend_inr('b1'), pg_temp.friend_inr('c1'))::text,
  row(5000::bigint, null::bigint)::text,
  'TC-16-02 with simplify on the group counts its simplified transfers (C is settled with A)');

insert into res values ('rename', public.apply_mutations(jsonb_build_array(jsonb_build_object(
    'mutation_id', '51110000-0000-4000-8000-000000000002', 'entity', 'group', 'op', 'upsert',
    'id', '11110000-0000-4000-8000-000000000001', 'group_id', '11110000-0000-4000-8000-000000000001',
    'client_updated_at', now(), 'source', 'app', 'data', '{"name": "P11 Goa 2026"}'::jsonb))));
select is(
  (select v -> 'results' -> 0 ->> 'status' from res where k = 'rename') || ' '
  || (select a.type from public.activity a
      where a.group_id = '11110000-0000-4000-8000-000000000001' order by a.seq desc limit 1),
  'applied group_updated',
  'a rename is still an ordinary group_updated');

select * from finish();
rollback;
