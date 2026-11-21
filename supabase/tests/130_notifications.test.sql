begin;
-- Notifications and reminders (0016; TC-19-01, TC-23-01): fan-out recipients (involved linked members, never the
-- actor, name-only never), muted groups (in-app yes, push no), per-kind in-app/push settings, texts, the push
-- queue, reminders (recipient, amounts, 24 h throttle, rejections), mark read, device tokens, own-rows RLS.
select plan(80);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000013a1', 'ntf-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000013b1', 'ntf-b@splitify.test', '{"full_name": "Bina"}'),
  ('00000000-0000-4000-8000-0000000013c1', 'ntf-c@splitify.test', '{"full_name": "Chirag"}'),
  ('00000000-0000-4000-8000-0000000013d1', 'ntf-d@splitify.test', '{"full_name": "Dev"}');

-- A push target for the queue (rolled back with everything else; pg_net sends only after commit).
insert into private.settings (key, value) values ('project_url', 'https://notify.test.invalid')
on conflict (key) do update set value = excluded.value;

create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000013' || p || '","role":"authenticated"}', true);
$$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-0000000013' || p)::uuid;
$$;
-- Member ids: a1 Asha, b1 Bina, d1 Dev (linked), e1 Nina (name-only).
create function pg_temp.mem(p text) returns text language sql immutable as $$
  select 'c1310000-0000-4000-8000-0000000000' || p;
$$;
create function pg_temp.m(p_mid text, p_entity text, p_op text, p_id text, p_data jsonb default '{}'::jsonb)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', 'c1350000-0000-4000-8000-0000000000' || p_mid, 'entity', p_entity, 'op', p_op, 'id', p_id,
    'group_id', 'c1300000-0000-4000-8000-000000000001', 'base_seq', null, 'client_updated_at', now(),
    'source', 'app', 'data', p_data);
$$;
create function pg_temp.apply(p jsonb) returns jsonb language sql as $$
  select public.apply_mutations(jsonb_build_array(p)) -> 'results' -> 0;
$$;
-- Expense paid in full by p_payer; p_shares = {"a1": 100, ...} keyed by member suffix.
create function pg_temp.exp(p_desc text, p_total bigint, p_payer text, p_shares jsonb) returns jsonb
language sql immutable as $$
  select jsonb_build_object(
    'description', p_desc, 'date', '2026-11-20', 'currency', 'INR', 'total', p_total, 'split_kind', 'exact',
    'payers', jsonb_build_object(pg_temp.mem(p_payer), p_total),
    'shares', (select jsonb_object_agg(pg_temp.mem(k), v) from jsonb_each(p_shares) as s(k, v)));
$$;
create function pg_temp.pay(p_from text, p_to text, p_amount bigint) returns jsonb language sql immutable as $$
  select jsonb_build_object('from_member', pg_temp.mem(p_from), 'to_member', pg_temp.mem(p_to), 'amount', p_amount,
    'currency', 'INR', 'date', '2026-11-21');
$$;
-- The newest activity row of a target.
create function pg_temp.act(p_target text) returns uuid language sql stable as $$
  select id from public.activity where target_id = p_target::uuid order by seq desc limit 1;
$$;
-- Notifications of the newest activity of p_target for user p (null p = everyone).
create function pg_temp.n_count(p_target text, p text default null) returns int language sql stable as $$
  select count(*)::int from public.notifications
  where activity_id = pg_temp.act(p_target) and (p is null or user_id = pg_temp.uid(p));
$$;
create function pg_temp.n(p_target text, p text) returns public.notifications language sql stable as $$
  select * from public.notifications where activity_id = pg_temp.act(p_target) and user_id = pg_temp.uid(p);
$$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'no error';
exception when others then
  return sqlerrm;
end;
$$;

-- Group of Asha with Bina, Dev (linked, standing in for joins) and Nina (name-only).
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('01', 'group', 'upsert', 'c1300000-0000-4000-8000-000000000001',
  jsonb_build_object('name', 'Goa trip', 'type', 'trip',
    'owner_member', jsonb_build_object('id', pg_temp.mem('a1'), 'display_name', 'Asha'))));
