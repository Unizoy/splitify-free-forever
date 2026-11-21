-- RLS on expenses, payments, comments (03-backend.md §3). TC-B2-05: a co-member can read.
begin;
select plan(15);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'exp-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000000b1', 'exp-b@splitify.test'),
  ('00000000-0000-4000-8000-0000000000c1', 'exp-c@splitify.test'),
  ('00000000-0000-4000-8000-0000000000d1', 'exp-d@splitify.test');
insert into public.groups (id, name) values
  ('10000000-0000-4000-8000-000000000001', 'G1'),
  ('10000000-0000-4000-8000-000000000002', 'G2');
insert into public.group_members (id, group_id, user_id, display_name, position, status) values
  ('20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000a1', 'A', 0, 'active'),
  ('20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000b1', 'B', 1, 'active'),
  ('20000000-0000-4000-8000-0000000000d1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000d1', 'D', 2, 'left'),
  ('20000000-0000-4000-8000-0000000000c1', '10000000-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-0000000000c1', 'C', 0, 'active');
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares) values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Dinner', '2026-11-01', 'INR',
   10000, '{"20000000-0000-4000-8000-0000000000a1": 10000}',
   '{"20000000-0000-4000-8000-0000000000a1": 5000, "20000000-0000-4000-8000-0000000000b1": 5000}'),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'Cab', '2026-11-02', 'INR',
   600, '{"20000000-0000-4000-8000-0000000000b1": 600}',
   '{"20000000-0000-4000-8000-0000000000a1": 300, "20000000-0000-4000-8000-0000000000b1": 300}'),
  ('30000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002', 'Rent', '2026-11-01', 'INR',
   50000, '{"20000000-0000-4000-8000-0000000000c1": 50000}', '{"20000000-0000-4000-8000-0000000000c1": 50000}');
insert into public.payments (id, group_id, from_member, to_member, amount, currency, date) values
  ('40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-0000000000b1', '20000000-0000-4000-8000-0000000000a1', 4700, 'INR', '2026-11-03');
insert into public.comments (id, group_id, target_type, target_id, body) values
  ('50000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'expense',
   '30000000-0000-4000-8000-000000000001', 'Thanks!');

set local role authenticated;

-- A (member).
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';
select is((select count(*) from public.expenses), 2::bigint, 'member sees their group expenses');
select is((select count(*) from public.payments), 1::bigint, 'member sees their group payments');
select is((select count(*) from public.comments), 1::bigint, 'member sees their group comments');

-- B (co-member, TC-B2-05).
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}';
select results_eq('select id from public.expenses order by id',
  array['30000000-0000-4000-8000-000000000001'::uuid, '30000000-0000-4000-8000-000000000002'::uuid],
  'TC-B2-05 co-member can read the same expenses');

-- Writes outside RPCs fail.
select throws_ok(
  $$ insert into public.expenses (id, group_id, description, date, currency, total, payers, shares)
     values ('30000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000001', 'x', '2026-11-01',
             'INR', 100, '{}', '{}') $$,
  '42501', null, 'direct insert into expenses is denied');
select throws_ok(
  $$ update public.expenses set total = 1 where id = '30000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'direct update of expenses is denied');
select throws_ok(
  $$ delete from public.payments where id = '40000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'direct delete from payments is denied');
select throws_ok(
  $$ insert into public.comments (id, group_id, target_type, target_id, body)
     values ('50000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000001', 'expense',
             '30000000-0000-4000-8000-000000000001', 'x') $$,
  '42501', null, 'direct insert into comments is denied');

-- C (non-member of G1).
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}';
select results_eq('select id from public.expenses', array['30000000-0000-4000-8000-000000000003'::uuid],
  'non-member sees only their own group expenses');
select is((select count(*) from public.payments), 0::bigint, 'non-member cannot see payments');
select is((select count(*) from public.comments), 0::bigint, 'non-member cannot see comments');

-- D (left G1).
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}';
select is((select count(*) from public.expenses), 0::bigint, 'left member cannot see expenses');
select is((select count(*) from public.payments), 0::bigint, 'left member cannot see payments');
select throws_ok($$ select public.group_balances('10000000-0000-4000-8000-000000000001') $$,
  '42501', 'NOT_MEMBER', 'left member cannot read balances');

reset role;
set local role anon;
select throws_ok($$ select * from public.expenses $$, '42501', null, 'anon cannot read expenses');

reset role;
select * from finish();
rollback;
