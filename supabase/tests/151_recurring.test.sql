-- Recurring bills (0019, phase 16): templates through apply_mutations (create / edit / stop / resume / delete,
-- last write wins, validation, NOT_MEMBER), RLS, pull_changes, and the generator: TC-12-01 double run = one copy,
-- TC-12-02 31st clamp for Feb/Apr with catch-up, TC-12-03 stop and ends_on; copies are normal expenses with
-- deterministic ids, source 'recurring', expense_added {recurring: true} by the template's creator.
begin;
select plan(49);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000016a1', 'rec-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000016b1', 'rec-b@splitify.test'),
  ('00000000-0000-4000-8000-0000000016c1', 'rec-c@splitify.test');

create temp table res (k text primary key, v jsonb);

-- One mutation by the caller; p_mid = last two hex digits of the mutation id, p_ago = how long ago it was saved.
create function pg_temp.m(p_mid text, p_entity text, p_op text, p_id text, p_ago interval,
  p_data jsonb default '{}'::jsonb, p_group text default '16000000-0000-4000-8000-000000000001')
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', '41600000-0000-4000-8000-0000000000' || p_mid, 'entity', p_entity, 'op', p_op, 'id', p_id,
    'group_id', p_group, 'base_seq', null, 'client_updated_at', now() - p_ago, 'source', 'app', 'data', p_data);
$$;
-- Template fields: paid by A, split between A and B.
create function pg_temp.tpl(p_total bigint, p_a bigint, p_b bigint)
returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'description', 'Rent', 'category', 'rent.rent', 'currency', 'INR', 'total', p_total, 'split_kind', 'equal',
    'payers', jsonb_build_object('26000000-0000-4000-8000-0000000000a1', p_total),
    'shares', jsonb_build_object('26000000-0000-4000-8000-0000000000a1', p_a,
                                 '26000000-0000-4000-8000-0000000000b1', p_b));
$$;
create function pg_temp.st(p_k text) returns text language sql stable as $$
  select v -> 'results' -> 0 ->> 'status' from res where k = p_k;
$$;
create function pg_temp.code(p_k text) returns text language sql stable as $$
  select v -> 'results' -> 0 ->> 'code' from res where k = p_k;
$$;
create function pg_temp.as_user(p_sub text) returns text language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || p_sub || '","role":"authenticated"}', true);
$$;
create function pg_temp.copies(p_t text) returns text language sql stable as $$
  select coalesce(string_agg(to_char(e.date, 'YYYY-MM-DD'), ',' order by e.date), '')
  from public.expenses e where e.recurring_id = p_t::uuid;
$$;

select pg_temp.as_user('00000000-0000-4000-8000-0000000016a1');
insert into res select 'group', public.apply_mutations(jsonb_build_array(
  pg_temp.m('01', 'group', 'upsert', '16000000-0000-4000-8000-000000000001', '5 hours',
    '{"name": "Flat 302", "type": "home",
      "owner_member": {"id": "26000000-0000-4000-8000-0000000000a1", "display_name": "Asha"}}'),
  pg_temp.m('02', 'member', 'upsert', '26000000-0000-4000-8000-0000000000b1', '5 hours',
    '{"display_name": "Bala", "position": 1}')));
update public.group_members set user_id = '00000000-0000-4000-8000-0000000016b1'
where id = '26000000-0000-4000-8000-0000000000b1';

-- ------------------------------------------------------------------ create

-- T1: monthly on the 31st (anchor 2026-01-31). Saved "now", so the first copy is the first one on or after today.
insert into res select 't1', public.apply_mutations(jsonb_build_array(pg_temp.m('03', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000001', '0 seconds',
  jsonb_build_object('interval', 'monthly', 'anchor_date', '2026-01-31', 'ends_on', null, 'active', true,
                     'expense_id', '46000000-0000-4000-8000-000000000001', 'next_date', '1999-01-01',
                     'template', pg_temp.tpl(1000000, 500000, 500000)))));
select is(pg_temp.st('t1'), 'applied', 'a template is created through apply_mutations');
select is(
  (select next_date from public.recurring_templates where id = '36000000-0000-4000-8000-000000000001'),
  private.recurring_next_after('monthly', '2026-01-31', null, (now() at time zone 'Asia/Kolkata')::date - 1),
  'the server sets next_date (first copy on or after the day of the save; the client value is ignored)');
select is(
  (select created_by::text || ':' || expense_id::text || ':' || active::text
   from public.recurring_templates where id = '36000000-0000-4000-8000-000000000001'),
  '00000000-0000-4000-8000-0000000016a1:46000000-0000-4000-8000-000000000001:true',
  'creator, source expense and active are stored');
