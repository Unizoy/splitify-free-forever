-- Profiles: created by the auth trigger; visible to self and co-members only; no client writes (03-backend.md §2-3).
begin;
select plan(11);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000a1', 'asha@splitify.test', '{"full_name": "Asha Rao"}'),
  ('00000000-0000-4000-8000-0000000000b1', 'bee@splitify.test', '{}'),
  ('00000000-0000-4000-8000-0000000000c1', 'stranger@splitify.test', '{}'),
  ('00000000-0000-4000-8000-0000000000e1', 'gone@splitify.test', '{"name": "Esha"}');

select is((select display_name from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'),
  'Asha Rao', 'profile name comes from Google metadata');
select is((select display_name from public.profiles where id = '00000000-0000-4000-8000-0000000000b1'),
  'bee', 'profile name falls back to the email prefix');

insert into public.groups (id, name) values ('10000000-0000-4000-8000-000000000001', 'G1');
insert into public.group_members (id, group_id, user_id, display_name, position, status) values
  ('20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000a1', 'A', 0, 'active'),
  ('20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000b1', 'B', 1, 'active'),
  ('20000000-0000-4000-8000-0000000000e1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000e1', 'E', 2, 'left');

select throws_ok(
  $$ update public.profiles set upi_id = 'not a upi id' where id = '00000000-0000-4000-8000-0000000000a1' $$,
  '23514', null, 'malformed UPI id is rejected');
select lives_ok(
  $$ update public.profiles set upi_id = 'asha.rao@okaxis' where id = '00000000-0000-4000-8000-0000000000a1' $$,
  'valid UPI id is accepted');

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';
select is((select count(*) from public.profiles), 3::bigint, 'member sees self, co-members and former members');
select is((select count(*) from public.profiles where id = '00000000-0000-4000-8000-0000000000c1'), 0::bigint,
  'member cannot see a stranger');
select throws_ok(
  $$ update public.profiles set display_name = 'X' where id = '00000000-0000-4000-8000-0000000000a1' $$,
  '42501', null, 'profile cannot be updated directly (RPC only)');

set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}';
select results_eq('select id from public.profiles', array['00000000-0000-4000-8000-0000000000c1'::uuid],
  'stranger sees only their own profile');

set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000e1","role":"authenticated"}';
select results_eq('select id from public.profiles', array['00000000-0000-4000-8000-0000000000e1'::uuid],
  'a member who left no longer sees the others');

set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}';
select is((select upi_id from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'),
  'asha.rao@okaxis', 'co-member can read the UPI id (needed to pay)');

reset role;
set local role anon;
select throws_ok($$ select * from public.profiles $$, '42501', null, 'anon cannot read profiles');

reset role;
select * from finish();
rollback;