select pg_temp.apply(pg_temp.m('02', 'member', 'upsert', pg_temp.mem('b1'), '{"display_name": "Bina", "position": 1}'));
select pg_temp.apply(pg_temp.m('03', 'member', 'upsert', pg_temp.mem('d1'), '{"display_name": "Dev", "position": 2}'));
select pg_temp.apply(pg_temp.m('04', 'member', 'upsert', pg_temp.mem('e1'), '{"display_name": "Nina", "position": 3}'));
update public.group_members set user_id = pg_temp.uid('b1') where id = pg_temp.mem('b1')::uuid;
update public.group_members set user_id = pg_temp.uid('d1') where id = pg_temp.mem('d1')::uuid;

select is((select count(*)::int from public.notifications where group_id = 'c1300000-0000-4000-8000-000000000001'),
  0, 'TC-19-01 group created / members added notify nobody');

-- ---------------------------------------------------------------- expense fan-out
-- E1 "Dinner" ₹1,200 paid by Asha, split Asha / Bina / Nina (Dev not in it).
select is(pg_temp.apply(pg_temp.m('10', 'expense', 'upsert', 'c1320000-0000-4000-8000-000000000001',
  pg_temp.exp('Dinner', 120000, 'a1', '{"a1": 40000, "b1": 40000, "e1": 40000}'))) ->> 'status', 'applied',
  'E1 applied');
select is(pg_temp.n_count('c1320000-0000-4000-8000-000000000001', 'b1'), 1, 'TC-19-01 Bina (in the split) is notified');
select is(pg_temp.n_count('c1320000-0000-4000-8000-000000000001', 'a1'), 0, 'TC-19-01 the actor is never notified');
select is(pg_temp.n_count('c1320000-0000-4000-8000-000000000001', 'd1'), 0, 'TC-19-01 Dev (not in the split) is not');
select is(pg_temp.n_count('c1320000-0000-4000-8000-000000000001'), 1, 'TC-19-01 name-only Nina gets nothing');
select is((pg_temp.n('c1320000-0000-4000-8000-000000000001', 'b1')).body, 'Asha added “Dinner” · ₹1,200',
  'TC-19-01 expense text');
select is((pg_temp.n('c1320000-0000-4000-8000-000000000001', 'b1')).title, 'Goa trip', 'title = group name');
select is((pg_temp.n('c1320000-0000-4000-8000-000000000001', 'b1')).kind, 'expenses', 'kind expenses');
select is((pg_temp.n('c1320000-0000-4000-8000-000000000001', 'b1')).type, 'expense_added', 'activity type kept');
select is((pg_temp.n('c1320000-0000-4000-8000-000000000001', 'b1')).push_status, 'pending', 'push pending by default');
select is((pg_temp.n('c1320000-0000-4000-8000-000000000001', 'b1')).data,
  jsonb_build_object('target_type', 'expense', 'target_id', 'c1320000-0000-4000-8000-000000000001',
    'group_id', 'c1300000-0000-4000-8000-000000000001', 'actor_member_id', pg_temp.mem('a1'), 'actor_name', 'Asha'),
  'data says what a tap opens');
select ok((pg_temp.n('c1320000-0000-4000-8000-000000000001', 'b1')).inapp
          and (pg_temp.n('c1320000-0000-4000-8000-000000000001', 'b1')).read_at is null, 'in-app and unread');
select ok(exists (select 1 from net.http_request_queue
                  where url = 'https://notify.test.invalid/functions/v1/send-push'
                    and convert_from(body, 'utf8')::jsonb ->> 'notification_id'
                        = (pg_temp.n('c1320000-0000-4000-8000-000000000001', 'b1')).id::text),
  'TC-19-01 a pending push is queued for send-push via pg_net');

