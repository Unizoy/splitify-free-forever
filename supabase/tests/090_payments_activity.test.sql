-- Phase 09: payments through apply_mutations (#25) → activity rows (TC-18-01 payment part), group balances
-- (pairs/nets after add, edit, delete, restore) and my_overview (overall, per group, per person; T6).
begin;
select plan(12);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000009a1', 'p09-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000009b1', 'p09-b@splitify.test');
insert into public.groups (id, name) values ('19090000-0000-4000-8000-000000000001', 'P09 Goa');
insert into public.group_members (id, group_id, user_id, display_name, position) values
  ('29090000-0000-4000-8000-0000000000a1', '19090000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000009a1', 'A', 0),
  ('29090000-0000-4000-8000-0000000000b1', '19090000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000009b1', 'B', 1),
  ('29090000-0000-4000-8000-0000000000c1', '19090000-0000-4000-8000-000000000001', null, 'C', 2);
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares) values
  ('39090000-0000-4000-8000-000000000001', '19090000-0000-4000-8000-000000000001', 'Villa', '2026-11-20',
   'INR', 9000, '{"29090000-0000-4000-8000-0000000000a1": 9000}',
   '{"29090000-0000-4000-8000-0000000000a1": 3000, "29090000-0000-4000-8000-0000000000b1": 3000,
     "29090000-0000-4000-8000-0000000000c1": 3000}');

-- B records that B paid A ₹30 (UPI).
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000009b1","role":"authenticated"}';

select is(
  public.apply_mutations('[{"mutation_id": "59090000-0000-4000-8000-000000000001", "entity": "payment",
    "op": "upsert", "id": "49090000-0000-4000-8000-000000000001",
    "group_id": "19090000-0000-4000-8000-000000000001", "client_updated_at": "2026-11-21T10:00:00Z",
    "source": "app", "data": {"from_member": "29090000-0000-4000-8000-0000000000b1",
    "to_member": "29090000-0000-4000-8000-0000000000a1", "amount": 3000, "currency": "INR",
    "date": "2026-11-21", "method": "upi"}}]'::jsonb) -> 'results' -> 0 ->> 'status',
  'applied',
  'a member records a payment through apply_mutations');
select is(
  (select count(*)::int from public.activity
   where group_id = '19090000-0000-4000-8000-000000000001' and type = 'payment_added'
     and target_id = '49090000-0000-4000-8000-000000000001'
     and actor_user_id = '00000000-0000-4000-8000-0000000009b1'
     and (data ->> 'amount')::bigint = 3000 and data ->> 'currency' = 'INR'
     and data ->> 'from_member' = '29090000-0000-4000-8000-0000000000b1'
     and data ->> 'to_member' = '29090000-0000-4000-8000-0000000000a1'),
  1,
  'TC-18-01 payment_added activity carries amount, currency and both people');
select is(
  public.group_balances('19090000-0000-4000-8000-000000000001') -> 'currencies' -> 'INR' -> 'nets',
  '{"29090000-0000-4000-8000-0000000000a1": 3000, "29090000-0000-4000-8000-0000000000b1": 0,
    "29090000-0000-4000-8000-0000000000c1": -3000}'::jsonb,
  'the payment settles B');
select is(
  public.group_balances('19090000-0000-4000-8000-000000000001') -> 'currencies' -> 'INR' -> 'pairs',
  '[["29090000-0000-4000-8000-0000000000c1", "29090000-0000-4000-8000-0000000000a1", 3000]]'::jsonb,
  'only C still owes A');

-- Partial payment after an edit (₹20), then delete and restore (rule 9).
select is(
  public.apply_mutations('[{"mutation_id": "59090000-0000-4000-8000-000000000002", "entity": "payment",
    "op": "upsert", "id": "49090000-0000-4000-8000-000000000001",
    "group_id": "19090000-0000-4000-8000-000000000001", "client_updated_at": "2026-11-21T10:01:00Z",
    "source": "app", "data": {"amount": 2000}}]'::jsonb) -> 'results' -> 0 ->> 'status',
  'applied',
  'the payment is edited');
select is(
  public.group_balances('19090000-0000-4000-8000-000000000001') -> 'currencies' -> 'INR' -> 'pairs',
  '[["29090000-0000-4000-8000-0000000000b1", "29090000-0000-4000-8000-0000000000a1", 1000],
    ["29090000-0000-4000-8000-0000000000c1", "29090000-0000-4000-8000-0000000000a1", 3000]]'::jsonb,
  'a partial payment leaves the rest of the pair');
select is(
  public.apply_mutations('[{"mutation_id": "59090000-0000-4000-8000-000000000003", "entity": "payment",
    "op": "delete", "id": "49090000-0000-4000-8000-000000000001",
    "group_id": "19090000-0000-4000-8000-000000000001", "client_updated_at": "2026-11-21T10:02:00Z",
    "source": "app", "data": {}}]'::jsonb) -> 'results' -> 0 ->> 'status',
  'applied',
  'the payment is deleted (soft)');
select is(
  public.group_balances('19090000-0000-4000-8000-000000000001') -> 'currencies' -> 'INR' -> 'nets',
  '{"29090000-0000-4000-8000-0000000000a1": 6000, "29090000-0000-4000-8000-0000000000b1": -3000,
    "29090000-0000-4000-8000-0000000000c1": -3000}'::jsonb,
  'a deleted payment no longer counts');
select is(
  public.apply_mutations('[{"mutation_id": "59090000-0000-4000-8000-000000000004", "entity": "payment",
    "op": "restore", "id": "49090000-0000-4000-8000-000000000001",
    "group_id": "19090000-0000-4000-8000-000000000001", "client_updated_at": "2026-11-21T10:03:00Z",
    "source": "app", "data": {}}]'::jsonb) -> 'results' -> 0 ->> 'status',
  'applied',
  'the payment is restored');
select is(
  (select array_agg(type order by seq) from public.activity
   where group_id = '19090000-0000-4000-8000-000000000001' and target_type = 'payment'),
  array['payment_added', 'payment_edited', 'payment_deleted', 'payment_restored'],
  'TC-18-01 every payment op writes its activity');

-- A's overview: overall, per group and per person (positive = they owe me).
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000009a1","role":"authenticated"}';
select is(
  (select g -> 'balances' from jsonb_array_elements(public.my_overview() -> 'groups') g
   where g ->> 'group_id' = '19090000-0000-4000-8000-000000000001'),
  '{"INR": 4000}'::jsonb,
  'my_overview: my net in the group');
select is(
  (select jsonb_object_agg(coalesce(f ->> 'user_id', f ->> 'member_id'), f -> 'balances' -> 'INR')
   from jsonb_array_elements(public.my_overview() -> 'friends') f
   where f ->> 'user_id' = '00000000-0000-4000-8000-0000000009b1'
      or f ->> 'member_id' = '29090000-0000-4000-8000-0000000000c1'),
  '{"00000000-0000-4000-8000-0000000009b1": 1000, "29090000-0000-4000-8000-0000000000c1": 3000}'::jsonb,
  'my_overview: what each person owes me (account and name-only member)');

select * from finish();
rollback;
