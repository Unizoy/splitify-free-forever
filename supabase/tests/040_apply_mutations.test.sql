-- apply_mutations (04-sync-engine.md §3): group create makes the caller owner (TC-1-02), applied / duplicate (TC-27-02) /
-- superseded with both versions in history (TC-27-03) / rejected (TC-27-08, NOT_MEMBER), per-mutation savepoints,
-- soft delete + restore with activity, clamped future client time (TC-27-04), auth and grants.
begin;
select plan(35);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'sync-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000000b1', 'sync-b@splitify.test'),
  ('00000000-0000-4000-8000-0000000000c1', 'sync-c@splitify.test');

create temp table res (k text primary key, v jsonb);

-- One mutation; p_mid is the last two hex digits of the mutation id, p_ago how long ago the phone saved it.
create function pg_temp.m(p_mid text, p_entity text, p_op text, p_id text, p_ago interval,
  p_data jsonb default '{}'::jsonb, p_group text default '10000000-0000-4000-8000-000000000001')
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', '40000000-0000-4000-8000-0000000000' || p_mid, 'entity', p_entity, 'op', p_op, 'id', p_id,
    'group_id', p_group, 'base_seq', null, 'client_updated_at', now() - p_ago, 'source', 'app', 'data', p_data);
$$;
-- Expense paid by A, split between A and B.
create function pg_temp.exp(p_desc text, p_total bigint, p_a bigint, p_b bigint)
returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'description', p_desc, 'date', '2026-11-01', 'currency', 'INR', 'total', p_total,
    'payers', jsonb_build_object('20000000-0000-4000-8000-0000000000a1', p_total),
    'shares', jsonb_build_object('20000000-0000-4000-8000-0000000000a1', p_a,
                                 '20000000-0000-4000-8000-0000000000b1', p_b));
$$;
create function pg_temp.st(p_k text, p_i int default 0) returns text language sql stable as $$
  select v -> 'results' -> p_i ->> 'status' from res where k = p_k;
$$;
create function pg_temp.code(p_k text, p_i int default 0) returns text language sql stable as $$
  select v -> 'results' -> p_i ->> 'code' from res where k = p_k;
$$;

set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';

