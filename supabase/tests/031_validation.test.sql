-- Server-side validation triggers (03-backend.md §2, 05-money-engine.md §4): TC-5..9-05 inconsistent
-- payers/shares rejected, foreign members rejected, TC-1-03 archived groups are read-only.
-- Runs as the table owner, i.e. the way the security-definer RPCs write.
begin;
select plan(20);

insert into public.groups (id, name) values
  ('10000000-0000-4000-8000-000000000001', 'G1'),
  ('10000000-0000-4000-8000-000000000002', 'G2');
insert into public.group_members (id, group_id, display_name, position) values
  ('20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000001', 'A', 0),
  ('20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000001', 'B', 1),
  ('20000000-0000-4000-8000-0000000000c1', '10000000-0000-4000-8000-000000000002', 'C', 0);

-- Helper: insert one G1 expense with the given parts.
create function pg_temp.add_expense(p_id text, p_total bigint, p_payers jsonb, p_shares jsonb,
  p_group text default '10000000-0000-4000-8000-000000000001', p_kind text default 'expense')
returns void language sql as $$
  insert into public.expenses (id, group_id, kind, description, date, currency, total, payers, shares)
  values (p_id::uuid, p_group::uuid, p_kind, 'Test', '2026-11-01', 'INR', p_total, p_payers, p_shares);
$$;

select lives_ok(
  $$ select pg_temp.add_expense('30000000-0000-4000-8000-000000000001', 10000,
       '{"20000000-0000-4000-8000-0000000000a1": 10000}',
       '{"20000000-0000-4000-8000-0000000000a1": 5000, "20000000-0000-4000-8000-0000000000b1": 5000}') $$,
  'consistent expense is accepted');
select throws_ok(
  $$ select pg_temp.add_expense('30000000-0000-4000-8000-000000000002', 10000,
       '{"20000000-0000-4000-8000-0000000000a1": 10000}',
       '{"20000000-0000-4000-8000-0000000000a1": 5000, "20000000-0000-4000-8000-0000000000b1": 4000}') $$,
  'P0001', 'SPLIT_SUM_MISMATCH', 'TC-5..9-05 shares not summing to the total are rejected');
select throws_ok(
  $$ select pg_temp.add_expense('30000000-0000-4000-8000-000000000003', 10000,
       '{"20000000-0000-4000-8000-0000000000a1": 6000, "20000000-0000-4000-8000-0000000000b1": 3000}',
       '{"20000000-0000-4000-8000-0000000000a1": 5000, "20000000-0000-4000-8000-0000000000b1": 5000}') $$,
  'P0001', 'PAYERS_SUM_MISMATCH', 'TC-5..9-05 payers not summing to the total are rejected');
select throws_ok(
  $$ select pg_temp.add_expense('30000000-0000-4000-8000-000000000004', 10000,
       '{"20000000-0000-4000-8000-0000000000a1": 10000}',
       '{"20000000-0000-4000-8000-0000000000a1": 5000, "20000000-0000-4000-8000-0000000000c1": 5000}') $$,
  'P0001', 'FOREIGN_MEMBER', 'a member of another group cannot be in the split');
select throws_ok(
  $$ select pg_temp.add_expense('30000000-0000-4000-8000-000000000005', 10000,
       '{"20000000-0000-4000-8000-0000000000a1": 10000}', '{"A": 10000}') $$,
  'P0001', 'FOREIGN_MEMBER', 'a key that is not a member id is rejected');
select throws_ok(
  $$ select pg_temp.add_expense('30000000-0000-4000-8000-000000000006', 10000,
       '{"20000000-0000-4000-8000-0000000000a1": 10000}',
       '{"20000000-0000-4000-8000-0000000000a1": 11000, "20000000-0000-4000-8000-0000000000b1": -1000}') $$,
  'P0001', 'INVALID_AMOUNT', 'negative shares are rejected');
select throws_ok(
  $$ select pg_temp.add_expense('30000000-0000-4000-8000-000000000007', 10000,
       '{"20000000-0000-4000-8000-0000000000a1": 10000}',
       '{"20000000-0000-4000-8000-0000000000a1": 5000.5, "20000000-0000-4000-8000-0000000000b1": 4999.5}') $$,
  'P0001', 'INVALID_AMOUNT', 'fractional minor units are rejected');
select throws_ok(
  $$ select pg_temp.add_expense('30000000-0000-4000-8000-000000000008', 0, '{}', '{}') $$,
  'P0001', 'AMOUNT_NOT_POSITIVE', 'zero total is rejected');
