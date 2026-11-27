begin;
-- Group extras (0026, D-034 WP-C C4/C5): the new group columns and their checks, apply_mutations accepting and
-- rejecting them, the whiteboard_updated / settings_changed activity, conflicts keeping both whiteboard versions,
-- pull_changes carrying the columns, RLS (non-members see nothing), the activity type check, send_settle_nudges
-- (weekly / monthly / trip end, idempotent per day, skipped when settled or archived), the fan-out (members with a
-- balance only, muted = in-app only, whiteboard never pushed) and the server-only nudge table / functions.
select plan(60);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000026a1', 'gx-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000026b1', 'gx-b@splitify.test', '{"full_name": "Bina"}'),
  ('00000000-0000-4000-8000-0000000026c1', 'gx-c@splitify.test', '{"full_name": "Chirag"}'),
  ('00000000-0000-4000-8000-0000000026d1', 'gx-d@splitify.test', '{"full_name": "Dev"}'),
  ('00000000-0000-4000-8000-0000000026e1', 'gx-e@splitify.test', '{"full_name": "Esha"}');

-- A push target so pushes queue (rolled back; pg_net sends only after commit).
insert into private.settings (key, value) values ('project_url', 'https://notify.test.invalid')
on conflict (key) do update set value = excluded.value;

create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000026' || p || '","role":"authenticated"}', true);
$$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-0000000026' || p)::uuid;
$$;
-- Groups: 01 Goa (trip, weekly), 02 Flat (monthly), 03 Ladakh (trip end), 04 Settled, 05 Archived.
create function pg_temp.g(p text) returns text language sql immutable as $$
  select 'c2600000-0000-4000-8000-0000000000' || p;
$$;
-- Members: <group><person>, e.g. 01a1 = Asha in Goa.
create function pg_temp.mem(p text) returns text language sql immutable as $$
  select 'c2610000-0000-4000-8000-00000000' || p;
$$;
create function pg_temp.m(p_mid text, p_entity text, p_op text, p_id text, p_group text,
                          p_data jsonb default '{}'::jsonb, p_at timestamptz default now())
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', 'c2650000-0000-4000-8000-0000000000' || p_mid, 'entity', p_entity, 'op', p_op, 'id', p_id,
    'group_id', pg_temp.g(p_group), 'base_seq', null, 'client_updated_at', p_at, 'source', 'app', 'data', p_data);
$$;
create function pg_temp.apply(p jsonb) returns jsonb language sql as $$
  select public.apply_mutations(jsonb_build_array(p)) -> 'results' -> 0;
$$;
create function pg_temp.new_group(p_mid text, p_group text, p_name text, p_data jsonb default '{}'::jsonb)
returns jsonb language sql as $$
  select pg_temp.apply(pg_temp.m(p_mid, 'group', 'upsert', pg_temp.g(p_group), p_group,
    jsonb_build_object('name', p_name, 'type', 'trip',
      'owner_member', jsonb_build_object('id', pg_temp.mem(p_group || 'a1'), 'display_name', 'Asha')) || p_data));
$$;
create function pg_temp.add_member(p_mid text, p_group text, p text, p_name text, p_pos int) returns void
language sql as $$
  select pg_temp.apply(pg_temp.m(p_mid, 'member', 'upsert', pg_temp.mem(p_group || p), p_group,
    jsonb_build_object('display_name', p_name, 'position', p_pos)));
  update public.group_members set user_id = pg_temp.uid(p) where id = pg_temp.mem(p_group || p)::uuid;
$$;
-- Expense in group p_group paid in full by member p_payer; shares keyed by person suffix.
create function pg_temp.exp(p_mid text, p_group text, p_total bigint, p_payer text, p_shares jsonb) returns jsonb
language sql as $$
  select pg_temp.apply(pg_temp.m(p_mid, 'expense', 'upsert', 'c2620000-0000-4000-8000-0000000000' || p_mid,
    p_group, jsonb_build_object(
      'description', 'Dinner', 'date', '2026-11-20', 'currency', 'INR', 'total', p_total, 'split_kind', 'exact',
      'payers', jsonb_build_object(pg_temp.mem(p_group || p_payer), p_total),
      'shares', (select jsonb_object_agg(pg_temp.mem(p_group || k), v) from jsonb_each(p_shares) as s(k, v)))));
