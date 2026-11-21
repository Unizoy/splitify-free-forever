-- pull_changes (04-sync-engine.md §4): first pull, cursors (TC-27-05), paging with has_more (TC-27-05),
-- tombstones (TC-27-06), lost access (TC-27-10), non-members see nothing, co-member profiles + user cursor.
begin;
select plan(29);

-- C first so C's profile is older than A's and B's (the late-join profile check below needs that).
insert into auth.users (id, email) values ('00000000-0000-4000-8000-0000000000c1', 'pull-c@splitify.test');
insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'pull-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000000b1', 'pull-b@splitify.test');

-- G1: A, B. G2: C. G3: C active, A left.
insert into public.groups (id, name) values
  ('10000000-0000-4000-8000-000000000001', 'G1'),
  ('10000000-0000-4000-8000-000000000002', 'G2'),
  ('10000000-0000-4000-8000-000000000003', 'G3');
insert into public.group_members (id, group_id, user_id, display_name, position, status) values
  ('20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000a1', 'A', 0, 'active'),
  ('20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000b1', 'B', 1, 'active'),
  ('20000000-0000-4000-8000-0000000000c2', '10000000-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-0000000000c1', 'C', 0, 'active'),
  ('20000000-0000-4000-8000-0000000000a3', '10000000-0000-4000-8000-000000000003',
   '00000000-0000-4000-8000-0000000000a1', 'A', 0, 'left'),
  ('20000000-0000-4000-8000-0000000000c3', '10000000-0000-4000-8000-000000000003',
   '00000000-0000-4000-8000-0000000000c1', 'C', 1, 'active');
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares)
select ('30000000-0000-4000-8000-00000000000' || i)::uuid, '10000000-0000-4000-8000-000000000001', 'E' || i,
       '2026-11-01', 'INR', 1000,
       '{"20000000-0000-4000-8000-0000000000a1": 1000}',
       '{"20000000-0000-4000-8000-0000000000a1": 500, "20000000-0000-4000-8000-0000000000b1": 500}'
from generate_series(1, 3) i;
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares) values
  ('30000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000002', 'C only', '2026-11-01', 'INR',
   100, '{"20000000-0000-4000-8000-0000000000c2": 100}', '{"20000000-0000-4000-8000-0000000000c2": 100}');
update public.expenses set deleted_at = now() where id = '30000000-0000-4000-8000-000000000003';

create temp table res (k text primary key, v jsonb);
create function pg_temp.n(p_k text, p_tbl text) returns int language sql stable as $$
  select jsonb_array_length(v -> 'rows' -> p_tbl) from res where k = p_k;
$$;
-- Group-scoped rows in a response (profiles excluded).
create function pg_temp.total(p_k text) returns int language sql stable as $$
  select coalesce(sum(jsonb_array_length(t.arr)), 0)::int
  from res, jsonb_each(res.v -> 'rows') as t(tbl, arr) where res.k = p_k and t.tbl <> 'profiles';
$$;
create function pg_temp.g1max() returns bigint language sql stable as $$
  select max(s) from (
    select seq as s from public.groups where id = '10000000-0000-4000-8000-000000000001'
    union all select seq from public.group_members where group_id = '10000000-0000-4000-8000-000000000001'
    union all select seq from public.expenses where group_id = '10000000-0000-4000-8000-000000000001') x;
$$;
create function pg_temp.cur(p_k text) returns jsonb language sql stable as $$
  select v -> 'next_cursors' from res where k = p_k;
$$;
create function pg_temp.useq(p_k text) returns bigint language sql stable as $$
  select (v ->> 'user_seq')::bigint from res where k = p_k;
$$;

set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';

-- First pull.
insert into res select 'p1', public.pull_changes('{}'::jsonb, 0, 500);
select is(pg_temp.n('p1', 'groups'), 1, 'the first pull returns one group');
select is((select v -> 'rows' -> 'groups' -> 0 ->> 'id' from res where k = 'p1'),
  '10000000-0000-4000-8000-000000000001', 'it is my group');
select is(pg_temp.n('p1', 'group_members'), 2, 'members of my group');
select is(pg_temp.n('p1', 'expenses'), 3, 'all my group''s expenses, the tombstone included');
select ok(
  exists (select 1 from res, jsonb_array_elements(res.v -> 'rows' -> 'expenses') e
          where res.k = 'p1' and e ->> 'id' = '30000000-0000-4000-8000-000000000003'
            and e ->> 'deleted_at' is not null),
  'TC-27-06 the tombstone arrives with deleted_at');
select is((pg_temp.cur('p1') ->> '10000000-0000-4000-8000-000000000001')::bigint, pg_temp.g1max(),
  'the cursor advances to the last seq');
select ok(not (pg_temp.cur('p1') ? '10000000-0000-4000-8000-000000000002')
          and not (pg_temp.cur('p1') ? '10000000-0000-4000-8000-000000000003'),
  'no cursors for groups I am not active in');
