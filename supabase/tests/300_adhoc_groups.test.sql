begin;
-- 0028 (W2-X F11, S-420..S-423): ad-hoc groups for "With you and" several friends. The phone makes them offline
-- (type 'adhoc' through apply_mutations); members picked from another group get the id origin XOR group id and
-- keep their account; RLS: only members see the group; claims follow; attack cases.
select plan(34);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000028a1', 'adhoc-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000028b1', 'adhoc-b@splitify.test', '{"full_name": "Bina"}'),
  ('00000000-0000-4000-8000-0000000028c1', 'adhoc-c@splitify.test', '{"full_name": "Chirag"}'),
  ('00000000-0000-4000-8000-0000000028d1', 'adhoc-r@splitify.test', '{"full_name": "Raj"}');

create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000028' || p || '","role":"authenticated"}', true);
$$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-0000000028' || p)::uuid;
$$;
-- Trip (normal group) and its members.
create function pg_temp.trip() returns uuid language sql immutable as $$
  select 'c2800000-0000-4000-8000-000000000001'::uuid;
$$;
create function pg_temp.tm(p text) returns uuid language sql immutable as $$
  select ('c2810000-0000-4000-8000-0000000000' || p)::uuid;
$$;
-- Ad-hoc groups.
create function pg_temp.g(p text) returns uuid language sql immutable as $$
  select ('c2820000-0000-4000-8000-0000000000' || p)::uuid;
$$;
create function pg_temp.m(p_mid text, p_entity text, p_op text, p_id uuid, p_group uuid,
                          p_data jsonb default '{}'::jsonb)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', 'c2850000-0000-4000-8000-0000000' || p_mid, 'entity', p_entity, 'op', p_op, 'id', p_id,
    'group_id', p_group, 'base_seq', null, 'client_updated_at', now(), 'source', 'app', 'data', p_data);
$$;
create function pg_temp.apply(p jsonb) returns jsonb language sql as $$
  select public.apply_mutations(jsonb_build_array(p)) -> 'results' -> 0;
$$;
create function pg_temp.xid(p_origin uuid, p_group uuid) returns uuid language sql immutable as $$
  select private.uuid_xor(p_origin, p_group);
$$;
grant execute on function pg_temp.as_user(text), pg_temp.uid(text), pg_temp.g(text), pg_temp.trip(),
  pg_temp.tm(text) to authenticated;

-- uuid_xor
select is(private.uuid_xor('00000000-0000-4000-8000-000000000001', 'ffffffff-ffff-ffff-ffff-fffffffffffe'),
  'ffffffff-ffff-bfff-7fff-ffffffffffff'::uuid, 'uuid_xor: the same vector as the phone');
select is(private.uuid_xor(private.uuid_xor(pg_temp.tm('b1'), pg_temp.g('01')), pg_temp.g('01')), pg_temp.tm('b1'),
  'uuid_xor: xor twice gives the origin back');

-- Asha's trip with Bina (account) and Raj (name only).
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('00001', 'group', 'upsert', pg_temp.trip(), pg_temp.trip(),
  jsonb_build_object('name', 'Goa trip', 'type', 'trip',
    'owner_member', jsonb_build_object('id', pg_temp.tm('a1'), 'display_name', 'Asha'))));
select pg_temp.apply(pg_temp.m('00002', 'member', 'upsert', pg_temp.tm('b1'), pg_temp.trip(),
  '{"display_name": "Bina", "position": 1}'));
select pg_temp.apply(pg_temp.m('00003', 'member', 'upsert', pg_temp.tm('e1'), pg_temp.trip(),
  '{"display_name": "Raj", "position": 2}'));
update public.group_members set user_id = pg_temp.uid('b1') where id = pg_temp.tm('b1');

-- Asha: "With you and" Bina + Raj -> ad-hoc group 01, made offline like any group.
select is(pg_temp.apply(pg_temp.m('00010', 'group', 'upsert', pg_temp.g('01'), pg_temp.g('01'),
  jsonb_build_object('name', 'Asha, Bina & Raj', 'type', 'adhoc', 'main_currency', 'INR',
    'owner_member', jsonb_build_object('id', pg_temp.g('a1'), 'display_name', 'Asha')))) ->> 'status',
  'applied', 'ad-hoc group made through apply_mutations');