$$;
create function pg_temp.last_act(p_group text) returns public.activity language sql stable as $$
  select * from public.activity where group_id = pg_temp.g(p_group)::uuid order by seq desc limit 1;
$$;
create function pg_temp.nudges(p_group text) returns int language sql stable as $$
  select count(*)::int from public.activity where group_id = pg_temp.g(p_group)::uuid and type = 'settle_nudge';
$$;
create function pg_temp.nudge_note(p_group text, p text) returns public.notifications language sql stable as $$
  select n.* from public.notifications n
  join public.activity a on a.id = n.activity_id
  where a.group_id = pg_temp.g(p_group)::uuid and a.type = 'settle_nudge' and n.user_id = pg_temp.uid(p)
  order by a.seq desc limit 1;
$$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'no error';
exception when others then
  return sqlstate;
end;
$$;

-- ---------------------------------------------------------------- columns, defaults, checks

select pg_temp.as_user('a1');
select is(pg_temp.new_group('01', '01', 'Goa trip', '{"trip_starts_on": "2026-12-12", "trip_ends_on": "2026-12-18",
  "settle_reminder": "weekly", "whiteboard": "Villa: 12 Beach Rd"}') ->> 'status', 'applied',
  'create with trip dates, weekly reminders and notes');
select is((select row(trip_starts_on, trip_ends_on, settle_reminder, whiteboard)::text from public.groups
           where id = pg_temp.g('01')::uuid),
  row(date '2026-12-12', date '2026-12-18', 'weekly', 'Villa: 12 Beach Rd')::text, 'the four columns are stored');
select is(pg_temp.new_group('02', '02', 'Flat 4B') ->> 'status', 'applied', 'create without the new fields');
select is((select settle_reminder from public.groups where id = pg_temp.g('02')::uuid), 'off',
  'settle_reminder defaults to off');
select ok((select trip_starts_on is null and trip_ends_on is null and whiteboard is null from public.groups
           where id = pg_temp.g('02')::uuid), 'trip dates and notes default to null');
select is(pg_temp.apply(pg_temp.m('03', 'group', 'upsert', pg_temp.g('01'), '01',
  '{"trip_starts_on": "2026-12-12", "trip_ends_on": "2026-12-11"}')) ->> 'code', 'INVALID_VALUE',
  'end before start is rejected');
select is(pg_temp.apply(pg_temp.m('04', 'group', 'upsert', pg_temp.g('02'), '02', '{"trip_ends_on": "2026-12-11"}'))
  ->> 'status', 'applied', 'an end date without a start is fine');
select is(pg_temp.apply(pg_temp.m('05', 'group', 'upsert', pg_temp.g('02'), '02', '{"settle_reminder": "daily"}'))
  ->> 'code', 'INVALID_VALUE', 'unknown reminder setting is rejected');
select is(pg_temp.apply(pg_temp.m('06', 'group', 'upsert', pg_temp.g('02'), '02',
  jsonb_build_object('whiteboard', repeat('x', 5001)))) ->> 'code', 'INVALID_VALUE',
  'notes longer than 5,000 characters are rejected');
select is(pg_temp.apply(pg_temp.m('07', 'group', 'upsert', pg_temp.g('02'), '02',
  jsonb_build_object('whiteboard', repeat('Ã©', 5000)))) ->> 'status', 'applied', 'exactly 5,000 characters fit');
select is(pg_temp.err($$ update public.groups set settle_reminder = null where id = 'c2600000-0000-4000-8000-000000000002' $$),
  '23502', 'settle_reminder is not null');

