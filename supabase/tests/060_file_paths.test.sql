-- Photo paths (0013, phase 10 #29 / S-073, TC-29-02 server side): a receipt must live in its own expense's
-- folder and a cover in its own group's folder; a photo cover needs a path; the sync RPC rejects bad paths.
begin;
select plan(12);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'fp-a@splitify.test');
insert into public.groups (id, name) values
  ('11000000-0000-4000-8000-000000000001', 'G1'),
  ('11000000-0000-4000-8000-000000000002', 'G2');
insert into public.group_members (id, group_id, user_id, display_name, position) values
  ('21000000-0000-4000-8000-0000000000a1', '11000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000a1', 'A', 0),
  ('21000000-0000-4000-8000-0000000000a2', '11000000-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-0000000000a1', 'A', 0);

create function pg_temp.expense(p_id text, p_receipt text) returns void language sql as $$
  insert into public.expenses (id, group_id, description, date, currency, total, payers, shares, receipt_path)
  values (p_id::uuid, '11000000-0000-4000-8000-000000000001', 'Dinner', '2026-11-01', 'INR', 1000,
          '{"21000000-0000-4000-8000-0000000000a1": 1000}', '{"21000000-0000-4000-8000-0000000000a1": 1000}',
          p_receipt);
$$;

select lives_ok(
  $$ select pg_temp.expense('31000000-0000-4000-8000-000000000001',
     '11000000-0000-4000-8000-000000000001/31000000-0000-4000-8000-000000000001/' ||
     '41000000-0000-4000-8000-000000000001.jpg') $$,
  'a receipt in its own expense folder is accepted');
select lives_ok(
  $$ select pg_temp.expense('31000000-0000-4000-8000-000000000002',
     '11000000-0000-4000-8000-000000000001/31000000-0000-4000-8000-000000000002/' ||
     '41000000-0000-4000-8000-00000000000A.webp') $$,
  'WebP and upper-case hex are fine');
select lives_ok(
  $$ select pg_temp.expense('31000000-0000-4000-8000-000000000003', null) $$,
  'no receipt is fine');
select throws_ok(
  $$ select pg_temp.expense('31000000-0000-4000-8000-000000000004',
     '11000000-0000-4000-8000-000000000002/31000000-0000-4000-8000-000000000004/' ||
     '41000000-0000-4000-8000-000000000001.jpg') $$,
  'P0001', 'INVALID_RECEIPT_PATH', 'a receipt in another group''s folder is refused');
select throws_ok(
  $$ select pg_temp.expense('31000000-0000-4000-8000-000000000005',
     '11000000-0000-4000-8000-000000000001/31000000-0000-4000-8000-000000000001/' ||
     '41000000-0000-4000-8000-000000000001.jpg') $$,
  'P0001', 'INVALID_RECEIPT_PATH', 'a receipt in another expense''s folder is refused');
select throws_ok(
  $$ select pg_temp.expense('31000000-0000-4000-8000-000000000006',
     '11000000-0000-4000-8000-000000000001/31000000-0000-4000-8000-000000000006/../x.png') $$,
  'P0001', 'INVALID_RECEIPT_PATH', 'odd file names are refused');
select lives_ok(
  $$ update public.expenses set receipt_path = null where id = '31000000-0000-4000-8000-000000000001' $$,
  'a receipt can be removed');

select lives_ok(
  $$ update public.groups set cover_kind = 'photo',
       cover_path = '11000000-0000-4000-8000-000000000001/41000000-0000-4000-8000-000000000009.jpg'
     where id = '11000000-0000-4000-8000-000000000001' $$,
  'a photo cover in its own group folder is accepted');
select throws_ok(
  $$ update public.groups set cover_kind = 'photo',
       cover_path = '11000000-0000-4000-8000-000000000001/41000000-0000-4000-8000-000000000009.jpg'
     where id = '11000000-0000-4000-8000-000000000002' $$,
  'P0001', 'INVALID_COVER_PATH', 'a cover from another group''s folder is refused');
select throws_ok(
  $$ update public.groups set cover_kind = 'photo', cover_path = null
     where id = '11000000-0000-4000-8000-000000000002' $$,
  'P0001', 'INVALID_COVER_PATH', 'a photo cover needs a path');

-- Through sync: the mutation is rejected with the code (Sync issues shows it).
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';
select is(
  public.apply_mutations(jsonb_build_array(jsonb_build_object(
    'mutation_id', '51000000-0000-4000-8000-000000000001', 'entity', 'expense', 'op', 'upsert',
    'id', '31000000-0000-4000-8000-000000000003', 'group_id', '11000000-0000-4000-8000-000000000001',
    'base_seq', null, 'client_updated_at', now(), 'source', 'app',
    'data', jsonb_build_object('receipt_path',
      '11000000-0000-4000-8000-000000000002/31000000-0000-4000-8000-000000000003/' ||
      '41000000-0000-4000-8000-000000000001.jpg')))) -> 'results' -> 0 ->> 'code',
  'INVALID_RECEIPT_PATH',
  'apply_mutations rejects a receipt path outside the expense folder');
reset role;

select ok(not has_function_privilege('authenticated', 'private.validate_file_paths()', 'execute'),
  'the trigger function is not callable by clients');

select * from finish();
rollback;
