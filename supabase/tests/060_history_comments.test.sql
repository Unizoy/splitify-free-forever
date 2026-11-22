begin;
-- Edit history + restore (TC-20-01) and comments (TC-13-04): record_versions ops (insert/update/delete/restore/
-- conflict_lost) for an expense and a payment, matching activity types, member-only RLS on record_versions and
-- comments, and the comment author guard (NOT_AUTHOR) from 0015.
select plan(42);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000a1', 'hist-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000000b1', 'hist-b@splitify.test', '{"full_name": "Bina"}'),
  ('00000000-0000-4000-8000-0000000000c1', 'hist-c@splitify.test', '{"full_name": "Chirag"}');

create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000000' || p || '","role":"authenticated"}', true);
$$;
-- One mutation; p_mid = last two hex digits of the mutation id, p_ago = how long ago the phone saved it.
create function pg_temp.m(p_mid text, p_entity text, p_op text, p_id text, p_ago interval,
  p_data jsonb default '{}'::jsonb)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', 'a5000000-0000-4000-8000-0000000000' || p_mid, 'entity', p_entity, 'op', p_op, 'id', p_id,
    'group_id', 'a0000000-0000-4000-8000-000000000001', 'base_seq', null, 'client_updated_at', now() - p_ago,
    'source', 'app', 'data', p_data);
$$;
create function pg_temp.apply(p jsonb) returns jsonb language sql as $$
  select public.apply_mutations(jsonb_build_array(p)) -> 'results' -> 0;
$$;
-- Expense paid by A, split between A and B.
create function pg_temp.exp(p_total bigint, p_a bigint, p_b bigint) returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'description', 'Dinner', 'date', '2026-11-01', 'currency', 'INR', 'total', p_total,
    'payers', jsonb_build_object('a1000000-0000-4000-8000-0000000000a1', p_total),
    'shares', jsonb_build_object('a1000000-0000-4000-8000-0000000000a1', p_a,
                                 'a1000000-0000-4000-8000-0000000000b1', p_b));
$$;
-- B pays A back.
create function pg_temp.pay(p_amount bigint) returns jsonb language sql immutable as $$
  select jsonb_build_object('from_member', 'a1000000-0000-4000-8000-0000000000b1',
    'to_member', 'a1000000-0000-4000-8000-0000000000a1', 'amount', p_amount, 'currency', 'INR', 'date', '2026-11-02');
$$;
-- Version ops of one record, oldest first.
create function pg_temp.ops(p_id text) returns text language sql stable as $$
  select string_agg(op, ',' order by id) from public.record_versions where record_id = p_id::uuid;
$$;

-- Group of A and B (B is linked directly, standing in for a join).
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('01', 'group', 'upsert', 'a0000000-0000-4000-8000-000000000001', '30 hours',
  '{"name": "Goa trip", "type": "trip",
    "owner_member": {"id": "a1000000-0000-4000-8000-0000000000a1", "display_name": "Asha"}}'));
select pg_temp.apply(pg_temp.m('02', 'member', 'upsert', 'a1000000-0000-4000-8000-0000000000b1', '30 hours',
  '{"display_name": "Bina", "position": 1}'));
update public.group_members set user_id = '00000000-0000-4000-8000-0000000000b1'
where id = 'a1000000-0000-4000-8000-0000000000b1';

-- ---------------------------------------------------------------- expense history
select is(pg_temp.apply(pg_temp.m('03', 'expense', 'upsert', 'a2000000-0000-4000-8000-000000000001', '10 hours',
  pg_temp.exp(10000, 5000, 5000))) ->> 'status', 'applied', 'TC-20-01 expense insert (A) is applied');
select is(pg_temp.ops('a2000000-0000-4000-8000-000000000001'), 'insert', 'TC-20-01 first version is an insert');

select is(pg_temp.apply(pg_temp.m('04', 'expense', 'upsert', 'a2000000-0000-4000-8000-000000000001', '9 hours',
  pg_temp.exp(12000, 6000, 6000))) ->> 'status', 'applied', 'TC-20-01 expense edit (A) is applied');
select is((select (snapshot ->> 'total')::bigint from public.record_versions
           where record_id = 'a2000000-0000-4000-8000-000000000001' and op = 'update'),
  12000::bigint, 'TC-20-01 the update version carries the new total');