select throws_ok(
  $$ select pg_temp.add_expense('30000000-0000-4000-8000-000000000009', 10000,
       '{"20000000-0000-4000-8000-0000000000a1": 10000}',
       '{"20000000-0000-4000-8000-0000000000a1": 5000, "20000000-0000-4000-8000-0000000000b1": 5000}',
       '10000000-0000-4000-8000-000000000001', 'iou') $$,
  'P0001', 'INVALID_IOU', 'an IOU has exactly one lender and one different borrower');
select throws_ok(
  $$ update public.expenses set group_id = '10000000-0000-4000-8000-000000000002'
     where id = '30000000-0000-4000-8000-000000000001' $$,
  'P0001', 'GROUP_CHANGE_NOT_ALLOWED', 'an expense cannot move to another group');

-- Saved conversions must be complete and sum (rule 4).
select throws_ok(
  $$ update public.expenses set fx_rate = 0.012 where id = '30000000-0000-4000-8000-000000000001' $$,
  '23514', null, 'a partial conversion is rejected');
select throws_ok(
  $$ update public.expenses set fx_rate = 0.012, fx_rate_date = '2026-11-01', fx_source = 'manual',
       fx_currency = 'USD', fx_total = 120,
       fx_payers = '{"20000000-0000-4000-8000-0000000000a1": 120}',
       fx_shares = '{"20000000-0000-4000-8000-0000000000a1": 60, "20000000-0000-4000-8000-0000000000b1": 59}'
     where id = '30000000-0000-4000-8000-000000000001' $$,
  'P0001', 'FX_SPLIT_SUM_MISMATCH', 'converted shares must sum to the converted total');

-- Reference data is enforced.
select throws_ok(
  $$ insert into public.expenses (id, group_id, description, date, currency, total, payers, shares)
     values ('30000000-0000-4000-8000-000000000010', '10000000-0000-4000-8000-000000000001', 'x', '2026-11-01',
             'XXX', 100, '{"20000000-0000-4000-8000-0000000000a1": 100}',
             '{"20000000-0000-4000-8000-0000000000a1": 100}') $$,
  '23503', null, 'unknown currency is rejected');

-- Payments.
select throws_ok(
  $$ insert into public.payments (id, group_id, from_member, to_member, amount, currency, date)
     values ('40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
             '20000000-0000-4000-8000-0000000000a1', '20000000-0000-4000-8000-0000000000c1', 100, 'INR',
             '2026-11-01') $$,
  'P0001', 'FOREIGN_MEMBER', 'payment to a member of another group is rejected');
select throws_ok(
  $$ insert into public.payments (id, group_id, from_member, to_member, amount, currency, date)
     values ('40000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001',
             '20000000-0000-4000-8000-0000000000a1', '20000000-0000-4000-8000-0000000000a1', 100, 'INR',
             '2026-11-01') $$,
  '23514', null, 'payment to yourself is rejected');

-- Comments must point at a record of the same group.
select throws_ok(
  $$ insert into public.comments (id, group_id, target_type, target_id, body)
     values ('50000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'expense',
             '30000000-0000-4000-8000-000000000001', 'Hi') $$,
  'P0001', 'TARGET_NOT_FOUND', 'comment on a record of another group is rejected');

-- TC-1-03: archived groups are read-only.
update public.groups set archived_at = now() where id = '10000000-0000-4000-8000-000000000001';
select throws_ok(
  $$ select pg_temp.add_expense('30000000-0000-4000-8000-000000000011', 100,
       '{"20000000-0000-4000-8000-0000000000a1": 100}', '{"20000000-0000-4000-8000-0000000000a1": 100}') $$,
  'P0001', 'GROUP_ARCHIVED', 'TC-1-03 archived group rejects new expenses');
select throws_ok(
  $$ update public.expenses set description = 'Edited' where id = '30000000-0000-4000-8000-000000000001' $$,
  'P0001', 'GROUP_ARCHIVED', 'archived group rejects edits');
select throws_ok(
  $$ insert into public.payments (id, group_id, from_member, to_member, amount, currency, date)
     values ('40000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001',
             '20000000-0000-4000-8000-0000000000b1', '20000000-0000-4000-8000-0000000000a1', 100, 'INR',
             '2026-11-01') $$,
  'P0001', 'GROUP_ARCHIVED', 'archived group rejects new payments');
update public.groups set archived_at = null where id = '10000000-0000-4000-8000-000000000001';
select lives_ok(
  $$ update public.expenses set description = 'Edited' where id = '30000000-0000-4000-8000-000000000001' $$,
  'unarchived group accepts edits again');

select * from finish();
rollback;
