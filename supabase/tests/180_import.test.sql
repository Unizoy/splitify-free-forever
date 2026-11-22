-- Phase 18 (X1, 0021): an import through apply_mutations writes no activity or notification per record and one
-- `import_completed` row from the summary note; "Delete this import" writes one undone row; ordinary edits of an
-- imported expense stay ordinary.
begin;
select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000018a1', 'p18-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000018b1', 'p18-b@splitify.test');
insert into public.groups (id, name) values ('19180000-0000-4000-8000-000000000001', 'P18 Flat');
insert into public.group_members (id, group_id, user_id, display_name, position) values
  ('29180000-0000-4000-8000-0000000000a1', '19180000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000018a1', 'A', 0),
  ('29180000-0000-4000-8000-0000000000b1', '19180000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000018b1', 'B', 1),
  ('29180000-0000-4000-8000-0000000000c1', '19180000-0000-4000-8000-000000000001', null, 'C', 2);

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000018a1","role":"authenticated"}';

-- A imports one payment and two expenses (batch 7918…01); the last expense carries the summary.
select is(
  (select count(*)::int from jsonb_array_elements(public.apply_mutations('[
    {"mutation_id": "59180000-0000-4000-8000-000000000001", "entity": "payment", "op": "upsert",
     "id": "49180000-0000-4000-8000-000000000001", "group_id": "19180000-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:00:00Z", "source": "import",
     "data": {"from_member": "29180000-0000-4000-8000-0000000000b1",
              "to_member": "29180000-0000-4000-8000-0000000000a1", "amount": 500, "currency": "INR",
              "date": "2026-01-15", "method": "other", "source": "import"}},
    {"mutation_id": "59180000-0000-4000-8000-000000000002", "entity": "expense", "op": "upsert",
     "id": "39180000-0000-4000-8000-000000000001", "group_id": "19180000-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:00:01Z", "source": "import",
     "data": {"kind": "expense", "description": "Dinner", "category": "food.dining_out", "date": "2026-01-05",
              "currency": "INR", "total": 3000, "payers": {"29180000-0000-4000-8000-0000000000a1": 3000},
              "shares": {"29180000-0000-4000-8000-0000000000a1": 1000, "29180000-0000-4000-8000-0000000000b1": 1000,
                         "29180000-0000-4000-8000-0000000000c1": 1000},
              "split_kind": "exact",
              "split_values": {"29180000-0000-4000-8000-0000000000a1": 1000,
                               "29180000-0000-4000-8000-0000000000b1": 1000,
                               "29180000-0000-4000-8000-0000000000c1": 1000,
                               "import_batch_id": "79180000-0000-4000-8000-000000000001"},
              "source": "import"}},
    {"mutation_id": "59180000-0000-4000-8000-000000000003", "entity": "expense", "op": "upsert",
     "id": "39180000-0000-4000-8000-000000000002", "group_id": "19180000-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:00:02Z", "source": "import",
     "data": {"kind": "expense", "description": "Rent", "category": "rent.rent", "date": "2026-01-06",
              "currency": "INR", "total": 900, "payers": {"29180000-0000-4000-8000-0000000000b1": 900},
              "shares": {"29180000-0000-4000-8000-0000000000a1": 450, "29180000-0000-4000-8000-0000000000b1": 450},
              "split_kind": "exact",
              "split_values": {"29180000-0000-4000-8000-0000000000a1": 450,
                               "29180000-0000-4000-8000-0000000000b1": 450,
                               "import_batch_id": "79180000-0000-4000-8000-000000000001",
                               "import_summary": {"source": "splitwise", "expenses": 2, "payments": 1}},
              "source": "import"}}
  ]'::jsonb) -> 'results') r where r ->> 'status' = 'applied'),
  3,
  'TC-X1-04 the import rows are applied');
select is(
  (select count(*)::int from public.expenses
   where group_id = '19180000-0000-4000-8000-000000000001' and source = 'import'),
  2,
  'imported expenses keep source = import');
select is(
  (select count(*)::int from public.activity
   where group_id = '19180000-0000-4000-8000-000000000001' and type in ('expense_added', 'payment_added')),
  0,
  'no activity row per imported record');
select is(
  (select count(*)::int from public.activity
   where group_id = '19180000-0000-4000-8000-000000000001' and type = 'import_completed'
     and target_id = '79180000-0000-4000-8000-000000000001'
     and actor_user_id = '00000000-0000-4000-8000-0000000018a1'
     and actor_member_id = '29180000-0000-4000-8000-0000000000a1'
     and data = '{"batch_id": "79180000-0000-4000-8000-000000000001", "source": "splitwise",
                  "expenses": 2, "payments": 1, "undone": false}'::jsonb),
  1,
  'one import_completed activity with the counts');
select is(
  (select count(*)::int from public.notifications n
   join public.activity a on a.id = n.activity_id
   where a.group_id = '19180000-0000-4000-8000-000000000001'),
  0,
  'an import sends no notifications');
select is(
  public.group_balances('19180000-0000-4000-8000-000000000001') -> 'currencies' -> 'INR' -> 'nets',
  '{"29180000-0000-4000-8000-0000000000a1": 1050, "29180000-0000-4000-8000-0000000000b1": -50,
    "29180000-0000-4000-8000-0000000000c1": -1000}'::jsonb,
  'imported records count in the balances');

-- The same summary again (a resent row of the batch) adds nothing.
select is(
  public.apply_mutations('[{"mutation_id": "59180000-0000-4000-8000-000000000004", "entity": "expense",
    "op": "upsert", "id": "39180000-0000-4000-8000-000000000003",
    "group_id": "19180000-0000-4000-8000-000000000001", "client_updated_at": "2026-11-22T10:00:03Z",
    "source": "import", "data": {"description": "Snacks", "date": "2026-01-07", "currency": "INR", "total": 100,
    "payers": {"29180000-0000-4000-8000-0000000000a1": 100}, "shares": {"29180000-0000-4000-8000-0000000000a1": 100},
    "split_kind": "exact", "split_values": {"import_batch_id": "79180000-0000-4000-8000-000000000001",
    "import_summary": {"source": "splitwise", "expenses": 2, "payments": 1}}}}]'::jsonb)
    -> 'results' -> 0 ->> 'status',
  'applied',
  'a second row with the same summary is applied');