-- Members: Bina, Dev and Esha (linked) in Goa; Bina in Flat.
select pg_temp.add_member('10', '01', 'b1', 'Bina', 1);
select pg_temp.add_member('11', '01', 'd1', 'Dev', 2);
select pg_temp.add_member('12', '01', 'e1', 'Esha', 3);
select pg_temp.add_member('13', '02', 'b1', 'Bina', 1);

-- ---------------------------------------------------------------- activity of edits

select is(pg_temp.apply(pg_temp.m('20', 'group', 'upsert', pg_temp.g('01'), '01',
  '{"whiteboard": "Villa: 12 Beach Rd\nWi-Fi: goa2026"}')) ->> 'status', 'applied', 'notes edit applied');
select is((pg_temp.last_act('01')).type, 'whiteboard_updated', 'a notes-only edit logs whiteboard_updated');
select is((select count(*)::int from public.notifications where activity_id = (pg_temp.last_act('01')).id
           and user_id = pg_temp.uid('b1') and inapp and push_status = 'skipped'), 1,
  'whiteboard_updated: in the bell, never pushed');
select is((select count(*)::int from public.notifications where activity_id = (pg_temp.last_act('01')).id
           and user_id = pg_temp.uid('a1')), 0, 'whiteboard_updated: not for the actor');
select is((select body from public.notifications where activity_id = (pg_temp.last_act('01')).id
           and user_id = pg_temp.uid('b1')), 'Asha updated the group notes', 'notes notification text');
select is(pg_temp.apply(pg_temp.m('21', 'group', 'upsert', pg_temp.g('02'), '02', '{"settle_reminder": "monthly"}'))
  ->> 'status', 'applied', 'reminder change applied');
select is((pg_temp.last_act('02')).type, 'settings_changed', 'a reminder change alone is settings_changed');
select is((pg_temp.last_act('02')).data ->> 'settle_reminder', 'monthly', 'with the new setting in its data');
select is((select body from public.notifications where activity_id = (pg_temp.last_act('02')).id
           and user_id = pg_temp.uid('b1')), 'Asha turned on monthly settle-up reminders', 'reminder setting text');
select is(pg_temp.apply(pg_temp.m('22', 'group', 'upsert', pg_temp.g('02'), '02',
  '{"name": "Flat 4B", "trip_starts_on": "2026-12-01", "settle_reminder": "monthly"}')) ->> 'status', 'applied',
  'trip date edit applied');
select is((pg_temp.last_act('02')).type, 'group_updated', 'a trip date edit is group_updated');
select is((pg_temp.last_act('02')).data ->> 'name', 'Flat 4B', 'with the group name');

-- ---------------------------------------------------------------- conflicts keep both notes (rule 6)

select is(pg_temp.apply(pg_temp.m('23', 'group', 'upsert', pg_temp.g('01'), '01', '{"whiteboard": "Old phone text"}',
  now() - interval '1 hour')) ->> 'status', 'superseded', 'an older notes edit loses');
select is((select whiteboard from public.groups where id = pg_temp.g('01')::uuid),
  'Villa: 12 Beach Rd' || chr(10) || 'Wi-Fi: goa2026', 'the newer notes stay');
select is((select snapshot ->> 'whiteboard' from public.record_versions
           where record_id = pg_temp.g('01')::uuid and op = 'conflict_lost' order by id desc limit 1),
  'Old phone text', 'the losing notes are kept in record_versions');
select ok((select count(*) >= 2 from public.record_versions
           where record_id = pg_temp.g('01')::uuid and op in ('insert', 'update') and snapshot ->> 'whiteboard' is not null),
  'every notes save is a version');

-- ---------------------------------------------------------------- pull_changes + RLS

select pg_temp.as_user('b1');
set local role authenticated;
select is((select g ->> 'whiteboard' from jsonb_array_elements(public.pull_changes('{}'::jsonb, 0, 500)
                                                                -> 'rows' -> 'groups') g
           where g ->> 'id' = pg_temp.g('01')),
  'Villa: 12 Beach Rd' || chr(10) || 'Wi-Fi: goa2026', 'pull_changes carries the notes');