select is(
  (select template ->> 'notes' is null and template ->> 'kind' = 'expense' and template -> 'split_values' = 'null'
   from public.recurring_templates where id = '36000000-0000-4000-8000-000000000001'),
  true, 'the template keeps only known expense fields');
select is(
  (select count(*)::int from public.activity where target_id = '36000000-0000-4000-8000-000000000001'
     and type = 'recurring_created' and actor_member_id = '26000000-0000-4000-8000-0000000000a1'
     and data ->> 'interval' = 'monthly'),
  1, 'recurring_created activity names the actor');
select is(
  (select count(*)::int from public.record_versions
   where table_name = 'recurring_templates' and record_id = '36000000-0000-4000-8000-000000000001'
     and op = 'insert'),
  1, 'the insert is in history');

-- T2 starts in the future: its first copy is one week after the anchor.
insert into res select 't2', public.apply_mutations(jsonb_build_array(pg_temp.m('04', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000002', '0 seconds',
  jsonb_build_object('interval', 'weekly',
                     'anchor_date', to_char((now() at time zone 'Asia/Kolkata')::date + 10, 'YYYY-MM-DD'),
                     'template', pg_temp.tpl(30000, 15000, 15000)))));
select is(
  (select next_date - anchor_date from public.recurring_templates
   where id = '36000000-0000-4000-8000-000000000002'),
  7, 'a future anchor: next_date = anchor + 1 week');

-- ------------------------------------------------------------------ validation and access

insert into res select 'bad-sum', public.apply_mutations(jsonb_build_array(pg_temp.m('05', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000009', '0 seconds',
  jsonb_build_object('interval', 'monthly', 'anchor_date', '2026-01-01', 'template',
                     pg_temp.tpl(1000, 500, 400)))));
select is(pg_temp.code('bad-sum'), 'SPLIT_SUM_MISMATCH', 'shares must add up to the total');
insert into res select 'bad-end', public.apply_mutations(jsonb_build_array(pg_temp.m('06', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000009', '0 seconds',
  jsonb_build_object('interval', 'monthly', 'anchor_date', '2026-01-10', 'ends_on', '2026-01-09', 'template',
                     pg_temp.tpl(1000, 500, 500)))));
select is(pg_temp.code('bad-end'), 'ENDS_BEFORE_ANCHOR', 'an end date before the anchor is refused');
insert into res select 'bad-int', public.apply_mutations(jsonb_build_array(pg_temp.m('07', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000009', '0 seconds',
  jsonb_build_object('interval', 'daily', 'anchor_date', '2026-01-10', 'template', pg_temp.tpl(1000, 500, 500)))));
select is(pg_temp.code('bad-int'), 'UNKNOWN_INTERVAL', 'an unknown interval is refused');
insert into res select 'bad-date', public.apply_mutations(jsonb_build_array(pg_temp.m('08', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000009', '0 seconds',
  jsonb_build_object('interval', 'monthly', 'anchor_date', '2026-02-30', 'template', pg_temp.tpl(1000, 500, 500)))));
select is(pg_temp.code('bad-date'), 'NOT_A_DATE', 'an impossible date is refused');
insert into res select 'bad-amt', public.apply_mutations(jsonb_build_array(pg_temp.m('09', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000009', '0 seconds',
  jsonb_build_object('interval', 'monthly', 'anchor_date', '2026-01-10',
                     'template', pg_temp.tpl(1000, 500, 500) || '{"total": 1000.5}'::jsonb))));