-- Edit takes Bina out of the split: she still hears about it (participant of the previous version).
select pg_temp.apply(pg_temp.m('11', 'expense', 'upsert', 'c1320000-0000-4000-8000-000000000001',
  pg_temp.exp('Dinner', 120000, 'a1', '{"a1": 60000, "e1": 60000}')));
select is((pg_temp.n('c1320000-0000-4000-8000-000000000001', 'b1')).body, 'Asha edited “Dinner” · ₹1,200',
  'TC-19-01 someone taken out of the split is told about the edit');

-- ---------------------------------------------------------------- muted group, per-kind settings
select pg_temp.as_user('d1');
set local role authenticated;
select is(public.upsert_notification_settings(null, array['c1300000-0000-4000-8000-000000000001'::uuid])
  -> 'muted_group_ids', '["c1300000-0000-4000-8000-000000000001"]'::jsonb, 'Dev mutes the group');
reset role;
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('12', 'expense', 'upsert', 'c1320000-0000-4000-8000-000000000002',
  pg_temp.exp('Taxi', 30000, 'a1', '{"a1": 10000, "b1": 10000, "d1": 10000}')));
select is((pg_temp.n('c1320000-0000-4000-8000-000000000002', 'd1')).push_status, 'skipped',
  'TC-19-01 muted group: no push');
select ok((pg_temp.n('c1320000-0000-4000-8000-000000000002', 'd1')).inapp, 'TC-19-01 muted group: still in the bell');
select is((pg_temp.n('c1320000-0000-4000-8000-000000000002', 'b1')).push_status, 'pending',
  'not muted: push pending');

-- Bina: expenses in-app off (push stays on) -> push-only row; then both off -> no row.
select pg_temp.as_user('b1');
set local role authenticated;
select is(public.upsert_notification_settings('{"expenses": {"inapp": false}}'::jsonb) -> 'kinds',
  '{"expenses": {"inapp": false}}'::jsonb, 'Bina turns off in-app expense notifications');
reset role;
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('13', 'expense', 'upsert', 'c1320000-0000-4000-8000-000000000003',
  pg_temp.exp('Snacks', 2000, 'a1', '{"a1": 1000, "b1": 1000}')));
select is((pg_temp.n('c1320000-0000-4000-8000-000000000003', 'b1')).inapp, false, 'in-app off: row hidden from the bell');
select is((pg_temp.n('c1320000-0000-4000-8000-000000000003', 'b1')).push_status, 'pending', 'in-app off: push still sent');
select pg_temp.as_user('b1');
set local role authenticated;
select is(public.upsert_notification_settings('{"expenses": {"inapp": false, "push": false}}'::jsonb) -> 'muted_group_ids',
  '[]'::jsonb, 'null muted list keeps the saved one');
reset role;
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('14', 'expense', 'upsert', 'c1320000-0000-4000-8000-000000000004',
  pg_temp.exp('Water', 1000, 'a1', '{"a1": 500, "b1": 500}')));
select is(pg_temp.n_count('c1320000-0000-4000-8000-000000000004', 'b1'), 0, 'TC-19-01 kind off for both: no row');
select pg_temp.as_user('b1');
set local role authenticated;
select is(public.upsert_notification_settings('{}'::jsonb) -> 'kinds', '{}'::jsonb, 'Bina back to defaults');
select is(pg_temp.err($$select public.upsert_notification_settings('{"spam": {"push": true}}'::jsonb)$$),
  'INVALID_SETTINGS', 'unknown kind rejected');
select is(pg_temp.err($$select public.upsert_notification_settings('{"expenses": {"push": "yes"}}'::jsonb)$$),
  'INVALID_SETTINGS', 'non-boolean value rejected');
select is(pg_temp.err($$select public.upsert_notification_settings('[]'::jsonb)$$),
  'INVALID_SETTINGS', 'kinds must be an object');
reset role;
select pg_temp.as_user('c1');
set local role authenticated;
select is(public.upsert_notification_settings(null, array['c1300000-0000-4000-8000-000000000001'::uuid])
  -> 'muted_group_ids', '[]'::jsonb, 'a group you are not in cannot be muted');
reset role;

