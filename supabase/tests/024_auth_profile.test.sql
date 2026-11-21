-- Phase 05: update_profile (self only, validated, full replace) and prepare_account_deletion (delete-account
-- Edge Function, 03-backend.md §7). TC-B1-06: a deleted user's expenses still balance for the others.
begin;
select plan(29);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000a1', 'asha@splitify.test', '{"full_name": "Asha Rao"}'),
  ('00000000-0000-4000-8000-0000000000b1', 'bee@splitify.test', '{}');

insert into public.groups (id, name) values
  ('10000000-0000-4000-8000-000000000001', 'Flat'),
  ('10000000-0000-4000-8000-000000000002', 'Trip');
insert into public.group_members (id, group_id, user_id, display_name, position) values
  ('20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000a1', 'Asha', 0),
  ('20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000b1', 'Bee', 1),
  ('20000000-0000-4000-8000-0000000000c1', '10000000-0000-4000-8000-000000000001', null, 'Chandu', 2),
  ('20000000-0000-4000-8000-0000000000a2', '10000000-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-0000000000a1', repeat('L', 50), 0),
  ('20000000-0000-4000-8000-0000000000d2', '10000000-0000-4000-8000-000000000002', null, 'Dev', 1);
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares) values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Groceries', '2026-11-01',
   'INR', 9000, '{"20000000-0000-4000-8000-0000000000a1": 9000}',
   '{"20000000-0000-4000-8000-0000000000a1": 3000, "20000000-0000-4000-8000-0000000000b1": 3000,
     "20000000-0000-4000-8000-0000000000c1": 3000}');

-- ------------------------------------------------------------------ update_profile

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';

select is(
  public.update_profile('  Asha R  ', ' asha.r@okaxis ', 'USD',
    '00000000-0000-4000-8000-0000000000a1/avatar.jpg') - 'updated_at'::text,
  '{"id": "00000000-0000-4000-8000-0000000000a1", "display_name": "Asha R",
    "avatar_path": "00000000-0000-4000-8000-0000000000a1/avatar.jpg", "upi_id": "asha.r@okaxis",
    "default_currency": "USD"}'::jsonb,
  'update_profile saves trimmed values and returns the profile');