select pg_temp.as_user('b1');
select is(pg_temp.apply(pg_temp.m('05', 'expense', 'delete', 'a2000000-0000-4000-8000-000000000001', '8 hours'))
  ->> 'status', 'applied', 'TC-20-01 expense delete (B) is applied');
select ok((select snapshot ->> 'deleted_at' is not null from public.record_versions
           where record_id = 'a2000000-0000-4000-8000-000000000001' and op = 'delete'),
  'TC-20-01 the delete version snapshot has deleted_at');
select is((select count(*)::int from public.activity where target_id = 'a2000000-0000-4000-8000-000000000001'
           and type = 'expense_deleted' and actor_user_id = '00000000-0000-4000-8000-0000000000b1'),
  1, 'TC-20-01 expense_deleted activity names B');

select pg_temp.as_user('a1');
select is(pg_temp.apply(pg_temp.m('06', 'expense', 'restore', 'a2000000-0000-4000-8000-000000000001', '7 hours'))
  ->> 'status', 'applied', 'TC-20-01 expense restore (A) is applied');
select ok((select snapshot ->> 'deleted_at' is null from public.record_versions
           where record_id = 'a2000000-0000-4000-8000-000000000001' and op = 'restore'),
  'TC-20-01 the restore version snapshot has no deleted_at');
select ok((select deleted_at is null from public.expenses where id = 'a2000000-0000-4000-8000-000000000001'),
  'TC-20-01 the expense row is live again');
select is((select count(*)::int from public.activity where target_id = 'a2000000-0000-4000-8000-000000000001'
           and type = 'expense_restored'), 1, 'TC-20-01 expense_restored activity');

select is(pg_temp.apply(pg_temp.m('07', 'expense', 'upsert', 'a2000000-0000-4000-8000-000000000001', '20 hours',
  pg_temp.exp(9000, 4500, 4500))) ->> 'status', 'superseded', 'TC-20-01 an older expense edit is superseded');
select is((select (snapshot ->> 'total')::bigint from public.record_versions
           where record_id = 'a2000000-0000-4000-8000-000000000001' and op = 'conflict_lost'),
  9000::bigint, 'TC-20-01 the conflict_lost version carries the losing total');
select is((select total from public.expenses where id = 'a2000000-0000-4000-8000-000000000001'),
  12000::bigint, 'TC-20-01 the expense keeps the winning total');
select is(pg_temp.ops('a2000000-0000-4000-8000-000000000001'), 'insert,update,delete,restore,conflict_lost',
  'TC-20-01 expense versions in order');

-- ---------------------------------------------------------------- payment history
select is(pg_temp.apply(pg_temp.m('08', 'payment', 'upsert', 'a3000000-0000-4000-8000-000000000001', '10 hours',
  pg_temp.pay(700))) ->> 'status', 'applied', 'TC-20-01 payment insert is applied');
select pg_temp.as_user('b1');
select is(pg_temp.apply(pg_temp.m('09', 'payment', 'delete', 'a3000000-0000-4000-8000-000000000001', '8 hours'))
  ->> 'status', 'applied', 'TC-20-01 payment delete (B) is applied');
select is((select count(*)::int from public.activity where target_id = 'a3000000-0000-4000-8000-000000000001'
           and type = 'payment_deleted'), 1, 'TC-20-01 payment_deleted activity');
select pg_temp.as_user('a1');
select is(pg_temp.apply(pg_temp.m('0a', 'payment', 'restore', 'a3000000-0000-4000-8000-000000000001', '7 hours'))
  ->> 'status', 'applied', 'TC-20-01 payment restore (A) is applied');
select is((select count(*)::int from public.activity where target_id = 'a3000000-0000-4000-8000-000000000001'
           and type = 'payment_restored'), 1, 'TC-20-01 payment_restored activity');
select is(pg_temp.apply(pg_temp.m('0b', 'payment', 'upsert', 'a3000000-0000-4000-8000-000000000001', '20 hours',
  pg_temp.pay(300))) ->> 'status', 'superseded', 'TC-20-01 an older payment edit is superseded');
select is((select (snapshot ->> 'amount')::bigint from public.record_versions
           where record_id = 'a3000000-0000-4000-8000-000000000001' and op = 'conflict_lost'),
  300::bigint, 'TC-20-01 the payment conflict_lost version carries the losing amount');
select is((select amount from public.payments where id = 'a3000000-0000-4000-8000-000000000001'),
  700::bigint, 'TC-20-01 the payment keeps the winning amount');
