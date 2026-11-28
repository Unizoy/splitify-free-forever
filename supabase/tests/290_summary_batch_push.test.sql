-- 0030 (W2-Y, S-434 / S-435): one push per batch settle-up (bell rows per group stay; per-user settings, mutes and
-- the actor rule unchanged) and the opt-in monthly summary (cron, once per person and month).
begin;
select plan(32);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000030a1', 'sum-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000030b1', 'sum-b@splitify.test', '{"full_name": "Bina"}'),
  ('00000000-0000-4000-8000-0000000030c1', 'sum-c@splitify.test', '{"full_name": "Chetan"}');

-- G1..G4: Asha (a), Bina (b); Chetan (c) only in G1.
insert into public.groups (id, name, type) values
  ('c3000000-0000-4000-8000-000000000001', 'Goa', 'trip'),
  ('c3000000-0000-4000-8000-000000000002', 'Flat', 'home'),
  ('c3000000-0000-4000-8000-000000000003', 'Office', 'other'),
  ('c3000000-0000-4000-8000-000000000004', 'Gym', 'other');
insert into public.group_members (id, group_id, user_id, display_name, position, status, role)
select ('c3010000-0000-4000-8000-0000000000' || u || g)::uuid, ('c3000000-0000-4000-8000-00000000000' || g)::uuid,
       ('00000000-0000-4000-8000-0000000030' || u || '1')::uuid,
       case u when 'a' then 'Asha' when 'b' then 'Bina' else 'Chetan' end,
       case u when 'a' then 0 when 'b' then 1 else 2 end, 'active', case u when 'a' then 'owner' else 'member' end
from (values ('a'), ('b')) us(u), generate_series(1, 4) g
union all
select 'c3010000-0000-4000-8000-0000000000c1'::uuid, 'c3000000-0000-4000-8000-000000000001'::uuid,
       '00000000-0000-4000-8000-0000000030c1'::uuid, 'Chetan', 2, 'active', 'member';

-- Last month (November 2026) for the summary: Bina's shares 500 (Goa) + 300 (Flat); an IOU, a deleted expense
-- and an October expense don't count.
insert into public.expenses (id, group_id, kind, description, date, currency, total, payers, shares, deleted_at)
values
  ('c3020000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'expense', 'Dinner', '2026-11-10',
   'INR', 1000, '{"c3010000-0000-4000-8000-0000000000a1": 1000}',
   '{"c3010000-0000-4000-8000-0000000000a1": 500, "c3010000-0000-4000-8000-0000000000b1": 500}', null),
  ('c3020000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000002', 'expense', 'Rent', '2026-11-01',
   'INR', 600, '{"c3010000-0000-4000-8000-0000000000b2": 600}',
   '{"c3010000-0000-4000-8000-0000000000a2": 300, "c3010000-0000-4000-8000-0000000000b2": 300}', null),
  ('c3020000-0000-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000001', 'iou', 'Loan', '2026-11-12',
   'INR', 400, '{"c3010000-0000-4000-8000-0000000000a1": 400}', '{"c3010000-0000-4000-8000-0000000000b1": 400}', null),
  ('c3020000-0000-4000-8000-000000000004', 'c3000000-0000-4000-8000-000000000001', 'expense', 'Gone', '2026-11-12',
   'INR', 999, '{"c3010000-0000-4000-8000-0000000000a1": 999}', '{"c3010000-0000-4000-8000-0000000000b1": 999}',
   now()),
  ('c3020000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000001', 'expense', 'October', '2026-10-30',
   'INR', 100, '{"c3010000-0000-4000-8000-0000000000a1": 100}', '{"c3010000-0000-4000-8000-0000000000b1": 100}', null);

create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000030' || p || '","role":"authenticated"}', true);
$$;
-- A payment Asha -> Bina in group g, optionally inside batch b.
create function pg_temp.pay(p_mid int, g int, p_amount int, p_batch text default null, p_currency text default 'INR')
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', 'c3050000-0000-4000-8000-' || lpad(p_mid::text, 12, '0'), 'entity', 'payment', 'op', 'upsert',
    'id', 'c3040000-0000-4000-8000-' || lpad(p_mid::text, 12, '0'),
    'group_id', 'c3000000-0000-4000-8000-00000000000' || g, 'base_seq', null, 'client_updated_at', now(),
    'source', 'app',
    'data', jsonb_build_object('from_member', 'c3010000-0000-4000-8000-0000000000a' || g,
                               'to_member', 'c3010000-0000-4000-8000-0000000000b' || g, 'amount', p_amount,
                               'currency', p_currency, 'date', '2026-11-28', 'method', 'upi')
            || case when p_batch is null then '{}'::jsonb else jsonb_build_object('batch_id', p_batch) end);
$$;
-- Bina's push states for the payments of batch b (or of mutation ids when b is null), sorted.
create function pg_temp.states(p_batch text) returns text language sql stable as $$
  select string_agg(n.push_status, ',' order by n.push_status) from public.notifications n
  where n.user_id = '00000000-0000-4000-8000-0000000030b1' and n.data ->> 'batch_id' = p_batch;