select isnt((select updated_at from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'), null,
  'update_profile sets updated_at');

select lives_ok(
  $$ select public.update_profile('Asha R', '   ', 'INR', null) $$,
  'full replace: blank UPI id and null avatar are accepted');
select is((select upi_id from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'), null::text,
  'blank UPI id removes it');
select is((select avatar_path from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'), null::text,
  'null avatar path removes it');

select throws_ok($$ select public.update_profile('   ', null, 'INR', null) $$,
  'P0001', 'INVALID_NAME', 'blank name is rejected');
select throws_ok($$ select public.update_profile(repeat('x', 51), null, 'INR', null) $$,
  'P0001', 'INVALID_NAME', 'name over 50 characters is rejected');
select throws_ok($$ select public.update_profile('Asha', 'not a upi id', 'INR', null) $$,
  'P0001', 'INVALID_UPI', 'malformed UPI id is rejected');
select throws_ok($$ select public.update_profile('Asha', null, 'ZZZ', null) $$,
  'P0001', 'UNKNOWN_CURRENCY', 'unknown currency is rejected');
select throws_ok($$ select public.update_profile('Asha', null, 'INRX', null) $$,
  'P0001', 'UNKNOWN_CURRENCY', 'over-long currency code is rejected, not cut');
select throws_ok(
  $$ select public.update_profile('Asha', null, 'INR', '00000000-0000-4000-8000-0000000000b1/avatar.jpg') $$,
  'P0001', 'INVALID_AVATAR_PATH', 'avatar in another user''s folder is rejected');
select throws_ok(
  $$ select public.update_profile('Asha', null, 'INR', '00000000-0000-4000-8000-0000000000a1.jpg') $$,
  'P0001', 'INVALID_AVATAR_PATH', 'avatar outside the user''s folder is rejected');

select is((select display_name from public.profiles where id = '00000000-0000-4000-8000-0000000000b1'), 'bee',
  'update_profile never touches another profile');

set local request.jwt.claims = '{"role":"authenticated"}';
select throws_ok($$ select public.update_profile('X', null, 'INR', null) $$,
  '42501', 'NOT_AUTHENTICATED', 'update_profile needs a signed-in user');
select throws_ok($$ select public.prepare_account_deletion() $$,
  '42501', 'NOT_AUTHENTICATED', 'prepare_account_deletion needs a signed-in user');

reset role;
set local role anon;
select throws_ok($$ select public.update_profile('X', null, 'INR', null) $$,
  '42501', null, 'anon cannot call update_profile');
select throws_ok($$ select public.prepare_account_deletion() $$,
  '42501', null, 'anon cannot call prepare_account_deletion');

-- ------------------------------------------------------------------ prepare_account_deletion

reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';
select lives_ok(
  $$ select public.update_profile('Asha R', 'asha.r@okaxis', 'INR', '00000000-0000-4000-8000-0000000000a1/me.jpg') $$,
  'set an avatar and UPI id before deleting');

set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}';
select is(
  public.group_balances('10000000-0000-4000-8000-000000000001') -> 'currencies' -> 'INR' -> 'nets',
  '{"20000000-0000-4000-8000-0000000000a1": 6000, "20000000-0000-4000-8000-0000000000b1": -3000,
    "20000000-0000-4000-8000-0000000000c1": -3000}'::jsonb,
  'TC-B1-06 balances before the account is deleted');

set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';
select is(public.prepare_account_deletion(),
  '{"avatar_path": "00000000-0000-4000-8000-0000000000a1/me.jpg", "groups": 2}'::jsonb,
  'prepare_account_deletion returns the old avatar path and the number of groups');
select is(public.prepare_account_deletion(), '{"avatar_path": null, "groups": 0}'::jsonb,
  'prepare_account_deletion is idempotent');

reset role;
select is(
  (select display_name from public.group_members where id = '20000000-0000-4000-8000-0000000000a1'
     and user_id is null),
  'Asha (left)', 'membership becomes a name-only member with " (left)"');
select is(
  (select display_name from public.group_members where id = '20000000-0000-4000-8000-0000000000a2'
     and user_id is null),
  repeat('L', 43) || ' (left)', 'a 50-character name is cut so the suffix fits');
select is(
  (select count(*) from public.activity
   where type = 'member_left' and actor_user_id = '00000000-0000-4000-8000-0000000000a1'
     and target_type = 'group_member' and actor_member_id = target_id
     and data = '{"reason": "account_deleted"}'::jsonb),
  2::bigint, 'one member_left activity per group');
select is(
  (select jsonb_build_object('display_name', display_name, 'avatar_path', avatar_path, 'upi_id', upi_id,
                             'deleted', deleted_at is not null)
   from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'),
  '{"display_name": "Deleted user", "avatar_path": null, "upi_id": null, "deleted": true}'::jsonb,
  'profile is cleared');

select lives_ok($$ delete from auth.users where id = '00000000-0000-4000-8000-0000000000a1' $$,
  'the auth user can be deleted afterwards');
select is((select count(*) from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'), 0::bigint,
  'deleting the auth user removes the profile');
select is(
  (select count(*) from public.group_members
   where id in ('20000000-0000-4000-8000-0000000000a1', '20000000-0000-4000-8000-0000000000a2')
     and user_id is null and deleted_at is null),
  2::bigint, 'the name-only members stay after the auth user is gone');

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}';
select is(
  public.group_balances('10000000-0000-4000-8000-000000000001') -> 'currencies' -> 'INR' -> 'nets',
  '{"20000000-0000-4000-8000-0000000000a1": 6000, "20000000-0000-4000-8000-0000000000b1": -3000,
    "20000000-0000-4000-8000-0000000000c1": -3000}'::jsonb,
  'TC-B1-06 the deleted user''s expense still balances for the others');

reset role;
select * from finish();
rollback;