select is((select (g ->> 'trip_ends_on') || '/' || (g ->> 'settle_reminder')
           from jsonb_array_elements(public.pull_changes('{}'::jsonb, 0, 500) -> 'rows' -> 'groups') g
           where g ->> 'id' = pg_temp.g('01')), '2026-12-18/weekly', 'pull_changes carries trip dates and reminders');
select is((select whiteboard from public.groups where id = pg_temp.g('01')::uuid),
  'Villa: 12 Beach Rd' || chr(10) || 'Wi-Fi: goa2026', 'a member reads the notes');
select throws_ok($$ update public.groups set whiteboard = 'hack' where id = 'c2600000-0000-4000-8000-000000000001' $$,
  '42501', null, 'members cannot write the columns directly');
select pg_temp.as_user('c1');
select is((select count(*)::int from public.groups where id = pg_temp.g('01')::uuid), 0,
  'RLS: a non-member cannot read the group, its notes or trip dates');
select is(jsonb_array_length(public.pull_changes(jsonb_build_object(pg_temp.g('01'), 0), 0, 500) -> 'rows' -> 'groups'),
  0, 'RLS: pull_changes gives a non-member nothing');
select is(pg_temp.apply(pg_temp.m('24', 'group', 'upsert', pg_temp.g('01'), '01', '{"whiteboard": "x"}')) ->> 'code',
  'NOT_MEMBER', 'a non-member cannot edit the notes');
select throws_ok($$ select private.send_settle_nudges() $$, '42501', null,
  'clients cannot run the nudge job');
reset role;

-- ---------------------------------------------------------------- activity type check

select is(pg_temp.err($$ insert into public.activity (group_id, type, data)
  values ('c2600000-0000-4000-8000-000000000001', 'bogus_type', '{}') $$), '23514', 'unknown activity types fail');
select is(pg_temp.err($$ insert into public.activity (group_id, type, data)
  values ('c2600000-0000-4000-8000-000000000002', 'whiteboard_updated', '{}') $$), 'no error',
  'whiteboard_updated is a known type');

-- ---------------------------------------------------------------- settle-up nudges

-- Goa: Asha paid 1000 for Asha 400, Bina 300, Dev 300 -> Asha +600, Bina -300, Dev -300, Esha 0. Dev mutes Goa.
select pg_temp.as_user('a1');
select is(pg_temp.exp('30', '01', 100000, 'a1', '{"a1": 40000, "b1": 30000, "d1": 30000}') ->> 'status', 'applied',
  'Goa expense');
select pg_temp.as_user('d1');
set local role authenticated;
select is(public.upsert_notification_settings(null, array[pg_temp.g('01')::uuid]) -> 'muted_group_ids',
  jsonb_build_array(pg_temp.g('01')), 'Dev mutes Goa');
reset role;
-- Goa was created on a Wednesday (IST); its weekly nudge is due on Wednesdays.
update public.groups set created_at = timestamptz '2026-11-04 10:00+05:30' where id = pg_temp.g('01')::uuid;

select is(private.send_settle_nudges(date '2026-11-10'), 0, 'weekly: nothing on a Tuesday');
select is(private.send_settle_nudges(date '2026-11-11'), 1, 'weekly: one nudge on the creation weekday');
select is(private.send_settle_nudges(date '2026-11-11'), 0, 'a second run the same day adds nothing');
select is(pg_temp.nudges('01'), 1, 'exactly one settle_nudge row');
select is((select actor_user_id is null and data ->> 'reason' = 'weekly' from public.activity
           where group_id = pg_temp.g('01')::uuid and type = 'settle_nudge'), true, 'system row, reason weekly');
select is((pg_temp.nudge_note('01', 'b1')).body, 'Time to settle up: you owe â‚¹300',
  'Bina hears what she owes');