select is(
  (select count(*)::int from public.activity
   where group_id = '19180000-0000-4000-8000-000000000001' and type = 'import_completed'),
  1,
  'still one import_completed activity per batch');

-- An ordinary edit of an imported expense is logged as usual.
select is(
  public.apply_mutations('[{"mutation_id": "59180000-0000-4000-8000-000000000005", "entity": "expense",
    "op": "upsert", "id": "39180000-0000-4000-8000-000000000001",
    "group_id": "19180000-0000-4000-8000-000000000001", "client_updated_at": "2026-11-22T10:01:00Z",
    "source": "app", "data": {"description": "Dinner at Toit"}}]'::jsonb) -> 'results' -> 0 ->> 'status',
  'applied',
  'an imported expense can be edited');
select is(
  (select count(*)::int from public.activity
   where group_id = '19180000-0000-4000-8000-000000000001' and type = 'expense_edited'),
  1,
  'the edit has its own expense_edited activity');

-- "Delete this import": the undo note on the first live expense, then quiet deletes.
select is(
  (select count(*)::int from jsonb_array_elements(public.apply_mutations('[
    {"mutation_id": "59180000-0000-4000-8000-000000000006", "entity": "expense", "op": "upsert",
     "id": "39180000-0000-4000-8000-000000000001", "group_id": "19180000-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:02:00Z", "source": "import",
     "data": {"split_values": {"29180000-0000-4000-8000-0000000000a1": 1000,
                               "29180000-0000-4000-8000-0000000000b1": 1000,
                               "29180000-0000-4000-8000-0000000000c1": 1000,
                               "import_batch_id": "79180000-0000-4000-8000-000000000001",
                               "import_undo": {"expenses": 3, "payments": 1}}, "source": "import"}},
    {"mutation_id": "59180000-0000-4000-8000-000000000007", "entity": "expense", "op": "delete",
     "id": "39180000-0000-4000-8000-000000000001", "group_id": "19180000-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:02:01Z", "source": "import", "data": {"source": "import"}},
    {"mutation_id": "59180000-0000-4000-8000-000000000008", "entity": "expense", "op": "delete",
     "id": "39180000-0000-4000-8000-000000000002", "group_id": "19180000-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:02:02Z", "source": "import", "data": {"source": "import"}},
    {"mutation_id": "59180000-0000-4000-8000-000000000009", "entity": "expense", "op": "delete",
     "id": "39180000-0000-4000-8000-000000000003", "group_id": "19180000-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:02:03Z", "source": "import", "data": {"source": "import"}},
    {"mutation_id": "59180000-0000-4000-8000-000000000010", "entity": "payment", "op": "delete",
     "id": "49180000-0000-4000-8000-000000000001", "group_id": "19180000-0000-4000-8000-000000000001",
     "client_updated_at": "2026-11-22T10:02:04Z", "source": "import", "data": {"source": "import"}}
  ]'::jsonb) -> 'results') r where r ->> 'status' = 'applied'),
  5,
  'the undo note and the deletes are applied');
select is(
  (select array_agg(type order by type) from public.activity
   where group_id = '19180000-0000-4000-8000-000000000001' and created_at = now()
     and type not in ('expense_edited')),
  array['import_completed', 'import_completed'],
  'deleting the import adds one import_completed (undone) row and nothing per record');
select is(
  (select data from public.activity
   where group_id = '19180000-0000-4000-8000-000000000001' and type = 'import_completed'
     and data ->> 'undone' = 'true'),
  '{"batch_id": "79180000-0000-4000-8000-000000000001", "source": "splitwise",
    "expenses": 3, "payments": 1, "undone": true}'::jsonb,
  'the undone row carries the deleted counts');

select * from finish();
rollback;