select is(pg_temp.ops('a3000000-0000-4000-8000-000000000001'), 'insert,delete,restore,conflict_lost',
  'TC-20-01 payment versions in order');

-- ---------------------------------------------------------------- comments (TC-13-04)
select is(pg_temp.apply(pg_temp.m('0c', 'comment', 'upsert', 'a4000000-0000-4000-8000-000000000001', '6 hours',
  '{"target_type": "expense", "target_id": "a2000000-0000-4000-8000-000000000001", "body": "Who had the dessert?"}'))
  ->> 'status', 'applied', 'TC-13-04 A adds a comment');
select is((select count(*)::int from public.activity where target_id = 'a4000000-0000-4000-8000-000000000001'
           and type = 'comment_added'), 1, 'TC-13-04 comment_added activity');
select is((select created_by from public.comments where id = 'a4000000-0000-4000-8000-000000000001'),
  '00000000-0000-4000-8000-0000000000a1'::uuid, 'TC-13-04 created_by is A');

select pg_temp.as_user('b1');
select is(pg_temp.apply(pg_temp.m('0d', 'comment', 'delete', 'a4000000-0000-4000-8000-000000000001', '5 hours'))
  ->> 'code', 'NOT_AUTHOR', 'TC-13-04 B cannot delete A''s comment');
select ok((select deleted_at is null from public.comments where id = 'a4000000-0000-4000-8000-000000000001'),
  'TC-13-04 the comment is still live after the rejected delete');
select is(pg_temp.apply(pg_temp.m('0e', 'comment', 'upsert', 'a4000000-0000-4000-8000-000000000001', '4 hours',
  '{"target_type": "expense", "target_id": "a2000000-0000-4000-8000-000000000001", "body": "Hijacked"}'))
  ->> 'code', 'NOT_AUTHOR', 'TC-13-04 B cannot edit A''s comment');
select is((select body from public.comments where id = 'a4000000-0000-4000-8000-000000000001'),
  'Who had the dessert?', 'TC-13-04 the body is unchanged');

select pg_temp.as_user('a1');
select is(pg_temp.apply(pg_temp.m('0f', 'comment', 'delete', 'a4000000-0000-4000-8000-000000000001', '3 hours'))
  ->> 'status', 'applied', 'TC-13-04 A deletes their comment');
select ok((select deleted_at is not null from public.comments where id = 'a4000000-0000-4000-8000-000000000001'),
  'TC-13-04 the comment is soft deleted');
select is((select count(*)::int from public.activity where target_id = 'a4000000-0000-4000-8000-000000000001'
           and type = 'comment_deleted'), 1, 'TC-13-04 comment_deleted activity');

select pg_temp.as_user('b1');
select is(pg_temp.apply(pg_temp.m('10', 'comment', 'restore', 'a4000000-0000-4000-8000-000000000001', '2 hours'))
  ->> 'code', 'NOT_AUTHOR', 'TC-13-04 B cannot restore A''s comment');
select ok((select deleted_at is not null from public.comments where id = 'a4000000-0000-4000-8000-000000000001'),
  'TC-13-04 the comment stays deleted after the rejected restore');

select pg_temp.as_user('a1');
select is(pg_temp.apply(pg_temp.m('11', 'comment', 'restore', 'a4000000-0000-4000-8000-000000000001', '1 hour'))
  ->> 'status', 'applied', 'TC-13-04 A restores their comment');
select ok((select deleted_at is null from public.comments where id = 'a4000000-0000-4000-8000-000000000001'),
  'TC-13-04 the comment is live again');

-- ---------------------------------------------------------------- RLS: members only
select pg_temp.as_user('a1');
set local role authenticated;
select ok((select count(*) from public.record_versions where group_id = 'a0000000-0000-4000-8000-000000000001') > 0,
  'TC-20-01 a member sees the group''s record_versions');
select is((select count(*)::int from public.comments where group_id = 'a0000000-0000-4000-8000-000000000001'),
  1, 'TC-13-04 a member sees the group''s comments');
reset role;

select pg_temp.as_user('c1');
set local role authenticated;
select is((select count(*)::int from public.record_versions where group_id = 'a0000000-0000-4000-8000-000000000001'),
  0, 'TC-20-01 a non-member sees no record_versions');
select is((select count(*)::int from public.comments where group_id = 'a0000000-0000-4000-8000-000000000001'),
  0, 'TC-13-04 a non-member sees no comments');
reset role;

select * from finish();
select num_failed(), _get('curr_test'), _get('plan');
rollback;