select is(pg_temp.code('bad-amt'), 'INVALID_AMOUNT', 'a fractional total is refused');
insert into res select 'bad-new', public.apply_mutations(jsonb_build_array(pg_temp.m('10', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000009', '0 seconds', '{"interval": "monthly", "anchor_date": "2026-01-10"}')));
select is(pg_temp.code('bad-new'), 'INVALID_TEMPLATE', 'a new template needs its expense fields');
select is(
  (select count(*)::int from public.recurring_templates where id = '36000000-0000-4000-8000-000000000009'),
  0, 'refused templates are not stored');

select pg_temp.as_user('00000000-0000-4000-8000-0000000016c1');
insert into res select 'stranger', public.apply_mutations(jsonb_build_array(pg_temp.m('11', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000001', '0 seconds', '{"active": false}')));
select is(pg_temp.code('stranger'), 'NOT_MEMBER', 'a stranger cannot stop a template');

set local role authenticated;
select pg_temp.as_user('00000000-0000-4000-8000-0000000016b1');
select is((select count(*)::int from public.recurring_templates
           where group_id = '16000000-0000-4000-8000-000000000001'), 2, 'a member sees the group''s templates');
select pg_temp.as_user('00000000-0000-4000-8000-0000000016c1');
select is((select count(*)::int from public.recurring_templates
           where group_id = '16000000-0000-4000-8000-000000000001'), 0, 'a stranger sees none');
select throws_ok(
  $$insert into public.recurring_templates (id, group_id, "interval", anchor_date, template, seq)
    values ('36000000-0000-4000-8000-0000000000ff', '16000000-0000-4000-8000-000000000001', 'weekly',
            '2026-01-01', '{}', 0)$$,
  '42501', null, 'clients cannot insert templates directly');
reset role;
select is(has_function_privilege('authenticated', 'private.generate_recurring(date)', 'execute'), false,
  'clients cannot run the generator');

select pg_temp.as_user('00000000-0000-4000-8000-0000000016b1');
select is(
  (select jsonb_array_length(public.pull_changes('{}'::jsonb, 0, 500) -> 'rows' -> 'recurring_templates')),
  2, 'pull_changes sends the templates');

-- ------------------------------------------------------------------ generator: TC-12-01 idempotent

update public.recurring_templates set next_date = '2026-02-28' where id = '36000000-0000-4000-8000-000000000001';
update public.recurring_templates set active = false where id = '36000000-0000-4000-8000-000000000002';
select is(private.generate_recurring('2026-02-28'), 1, 'the first run adds the copy that is due');
select is(private.generate_recurring('2026-02-28'), 0, 'a second run the same day adds nothing');
select is(pg_temp.copies('36000000-0000-4000-8000-000000000001'), '2026-02-28', 'TC-12-01: one copy, Jan 31 clamped to Feb 28');
select is(
  (select id from public.expenses where recurring_id = '36000000-0000-4000-8000-000000000001'),
  md5('36000000-0000-4000-8000-000000000001' || '2026-02-28')::uuid, 'the copy id is md5(template id || date)');
select is(
  (select source || ':' || total || ':' || created_by::text || ':' || (shares ->> '26000000-0000-4000-8000-0000000000b1')
   from public.expenses where recurring_id = '36000000-0000-4000-8000-000000000001'),
  'recurring:1000000:00000000-0000-4000-8000-0000000016a1:500000', 'the copy is a normal expense by the creator');
select is(
  (select count(*)::int from public.activity a
   join public.expenses e on e.id = a.target_id
   where e.recurring_id = '36000000-0000-4000-8000-000000000001' and a.type = 'expense_added'
     and a.data ->> 'recurring' = 'true' and a.actor_member_id = '26000000-0000-4000-8000-0000000000a1'),
  1, 'expense_added {recurring: true} by the creator''s member');
select is(
  (select count(*)::int from public.record_versions rv join public.expenses e on e.id = rv.record_id
   where e.recurring_id = '36000000-0000-4000-8000-000000000001' and rv.op = 'insert'),
  1, 'the copy is in history');
select is(
  (select count(*)::int from public.notifications n join public.activity a on a.id = n.activity_id
   join public.expenses e on e.id = a.target_id
   where e.recurring_id = '36000000-0000-4000-8000-000000000001'
     and n.user_id in ('00000000-0000-4000-8000-0000000016a1', '00000000-0000-4000-8000-0000000016b1')),
  2, 'both linked people involved hear about the copy (the creator too)');
select is(
  (select next_date from public.recurring_templates where id = '36000000-0000-4000-8000-000000000001'),
  '2026-03-31'::date, 'next_date returns to the 31st');

-- ------------------------------------------------------------------ TC-12-02 clamp + catch-up

select is(private.generate_recurring('2026-04-30'), 2, 'missed days are caught up');
select is(pg_temp.copies('36000000-0000-4000-8000-000000000001'), '2026-02-28,2026-03-31,2026-04-30',
  'TC-12-02: 31st -> Feb 28, Mar 31, Apr 30');

-- Template edit without a schedule change: next_date stays, later copies use the new amount.
select pg_temp.as_user('00000000-0000-4000-8000-0000000016b1');
insert into res select 'edit', public.apply_mutations(jsonb_build_array(pg_temp.m('12', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000001', '0 seconds', jsonb_build_object('template', pg_temp.tpl(1100000, 550000, 550000)))));
select is(pg_temp.st('edit'), 'applied', 'any member can edit the template');
select is(
  (select next_date from public.recurring_templates where id = '36000000-0000-4000-8000-000000000001'),
  '2026-05-31'::date, 'editing the amount keeps next_date');
select is(
  (select count(*)::int from public.activity where target_id = '36000000-0000-4000-8000-000000000001'
     and type = 'recurring_updated' and actor_member_id = '26000000-0000-4000-8000-0000000000b1'),
  1, 'recurring_updated activity');
select is(private.generate_recurring('2026-05-31'), 1, 'the next copy is added');
select is(
  (select total from public.expenses where recurring_id = '36000000-0000-4000-8000-000000000001'
     and date = '2026-05-31'),
  1100000::bigint, 'future copies use the edited template; earlier copies are unchanged');

-- Older save loses (last write wins) and is kept in history.
insert into res select 'old', public.apply_mutations(jsonb_build_array(pg_temp.m('13', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000001', '3 hours', '{"active": false}')));
select is(pg_temp.st('old'), 'superseded', 'an older save is superseded');
select is(
  (select count(*)::int from public.record_versions where record_id = '36000000-0000-4000-8000-000000000001'
     and op = 'conflict_lost'),
  1, 'the losing version is kept');

-- Archived group: no copies, the template moves on.
update public.groups set archived_at = now() where id = '16000000-0000-4000-8000-000000000001';
select is(private.generate_recurring('2026-06-30'), 0, 'archived groups get no copies');
select is(
  (select next_date from public.recurring_templates where id = '36000000-0000-4000-8000-000000000001'),
  '2026-07-31'::date, 'and the template moves on');
update public.groups set archived_at = null where id = '16000000-0000-4000-8000-000000000001';

-- ------------------------------------------------------------------ TC-12-03 stop, ends_on, resume

insert into res select 'stop', public.apply_mutations(jsonb_build_array(pg_temp.m('14', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000001', '0 seconds', '{"active": false}')));
select is(
  (select count(*)::int from public.activity where target_id = '36000000-0000-4000-8000-000000000001'
     and type = 'recurring_stopped'),
  1, 'Stop repeating writes recurring_stopped');
select is(private.generate_recurring('2026-08-31'), 0, 'TC-12-03: a stopped template adds nothing');

insert into res select 'resume', public.apply_mutations(jsonb_build_array(pg_temp.m('15', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000001', '0 seconds', '{"active": true}')));
select ok(
  (select next_date >= (now() at time zone 'Asia/Kolkata')::date from public.recurring_templates
   where id = '36000000-0000-4000-8000-000000000001'),
  'resuming starts again from today (no back-fill)');

-- T3: weekly, ends on Jan 19 (inclusive).
select pg_temp.as_user('00000000-0000-4000-8000-0000000016a1');
insert into res select 't3', public.apply_mutations(jsonb_build_array(pg_temp.m('16', 'recurring', 'upsert',
  '36000000-0000-4000-8000-000000000003', '0 seconds',
  jsonb_build_object('interval', 'weekly', 'anchor_date', '2026-01-05', 'ends_on', '2026-01-19',
                     'template', pg_temp.tpl(20000, 10000, 10000)))));
update public.recurring_templates set next_date = '2026-01-12' where id = '36000000-0000-4000-8000-000000000003';
update public.recurring_templates set active = false where id = '36000000-0000-4000-8000-000000000001';
select is(private.generate_recurring('2026-02-01'), 2, 'copies up to the end date');
select is(pg_temp.copies('36000000-0000-4000-8000-000000000003'), '2026-01-12,2026-01-19', 'ends_on is inclusive');
select is(
  (select next_date from public.recurring_templates where id = '36000000-0000-4000-8000-000000000003'),
  null, 'no copies left: next_date is null');

-- A copy the expense rules refuse stops the template and says why.
update public.recurring_templates
set active = true, ends_on = null, next_date = '2026-01-26',
    template = template || jsonb_build_object('shares', jsonb_build_object('26000000-0000-4000-8000-0000000000ee', 20000))
where id = '36000000-0000-4000-8000-000000000003';
select is(private.generate_recurring('2026-01-26'), 0, 'a refused copy is not added');
select is(
  (select active::text || ':' || (select data ->> 'reason' from public.activity
                                  where target_id = '36000000-0000-4000-8000-000000000003'
                                    and type = 'recurring_stopped' order by seq desc limit 1)
   from public.recurring_templates where id = '36000000-0000-4000-8000-000000000003'),
  'false:FOREIGN_MEMBER', 'the template stops with the reason');

-- Delete is soft.
insert into res select 'del', public.apply_mutations(jsonb_build_array(pg_temp.m('17', 'recurring', 'delete',
  '36000000-0000-4000-8000-000000000003', '0 seconds')));
select is(
  (select deleted_at is not null from public.recurring_templates where id = '36000000-0000-4000-8000-000000000003'),
  true, 'delete is soft');

select * from finish();
rollback;
