-- D-034 B4 (0025): personal friend codes — RLS (only your own row), made on first use, rotate (the old code stops),
-- add a friend by code (new pair, existing pair, both directions, own code, unknown code, a deleted account), the
-- direct group has both accounts linked, member_joined activity, the shared rate limit, auth and grants.
begin;
select plan(27);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000025a1', 'fc-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000025b1', 'fc-b@splitify.test', '{"full_name": "Bina"}'),
  ('00000000-0000-4000-8000-0000000025c1', 'fc-c@splitify.test', '{"full_name": "Chirag"}'),
  ('00000000-0000-4000-8000-0000000025d1', 'fc-d@splitify.test', '{"full_name": "Dev"}'),
  ('00000000-0000-4000-8000-0000000025e1', 'fc-e@splitify.test', '{"full_name": "Esha"}');

create temp table res (k text primary key, v jsonb);
grant all on res to authenticated;
create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000025' || p || '","role":"authenticated"}', true);
$$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-0000000025' || p)::uuid;
$$;
create function pg_temp.r(p text) returns jsonb language sql stable as $$
  select v from res where k = p;
$$;
grant execute on function pg_temp.as_user(text), pg_temp.uid(text), pg_temp.r(text) to authenticated;

-- Made on first use, the same code after that.
set local role authenticated;
select pg_temp.as_user('a1');
insert into res values ('a_code', to_jsonb(public.my_friend_code()));
select matches(pg_temp.r('a_code') #>> '{}', '^[0-9A-HJKMNP-TV-Z]{8}$', 'an 8-character Crockford code');
select is(public.my_friend_code(), pg_temp.r('a_code') #>> '{}', 'asking again gives the same code');
select pg_temp.as_user('b1');
insert into res values ('b_code', to_jsonb(public.my_friend_code()));
select isnt(pg_temp.r('b_code') #>> '{}', pg_temp.r('a_code') #>> '{}', 'every account has its own code');

-- RLS: only your own row.
select is((select count(*)::int from public.friend_codes), 1, 'RLS: B sees one friend code');
select is((select user_id from public.friend_codes), pg_temp.uid('b1'), 'RLS: and it is their own');
select is((select count(*)::int from public.friend_codes where user_id = pg_temp.uid('a1')), 0,
  'RLS: nobody can read someone else''s code');
select throws_ok($$insert into public.friend_codes (user_id, code) values
  ('00000000-0000-4000-8000-0000000025b1', 'ABCDEFGH')$$, '42501', null, 'no direct inserts');
select throws_ok($$update public.friend_codes set code = 'ABCDEFGH'$$, '42501', null, 'no direct updates');

-- B adds A by code (lower case with a dash works, like invite codes): a new linked direct group.
insert into res values ('ba', public.add_friend_by_code(
  lower(left(pg_temp.r('a_code') #>> '{}', 4) || '-' || right(pg_temp.r('a_code') #>> '{}', 4))));
select is(pg_temp.r('ba') ->> 'status', 'created', 'a new pair creates the friend group');
select is((pg_temp.r('ba') ->> 'friend_user_id')::uuid, pg_temp.uid('a1'), 'the code''s owner is the friend');
select is(pg_temp.r('ba') ->> 'friend_name', 'Asha', 'with their profile name');
reset role;
select is(
  (select row(g.type, g.name, g.created_by)::text from public.groups g
   where g.id = (pg_temp.r('ba') ->> 'group_id')::uuid),
  row('direct', 'Bina & Asha', pg_temp.uid('b1'))::text,
  'a hidden direct group named after both');
select is(
  (select array_agg(row(m.user_id, m.role, m.status)::text order by m.position) from public.group_members m
   where m.group_id = (pg_temp.r('ba') ->> 'group_id')::uuid),
  array[row(pg_temp.uid('b1'), 'owner', 'active')::text, row(pg_temp.uid('a1'), 'member', 'active')::text],
  'both accounts are linked members (the scanner owns it)');
select is(
  (select count(*)::int from public.activity a
   where a.group_id = (pg_temp.r('ba') ->> 'group_id')::uuid and a.type = 'member_joined'
     and a.actor_user_id = pg_temp.uid('b1') and a.data ->> 'via' = 'friend_code'),
  1, 'member_joined activity is written once (rule 9; the owner gets a notification)');
select is(
  (select count(*)::int from public.record_versions v
   where v.group_id = (pg_temp.r('ba') ->> 'group_id')::uuid and v.op = 'insert'),
  3, 'versions for the group and both members');

-- Existing pair: B again, and A with B's code, find the same group (no second group, no second activity).
set local role authenticated;
select pg_temp.as_user('b1');
select is(public.add_friend_by_code(pg_temp.r('a_code') #>> '{}') ->> 'status', 'found', 'adding again finds it');
select pg_temp.as_user('a1');
insert into res values ('ab', public.add_friend_by_code(pg_temp.r('b_code') #>> '{}'));
select is(
  (select row(v ->> 'status', v ->> 'group_id', v ->> 'member_id')::text from res where k = 'ab'),
  row('found', pg_temp.r('ba') ->> 'group_id', pg_temp.r('ba') ->> 'my_member_id')::text,
  'the other way round finds the same group, with B as A''s friend member');
reset role;
select is(
  (select count(*)::int from public.activity a
   where a.group_id = (pg_temp.r('ba') ->> 'group_id')::uuid and a.type = 'member_joined'),
  1, 'an existing pair writes no new activity');

-- Own code, unknown code.
set local role authenticated;
select pg_temp.as_user('a1');
select is(public.add_friend_by_code(pg_temp.r('a_code') #>> '{}') ->> 'error', 'OWN_CODE', 'your own code says so');
select is(public.add_friend_by_code('ZZZZZZZZ') ->> 'error', 'INVALID_CODE', 'an unknown code is a friendly error');

-- Rotate: the old code stops at once, the new one works.
insert into res values ('a_new', to_jsonb(public.rotate_friend_code()));
select isnt(pg_temp.r('a_new') #>> '{}', pg_temp.r('a_code') #>> '{}', 'reset gives a new code');
select pg_temp.as_user('c1');
select is(public.add_friend_by_code(pg_temp.r('a_code') #>> '{}') ->> 'error', 'INVALID_CODE',
  'the old code stops working');
select is(public.add_friend_by_code(pg_temp.r('a_new') #>> '{}') ->> 'status', 'created', 'the new code works');

-- A deleted account's code no longer adds anyone.
select pg_temp.as_user('e1');
insert into res values ('e_code', to_jsonb(public.my_friend_code()));
reset role;
update public.profiles set deleted_at = now() where id = pg_temp.uid('e1');
set local role authenticated;
select pg_temp.as_user('c1');
select is(public.add_friend_by_code(pg_temp.r('e_code') #>> '{}') ->> 'error', 'INVALID_CODE',
  'a deleted account''s code is unknown');

-- Rate limit: 10 wrong codes an hour (shared with joins), then even a right code is refused.
select pg_temp.as_user('d1');
select is((select count(*)::int from generate_series(1, 10) s,
             lateral (select public.add_friend_by_code('ZZZZZZZZ' || repeat('-', s))) x),
  10, 'ten wrong codes run');
select throws_ok(format('select public.add_friend_by_code(%L)', pg_temp.r('a_new') #>> '{}'), 'P0001', 'RATE_LIMITED',
  'the 11th try is rate limited');
reset role;

-- Auth and grants.
select ok(not has_function_privilege('anon', 'public.add_friend_by_code(text)', 'execute')
          and not has_function_privilege('anon', 'public.my_friend_code()', 'execute')
          and not has_function_privilege('authenticated', 'private.new_friend_code()', 'execute'),
  'anon cannot call the RPCs; nobody calls the code generator');

select * from finish();
rollback;