-- Group create: the creator becomes the owner member.
insert into res select 'create', public.apply_mutations(jsonb_build_array(pg_temp.m('01', 'group', 'upsert',
  '10000000-0000-4000-8000-000000000001', '4 hours',
  '{"name": "Goa trip", "type": "trip",
    "owner_member": {"id": "20000000-0000-4000-8000-0000000000a1", "display_name": "Asha", "tint": 1}}')));
select is(pg_temp.st('create'), 'applied', 'group create is applied');
select is(
  (select role || ':' || user_id::text from public.group_members where id = '20000000-0000-4000-8000-0000000000a1'),
  'owner:00000000-0000-4000-8000-0000000000a1',
  'the creator becomes the owner member');
select is(
  (select count(*)::int from public.activity where group_id = '10000000-0000-4000-8000-000000000001'
     and type = 'group_created' and actor_member_id = '20000000-0000-4000-8000-0000000000a1'),
  1, 'group_created activity names the actor');
select is(
  (select count(*)::int from public.record_versions
   where record_id = '10000000-0000-4000-8000-000000000001' and op = 'insert'),
  1, 'the group insert is in history');

-- Name-only member B (then linked directly, standing in for the phase 07 claim).
insert into res select 'member', public.apply_mutations(jsonb_build_array(pg_temp.m('02', 'member', 'upsert',
  '20000000-0000-4000-8000-0000000000b1', '4 hours', '{"display_name": "Bala", "position": 1, "tint": 2}')));
select is(pg_temp.st('member'), 'applied', 'a member is added');
select ok(
  (select user_id is null and role = 'member' from public.group_members
   where id = '20000000-0000-4000-8000-0000000000b1'),
  'members added by mutation are name-only');
update public.group_members set user_id = '00000000-0000-4000-8000-0000000000b1'
where id = '20000000-0000-4000-8000-0000000000b1';

-- Expense applied.
insert into res select 'e1', public.apply_mutations(jsonb_build_array(pg_temp.m('03', 'expense', 'upsert',
  '30000000-0000-4000-8000-000000000001', '3 hours', pg_temp.exp('Dinner', 10000, 5000, 5000))));
select is(pg_temp.st('e1'), 'applied', 'an expense is applied');
select is(
  (select (v -> 'results' -> 0 ->> 'seq')::bigint from res where k = 'e1'),
  (select seq from public.expenses where id = '30000000-0000-4000-8000-000000000001'),
  'the result carries the row seq');
select is(
  (select count(*)::int from public.activity
   where target_id = '30000000-0000-4000-8000-000000000001' and type = 'expense_added'),
  1, 'expense_added activity');

-- Same mutation again (a retry after a lost response).
insert into res select 'e1-retry', public.apply_mutations(jsonb_build_array(pg_temp.m('03', 'expense', 'upsert',
  '30000000-0000-4000-8000-000000000001', '3 hours', pg_temp.exp('Dinner', 10000, 5000, 5000))));
select is(pg_temp.st('e1-retry'), 'duplicate', 'TC-27-02 the same mutation_id again is a duplicate');
select is(
  (select count(*)::int from public.activity where target_id = '30000000-0000-4000-8000-000000000001'),
  1, 'TC-27-02 a retry writes no second activity');
select is(
  (select count(*)::int from public.record_versions where record_id = '30000000-0000-4000-8000-000000000001'),
  1, 'TC-27-02 a retry writes no second version');

-- Newer edit wins.
insert into res select 'newer', public.apply_mutations(jsonb_build_array(pg_temp.m('04', 'expense', 'upsert',
  '30000000-0000-4000-8000-000000000001', '1 hour', pg_temp.exp('Dinner and drinks', 12000, 6000, 6000))));
select is(pg_temp.st('newer'), 'applied', 'TC-27-03 a newer edit is applied');
select is(
  (select total from public.expenses where id = '30000000-0000-4000-8000-000000000001'),
  12000::bigint, 'the newer total is stored');

-- Older edit loses but is kept.
insert into res select 'older', public.apply_mutations(jsonb_build_array(pg_temp.m('05', 'expense', 'upsert',
  '30000000-0000-4000-8000-000000000001', '2 hours', pg_temp.exp('Dinner', 9000, 4500, 4500))));
select is(pg_temp.st('older'), 'superseded', 'TC-27-03 an older edit is superseded');
select is(
  (select total from public.expenses where id = '30000000-0000-4000-8000-000000000001'),
  12000::bigint, 'the newer row is kept');
select is(
  (select (snapshot ->> 'total')::bigint from public.record_versions
   where record_id = '30000000-0000-4000-8000-000000000001' and op = 'conflict_lost'),
  9000::bigint, 'the losing version is kept in history');
select is(
  (select count(*)::int from public.record_versions where record_id = '30000000-0000-4000-8000-000000000001'),
  3, 'both versions are in history (insert, update, conflict_lost)');
select is(
  (select (v -> 'results' -> 0 ->> 'seq')::bigint from res where k = 'older'),
  (select seq from public.expenses where id = '30000000-0000-4000-8000-000000000001'),
  'a superseded result carries the current seq');

-- Non-member.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}';
insert into res select 'stranger', public.apply_mutations(jsonb_build_array(pg_temp.m('06', 'expense', 'upsert',
  '30000000-0000-4000-8000-000000000002', '1 hour', pg_temp.exp('Sneaky', 10000, 5000, 5000))));
select is(pg_temp.code('stranger'), 'NOT_MEMBER', 'a non-member is rejected');
select is(
  (select count(*)::int from public.expenses where id = '30000000-0000-4000-8000-000000000002'),
  0, 'nothing is written for a non-member');
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';

-- A bad mutation does not undo the next one.
insert into res select 'batch', public.apply_mutations(jsonb_build_array(
  pg_temp.m('07', 'expense', 'upsert', '30000000-0000-4000-8000-000000000003', '1 hour',
            pg_temp.exp('Bad split', 10000, 5000, 4000)),
  pg_temp.m('08', 'expense', 'upsert', '30000000-0000-4000-8000-000000000004', '1 hour',
            pg_temp.exp('Taxi', 600, 300, 300))));
select is(pg_temp.code('batch', 0), 'SPLIT_SUM_MISMATCH', 'TC-27-08 a validation failure is rejected with its code');
select is(pg_temp.st('batch', 1), 'applied', 'TC-27-08 the next mutation in the batch still applies');
select is(
  (select count(*)::int from public.expenses where id = '30000000-0000-4000-8000-000000000003'),
  0, 'the rejected expense is not stored');
select is(
  (select count(*)::int from public.mutation_log where mutation_id = '40000000-0000-4000-8000-000000000007'),
  0, 'rejected mutations are not logged, so a fixed retry can apply');

-- Soft delete and restore.
insert into res select 'delete', public.apply_mutations(jsonb_build_array(pg_temp.m('09', 'expense', 'delete',
  '30000000-0000-4000-8000-000000000001', '30 minutes')));
select is(pg_temp.st('delete'), 'applied', 'a delete is applied');
select ok(
  (select deleted_at is not null and deleted_by = '00000000-0000-4000-8000-0000000000a1'
   from public.expenses where id = '30000000-0000-4000-8000-000000000001'),
  'the delete is soft (tombstone with who)');
select is(
  (select count(*)::int from public.activity
   where target_id = '30000000-0000-4000-8000-000000000001' and type = 'expense_deleted'),
  1, 'expense_deleted activity');
insert into res select 'restore', public.apply_mutations(jsonb_build_array(pg_temp.m('10', 'expense', 'restore',
  '30000000-0000-4000-8000-000000000001', '20 minutes')));
select ok(
  (select deleted_at is null from public.expenses where id = '30000000-0000-4000-8000-000000000001')
  and exists (select 1 from public.activity
              where target_id = '30000000-0000-4000-8000-000000000001' and type = 'expense_restored'),
  'a restore clears the tombstone and is logged');

-- A phone clock in the future is clamped to server time.
insert into res select 'future', public.apply_mutations(jsonb_build_array(pg_temp.m('11', 'expense', 'upsert',
  '30000000-0000-4000-8000-000000000004', '-1 day', pg_temp.exp('Taxi', 700, 350, 350))));
select is(
  (select client_updated_at from public.expenses where id = '30000000-0000-4000-8000-000000000004'),
  now(), 'TC-27-04 a future client_updated_at is clamped to now()');

insert into res select 'missing', public.apply_mutations(jsonb_build_array(pg_temp.m('12', 'expense', 'delete',
  '30000000-0000-4000-8000-000000000009', '1 minute')));
select is(pg_temp.code('missing'), 'NOT_FOUND', 'deleting an unknown record is rejected');

select throws_ok(
  $$ select public.apply_mutations((select jsonb_agg(jsonb_build_object('mutation_id', gen_random_uuid()))
                                    from generate_series(1, 101))) $$,
  'P0001', 'BATCH_TOO_LARGE', 'more than 100 mutations are refused');

-- Grants and auth.
set local role authenticated;
select lives_ok($$ select public.apply_mutations('[]'::jsonb) $$, 'authenticated users may call apply_mutations');
set local request.jwt.claims = '{"role":"authenticated"}';
select throws_ok($$ select public.apply_mutations('[]'::jsonb) $$,
  'P0001', 'NOT_AUTHENTICATED', 'a call without a user is refused');
reset role;
set local role anon;
select throws_ok($$ select public.apply_mutations('[]'::jsonb) $$, '42501', null, 'anon cannot call apply_mutations');
reset role;

select * from finish();
rollback;
