-- Phase 18b (X4, 0023, S-226): an expense added from a captured payment is stored with source 'capture' through
-- the normal apply_mutations path (membership, history, activity unchanged); only expenses may carry it; the
-- marker setting never leaks to the next record.
begin;
select plan(14);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-00000018b0a1', 'p18b-a@splitify.test'),
  ('00000000-0000-4000-8000-00000018b0b1', 'p18b-b@splitify.test');
insert into public.groups (id, name) values ('19180b00-0000-4000-8000-000000000001', 'P18b Trip');
insert into public.group_members (id, group_id, user_id, display_name, position) values
  ('29180b00-0000-4000-8000-0000000000a1', '19180b00-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-00000018b0a1', 'A', 0),
  ('29180b00-0000-4000-8000-0000000000c1', '19180b00-0000-4000-8000-000000000001', null, 'C', 1);

select ok(
  pg_get_constraintdef((select oid from pg_constraint where conname = 'expenses_source_check'))
    like '%capture%',
  'expenses.source accepts capture');

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-00000018b0a1","role":"authenticated"}';

-- A adds ₹500 paid to Rahul from a capture, split with C.
select is(
  (public.apply_mutations('[
    {"mutation_id": "59180b00-0000-4000-8000-000000000001", "entity": "expense", "op": "upsert",
     "id": "49180b00-0000-4000-8000-000000000001", "group_id": "19180b00-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:00:00Z", "source": "capture",
     "data": {"kind": "expense", "description": "Rahul Sharma", "notes": "Paid via Google Pay · UPI ref 612345678901",
              "category": "other.general", "date": "2026-11-22", "currency": "INR", "total": 50000,
              "payers": {"29180b00-0000-4000-8000-0000000000a1": 50000},
              "shares": {"29180b00-0000-4000-8000-0000000000a1": 25000, "29180b00-0000-4000-8000-0000000000c1": 25000},
              "split_kind": "equal", "source": "capture"}}
  ]'::jsonb) -> 'results' -> 0 ->> 'status'),
  'applied', 'capture mutation is applied');

select is((select source from public.expenses where id = '49180b00-0000-4000-8000-000000000001'),
  'capture', 'the new expense is marked capture');
select is((select total from public.expenses where id = '49180b00-0000-4000-8000-000000000001'),
  50000::bigint, 'amount stored as paise');
select is(
  (select snapshot ->> 'source' from public.record_versions
   where record_id = '49180b00-0000-4000-8000-000000000001' and op = 'insert'),
  'capture', 'edit history keeps the capture source');
select is(
  (select count(*)::int from public.activity
   where target_id = '49180b00-0000-4000-8000-000000000001' and type = 'expense_added'),
  1, 'activity: one expense_added, like any add');
select is(current_setting('splitify.capture_id', true), '', 'marker cleared after the mutation');

-- An ordinary add right after stays 'app'.
select is(
  (public.apply_mutations('[
    {"mutation_id": "59180b00-0000-4000-8000-000000000002", "entity": "expense", "op": "upsert",
     "id": "49180b00-0000-4000-8000-000000000002", "group_id": "19180b00-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:01:00Z",
     "data": {"description": "Chai", "date": "2026-11-22", "currency": "INR", "total": 4000,
              "payers": {"29180b00-0000-4000-8000-0000000000a1": 4000},
              "shares": {"29180b00-0000-4000-8000-0000000000a1": 4000}}}
  ]'::jsonb) -> 'results' -> 0 ->> 'status'),
  'applied', 'ordinary add applied');
select is((select source from public.expenses where id = '49180b00-0000-4000-8000-000000000002'),
  'app', 'ordinary add stays app');

-- Editing the captured expense (the client may still send source capture) is an ordinary edit.
select is(
  (public.apply_mutations('[
    {"mutation_id": "59180b00-0000-4000-8000-000000000003", "entity": "expense", "op": "upsert",
     "id": "49180b00-0000-4000-8000-000000000001", "group_id": "19180b00-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:02:00Z", "source": "capture",
     "data": {"description": "Dinner with Rahul"}}
  ]'::jsonb) -> 'results' -> 0 ->> 'status'),
  'applied', 'edit applied');
select is(
  (select description || '|' || source from public.expenses where id = '49180b00-0000-4000-8000-000000000001'),
  'Dinner with Rahul|capture', 'edit keeps the source');

-- Only expenses can be captures.
select is(
  (public.apply_mutations('[
    {"mutation_id": "59180b00-0000-4000-8000-000000000004", "entity": "payment", "op": "upsert",
     "id": "49180b00-0000-4000-8000-000000000004", "group_id": "19180b00-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:03:00Z", "source": "capture",
     "data": {"from_member": "29180b00-0000-4000-8000-0000000000c1",
              "to_member": "29180b00-0000-4000-8000-0000000000a1", "amount": 100, "currency": "INR",
              "date": "2026-11-22"}}
  ]'::jsonb) -> 'results' -> 0 ->> 'code'),
  'INVALID_MUTATION', 'a payment cannot be a capture');

-- B is not a member: the capture path keeps the membership rule.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-00000018b0b1","role":"authenticated"}';
select is(
  (public.apply_mutations('[
    {"mutation_id": "59180b00-0000-4000-8000-000000000005", "entity": "expense", "op": "upsert",
     "id": "49180b00-0000-4000-8000-000000000005", "group_id": "19180b00-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:04:00Z", "source": "capture",
     "data": {"description": "Sneaky", "date": "2026-11-22", "currency": "INR", "total": 100,
              "payers": {"29180b00-0000-4000-8000-0000000000a1": 100},
              "shares": {"29180b00-0000-4000-8000-0000000000a1": 100}}}
  ]'::jsonb) -> 'results' -> 0 ->> 'code'),
  'NOT_MEMBER', 'non-member capture rejected');

reset role;
select ok(
  not has_function_privilege('authenticated', 'private.sync_apply_capture(jsonb, uuid)', 'execute'),
  'clients cannot call the capture helper directly');

select * from finish();
rollback;
