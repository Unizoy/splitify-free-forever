-- RLS on groups, group_members, activity, record_versions (03-backend.md §3): member reads, non-member and
-- left member can't, writes outside RPCs fail, a name-only spot can't be hijacked by a direct update.
begin;
select plan(17);

-- Users: A, B active in G1; D left G1; C only in G2.
insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'rls-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000000b1', 'rls-b@splitify.test'),
  ('00000000-0000-4000-8000-0000000000c1', 'rls-c@splitify.test'),
  ('00000000-0000-4000-8000-0000000000d1', 'rls-d@splitify.test');
insert into public.groups (id, name, type) values
  ('10000000-0000-4000-8000-000000000001', 'Goa trip', 'trip'),
  ('10000000-0000-4000-8000-000000000002', 'Flat', 'home');
insert into public.group_members (id, group_id, user_id, display_name, position, status) values
  ('20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000a1', 'A', 0, 'active'),
  ('20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000b1', 'B', 1, 'active'),
  ('20000000-0000-4000-8000-0000000000d1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000d1', 'D', 2, 'left'),
  ('20000000-0000-4000-8000-0000000000e1', '10000000-0000-4000-8000-000000000001', null, 'Name only', 3, 'active'),
  ('20000000-0000-4000-8000-0000000000c1', '10000000-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-0000000000c1', 'C', 0, 'active');
insert into public.activity (group_id, actor_user_id, type) values
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000a1', 'group_created'),
  ('10000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000c1', 'group_created');
insert into public.record_versions (table_name, record_id, group_id, op, snapshot) values
  ('groups', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'insert', '{}'),
  ('groups', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'insert', '{}');

-- Member A.
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';
select results_eq('select id from public.groups', array['10000000-0000-4000-8000-000000000001'::uuid],
  'member sees only their group');
select is((select count(*) from public.group_members), 4::bigint, 'member sees all members of their group');
select is((select count(*) from public.activity), 1::bigint, 'member sees their group activity only');
select is((select count(*) from public.record_versions), 1::bigint, 'member sees their group history only');

-- Writes outside RPCs fail (no grants).
select throws_ok($$ insert into public.groups (id, name) values ('10000000-0000-4000-8000-000000000009', 'x') $$,
  '42501', null, 'direct insert into groups is denied');
select throws_ok($$ update public.groups set name = 'Hacked' where id = '10000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'direct update of groups is denied');
select throws_ok($$ delete from public.groups where id = '10000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'direct delete from groups is denied');
select throws_ok(
  $$ update public.group_members set user_id = '00000000-0000-4000-8000-0000000000a1'
     where id = '20000000-0000-4000-8000-0000000000e1' $$,
  '42501', null, 'a name-only spot cannot be claimed by a direct update');
select throws_ok(
  $$ insert into public.activity (group_id, type) values ('10000000-0000-4000-8000-000000000001', 'group_updated') $$,
  '42501', null, 'direct insert into activity is denied');

-- Non-member C sees only G2.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}';
select results_eq('select id from public.groups', array['10000000-0000-4000-8000-000000000002'::uuid],
  'non-member cannot see another group');
select is((select count(*) from public.group_members where group_id = '10000000-0000-4000-8000-000000000001'),
  0::bigint, 'non-member cannot see the members');
select is((select count(*) from public.activity where group_id = '10000000-0000-4000-8000-000000000001'),
  0::bigint, 'non-member cannot see the activity');

-- Left member D sees nothing of G1.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}';
select is((select count(*) from public.groups), 0::bigint, 'left member cannot see the group');
select is((select count(*) from public.group_members), 0::bigint, 'left member cannot see members');

-- Soft-deleted membership counts as not a member.
reset role;
update public.group_members set deleted_at = now() where id = '20000000-0000-4000-8000-0000000000b1';
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}';
select is((select count(*) from public.groups), 0::bigint, 'soft-deleted member cannot see the group');

-- Anonymous: nothing.
reset role;
set local role anon;
select throws_ok($$ select * from public.groups $$, '42501', null, 'anon cannot read groups');
select throws_ok($$ select * from public.group_members $$, '42501', null, 'anon cannot read members');

reset role;
select * from finish();
rollback;