select is((select type from public.groups where id = pg_temp.g('01')), 'other', 'stored with the normal type check');
select ok((select is_adhoc from public.groups where id = pg_temp.g('01')), 'and the ad-hoc flag');
select ok(not (select is_adhoc from public.groups where id = pg_temp.trip()), 'normal groups are not ad-hoc');
select pg_temp.apply(pg_temp.m('00011', 'member', 'upsert', pg_temp.xid(pg_temp.tm('b1'), pg_temp.g('01')),
  pg_temp.g('01'), '{"display_name": "Bina", "position": 1, "tint": 1}'));
select pg_temp.apply(pg_temp.m('00012', 'member', 'upsert', pg_temp.xid(pg_temp.tm('e1'), pg_temp.g('01')),
  pg_temp.g('01'), '{"display_name": "Raj", "position": 2, "tint": 2}'));
select is((select user_id from public.group_members where id = pg_temp.xid(pg_temp.tm('b1'), pg_temp.g('01'))),
  pg_temp.uid('b1'), 'a friend with an account keeps it in the ad-hoc group');
select ok((select claimed_at is not null from public.group_members
           where id = pg_temp.xid(pg_temp.tm('b1'), pg_temp.g('01'))), 'linked at once (claimed_at)');
select is((select user_id from public.group_members where id = pg_temp.xid(pg_temp.tm('e1'), pg_temp.g('01'))),
  null, 'a name-only friend stays name-only');
select is((select count(*)::int from public.notifications where group_id = pg_temp.g('01')), 0,
  'making the group notifies nobody');

-- An expense in it reaches Bina (rule 10) with the group name as the title.
select is(pg_temp.apply(pg_temp.m('00013', 'expense', 'upsert', 'c2830000-0000-4000-8000-000000000001',
  pg_temp.g('01'), jsonb_build_object('description', 'Dinner', 'date', '2026-11-27', 'currency', 'INR',
    'total', 90000, 'split_kind', 'equal',
    'payers', jsonb_build_object(pg_temp.g('a1'), 90000),
    'shares', jsonb_build_object(pg_temp.g('a1'), 30000, pg_temp.xid(pg_temp.tm('b1'), pg_temp.g('01')), 30000,
                                 pg_temp.xid(pg_temp.tm('e1'), pg_temp.g('01')), 30000)))) ->> 'status',
  'applied', 'an expense with three people saves');
select is((select title from public.notifications where group_id = pg_temp.g('01') and user_id = pg_temp.uid('b1')
           and type = 'expense_added'), 'Asha, Bina & Raj', 'Bina hears about it');
select is((select count(*)::int from public.activity where group_id = pg_temp.g('01')
           and type in ('group_created', 'member_added', 'expense_added')), 4, 'activity: created, 2 added, expense');

-- RLS: members see it, others don't.
set local role authenticated;
select pg_temp.as_user('b1');
select is((select count(*)::int from public.groups where id = pg_temp.g('01')), 1, 'Bina sees the ad-hoc group');
select is((select count(*)::int from public.expenses where group_id = pg_temp.g('01')), 1, 'and its expense');
select is((public.pull_changes('{}'::jsonb, 0, 500) -> 'rows' -> 'groups') @>
  jsonb_build_array(jsonb_build_object('id', pg_temp.g('01'), 'is_adhoc', true)), true,
  'pull_changes sends the flag to the phone');
select pg_temp.as_user('c1');
select is((select count(*)::int from public.groups where id = pg_temp.g('01')), 0, 'a stranger does not see it');
select is((select count(*)::int from public.group_members where group_id = pg_temp.g('01')), 0,
  'nor its members');
select is((select count(*)::int from public.expenses where group_id = pg_temp.g('01')), 0, 'nor its expenses');
reset role;

-- Attack: a stranger writes into the ad-hoc group.
select pg_temp.as_user('c1');
select is(pg_temp.apply(pg_temp.m('00020', 'member', 'upsert', 'c2840000-0000-4000-8000-000000000001',
  pg_temp.g('01'), '{"display_name": "Me too", "position": 7}')) ->> 'code', 'NOT_MEMBER',
  'a stranger can not add himself');
-- Attack: a stranger derives Bina's id into his own ad-hoc group: she is not linked (no groups with strangers).
select pg_temp.apply(pg_temp.m('00021', 'group', 'upsert', pg_temp.g('02'), pg_temp.g('02'),
  jsonb_build_object('name', 'Chirag & Bina', 'type', 'adhoc',
    'owner_member', jsonb_build_object('id', pg_temp.g('c1'), 'display_name', 'Chirag'))));