$$;
create function pg_temp.released(p_batch text) returns public.notifications language sql stable as $$
  select n.* from public.notifications n
  where n.user_id = '00000000-0000-4000-8000-0000000030b1' and n.data ->> 'batch_id' = p_batch
    and n.push_status = 'pending';
$$;

-- Money words computed before the role switch (format_money is not for app callers).
create temp table fm as
  select private.format_money(80000, 'INR') as a, private.format_money(2000, 'USD') as b,
         private.format_money(200, 'INR') as c;
grant select on fm to public;

-- ------------------------------------------------------------------ schema
select ok(exists (select 1 from pg_trigger where tgname = 'notifications_queue_push_released'
                    and tgrelid = 'public.notifications'::regclass),
  'a released batched push goes to send-push');
select is((select count(*) from cron.job where jobname = 'monthly-summary' and schedule = '30 3 1 * *'
             and command = 'select private.send_monthly_summaries()'),
  1::bigint, 'the monthly summary runs at 09:00 IST on the 1st');
select ok((select pg_get_constraintdef(oid) like '%summary%' and pg_get_constraintdef(oid) like '%groups%'
           from pg_constraint where conname = 'notifications_kind_check'),
  'kind summary added, the others kept');
select ok((select pg_get_constraintdef(oid) like '%batched%' and pg_get_constraintdef(oid) like '%skipped%'
           from pg_constraint where conname = 'notifications_push_status_check'),
  'push state batched added, the others kept');

set local role authenticated;

-- ------------------------------------------------------------------ batch settle: one push
select pg_temp.as_user('a1');
select is((select count(*) from jsonb_array_elements(public.apply_mutations(jsonb_build_array(
             pg_temp.pay(1, 1, 50000, 'c3060000-0000-4000-8000-000000000001'),
             pg_temp.pay(2, 2, 30000, 'c3060000-0000-4000-8000-000000000001'),
             pg_temp.pay(3, 3, 2000, 'c3060000-0000-4000-8000-000000000001', 'USD'))) -> 'results') r
           where r ->> 'status' = 'applied'),
  3::bigint, 'three payments of one batch are applied');
reset role;  -- Bina's rows are read as the server (RLS shows each person only their own)
select is(pg_temp.states('c3060000-0000-4000-8000-000000000001'), 'batched,batched,pending',
  'Bina gets three bell rows but one push');
select is((pg_temp.released('c3060000-0000-4000-8000-000000000001')).push_title, 'Asha',
  'the push is from Asha');
select is((pg_temp.released('c3060000-0000-4000-8000-000000000001')).push_body,
  (select 'Asha settled up with you in 3 groups · ' || fm.a || ' + ' || fm.b from fm),
  'the push sums the batch per currency');
select is((pg_temp.released('c3060000-0000-4000-8000-000000000001')).data ->> 'batch_count', '3',
  'the push says how many payments it covers');
select is((select count(*) from public.notifications n where n.user_id = '00000000-0000-4000-8000-0000000030b1'
             and n.data ->> 'batch_id' = 'c3060000-0000-4000-8000-000000000001' and n.inapp),
  3::bigint, 'each group keeps its bell row');
select is((select count(*) from public.notifications n where n.user_id = '00000000-0000-4000-8000-0000000030a1'),
  0::bigint, 'the actor hears nothing');
set local role authenticated;

-- One payment in a batch: a plain push.
select is(public.apply_mutations(jsonb_build_array(pg_temp.pay(4, 4, 1000, 'c3060000-0000-4000-8000-000000000002')))
            -> 'results' -> 0 ->> 'status', 'applied', 'a one-payment batch is applied');
reset role;  -- Bina's rows are read as the server (RLS shows each person only their own)
select is(pg_temp.states('c3060000-0000-4000-8000-000000000002'), 'pending', 'a one-payment batch pushes once');
select ok((pg_temp.released('c3060000-0000-4000-8000-000000000002')).push_title is null
          and (pg_temp.released('c3060000-0000-4000-8000-000000000002')).push_body is null,
  'with one payment the usual words stay');
set local role authenticated;

-- Without a batch nothing changes.
select is(public.apply_mutations(jsonb_build_array(pg_temp.pay(5, 1, 700))) -> 'results' -> 0 ->> 'status',
  'applied', 'a single payment is applied');
reset role;  -- Bina's rows are read as the server (RLS shows each person only their own)
select is((select n.push_status from public.notifications n join public.activity a on a.id = n.activity_id
           where n.user_id = '00000000-0000-4000-8000-0000000030b1'
             and a.target_id = 'c3040000-0000-4000-8000-000000000005'),
  'pending', 'a payment outside a batch pushes as before');
set local role authenticated;