-- Recurring copy: the template creator is told too (they did not just add it).
insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
values ('c1300000-0000-4000-8000-000000000001', pg_temp.uid('a1'), pg_temp.mem('a1')::uuid, 'expense_added',
  'expense', 'c1320000-0000-4000-8000-000000000001',
  '{"description": "Dinner", "total": 120000, "currency": "INR", "recurring": true}');
select is((pg_temp.n('c1320000-0000-4000-8000-000000000001', 'a1')).body, '“Dinner” was added (recurring) · ₹1,200',
  'recurring copy reaches its creator');

-- ---------------------------------------------------------------- payments + comments
select pg_temp.as_user('b1');
select pg_temp.apply(pg_temp.m('20', 'payment', 'upsert', 'c1330000-0000-4000-8000-000000000001',
  pg_temp.pay('b1', 'a1', 5000)));
select is((pg_temp.n('c1330000-0000-4000-8000-000000000001', 'a1')).body, 'Bina paid you ₹50',
  'TC-19-01 payment text for the receiver');
select is((pg_temp.n('c1330000-0000-4000-8000-000000000001', 'a1')).kind, 'payments', 'kind payments');
select is((pg_temp.n('c1330000-0000-4000-8000-000000000001', 'a1')).data ->> 'target_type', 'payment', 'opens the payment');
select is(pg_temp.n_count('c1330000-0000-4000-8000-000000000001'), 1, 'the payer (actor) is not told');
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('21', 'payment', 'upsert', 'c1330000-0000-4000-8000-000000000002',
  pg_temp.pay('b1', 'a1', 1500)));
select is((pg_temp.n('c1330000-0000-4000-8000-000000000002', 'b1')).body, 'Asha recorded your payment of ₹15',
  'payment recorded by the receiver: the payer is told');

select pg_temp.as_user('b1');
select pg_temp.apply(pg_temp.m('22', 'comment', 'upsert', 'c1340000-0000-4000-8000-000000000001',
  '{"target_type": "expense", "target_id": "c1320000-0000-4000-8000-000000000002", "body": "Paid by card"}'));
select is((pg_temp.n('c1340000-0000-4000-8000-000000000001', 'a1')).body, 'Bina commented on “Taxi”: “Paid by card”',
  'comment text');
select is(pg_temp.n_count('c1340000-0000-4000-8000-000000000001'), 2, 'comment: the other participants (Asha, Dev)');
select is((pg_temp.n('c1340000-0000-4000-8000-000000000001', 'd1')).data ->> 'target_id',
  'c1320000-0000-4000-8000-000000000002', 'comment opens the commented expense');

-- ---------------------------------------------------------------- reminders (TC-23-01)
-- Bina owes Asha: 10000 (Taxi) + 1000 (Snacks) + 500 (Water) - 5000 - 1500 = 5000 (₹50).
select pg_temp.as_user('a1');
set local role authenticated;
select is(public.send_reminder('c1300000-0000-4000-8000-000000000001', pg_temp.mem('b1')::uuid) -> 'amounts',
  '{"INR": 5000}'::jsonb, 'TC-23-01 reminder carries what Bina owes Asha');
reset role;
select is((pg_temp.n(pg_temp.mem('b1'), 'b1')).body, 'Asha reminded you about ₹50 in “Goa trip”',
  'TC-23-01 reminder copy (08 #23)');
select is((pg_temp.n(pg_temp.mem('b1'), 'b1')).kind, 'reminders', 'kind reminders');
select is((pg_temp.n(pg_temp.mem('b1'), 'b1')).data ->> 'target_type', 'balances', 'reminder opens the balances');
select is(pg_temp.n_count(pg_temp.mem('b1')), 1, 'TC-23-01 only the reminded person is told');
select ok(exists (select 1 from public.activity where type = 'reminder_sent' and actor_member_id = pg_temp.mem('a1')::uuid
                    and data ->> 'to_member' = pg_temp.mem('b1') and data ->> 'amount' = '5000'
                    and data ->> 'currency' = 'INR'),
  'rule 9: the reminder is in the activity log');