select is((pg_temp.nudge_note('01', 'b1')).kind || '/' || (pg_temp.nudge_note('01', 'b1')).push_status,
  'reminders/pending', 'kind reminders, pushed');
select is((pg_temp.nudge_note('01', 'a1')).body, 'Time to settle up: you''re owed â‚¹600',
  'Asha (who set it up) hears she is owed');
select is((pg_temp.nudge_note('01', 'd1')).push_status || '/' || (pg_temp.nudge_note('01', 'd1')).inapp::text,
  'skipped/true', 'muted Dev: in the bell, no push');
select is((select count(*)::int from public.notifications n join public.activity a on a.id = n.activity_id
           where a.type = 'settle_nudge' and n.user_id = pg_temp.uid('e1')), 0, 'Esha (balance 0) gets nothing');
select is((select data ->> 'target_type' from public.notifications where id = (pg_temp.nudge_note('01', 'b1')).id),
  'balances', 'a nudge opens the Balances tab');

-- Flat (monthly): Bina paid 500 for both.
select pg_temp.as_user('a1');
select is(pg_temp.exp('31', '02', 50000, 'a1', '{"a1": 25000, "b1": 25000}') ->> 'status', 'applied', 'Flat expense');
select is(private.send_settle_nudges(date '2026-11-02'), 0, 'monthly: nothing on the 2nd');
select is(private.send_settle_nudges(date '2026-12-01'), 1, 'monthly: a nudge on the 1st');

-- Ladakh: reminders off, trip ended 2026-11-15, Asha owes Bina. Settled trip: Asha paid for herself only.
select pg_temp.new_group('40', '03', 'Ladakh', '{"trip_starts_on": "2026-11-10", "trip_ends_on": "2026-11-15"}');
select pg_temp.add_member('41', '03', 'b1', 'Bina', 1);
select pg_temp.exp('42', '03', 20000, 'b1', '{"a1": 10000, "b1": 10000}');
select pg_temp.new_group('43', '04', 'Settled trip', '{"trip_ends_on": "2026-11-15"}');
select pg_temp.exp('44', '04', 20000, 'a1', '{"a1": 20000}');
select pg_temp.new_group('45', '05', 'Archived trip', '{"trip_ends_on": "2026-11-15"}');
select pg_temp.add_member('46', '05', 'b1', 'Bina', 1);
select pg_temp.exp('47', '05', 20000, 'a1', '{"a1": 10000, "b1": 10000}');
select pg_temp.apply(pg_temp.m('48', 'group', 'upsert', pg_temp.g('05'), '05', '{"archived_at": "2026-11-20T10:00:00Z"}'));

select is(private.send_settle_nudges(date '2026-11-15'), 0, 'trip end: nothing on the last day');
select is(private.send_settle_nudges(date '2026-11-16'), 1, 'trip end: one nudge the day after (Ladakh only)');
select is((select data ->> 'reason' from public.activity where group_id = pg_temp.g('03')::uuid and type = 'settle_nudge'),
  'trip_end', 'reason trip_end');
select is((pg_temp.nudge_note('03', 'a1')).body, 'Your trip is over. Time to settle up: you owe â‚¹100',
  'trip end text');
select is(pg_temp.nudges('04') + pg_temp.nudges('05'), 0, 'settled and archived groups get no nudge');

-- ---------------------------------------------------------------- server-only pieces

select ok((select c.relrowsecurity from pg_class c where c.oid = 'private.settle_nudges_sent'::regclass)
          and not exists (select 1 from pg_policy p where p.polrelid = 'private.settle_nudges_sent'::regclass)
          and not has_table_privilege('authenticated', 'private.settle_nudges_sent', 'select'),
  'settle_nudges_sent: RLS on, no policies, no client access');
select is((select count(*)::int from cron.job where jobname = 'settle-nudges' and schedule = '30 4 * * *'), 1,
  'the daily cron runs at 10:00 IST');

select * from finish();
rollback;