select pg_temp.apply(pg_temp.m('00022', 'member', 'upsert', pg_temp.xid(pg_temp.tm('b1'), pg_temp.g('02')),
  pg_temp.g('02'), '{"display_name": "Bina", "position": 1}'));
select is((select user_id from public.group_members where id = pg_temp.xid(pg_temp.tm('b1'), pg_temp.g('02'))),
  null, 'a derived id from a group the adder is not in links nobody');
-- ...and crafts Raj's derived id, hoping to catch Raj's account when he claims.
select pg_temp.apply(pg_temp.m('00023', 'member', 'upsert', pg_temp.xid(pg_temp.tm('e1'), pg_temp.g('02')),
  pg_temp.g('02'), '{"display_name": "Raj", "position": 2}'));

-- Attack: a member hides a normal group (type adhoc / direct) or unhides an ad-hoc one.
select pg_temp.as_user('a1');
select is(pg_temp.apply(pg_temp.m('00030', 'group', 'upsert', pg_temp.trip(), pg_temp.trip(),
  '{"type": "adhoc"}')) ->> 'code', 'TYPE_LOCKED', 'a normal group can not become ad-hoc');
select is(pg_temp.apply(pg_temp.m('00031', 'group', 'upsert', pg_temp.trip(), pg_temp.trip(),
  '{"type": "direct"}')) ->> 'code', 'TYPE_LOCKED', 'nor a friend (direct) group');
select is(pg_temp.apply(pg_temp.m('00032', 'group', 'upsert', pg_temp.trip(), pg_temp.trip(),
  '{"type": "home", "is_adhoc": true}')) ->> 'status', 'applied', 'other type changes still work');
select ok(not (select is_adhoc from public.groups where id = pg_temp.trip()), 'is_adhoc is not client-writable');
select pg_temp.apply(pg_temp.m('00033', 'group', 'upsert', pg_temp.g('01'), pg_temp.g('01'),
  '{"type": "trip", "simplify_debts": true}'));
select ok((select is_adhoc and type = 'other' and simplify_debts from public.groups where id = pg_temp.g('01')),
  'an ad-hoc group stays ad-hoc (other edits apply)');

-- Claims follow: Raj signs up and joins the trip as Raj; the ad-hoc Raj Asha added becomes his account.
select pg_temp.as_user('d1');
select is(public.join_group((select invite_code from public.groups where id = pg_temp.trip()), pg_temp.tm('e1'))
  ->> 'error', null, 'Raj joins the trip claiming Raj');
select is((select user_id from public.group_members where id = pg_temp.xid(pg_temp.tm('e1'), pg_temp.g('01'))),
  pg_temp.uid('d1'), 'the ad-hoc Raj is claimed for his account too');
select is((select count(*)::int from public.activity where group_id = pg_temp.g('01') and type = 'member_claimed'
           and data ->> 'adhoc' = 'true'), 1, 'the claim is logged in the ad-hoc group');
select is((select user_id from public.group_members where id = pg_temp.xid(pg_temp.tm('e1'), pg_temp.g('02'))),
  null, 'the stranger''s crafted Raj is not claimed');
set local role authenticated;
select pg_temp.as_user('d1');
select is((select count(*)::int from public.groups where id = pg_temp.g('01')), 1, 'Raj now sees the ad-hoc group');
select is((select count(*)::int from public.groups where id = pg_temp.g('02')), 0, 'but not the stranger''s');
reset role;

-- Day cap: 100 new ad-hoc groups per person.
insert into public.groups (id, name, type, created_by)
select gen_random_uuid(), 'Cap ' || i, 'adhoc', pg_temp.uid('c1') from generate_series(1, 99) i;
select pg_temp.as_user('c1');
select is(pg_temp.apply(pg_temp.m('00040', 'group', 'upsert', pg_temp.g('03'), pg_temp.g('03'),
  jsonb_build_object('name', 'One more', 'type', 'adhoc',
    'owner_member', jsonb_build_object('id', pg_temp.g('c3'), 'display_name', 'Chirag')))) ->> 'code',
  'RATE_LIMITED', 'the 101st ad-hoc group in a day is refused');
select is(pg_temp.apply(pg_temp.m('00041', 'group', 'upsert', pg_temp.g('04'), pg_temp.g('04'),
  jsonb_build_object('name', 'Flat', 'type', 'home',
    'owner_member', jsonb_build_object('id', pg_temp.g('c4'), 'display_name', 'Chirag')))) ->> 'status',
  'applied', 'normal groups are not capped');

select * from finish();
rollback;