-- A batch id on an expense is ignored.
select is(public.apply_mutations(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'c3050000-0000-4000-8000-000000000006', 'entity', 'expense', 'op', 'upsert',
    'id', 'c3020000-0000-4000-8000-000000000006', 'group_id', 'c3000000-0000-4000-8000-000000000001',
    'client_updated_at', now(), 'source', 'app',
    'data', jsonb_build_object('description', 'Taxi', 'date', '2026-12-02', 'currency', 'INR', 'total', 400,
      'payers', jsonb_build_object('c3010000-0000-4000-8000-0000000000a1', 400),
      'shares', jsonb_build_object('c3010000-0000-4000-8000-0000000000a1', 200, 'c3010000-0000-4000-8000-0000000000b1', 200),
      'batch_id', 'c3060000-0000-4000-8000-000000000003')))) -> 'results' -> 0 ->> 'status',
  'applied', 'an expense with a stray batch id is applied');
reset role;  -- Bina's rows are read as the server (RLS shows each person only their own)
select is((select n.push_status from public.notifications n join public.activity a on a.id = n.activity_id
           where n.user_id = '00000000-0000-4000-8000-0000000030b1'
             and a.target_id = 'c3020000-0000-4000-8000-000000000006'),
  'pending', 'expense pushes are never batched');
set local role authenticated;

-- Bina mutes Flat: its row has no push; the batch's push covers the other two.
select pg_temp.as_user('b1');
select lives_ok($$ select public.upsert_notification_settings(null, array['c3000000-0000-4000-8000-000000000002'::uuid]) $$,
  'Bina mutes Flat');
select pg_temp.as_user('a1');
select is((select count(*) from jsonb_array_elements(public.apply_mutations(jsonb_build_array(
             pg_temp.pay(7, 1, 100, 'c3060000-0000-4000-8000-000000000004'),
             pg_temp.pay(8, 2, 100, 'c3060000-0000-4000-8000-000000000004'),
             pg_temp.pay(9, 3, 100, 'c3060000-0000-4000-8000-000000000004'))) -> 'results') r
           where r ->> 'status' = 'applied'),
  3::bigint, 'a second batch is applied');
reset role;  -- Bina's rows are read as the server (RLS shows each person only their own)
select is(pg_temp.states('c3060000-0000-4000-8000-000000000004'), 'batched,pending,skipped',
  'a muted group keeps its bell row without a push');
select is((pg_temp.released('c3060000-0000-4000-8000-000000000004')).push_body,
  (select 'Asha settled up with you in 2 groups · ' || fm.c from fm),
  'the push counts only what it covers');
set local role authenticated;

-- Bina turns payment pushes off: a batch sends none.
select pg_temp.as_user('b1');
select lives_ok($$ select public.upsert_notification_settings('{"payments": {"push": false}}'::jsonb, null) $$,
  'Bina turns payment pushes off');
select pg_temp.as_user('a1');
select is((select count(*) from jsonb_array_elements(public.apply_mutations(jsonb_build_array(
             pg_temp.pay(10, 1, 100, 'c3060000-0000-4000-8000-000000000005'),
             pg_temp.pay(11, 2, 100, 'c3060000-0000-4000-8000-000000000005'))) -> 'results') r
           where r ->> 'status' = 'applied'),
  2::bigint, 'a third batch is applied');
reset role;  -- Bina's rows are read as the server (RLS shows each person only their own)
select is(pg_temp.states('c3060000-0000-4000-8000-000000000005'), 'skipped,skipped',
  'with payment pushes off the batch sends nothing');
set local role authenticated;

-- ------------------------------------------------------------------ settings + attacks
select pg_temp.as_user('b1');
select lives_ok($$ select public.upsert_notification_settings('{"summary": {"push": true}}'::jsonb, null) $$,
  'Bina asks for the monthly summary');
select throws_ok($$ select public.upsert_notification_settings('{"summary": {"push": "yes"}}'::jsonb, null) $$,
  'P0001', 'INVALID_SETTINGS', 'settings stay strictly boolean');
select throws_ok($$ select private.send_monthly_summaries('2026-12-01') $$, '42501', null,
  'attack: nobody can send summaries from the app');
select throws_ok($$ select private.flush_push_batches(array['c3060000-0000-4000-8000-000000000001'::uuid]) $$,
  '42501', null, 'attack: nobody can release pushes from the app');

-- ------------------------------------------------------------------ monthly summary (cron, as the server)
reset role;
update public.notification_settings set kinds = '{"summary": {"push": true}}'
where user_id = '00000000-0000-4000-8000-0000000030c1';
insert into public.notification_settings (user_id, kinds)
values ('00000000-0000-4000-8000-0000000030c1', '{"summary": {"push": true}}') on conflict (user_id) do nothing;
select is(private.send_monthly_summaries('2026-12-01'), 1,
  'one summary: Bina spent last month, Chetan did not, Asha did not ask');
select ok((select n.title = 'Your November' and n.kind = 'summary' and n.inapp and n.push_status = 'pending'
                  and n.data ->> 'target_type' = 'insights' and n.data ->> 'month' = '2026-11'
                  and n.body like 'You spent ' || private.format_money(800, 'INR') || ' across 2 groups · %'
           from public.notifications n
           where n.user_id = '00000000-0000-4000-8000-0000000030b1' and n.type = 'monthly_summary'),
  'Bina''s November: her shares only (no IOU, deleted or October expense), and where she stands');
select is(private.send_monthly_summaries('2026-12-01'), 0, 'sent once per person and month');

select * from finish();
rollback;
