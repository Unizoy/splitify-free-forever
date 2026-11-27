begin;
-- 0027 (final QA, S-406): a notification about a deleted expense or payment opens that expense / payment page
-- (Deleted + Restore), not the group; added / restored keep opening it; older rows in the bell are moved over.
select plan(10);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000027a1', 'del-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000027b1', 'del-b@splitify.test', '{"full_name": "Bina"}');

create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000027' || p || '","role":"authenticated"}', true);
$$;
create function pg_temp.uid(p text) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-0000000027' || p)::uuid;
$$;
create function pg_temp.mem(p text) returns text language sql immutable as $$
  select 'c2710000-0000-4000-8000-0000000000' || p;
$$;
create function pg_temp.m(p_mid text, p_entity text, p_op text, p_id text, p_data jsonb default '{}'::jsonb)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', 'c2750000-0000-4000-8000-0000000000' || p_mid, 'entity', p_entity, 'op', p_op, 'id', p_id,
    'group_id', 'c2700000-0000-4000-8000-000000000001', 'base_seq', null, 'client_updated_at', now(),
    'source', 'app', 'data', p_data);
$$;
create function pg_temp.apply(p jsonb) returns jsonb language sql as $$
  select public.apply_mutations(jsonb_build_array(p)) -> 'results' -> 0;
$$;
-- Bina's notification for the newest activity of type p_type.
create function pg_temp.n(p_type text) returns public.notifications language sql stable as $$
  select n.* from public.notifications n join public.activity a on a.id = n.activity_id
  where a.group_id = 'c2700000-0000-4000-8000-000000000001' and a.type = p_type
    and n.user_id = pg_temp.uid('b1')
  order by a.seq desc limit 1;
$$;

select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('01', 'group', 'upsert', 'c2700000-0000-4000-8000-000000000001',
  jsonb_build_object('name', 'Goa trip', 'type', 'trip',
    'owner_member', jsonb_build_object('id', pg_temp.mem('a1'), 'display_name', 'Asha'))));
select pg_temp.apply(pg_temp.m('02', 'member', 'upsert', pg_temp.mem('b1'), '{"display_name": "Bina", "position": 1}'));
update public.group_members set user_id = pg_temp.uid('b1') where id = pg_temp.mem('b1')::uuid;

-- Asha adds "Dinner" (Bina in the split), then deletes it, then restores it.
select pg_temp.apply(pg_temp.m('10', 'expense', 'upsert', 'c2720000-0000-4000-8000-000000000001',
  jsonb_build_object('description', 'Dinner', 'date', '2026-11-20', 'currency', 'INR', 'total', 60000,
    'split_kind', 'exact', 'payers', jsonb_build_object(pg_temp.mem('a1'), 60000),
    'shares', jsonb_build_object(pg_temp.mem('a1'), 30000, pg_temp.mem('b1'), 30000))));
select pg_temp.apply(pg_temp.m('11', 'expense', 'delete', 'c2720000-0000-4000-8000-000000000001'));
select is((pg_temp.n('expense_deleted')).body, 'Asha deleted “Dinner” · ₹600', 'deleted expense: the text is unchanged');
select is((pg_temp.n('expense_deleted')).data ->> 'target_type', 'expense', 'deleted expense opens the expense');
select is((pg_temp.n('expense_deleted')).data ->> 'target_id', 'c2720000-0000-4000-8000-000000000001',
  'deleted expense: its id');
select is((pg_temp.n('expense_deleted')).data ->> 'group_id', 'c2700000-0000-4000-8000-000000000001',
  'the group id stays in the data');
select pg_temp.apply(pg_temp.m('12', 'expense', 'restore', 'c2720000-0000-4000-8000-000000000001'));
select is((pg_temp.n('expense_restored')).data ->> 'target_type', 'expense', 'restored expense still opens the expense');

-- Bina paid Asha ₹100; Asha deletes the payment: Bina's bell row opens the payment.
select pg_temp.as_user('b1');
select pg_temp.apply(pg_temp.m('20', 'payment', 'upsert', 'c2730000-0000-4000-8000-000000000001',
  jsonb_build_object('from_member', pg_temp.mem('b1'), 'to_member', pg_temp.mem('a1'), 'amount', 10000,
    'currency', 'INR', 'date', '2026-11-21')));
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('21', 'payment', 'delete', 'c2730000-0000-4000-8000-000000000001'));
select is((pg_temp.n('payment_deleted')).body, 'Asha deleted a payment · ₹100', 'deleted payment: the text is unchanged');
select is((pg_temp.n('payment_deleted')).data ->> 'target_type', 'payment', 'deleted payment opens the payment');
select is((pg_temp.n('payment_deleted')).data ->> 'target_id', 'c2730000-0000-4000-8000-000000000001',
  'deleted payment: its id');

-- An older row (written before 0027 pointed at the group) is moved over by the same update the migration runs.
update public.notifications set data = data || jsonb_build_object('target_type', 'group',
  'target_id', 'c2700000-0000-4000-8000-000000000001')
where id = (pg_temp.n('expense_deleted')).id;
update public.notifications n
set data = n.data || jsonb_build_object('target_type', a.target_type, 'target_id', a.target_id)
from public.activity a
where a.id = n.activity_id
  and a.type in ('expense_deleted', 'payment_deleted')
  and a.target_type in ('expense', 'payment')
  and a.target_id is not null
  and n.data ->> 'target_type' = 'group';
select is((pg_temp.n('expense_deleted')).data ->> 'target_type', 'expense', 'an older row now opens the expense');
select is((pg_temp.n('expense_deleted')).data ->> 'target_id', 'c2720000-0000-4000-8000-000000000001',
  'an older row: the expense id');

select * from finish();
rollback;