select is((select v ->> 'has_more' from res where k = 'p1'), 'false', 'one page is enough');
select is(pg_temp.n('p1', 'profiles'), 2, 'my profile and my co-member''s, nobody else''s');
select is(pg_temp.useq('p1'),
  (select max(seq) from public.profiles
   where id in ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000b1')),
  'the user cursor advances');
select is((select v -> 'lost_groups' from res where k = 'p1'), '[]'::jsonb, 'nothing lost on the first pull');

-- Pull again with the returned cursors.
insert into res select 'p2', public.pull_changes(pg_temp.cur('p1'), pg_temp.useq('p1'), 500);
select is(pg_temp.total('p2'), 0, 'TC-27-05 pulling with the returned cursors returns nothing new');
select is(pg_temp.n('p2', 'profiles'), 0, 'no profile rows again');

-- An edit after the cursor.
update public.expenses set description = 'E1 edited' where id = '30000000-0000-4000-8000-000000000001';
insert into res select 'p3', public.pull_changes(pg_temp.cur('p1'), pg_temp.useq('p1'), 500);
select is((select v -> 'rows' -> 'expenses' -> 0 ->> 'description' from res where k = 'p3'), 'E1 edited',
  'TC-27-05 an edit after the cursor is pulled');
select is(pg_temp.total('p3'), 1, 'and nothing else');

-- Paging: 6 rows of G1 in pages of 2.
insert into res select 'q1', public.pull_changes('{}'::jsonb, 0, 2);
select is(pg_temp.total('q1'), 2, 'TC-27-05 the page size is respected');
select is((select v ->> 'has_more' from res where k = 'q1'), 'true', 'has_more while rows remain');
insert into res select 'q2', public.pull_changes(pg_temp.cur('q1'), pg_temp.useq('q1'), 2);
select is(pg_temp.total('q2'), 2, 'the second page');
insert into res select 'q3', public.pull_changes(pg_temp.cur('q2'), pg_temp.useq('q2'), 2);
select is(pg_temp.total('q3') || ':' || (select v ->> 'has_more' from res where k = 'q3'), '2:false',
  'the last page ends paging');
select is(
  (select count(*) || '/' || count(distinct e ->> 'id')
   from res, jsonb_each(res.v -> 'rows') as t(tbl, arr), jsonb_array_elements(t.arr) e
   where res.k in ('q1', 'q2', 'q3') and t.tbl <> 'profiles'),
  '6/6', 'the pages together hold every row exactly once');

-- Lost access: A left G3; malformed keys are ignored.
insert into res select 'lost', public.pull_changes(
  jsonb_build_object('10000000-0000-4000-8000-000000000001', pg_temp.cur('p1') -> '10000000-0000-4000-8000-000000000001',
                     '10000000-0000-4000-8000-000000000003', 0, 'not-a-uuid', 1), 0, 500);
select is((select v -> 'lost_groups' from res where k = 'lost'),
  '["10000000-0000-4000-8000-000000000003"]'::jsonb, 'TC-27-10 a group I left is reported lost');
select is(
  (select count(*)::int from res, jsonb_each(res.v -> 'rows') as t(tbl, arr), jsonb_array_elements(t.arr) e
   where res.k = 'lost' and t.tbl <> 'profiles'
     and (e ->> 'group_id' = '10000000-0000-4000-8000-000000000003' or e ->> 'id' = '10000000-0000-4000-8000-000000000003')),
  0, 'TC-27-10 no rows of the lost group');

-- A non-member never sees G1.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}';
insert into res select 'c', public.pull_changes('{}'::jsonb, 0, 500);
select is(
  (select count(*)::int from res, jsonb_each(res.v -> 'rows') as t(tbl, arr), jsonb_array_elements(t.arr) e
   where res.k = 'c' and t.tbl <> 'profiles'
     and (e ->> 'group_id' = '10000000-0000-4000-8000-000000000001' or e ->> 'id' = '10000000-0000-4000-8000-000000000001')),
  0, 'a non-member never receives G1 rows');
select is(pg_temp.n('c', 'groups'), 2, 'C receives exactly their own groups');
select ok(
  exists (select 1 from res, jsonb_array_elements(res.v -> 'rows' -> 'profiles') p
          where res.k = 'c' and p ->> 'id' = '00000000-0000-4000-8000-0000000000a1'),
  'a former co-member''s profile stays visible, so history keeps their name (shares_group)');

-- C joins G1: C's (older) profile comes with the member row although it is below A's user cursor.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';
insert into public.group_members (id, group_id, user_id, display_name, position) values
  ('20000000-0000-4000-8000-0000000000c1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000c1', 'C', 2);
insert into res select 'join', public.pull_changes(pg_temp.cur('p1'), pg_temp.useq('p1'), 500);
select ok(
  exists (select 1 from res, jsonb_array_elements(res.v -> 'rows' -> 'profiles') p
          where res.k = 'join' and p ->> 'id' = '00000000-0000-4000-8000-0000000000c1'),
  'a newly joined member''s profile is pulled with the member row');

-- Grants and auth.
set local role authenticated;
select lives_ok($$ select public.pull_changes('{}'::jsonb, 0, 10) $$, 'authenticated users may call pull_changes');
set local request.jwt.claims = '{"role":"authenticated"}';
select throws_ok($$ select public.pull_changes('{}'::jsonb, 0, 10) $$,
  'P0001', 'NOT_AUTHENTICATED', 'a call without a user is refused');
reset role;
set local role anon;
select throws_ok($$ select public.pull_changes('{}'::jsonb, 0, 10) $$, '42501', null, 'anon cannot call pull_changes');
reset role;

select * from finish();
rollback;