set local role authenticated;
select is(pg_temp.err($$select public.send_reminder('c1300000-0000-4000-8000-000000000001',
  'c1310000-0000-4000-8000-0000000000b1')$$), 'REMINDER_THROTTLED', 'TC-23-01 second reminder within 24 h is throttled');
select is(pg_temp.err($$select public.send_reminder('c1300000-0000-4000-8000-000000000001',
  'c1310000-0000-4000-8000-0000000000e1')$$), 'NAME_ONLY_MEMBER', 'TC-23-01 name-only members cannot be reminded');
select is(pg_temp.err($$select public.send_reminder('c1300000-0000-4000-8000-000000000001',
  'c1310000-0000-4000-8000-0000000000a1')$$), 'CANNOT_REMIND_SELF', 'no reminding yourself');
select is(pg_temp.err($$select public.send_reminder('c1300000-0000-4000-8000-000000000001',
  'c1310000-0000-4000-8000-0000000000f1')$$), 'MEMBER_NOT_FOUND', 'unknown member');
reset role;
select pg_temp.as_user('b1');
set local role authenticated;
select is(pg_temp.err($$select public.send_reminder('c1300000-0000-4000-8000-000000000001',
  'c1310000-0000-4000-8000-0000000000a1')$$), 'NOTHING_OWED', 'cannot remind someone who owes you nothing');
reset role;
select pg_temp.as_user('c1');
set local role authenticated;
select is(pg_temp.err($$select public.send_reminder('c1300000-0000-4000-8000-000000000001',
  'c1310000-0000-4000-8000-0000000000b1')$$), 'NOT_MEMBER', 'non-members cannot remind');
reset role;
-- 25 h later the pair may remind again.
update public.activity set created_at = now() - interval '25 hours'
where type = 'reminder_sent' and actor_member_id = pg_temp.mem('a1')::uuid;
select pg_temp.as_user('a1');
set local role authenticated;
select is(public.send_reminder('c1300000-0000-4000-8000-000000000001', pg_temp.mem('d1')::uuid) ->> 'status', 'sent',
  'another pair is not throttled');
select is(public.send_reminder('c1300000-0000-4000-8000-000000000001', pg_temp.mem('b1')::uuid) ->> 'status', 'sent',
  'TC-23-01 after 24 h the reminder can be sent again');
reset role;

-- ---------------------------------------------------------------- groups kind, kinds without notifications
insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
values ('c1300000-0000-4000-8000-000000000001', pg_temp.uid('d1'), pg_temp.mem('d1')::uuid, 'member_joined',
  'member', pg_temp.mem('d1')::uuid, jsonb_build_object('member_id', pg_temp.mem('d1'), 'name', 'Dev'));
select is(pg_temp.n_count(pg_temp.mem('d1')), 2, 'groups kind: every other linked member (Asha, Bina)');
select is((pg_temp.n(pg_temp.mem('d1'), 'a1')).body, 'Dev joined the group', 'joined text');
insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
values ('c1300000-0000-4000-8000-000000000001', pg_temp.uid('a1'), pg_temp.mem('a1')::uuid, 'member_removed',
  'member', pg_temp.mem('d1')::uuid, jsonb_build_object('member_id', pg_temp.mem('d1'), 'name', 'Dev'));
select is((pg_temp.n(pg_temp.mem('d1'), 'd1')).body, 'Asha removed you from the group', 'removed person is told');
select is((pg_temp.n(pg_temp.mem('d1'), 'b1')).body, 'Asha removed Dev from the group', 'others are told');
insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
values ('c1300000-0000-4000-8000-000000000001', pg_temp.uid('a1'), pg_temp.mem('a1')::uuid, 'group_updated',
  'group', 'c1300000-0000-4000-8000-000000000001', '{"name": "Goa trip"}');
select is(pg_temp.n_count('c1300000-0000-4000-8000-000000000001'), 0, 'group_updated is not a notification kind');

-- No project URL: rows still appear, push is skipped.
update private.settings set value = '' where key = 'project_url';
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('15', 'expense', 'upsert', 'c1320000-0000-4000-8000-000000000005',
  pg_temp.exp('Fuel', 4000, 'a1', '{"a1": 2000, "b1": 2000}')));
select is((pg_temp.n('c1320000-0000-4000-8000-000000000005', 'b1')).push_status, 'skipped',
  'no project URL: push skipped, bell row kept');

-- ---------------------------------------------------------------- RLS: own rows only
select pg_temp.as_user('b1');
set local role authenticated;
select ok((select count(*) from public.notifications) > 0, 'Bina sees her notifications');
select is((select count(*)::int from public.notifications where user_id <> pg_temp.uid('b1')), 0,
  'TC-19-01 RLS: nobody else''s notifications');
select is(pg_temp.err($$insert into public.notifications (user_id, kind, type, title, body)
  values ('00000000-0000-4000-8000-0000000013b1', 'expenses', 'expense_added', 't', 'b')$$),
  'permission denied for table notifications', 'clients cannot insert notifications');
select is(pg_temp.err($$update public.notifications set read_at = now()$$),
  'permission denied for table notifications', 'clients cannot update notifications directly');
select is(pg_temp.err($$delete from public.notification_settings where true$$),
  'permission denied for table notification_settings', 'clients cannot delete settings');
reset role;
select pg_temp.as_user('c1');
set local role authenticated;
select is((select count(*)::int from public.notifications), 0, 'a non-member sees none');
select is((select count(*)::int from public.notification_settings), 1, 'own settings row only');
reset role;

-- ---------------------------------------------------------------- mark read
select pg_temp.as_user('b1');
set local role authenticated;
select is(public.mark_notifications_read(array[(pg_temp.n('c1330000-0000-4000-8000-000000000002', 'b1')).id]), 1,
  'mark one read');
select ok((pg_temp.n('c1330000-0000-4000-8000-000000000002', 'b1')).read_at is not null, 'it is read');
select ok(public.mark_notifications_read() > 0, 'mark all read');
select is((select count(*)::int from public.notifications where read_at is null), 0, 'nothing unread for Bina');
select is(public.mark_notifications_read(), 0, 'marking again changes nothing');
reset role;
select ok((select count(*) from public.notifications where user_id = pg_temp.uid('a1') and read_at is null) > 0,
  'Asha''s notifications stay unread');

-- ---------------------------------------------------------------- device tokens
select pg_temp.as_user('b1');
set local role authenticated;
select lives_ok($$select public.register_device('tok-ntf-1', '0.1.0+1')$$, 'register a device');
select is((select count(*)::int from public.device_tokens where token = 'tok-ntf-1'), 1, 'Bina sees her token');
select is(pg_temp.err($$select public.register_device('  ')$$), 'INVALID_TOKEN', 'empty token rejected');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select lives_ok($$select public.register_device('tok-ntf-1', '0.1.0+1')$$, 'same phone, other account');
reset role;
select is((select user_id from public.device_tokens where token = 'tok-ntf-1'), pg_temp.uid('a1'),
  'the token moved to the new account');
select pg_temp.as_user('b1');
set local role authenticated;
select is(public.unregister_device('tok-ntf-1'), false, 'cannot remove someone else''s token');
reset role;
select pg_temp.as_user('a1');
set local role authenticated;
select is(public.unregister_device('tok-ntf-1'), true, 'sign-out removes the token');
reset role;

-- ---------------------------------------------------------------- money text
select is(private.format_money(10000050, 'INR') || ' / ' || private.format_money(5, 'INR'), '₹1,00,000.50 / ₹0.05',
  'Indian grouping + fraction, short amounts padded');
select is(private.format_money(500, 'JPY') || ' / ' || private.format_money(1234567, 'KWD'), '¥500 / KD' || chr(160) || '1,234.567',
  'exponents 0 and 3, letter unit gets a no-break space');

select * from finish();
select num_failed(), _get('curr_test'), _get('plan');
rollback;
