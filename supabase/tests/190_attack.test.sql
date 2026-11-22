-- Attack tests (phase 19, T1 security; planning/03-backend.md §3, rule 7). A malicious signed-in user (x1: owner of
-- groups G2/G3/G7, member of nothing else), a stranger without groups (z1), a left member (l1), an anonymous caller
-- and a brute-forcer (r1) try to read or change the data of group G1 (owner a1, linked member a2) and of other users:
--   * non-member writes/reads through every public RPC and apply_mutations / pull_changes, forged member ids,
--     forged created_by, moving records between groups, claiming linked members, the join rate limit,
--   * direct table access with the authenticated and anon roles, Storage path tricks,
--   * oversized or absurd payloads.
-- Needs migration 0022 (payload limits, member/device caps, Storage path policies).
begin;
select plan(288);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'atk-a1@splitify.test'),
  ('00000000-0000-4000-8000-0000000000a2', 'atk-a2@splitify.test'),
  ('00000000-0000-4000-8000-0000000000b1', 'atk-x1@splitify.test'),
  ('00000000-0000-4000-8000-0000000000b2', 'atk-w1@splitify.test'),
  ('00000000-0000-4000-8000-0000000000c1', 'atk-z1@splitify.test'),
  ('00000000-0000-4000-8000-0000000000d1', 'atk-l1@splitify.test'),
  ('00000000-0000-4000-8000-0000000000e1', 'atk-r1@splitify.test');

-- ------------------------------------------------------------------ helpers (temp, dropped with the session)

create function pg_temp.as_user(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000000' || p || '","role":"authenticated"}', true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('role', 'anon', true);
end $$;
create function pg_temp.as_nobody() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"authenticated"}', true);
  perform set_config('role', 'authenticated', true);
end $$;

-- 'OK' or the error message (an RPC's business code, or the Postgres message).
create function pg_temp.err(q text) returns text language plpgsql as $$
begin execute q; return 'OK'; exception when others then return sqlerrm; end $$;
create function pg_temp.denied(q text) returns boolean language plpgsql as $$
begin execute q; return false; exception when insufficient_privilege then return true; when others then return false; end $$;
create function pg_temp.writes_denied(t text, c text) returns boolean language plpgsql as $$
begin
  return pg_temp.denied(format('insert into public.%I default values', t))
     and pg_temp.denied(format('update public.%I set %I = %I where false', t, c, c))
     and pg_temp.denied(format('delete from public.%I where false', t));
end $$;
create function pg_temp.reads_denied(t text) returns boolean language plpgsql as $$
begin return pg_temp.denied(format('select count(*) from public.%I', t)); end $$;
create function pg_temp.cnt(q text) returns bigint language plpgsql as $$
declare n bigint;
begin execute q into n; return n; exception when others then return 0; end $$;

-- One mutation through apply_mutations: the result code ('applied', 'rejected' -> its code, ...).
create function pg_temp.ap(p_entity text, p_op text, p_id text, p_group text, p_data jsonb default '{}'::jsonb)
returns text language sql as $$
  select coalesce(r ->> 'code', r ->> 'status')
  from (select public.apply_mutations(jsonb_build_array(jsonb_build_object(
    'mutation_id', gen_random_uuid(), 'entity', p_entity, 'op', p_op, 'id', p_id, 'group_id', p_group,
    'client_updated_at', now(), 'source', 'app', 'data', p_data))) -> 'results' -> 0 as r) s;
$$;
-- Valid payloads for the attacker's own group G2 (members x1 and w1).
create function pg_temp.exp(p jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select '{"description": "Lunch", "date": "2026-11-01", "currency": "INR", "total": 1000,
           "payers": {"20000000-0000-4000-8000-0000000000b1": 1000}, "shares": {"20000000-0000-4000-8000-0000000000b1": 500, "20000000-0000-4000-8000-0000000000b2": 500}}'::jsonb || p;
$$;
create function pg_temp.pay(p jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select '{"from_member": "20000000-0000-4000-8000-0000000000b2", "to_member": "20000000-0000-4000-8000-0000000000b1", "amount": 100, "currency": "INR",
           "date": "2026-11-01"}'::jsonb || p;
$$;
create function pg_temp.rec(p jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('interval', 'monthly', 'anchor_date', '2026-12-01',
                            'template', pg_temp.exp()) || p;
$$;
create function pg_temp.code(g text) returns text language sql stable as $$
  select invite_code from public.groups where id = g::uuid;
$$;

-- ------------------------------------------------------------------ arrangement (as postgres)

insert into public.groups (id, name, type, invite_code, created_by, deleted_at) values
  ('10000000-0000-4000-8000-000000000001', 'Victim group', 'home', 'K9K9K9K9', '00000000-0000-4000-8000-0000000000a1', null),
  ('10000000-0000-4000-8000-000000000002', 'Attacker group', 'other', 'M8M8M8M8', '00000000-0000-4000-8000-0000000000b1', null),
  ('10000000-0000-4000-8000-000000000003', 'Attacker group two', 'other', 'Q7Q7Q7Q7', '00000000-0000-4000-8000-0000000000b1', null),
  ('10000000-0000-4000-8000-000000000004', 'Direct pair', 'direct', 'P7P7P7P7', '00000000-0000-4000-8000-0000000000a1', null),
  ('10000000-0000-4000-8000-000000000005', 'Deleted group', 'other', 'DEAD0000', '00000000-0000-4000-8000-0000000000a1', now()),
  ('10000000-0000-4000-8000-000000000007', 'Crowded group', 'other', 'C0C0C0C0', '00000000-0000-4000-8000-0000000000b1', null);
insert into public.group_members (id, group_id, user_id, display_name, position, status, role) values
  ('20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000a1', 'Asha', 0, 'active', 'owner'),
  ('20000000-0000-4000-8000-0000000000a2', '10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000a2', 'Bina', 1, 'active', 'member'),
  ('20000000-0000-4000-8000-0000000000a3', '10000000-0000-4000-8000-000000000001', null, 'Name Only', 2, 'active', 'member'),
  ('20000000-0000-4000-8000-0000000000a4', '10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000d1', 'Left One', 3, 'left', 'member'),
  ('20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000b1', 'Xavier', 0, 'active', 'owner'),
  ('20000000-0000-4000-8000-0000000000b2', '10000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000b2', 'Wanda', 1, 'active', 'member'),
  ('20000000-0000-4000-8000-0000000000b3', '10000000-0000-4000-8000-000000000002', null, 'Xavier friend', 2, 'active', 'member'),
  ('20000000-0000-4000-8000-0000000000c1', '10000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-0000000000b1', 'Xavier', 0, 'active', 'owner'),
  ('20000000-0000-4000-8000-0000000000d1', '10000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-0000000000a1', 'Asha', 0, 'active', 'owner'),
  ('20000000-0000-4000-8000-0000000000d2', '10000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-0000000000a2', 'Bina', 1, 'active', 'member');
insert into public.group_members (id, group_id, user_id, display_name, position)
  select ('21000000-0000-4000-8000-' || lpad(to_hex(i), 12, '0'))::uuid, '10000000-0000-4000-8000-000000000007',
       case when i = 0 then '00000000-0000-4000-8000-0000000000b1'::uuid end, 'Crowd ' || i, i
from generate_series(0, 99) i;
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares, created_by) values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Victim dinner', '2026-11-01', 'INR', 10000, '{"20000000-0000-4000-8000-0000000000a1": 10000}',
   '{"20000000-0000-4000-8000-0000000000a1": 5000, "20000000-0000-4000-8000-0000000000a2": 5000}', '00000000-0000-4000-8000-0000000000a1'),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'Attacker lunch', '2026-11-01', 'INR', 1000, '{"20000000-0000-4000-8000-0000000000b1": 1000}',
   '{"20000000-0000-4000-8000-0000000000b1": 500, "20000000-0000-4000-8000-0000000000b2": 500}', '00000000-0000-4000-8000-0000000000b1');
insert into public.payments (id, group_id, from_member, to_member, amount, currency, date, created_by) values
  ('40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-0000000000a2', '20000000-0000-4000-8000-0000000000a1', 100, 'INR', '2026-11-01', '00000000-0000-4000-8000-0000000000a2');
insert into public.comments (id, group_id, target_type, target_id, body, created_by) values
  ('60000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'expense', '30000000-0000-4000-8000-000000000001', 'victim comment', '00000000-0000-4000-8000-0000000000a1');
insert into public.recurring_templates (id, group_id, "interval", anchor_date, next_date, template, created_by) values
  ('70000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'monthly', '2026-12-01', '2026-12-01',
   '{"description": "Rent", "currency": "INR", "total": 100, "payers": {"20000000-0000-4000-8000-0000000000a1": 100}, "shares": {"20000000-0000-4000-8000-0000000000a1": 100}}',
   '00000000-0000-4000-8000-0000000000a1');
insert into public.activity (group_id, type, data) values ('10000000-0000-4000-8000-000000000001', 'group_updated', '{"name": "Victim group"}');
insert into public.record_versions (table_name, record_id, group_id, op, snapshot) values
  ('groups', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'insert', '{"name": "Victim group"}');
insert into public.notifications (id, user_id, group_id, kind, type, title, body) values
  ('80000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000001', 'expenses', 'expense_added', 'Victim title', 'Victim body');
insert into public.notification_settings (user_id, kinds) values ('00000000-0000-4000-8000-0000000000a1', '{"expenses": {"push": false}}');
insert into public.device_tokens (user_id, token) values ('00000000-0000-4000-8000-0000000000a1', 'tok-victim-a1');
update public.profiles set display_name = 'Victim', upi_id = 'victim@okbank' where id = '00000000-0000-4000-8000-0000000000a1';
insert into storage.objects (bucket_id, name) values
  ('receipts', '10000000-0000-4000-8000-000000000001/30000000-0000-4000-8000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.jpg'),
  ('group-covers', '10000000-0000-4000-8000-000000000001/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb.jpg'),
  ('avatars', '00000000-0000-4000-8000-0000000000a1/cccccccc-cccc-4ccc-8ccc-cccccccccccc.jpg'),
  ('receipts', '10000000-0000-4000-8000-000000000002/own1.jpg'),
  ('avatars', '00000000-0000-4000-8000-0000000000b1/own.jpg');

-- ================================================================== 1. non-member writes through apply_mutations
select pg_temp.as_user('b1');

select is(pg_temp.ap('group', 'upsert', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '{"name": "Hacked"}'), 'NOT_MEMBER',
  'x1 cannot rename the victim group');
select is(pg_temp.ap('group', 'delete', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001'), 'NOT_MEMBER', 'x1 cannot delete the victim group');
select is(pg_temp.ap('group', 'restore', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001'), 'NOT_MEMBER', 'x1 cannot restore the victim group');
select is(pg_temp.ap('member', 'upsert', 'f0000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '{"display_name": "Evil", "position": 9}'), 'NOT_MEMBER',
  'x1 cannot add a member to the victim group');
select is(pg_temp.ap('member', 'upsert', '20000000-0000-4000-8000-0000000000a3', '10000000-0000-4000-8000-000000000001', '{"display_name": "Renamed"}'), 'NOT_MEMBER',
  'x1 cannot rename a victim member');
select is(pg_temp.ap('member', 'delete', '20000000-0000-4000-8000-0000000000a3', '10000000-0000-4000-8000-000000000001'), 'NOT_MEMBER', 'x1 cannot delete a victim member');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001',
  '{"description": "Evil", "date": "2026-11-01", "currency": "INR", "total": 100,
    "payers": {"20000000-0000-4000-8000-0000000000a1": 100}, "shares": {"20000000-0000-4000-8000-0000000000a1": 100}}'), 'NOT_MEMBER',
  'x1 cannot add an expense to the victim group');
select is(pg_temp.ap('expense', 'upsert', '30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '{"description": "Hacked", "total": 1}'), 'NOT_MEMBER',
  'x1 cannot edit a victim expense');
select is(pg_temp.ap('expense', 'delete', '30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001'), 'NOT_MEMBER', 'x1 cannot delete a victim expense');
select is(pg_temp.ap('expense', 'restore', '30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001'), 'NOT_MEMBER', 'x1 cannot restore a victim expense');
select is(pg_temp.ap('payment', 'upsert', 'f0000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001',
  '{"from_member": "20000000-0000-4000-8000-0000000000a2", "to_member": "20000000-0000-4000-8000-0000000000a1", "amount": 5, "currency": "INR", "date": "2026-11-01"}'),
  'NOT_MEMBER', 'x1 cannot add a payment to the victim group');
select is(pg_temp.ap('payment', 'upsert', '40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '{"amount": 99999}'), 'NOT_MEMBER',
  'x1 cannot edit a victim payment');
select is(pg_temp.ap('payment', 'delete', '40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001'), 'NOT_MEMBER', 'x1 cannot delete a victim payment');
select is(pg_temp.ap('comment', 'upsert', 'f0000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001',
  '{"target_type": "expense", "target_id": "30000000-0000-4000-8000-000000000001", "body": "spam"}'), 'NOT_MEMBER',
  'x1 cannot comment in the victim group');
select is(pg_temp.ap('comment', 'upsert', '60000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '{"body": "hacked"}'), 'NOT_MEMBER',
  'x1 cannot edit a victim comment');
select is(pg_temp.ap('comment', 'delete', '60000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001'), 'NOT_MEMBER', 'x1 cannot delete a victim comment');
select is(pg_temp.ap('recurring', 'upsert', 'f0000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000001',
  jsonb_build_object('interval', 'monthly', 'anchor_date', '2026-12-01', 'template',
    '{"description": "Evil", "currency": "INR", "total": 100, "payers": {"20000000-0000-4000-8000-0000000000a1": 100},
      "shares": {"20000000-0000-4000-8000-0000000000a1": 100}}'::jsonb)), 'NOT_MEMBER', 'x1 cannot add a recurring bill to the victim group');
select is(pg_temp.ap('recurring', 'upsert', '70000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '{"active": false}'), 'NOT_MEMBER',
  'x1 cannot stop a victim recurring bill');
select is(pg_temp.ap('recurring', 'delete', '70000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001'), 'NOT_MEMBER',
  'x1 cannot delete a victim recurring bill');

reset role;
select ok(
  (select name = 'Victim group' and deleted_at is null from public.groups where id = '10000000-0000-4000-8000-000000000001')
  and (select description = 'Victim dinner' and total = 10000 and deleted_at is null
       from public.expenses where id = '30000000-0000-4000-8000-000000000001')
  and (select amount = 100 and deleted_at is null from public.payments where id = '40000000-0000-4000-8000-000000000001')
  and (select body = 'victim comment' and deleted_at is null from public.comments where id = '60000000-0000-4000-8000-000000000001')
  and (select active and deleted_at is null from public.recurring_templates where id = '70000000-0000-4000-8000-000000000001')
  and (select display_name = 'Name Only' and deleted_at is null from public.group_members where id = '20000000-0000-4000-8000-0000000000a3')
  and not exists (select 1 from public.group_members where id = 'f0000000-0000-4000-8000-000000000001')
  and not exists (select 1 from public.expenses where id = 'f0000000-0000-4000-8000-000000000002')
  and not exists (select 1 from public.payments where id = 'f0000000-0000-4000-8000-000000000003')
  and not exists (select 1 from public.comments where id = 'f0000000-0000-4000-8000-000000000004')
  and not exists (select 1 from public.recurring_templates where id = 'f0000000-0000-4000-8000-000000000005'),
  'none of the rejected attacks changed or created anything in the victim group');

-- ================================================================== 2. cross-group ids and forged member ids
select pg_temp.as_user('b1');

select is(pg_temp.ap('expense', 'upsert', '30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', pg_temp.exp()), 'ID_CONFLICT',
  'a victim expense id sent with my group id is an ID_CONFLICT (no takeover)');
select is(pg_temp.ap('payment', 'upsert', '40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', pg_temp.pay()), 'ID_CONFLICT',
  'a victim payment id sent with my group id is an ID_CONFLICT');
select is(pg_temp.ap('comment', 'upsert', '60000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', '{"body": "mine now"}'), 'ID_CONFLICT',
  'a victim comment id sent with my group id is an ID_CONFLICT');
select is(pg_temp.ap('member', 'upsert', '20000000-0000-4000-8000-0000000000a3', '10000000-0000-4000-8000-000000000002', '{"display_name": "mine now"}'), 'ID_CONFLICT',
  'a victim member id sent with my group id is an ID_CONFLICT');
select is(pg_temp.ap('member', 'upsert', '20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000002', '{"display_name": "mine now"}'), 'ID_CONFLICT',
  'a victim linked member id sent with my group id is an ID_CONFLICT');
select is(pg_temp.ap('recurring', 'upsert', '70000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', pg_temp.rec()), 'ID_CONFLICT',
  'a victim recurring id sent with my group id is an ID_CONFLICT');
select is(pg_temp.ap('group', 'upsert', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', '{"name": "mine now"}'), 'INVALID_MUTATION',
  'a group mutation whose id differs from its group id is invalid');
select is(pg_temp.ap('expense', 'upsert', '30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000003', pg_temp.exp()), 'ID_CONFLICT',
  'moving my expense to my other group by changing group_id is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000010', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"payers": {"20000000-0000-4000-8000-0000000000a1": 1000}}')), 'FOREIGN_MEMBER', 'a payer from another group is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000010', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"shares": {"20000000-0000-4000-8000-0000000000b1": 500, "20000000-0000-4000-8000-0000000000a2": 500}}')), 'FOREIGN_MEMBER',
  'a share holder from another group is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000010', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"payers": {"not-a-uuid": 1000}}')), 'FOREIGN_MEMBER', 'a payer key that is no uuid is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000010', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"payers": {"20000000-0000-4000-8000-0000000000b1": 1000, "20000000-0000-4000-8000-0000000000b1x": 0}}')), 'FOREIGN_MEMBER',
  'a malformed payer key (uuid plus suffix) is refused');
select is(pg_temp.ap('payment', 'upsert', 'f0000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000002', pg_temp.pay('{"to_member": "20000000-0000-4000-8000-0000000000a1"}')), 'FOREIGN_MEMBER',
  'a payment to a member of another group is refused');
select is(pg_temp.ap('payment', 'upsert', 'f0000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000002', pg_temp.pay('{"from_member": "20000000-0000-4000-8000-0000000000a2"}')), 'FOREIGN_MEMBER',
  'a payment from a member of another group is refused');
select is(pg_temp.ap('recurring', 'upsert', 'f0000000-0000-4000-8000-000000000012', '10000000-0000-4000-8000-000000000002',
  jsonb_build_object('interval', 'monthly', 'anchor_date', '2026-12-01',
    'template', pg_temp.exp('{"payers": {"20000000-0000-4000-8000-0000000000a1": 1000}}'))), 'FOREIGN_MEMBER',
  'a recurring template with a payer from another group is refused');
select is(pg_temp.ap('recurring', 'upsert', 'f0000000-0000-4000-8000-000000000012', '10000000-0000-4000-8000-000000000002',
  jsonb_build_object('interval', 'monthly', 'anchor_date', '2026-12-01',
    'template', pg_temp.exp('{"shares": {"20000000-0000-4000-8000-0000000000a1": 500, "20000000-0000-4000-8000-0000000000b1": 500}}'))), 'FOREIGN_MEMBER',
  'a recurring template with a share holder from another group is refused');
select is(pg_temp.ap('comment', 'upsert', 'f0000000-0000-4000-8000-000000000013', '10000000-0000-4000-8000-000000000002',
  '{"target_type": "expense", "target_id": "30000000-0000-4000-8000-000000000001", "body": "peek"}'), 'TARGET_NOT_FOUND',
  'a comment in my group cannot target an expense of the victim group');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000014', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"receipt_path": "10000000-0000-4000-8000-000000000001/f0000000-0000-4000-8000-000000000014/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.jpg"}')), 'INVALID_RECEIPT_PATH',
  'a receipt path in the victim group folder is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000014', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"receipt_path": "10000000-0000-4000-8000-000000000002/../10000000-0000-4000-8000-000000000001/30000000-0000-4000-8000-000000000001/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.jpg"}')),
  'INVALID_RECEIPT_PATH', 'a receipt path with ../ is refused');
select is(pg_temp.ap('group', 'upsert', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002',
  '{"cover_kind": "photo", "cover_path": "10000000-0000-4000-8000-000000000001/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb.jpg"}'), 'INVALID_COVER_PATH',
  'a group cover in the victim group folder is refused');

-- Groups created through sync cannot reuse a victim member id as their owner member.
select is(pg_temp.ap('group', 'upsert', 'f0000000-0000-4000-8000-000000000015', 'f0000000-0000-4000-8000-000000000015',
  '{"name": "Steal", "owner_member": {"id": "20000000-0000-4000-8000-0000000000a1", "display_name": "Asha"}}'), 'DUPLICATE',
  'a new group cannot use a victim member id as its owner member');
reset role;
select ok(not exists (select 1 from public.groups where id = 'f0000000-0000-4000-8000-000000000015')
  and (select group_id = '10000000-0000-4000-8000-000000000001' and user_id = '00000000-0000-4000-8000-0000000000a1' from public.group_members where id = '20000000-0000-4000-8000-0000000000a1'),
  'the refused group was rolled back and the victim member is untouched');

select pg_temp.as_user('b1');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000016', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"created_by": "00000000-0000-4000-8000-0000000000a1", "updated_by": "00000000-0000-4000-8000-0000000000a1", "deleted_by": "00000000-0000-4000-8000-0000000000a1", "seq": 0, "group_id": "10000000-0000-4000-8000-000000000001",
                "id": "30000000-0000-4000-8000-000000000001", "source": "recurring", "recurring_id": "70000000-0000-4000-8000-000000000001", "deleted_at": "2020-01-01"}')),
  'applied', 'extra system keys in an expense payload are ignored, the expense is created');
select is(pg_temp.ap('member', 'upsert', 'f0000000-0000-4000-8000-000000000017', '10000000-0000-4000-8000-000000000002',
  '{"display_name": "Friend", "position": 7, "user_id": "00000000-0000-4000-8000-0000000000a1", "role": "owner", "status": "active",
    "claimed_at": "2020-01-01"}'), 'applied', 'extra system keys in a member payload are ignored');
select is(pg_temp.ap('group', 'upsert', 'f0000000-0000-4000-8000-000000000018', 'f0000000-0000-4000-8000-000000000018',
  '{"name": "Mine", "created_by": "00000000-0000-4000-8000-0000000000a1", "invite_code": "HACKED00", "direct_key": "x:y", "deleted_at": "2020-01-01"}'),
  'applied', 'extra system keys in a group payload are ignored');
reset role;
select ok(
  (select e.created_by = '00000000-0000-4000-8000-0000000000b1' and e.updated_by = '00000000-0000-4000-8000-0000000000b1' and e.deleted_by is null and e.deleted_at is null
          and e.group_id = '10000000-0000-4000-8000-000000000002' and e.source = 'app' and e.recurring_id is null
   from public.expenses e where e.id = 'f0000000-0000-4000-8000-000000000016')
  and (select e.total = 10000 from public.expenses e where e.id = '30000000-0000-4000-8000-000000000001'),
  'created_by, group, source and recurring_id of the new expense are the server''s, the victim expense is untouched');
select ok(
  (select a.actor_user_id = '00000000-0000-4000-8000-0000000000b1' and a.actor_member_id = '20000000-0000-4000-8000-0000000000b1' and a.group_id = '10000000-0000-4000-8000-000000000002'
   from public.activity a where a.target_id = 'f0000000-0000-4000-8000-000000000016' and a.type = 'expense_added'),
  'the activity row names the real caller as actor, not a forged one');
select ok(
  (select m.user_id is null and m.role = 'member' and m.status = 'active' and m.claimed_at is null
   from public.group_members m where m.id = 'f0000000-0000-4000-8000-000000000017'),
  'a client-made member is never linked to an account and never an owner');
select ok(
  (select g.created_by = '00000000-0000-4000-8000-0000000000b1' and g.invite_code <> 'HACKED00' and g.direct_key is null and g.deleted_at is null
   from public.groups g where g.id = 'f0000000-0000-4000-8000-000000000018'),
  'a client-made group gets a server invite code and the real creator');
select throws_ok(
  $$ update public.expenses set group_id = '10000000-0000-4000-8000-000000000003' where id = '30000000-0000-4000-8000-000000000002' $$,
  'P0001', 'GROUP_CHANGE_NOT_ALLOWED', 'the database refuses moving an expense to another group');
select throws_ok(
  $$ update public.comments set group_id = '10000000-0000-4000-8000-000000000002' where id = '60000000-0000-4000-8000-000000000001' $$,
  'P0001', 'GROUP_CHANGE_NOT_ALLOWED', 'the database refuses moving a comment to another group');
select throws_ok(
  $$ update public.payments set group_id = '10000000-0000-4000-8000-000000000002' where id = '40000000-0000-4000-8000-000000000001' $$,
  'P0001', 'GROUP_CHANGE_NOT_ALLOWED', 'the database refuses moving a payment to another group');

-- Inside my own group: author-only comments, creator-only group delete, linked members only leave via RPC.
select pg_temp.as_user('b1');
select is(pg_temp.ap('comment', 'upsert', 'f0000000-0000-4000-8000-000000000019', '10000000-0000-4000-8000-000000000002',
  '{"target_type": "expense", "target_id": "30000000-0000-4000-8000-000000000002", "body": "mine"}'), 'applied', 'x1 comments in his own group');
select pg_temp.as_user('b2');
select is(pg_temp.ap('comment', 'upsert', 'f0000000-0000-4000-8000-000000000019', '10000000-0000-4000-8000-000000000002', '{"body": "edited by w1"}'), 'NOT_AUTHOR',
  'another member cannot edit my comment');
select is(pg_temp.ap('comment', 'delete', 'f0000000-0000-4000-8000-000000000019', '10000000-0000-4000-8000-000000000002'), 'NOT_AUTHOR', 'another member cannot delete my comment');
select is(pg_temp.ap('group', 'delete', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002'), 'NOT_CREATOR', 'a non-creator member cannot delete the group');
select is(pg_temp.ap('member', 'delete', '20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000002'), 'MEMBER_LINKED',
  'a linked member cannot be deleted through sync');
select pg_temp.as_user('d1');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000020', '10000000-0000-4000-8000-000000000001',
  '{"description": "Evil", "date": "2026-11-01", "currency": "INR", "total": 100,
    "payers": {"20000000-0000-4000-8000-0000000000a1": 100}, "shares": {"20000000-0000-4000-8000-0000000000a1": 100}}'), 'NOT_MEMBER',
  'a member who left cannot add expenses');

-- ================================================================== 3. pull_changes / balances / overview
select pg_temp.as_user('b1');
select ok(
  not (public.pull_changes('{}'::jsonb, 0)::text like '%10000000-0000-4000-8000-000000000001%')
  and not (public.pull_changes('{}'::jsonb, 0)::text like '%30000000-0000-4000-8000-000000000001%')
  and not (public.pull_changes('{}'::jsonb, 0)::text like '%Victim%'),
  'pull_changes returns nothing of the victim group to x1');
select ok(
  not ((public.pull_changes(jsonb_build_object('10000000-0000-4000-8000-000000000001', 0), 0) -> 'rows')::text like '%30000000-0000-4000-8000-000000000001%')
  and (public.pull_changes(jsonb_build_object('10000000-0000-4000-8000-000000000001', 0), 0) -> 'lost_groups') @> '["10000000-0000-4000-8000-000000000001"]'::jsonb,
  'a cursor for the victim group returns no rows and reports it as lost');
select ok(not ((public.pull_changes('{}'::jsonb, 0) -> 'rows' -> 'profiles')::text like '%00000000-0000-4000-8000-0000000000a1%'),
  'pull_changes returns no profile of a user x1 shares no group with');
select is(pg_temp.err($$ select public.pull_changes('[1,2]'::jsonb, -5, -1) $$), 'OK',
  'garbage cursors, a negative since and a negative page size do not break pull_changes');
select is(pg_temp.err($$ select public.pull_changes('{"10000000-0000-4000-8000-000000000002": "x", "zzz": 1}'::jsonb, 0, 2000000000) $$), 'OK',
  'non-numeric cursors and a huge page size do not break pull_changes');
select pg_temp.as_user('c1');
select ok(
  (select bool_and(jsonb_array_length(v) = 0) from jsonb_each(public.pull_changes('{}'::jsonb, 0) -> 'rows') e(k, v)
   where k <> 'profiles'),
  'a user without groups pulls no rows at all');
select pg_temp.as_user('d1');
select ok(
  not (public.pull_changes(jsonb_build_object('10000000-0000-4000-8000-000000000001', 0), 0)::text like '%30000000-0000-4000-8000-000000000001%'),
  'a member who left no longer pulls the group');
select pg_temp.as_user('b1');
select is(pg_temp.err($$ select public.group_balances('10000000-0000-4000-8000-000000000001') $$), 'NOT_MEMBER', 'group_balances refuses a non-member');
select is(pg_temp.err($$ select public.group_balances(gen_random_uuid()) $$), 'NOT_MEMBER',
  'group_balances does not reveal whether a group id exists');
select ok(not (public.my_overview()::text like '%10000000-0000-4000-8000-000000000001%') and public.my_overview()::text like '%10000000-0000-4000-8000-000000000002%',
  'my_overview lists my groups and never the victim group');
select pg_temp.as_user('d1');
select is(pg_temp.err($$ select public.group_balances('10000000-0000-4000-8000-000000000001') $$), 'NOT_MEMBER',
  'group_balances refuses a member who left');
select ok(not (public.my_overview()::text like '%10000000-0000-4000-8000-000000000001%'), 'my_overview omits a group the user left');

-- ================================================================== 4. no / anonymous session
select pg_temp.as_nobody();
select is(pg_temp.err($$ select public.apply_mutations('[]') $$), 'NOT_AUTHENTICATED',
  'apply_mutations needs a signed-in user');
select is(pg_temp.err($$ select public.pull_changes() $$), 'NOT_AUTHENTICATED', 'pull_changes needs a signed-in user');
select is(pg_temp.err($$ select public.group_balances('10000000-0000-4000-8000-000000000001') $$), 'NOT_AUTHENTICATED',
  'group_balances needs a signed-in user');
select is(pg_temp.err($$ select public.my_overview() $$), 'NOT_AUTHENTICATED', 'my_overview needs a signed-in user');
select is(pg_temp.err($$ select public.preview_join('K9K9K9K9') $$), 'NOT_AUTHENTICATED',
  'preview_join needs a signed-in user');
select is(pg_temp.err($$ select public.join_group('K9K9K9K9') $$), 'NOT_AUTHENTICATED',
  'join_group needs a signed-in user');
select is(pg_temp.err($$ select public.rotate_invite_code('10000000-0000-4000-8000-000000000001') $$), 'NOT_AUTHENTICATED',
  'rotate_invite_code needs a signed-in user');
select is(pg_temp.err($$ select public.leave_group('10000000-0000-4000-8000-000000000001') $$), 'NOT_AUTHENTICATED', 'leave_group needs a signed-in user');
select is(pg_temp.err($$ select public.send_reminder('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-0000000000a2') $$), 'NOT_AUTHENTICATED',
  'send_reminder needs a signed-in user');
select is(pg_temp.err($$ select public.mark_notifications_read() $$), 'NOT_AUTHENTICATED',
  'mark_notifications_read needs a signed-in user');
select is(pg_temp.err($$ select public.register_device('tok') $$), 'NOT_AUTHENTICATED',
  'register_device needs a signed-in user');
select is(pg_temp.err($$ select public.update_profile('Nobody', null, 'INR', null) $$), 'NOT_AUTHENTICATED',
  'update_profile needs a signed-in user');
select is(pg_temp.err($$ select public.prepare_account_deletion() $$), 'NOT_AUTHENTICATED',
  'prepare_account_deletion needs a signed-in user');
select is(pg_temp.err($$ select public.find_or_create_direct_group('00000000-0000-4000-8000-0000000000a1') $$), 'NOT_AUTHENTICATED',
  'find_or_create_direct_group needs a signed-in user');
reset role;
select ok(
  not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname in ('public', 'private', 'money') and has_function_privilege('anon', p.oid, 'execute')),
  'the anon role can execute no function of the public, private or money schema');
select is(
  (select array_agg(p.proname::text order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('private', 'money') and has_function_privilege('authenticated', p.oid, 'execute')),
  array['is_member', 'shares_group', 'try_uuid'],
  'signed-in users can execute only the three RLS helper functions of the private and money schemas');
select ok(
  not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname in ('public', 'private', 'money') and p.prosecdef
                and (p.proconfig is null
                     or not exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%'))),
  'every security definer function pins its search_path');

-- ================================================================== 5. group RPCs as a non-member
select pg_temp.as_user('b1');
select is(pg_temp.err($$ select public.leave_group('10000000-0000-4000-8000-000000000001') $$), 'NOT_MEMBER', 'x1 cannot leave (touch) the victim group');
select is(pg_temp.err($$ select public.leave_group(gen_random_uuid()) $$), 'NOT_MEMBER',
  'leave_group on an unknown group is NOT_MEMBER');
select is(pg_temp.err($$ select public.remove_member('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-0000000000a2') $$), 'NOT_MEMBER',
  'x1 cannot remove a victim member');
select is(pg_temp.err($$ select public.remove_member('10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-0000000000a2') $$), 'MEMBER_NOT_FOUND',
  'x1 cannot remove a victim member by naming his own group');
select is(pg_temp.err($$ select public.unlink_member('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-0000000000a2') $$), 'NOT_MEMBER',
  'x1 cannot unlink a victim member');
select is(pg_temp.err($$ select public.unlink_member('10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-0000000000a2') $$), 'MEMBER_NOT_FOUND',
  'x1 cannot unlink a victim member by naming his own group');
select is(pg_temp.err($$ select public.rotate_invite_code('10000000-0000-4000-8000-000000000001') $$), 'NOT_MEMBER',
  'x1 cannot rotate the victim invite code');
select is(pg_temp.err($$ select public.send_reminder('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-0000000000a2') $$), 'NOT_MEMBER',
  'x1 cannot send a reminder in the victim group');
select is(pg_temp.err($$ select public.send_reminder('10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-0000000000a2') $$), 'MEMBER_NOT_FOUND',
  'x1 cannot remind a victim member by naming his own group');
reset role;
select ok(
  (select count(*) = 4 from public.group_members where group_id = '10000000-0000-4000-8000-000000000001')
  and (select status = 'active' and user_id = '00000000-0000-4000-8000-0000000000a2' from public.group_members where id = '20000000-0000-4000-8000-0000000000a2')
  and pg_temp.code('10000000-0000-4000-8000-000000000001') = 'K9K9K9K9'
  and not exists (select 1 from public.activity where type = 'reminder_sent' and group_id = '10000000-0000-4000-8000-000000000001'),
  'the victim group is unchanged: members, code, no reminder');

-- Claiming and joining.
select pg_temp.as_user('c1');
select is(pg_temp.err($$ select public.join_group('K9K9K9K9', '20000000-0000-4000-8000-0000000000a2') $$), 'ALREADY_CLAIMED',
  'a linked member cannot be claimed');
select is(pg_temp.err($$ select public.join_group('K9K9K9K9', '20000000-0000-4000-8000-0000000000a1') $$), 'ALREADY_CLAIMED',
  'the owner member cannot be claimed');
select is(pg_temp.err($$ select public.join_group('K9K9K9K9', '20000000-0000-4000-8000-0000000000b1') $$), 'MEMBER_NOT_FOUND',
  'a member of another group cannot be claimed through this group''s code');
select is(pg_temp.err($$ select public.join_group('K9K9K9K9', '20000000-0000-4000-8000-0000000000a4') $$), 'MEMBER_NOT_FOUND',
  'a member who left cannot be claimed');
select is(pg_temp.err($$ select public.join_group('K9K9K9K9', gen_random_uuid()) $$), 'MEMBER_NOT_FOUND',
  'an unknown member id cannot be claimed');
select is(pg_temp.err($$ select public.join_group('P7P7P7P7') $$), 'CLAIM_REQUIRED',
  'a direct (two person) group cannot get a third member');
select is(pg_temp.err($$ select public.join_group('P7P7P7P7', '20000000-0000-4000-8000-0000000000d2') $$), 'ALREADY_CLAIMED',
  'the second person of a direct group cannot be claimed');
select is(public.join_group('DEAD-0000') ->> 'error', 'INVALID_CODE', 'the code of a deleted group is invalid');
select is(public.preview_join('K9K9K9K9') -> 'group' ->> 'name', 'Victim group',
  'preview with the right code shows the group card (the code is the invite)');
select ok(not (public.preview_join('K9K9K9K9')::text like '%00000000-0000-4000-8000-0000000000a1%')
  and not (public.preview_join('K9K9K9K9')::text like '%Victim dinner%'),
  'the preview leaks no user ids and no expenses');
reset role;
select ok(not exists (select 1 from public.group_members where group_id in ('10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004') and user_id = '00000000-0000-4000-8000-0000000000c1'),
  'none of the refused joins and claims added z1 to a group');

-- Rotating the code kills the old one.
select pg_temp.as_user('a1');
select isnt(public.rotate_invite_code('10000000-0000-4000-8000-000000000001'), 'K9K9K9K9', 'a member rotates the invite code');
select pg_temp.as_user('c1');
select is(public.join_group('K9K9K9K9') ->> 'error', 'INVALID_CODE', 'the old code stops working at once');

-- Direct friend groups only between people who share a group.
select pg_temp.as_user('b1');
select is(pg_temp.err($$ select public.find_or_create_direct_group('00000000-0000-4000-8000-0000000000a1') $$), 'NOT_FRIEND',
  'a stranger cannot open a direct group with a user by id');
select is(pg_temp.err($$ select public.find_or_create_direct_group(gen_random_uuid()) $$), 'NOT_FRIEND',
  'an unknown user id gives NOT_FRIEND');
select is(pg_temp.err($$ select public.find_or_create_direct_group('00000000-0000-4000-8000-0000000000b1') $$), 'INVALID_FRIEND',
  'a direct group with myself is refused');
select is(pg_temp.err($$ select public.find_or_create_direct_group(null) $$), 'INVALID_FRIEND',
  'a null friend is refused');
select pg_temp.as_user('a2');
select is(public.find_or_create_direct_group('00000000-0000-4000-8000-0000000000a1') ->> 'status', 'found',
  'a real co-member gets the direct group (control: the guard is not vacuous)');

-- ================================================================== 6. invite brute force (rate limit)
select pg_temp.as_user('e1');
select is(
  (select count(*) filter (where public.preview_join('BAD0000' || i)->> 'error' = 'INVALID_CODE')
   from generate_series(1, 10) i),
  10::bigint, 'the first ten wrong codes are answered INVALID_CODE');
select is(pg_temp.err($$ select public.preview_join('BAD00011') $$), 'RATE_LIMITED', 'the 11th try is RATE_LIMITED');
select is(pg_temp.err($$ select public.join_group('BAD00012') $$), 'RATE_LIMITED',
  'join_group is limited by the same counter');
select is(pg_temp.err($$ select public.join_group('M8M8M8M8') $$), 'RATE_LIMITED',
  'a blocked user cannot use even a right code (no oracle while blocked)');
select is(pg_temp.err($$ select public.join_group('M8M8M8M8', '20000000-0000-4000-8000-0000000000b3') $$), 'RATE_LIMITED',
  'a blocked user cannot claim either');
reset role;
select is((select count(*) from public.join_attempts where user_id = '00000000-0000-4000-8000-0000000000e1'), 10::bigint,
  'blocked calls do not add attempts: exactly ten are recorded');
select pg_temp.as_user('c1');
select is(public.preview_join('BAD00013') ->> 'error', 'INVALID_CODE', 'another user is not blocked by r1''s attempts');
reset role;
insert into public.join_attempts (user_id, at)
  select '00000000-0000-4000-8000-0000000000a2', now() - interval '2 hours' from generate_series(1, 10);
select pg_temp.as_user('a2');
select is(public.preview_join('BAD00014') ->> 'error', 'INVALID_CODE', 'attempts older than one hour do not count');

-- ================================================================== 7. notifications, devices, settings, profile
select pg_temp.as_user('b1');
select is(public.mark_notifications_read(array['80000000-0000-4000-8000-000000000001']::uuid[]), 0, 'x1 cannot mark the victim notification read');
select is(public.mark_notifications_read(), 0, 'mark all read touches only x1''s own notifications');
select is(public.unregister_device('tok-victim-a1'), false, 'x1 cannot remove the victim device token');
select is(pg_temp.err($$ select public.register_device('') $$), 'INVALID_TOKEN', 'an empty token is refused');
select is(pg_temp.err($$ select public.register_device('   ') $$), 'INVALID_TOKEN', 'a blank token is refused');
select is(pg_temp.err($$ select public.register_device(repeat('t', 4097)) $$), 'INVALID_TOKEN',
  'a 4097 character token is refused');
select is(pg_temp.err($$ select public.register_device('tok-x1', '1.0', 'windows') $$), 'INVALID_PLATFORM',
  'an unknown platform is refused');
select is(pg_temp.err($$ select public.register_device('tok-x1', repeat('9', 5000)) $$), 'OK', 'a long app version is accepted...');
select is((select char_length(app_version) from public.device_tokens where token = 'tok-x1'), 40,
  '...but stored cut to 40 characters');
select is(
  (select count(*) from generate_series(1, 30) i
   where pg_temp.err(format('select public.register_device(%L)', 'tok-flood-' || i)) = 'OK'),
  30::bigint, 'x1 floods device registrations...');
select ok((select count(*) from public.device_tokens where user_id = '00000000-0000-4000-8000-0000000000b1') <= 20,
  '...but keeps at most 20 device tokens (the oldest are dropped)');
select is(public.upsert_notification_settings(null, array['10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002']::uuid[]) -> 'muted_group_ids',
  '["10000000-0000-4000-8000-000000000002"]'::jsonb, 'x1 can mute only groups he belongs to');
select is(pg_temp.err($$ select public.upsert_notification_settings('{"evil": {"push": true}}') $$), 'INVALID_SETTINGS',
  'an unknown notification kind is refused');
select is(pg_temp.err($$ select public.upsert_notification_settings('{"expenses": {"push": "yes"}}') $$),
  'INVALID_SETTINGS', 'a non-boolean setting is refused');
select is(pg_temp.err($$ select public.upsert_notification_settings(null, array_fill(gen_random_uuid(), array[501])) $$),
  'INVALID_SETTINGS', 'more than 500 muted groups are refused');
select is(pg_temp.err($$ select public.update_profile('X', null, 'INR', '00000000-0000-4000-8000-0000000000a1/stolen.jpg') $$), 'INVALID_AVATAR_PATH',
  'x1 cannot point his avatar at another user''s folder');
select is(pg_temp.err($$ select public.update_profile('X', null, 'INR', '00000000-0000-4000-8000-0000000000b1/../00000000-0000-4000-8000-0000000000a1/stolen.jpg') $$),
  'INVALID_AVATAR_PATH', 'an avatar path with ../ is refused');
select is(pg_temp.err($$ select public.update_profile('X', null, 'INR', '00000000-0000-4000-8000-0000000000b1/' || repeat('a', 100000)) $$),
  'INVALID_AVATAR_PATH', 'a 100 KB avatar path is refused');
select is(pg_temp.err($$ select public.update_profile(repeat('n', 51), null, 'INR', null) $$), 'INVALID_NAME',
  'a 51 character name is refused');
select is(pg_temp.err($$ select public.update_profile('   ', null, 'INR', null) $$), 'INVALID_NAME',
  'a blank name is refused');
select is(pg_temp.err($$ select public.update_profile('X', 'not an upi id', 'INR', null) $$), 'INVALID_UPI',
  'a malformed UPI id is refused');
select is(pg_temp.err($$ select public.update_profile('X', null, 'ZZZ', null) $$), 'UNKNOWN_CURRENCY',
  'an unknown default currency is refused');
select is(pg_temp.err($$ select public.update_profile('X', null, 'INRR', null) $$), 'UNKNOWN_CURRENCY',
  'a four letter currency is refused, not cut');
select is(public.update_profile('Xavier', 'xavier@okbank', 'USD', null) ->> 'id', '00000000-0000-4000-8000-0000000000b1',
  'update_profile only ever changes the caller''s own profile');
reset role;
select ok(
  (select read_at is null from public.notifications where id = '80000000-0000-4000-8000-000000000001')
  and exists (select 1 from public.device_tokens where token = 'tok-victim-a1' and user_id = '00000000-0000-4000-8000-0000000000a1')
  and (select kinds = '{"expenses": {"push": false}}'::jsonb and muted_group_ids = '{}'
       from public.notification_settings where user_id = '00000000-0000-4000-8000-0000000000a1')
  and (select display_name = 'Victim' and upi_id = 'victim@okbank' and avatar_path is null
       from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'),
  'the victim notification, device token, settings and profile are unchanged');
select pg_temp.as_user('a1');
select is(public.mark_notifications_read(array['80000000-0000-4000-8000-000000000001']::uuid[]), 1, 'the owner can mark it read (control)');

-- ================================================================== 8. direct table access
select pg_temp.as_user('b1');
select is((select count(*) from public.groups where id = '10000000-0000-4000-8000-000000000001'), 0::bigint, 'x1 reads no victim group row');
select is((select count(*) from public.group_members where group_id = '10000000-0000-4000-8000-000000000001'), 0::bigint, 'x1 reads no victim member rows');
select is((select count(*) from public.expenses where group_id = '10000000-0000-4000-8000-000000000001'), 0::bigint, 'x1 reads no victim expenses');
select is((select count(*) from public.payments where group_id = '10000000-0000-4000-8000-000000000001'), 0::bigint, 'x1 reads no victim payments');
select is((select count(*) from public.comments where group_id = '10000000-0000-4000-8000-000000000001'), 0::bigint, 'x1 reads no victim comments');
select is((select count(*) from public.activity where group_id = '10000000-0000-4000-8000-000000000001'), 0::bigint, 'x1 reads no victim activity');
select is((select count(*) from public.record_versions where group_id = '10000000-0000-4000-8000-000000000001'), 0::bigint,
  'x1 reads no victim edit history');
select is((select count(*) from public.recurring_templates where group_id = '10000000-0000-4000-8000-000000000001'), 0::bigint,
  'x1 reads no victim recurring bills');
select is((select count(*) from public.notifications where user_id = '00000000-0000-4000-8000-0000000000a1'), 0::bigint,
  'x1 reads no victim notifications');
select is((select count(*) from public.notification_settings where user_id = '00000000-0000-4000-8000-0000000000a1'), 0::bigint,
  'x1 reads no victim notification settings');
select is((select count(*) from public.device_tokens where user_id = '00000000-0000-4000-8000-0000000000a1'), 0::bigint,
  'x1 reads no victim device tokens');
select is((select count(*) from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'), 0::bigint,
  'x1 reads no profile of a stranger (name, UPI id)');
select is((select count(*) from public.groups where id = '10000000-0000-4000-8000-000000000002'), 1::bigint, 'x1 reads his own group (control)');
select ok(pg_temp.reads_denied('join_attempts') and pg_temp.reads_denied('mutation_log'),
  'the RPC-only tables join_attempts and mutation_log are unreadable');
select ok(pg_temp.denied('select * from private.settings') and pg_temp.denied('select * from cron.job'),
  'private.settings and cron.job are unreadable');
select is(pg_temp.err('select count(*) from public.currencies'), 'OK', 'reference tables are readable (control)');
select ok(pg_temp.writes_denied('activity', 'id'), 'a signed-in user cannot insert, update or delete activity');
select ok(pg_temp.writes_denied('categories', 'key'), 'a signed-in user cannot insert, update or delete categories');
select ok(pg_temp.writes_denied('comments', 'id'), 'a signed-in user cannot insert, update or delete comments');
select ok(pg_temp.writes_denied('currencies', 'code'), 'a signed-in user cannot insert, update or delete currencies');
select ok(pg_temp.writes_denied('device_tokens', 'id'), 'a signed-in user cannot insert, update or delete device_tokens');
select ok(pg_temp.writes_denied('expenses', 'id'), 'a signed-in user cannot insert, update or delete expenses');
select ok(pg_temp.writes_denied('fx_rates', 'currency'), 'a signed-in user cannot insert, update or delete fx_rates');
select ok(pg_temp.writes_denied('group_members', 'id'), 'a signed-in user cannot insert, update or delete group_members');
select ok(pg_temp.writes_denied('groups', 'id'), 'a signed-in user cannot insert, update or delete groups');
select ok(pg_temp.writes_denied('join_attempts', 'user_id'), 'a signed-in user cannot insert, update or delete join_attempts');
select ok(pg_temp.writes_denied('mutation_log', 'mutation_id'), 'a signed-in user cannot insert, update or delete mutation_log');
select ok(pg_temp.writes_denied('notification_settings', 'user_id'), 'a signed-in user cannot insert, update or delete notification_settings');
select ok(pg_temp.writes_denied('notifications', 'id'), 'a signed-in user cannot insert, update or delete notifications');
select ok(pg_temp.writes_denied('payments', 'id'), 'a signed-in user cannot insert, update or delete payments');
select ok(pg_temp.writes_denied('profiles', 'id'), 'a signed-in user cannot insert, update or delete profiles');
select ok(pg_temp.writes_denied('record_versions', 'table_name'), 'a signed-in user cannot insert, update or delete record_versions');
select ok(pg_temp.writes_denied('recurring_templates', 'id'), 'a signed-in user cannot insert, update or delete recurring_templates');
select pg_temp.as_anon();
select ok(pg_temp.reads_denied('activity') and pg_temp.writes_denied('activity', 'id'), 'anon cannot read or write activity');
select ok(pg_temp.reads_denied('categories') and pg_temp.writes_denied('categories', 'key'), 'anon cannot read or write categories');
select ok(pg_temp.reads_denied('comments') and pg_temp.writes_denied('comments', 'id'), 'anon cannot read or write comments');
select ok(pg_temp.reads_denied('currencies') and pg_temp.writes_denied('currencies', 'code'), 'anon cannot read or write currencies');
select ok(pg_temp.reads_denied('device_tokens') and pg_temp.writes_denied('device_tokens', 'id'), 'anon cannot read or write device_tokens');
select ok(pg_temp.reads_denied('expenses') and pg_temp.writes_denied('expenses', 'id'), 'anon cannot read or write expenses');
select ok(pg_temp.reads_denied('fx_rates') and pg_temp.writes_denied('fx_rates', 'currency'), 'anon cannot read or write fx_rates');
select ok(pg_temp.reads_denied('group_members') and pg_temp.writes_denied('group_members', 'id'), 'anon cannot read or write group_members');
select ok(pg_temp.reads_denied('groups') and pg_temp.writes_denied('groups', 'id'), 'anon cannot read or write groups');
select ok(pg_temp.reads_denied('join_attempts') and pg_temp.writes_denied('join_attempts', 'user_id'), 'anon cannot read or write join_attempts');
select ok(pg_temp.reads_denied('mutation_log') and pg_temp.writes_denied('mutation_log', 'mutation_id'), 'anon cannot read or write mutation_log');
select ok(pg_temp.reads_denied('notification_settings') and pg_temp.writes_denied('notification_settings', 'user_id'), 'anon cannot read or write notification_settings');
select ok(pg_temp.reads_denied('notifications') and pg_temp.writes_denied('notifications', 'id'), 'anon cannot read or write notifications');
select ok(pg_temp.reads_denied('payments') and pg_temp.writes_denied('payments', 'id'), 'anon cannot read or write payments');
select ok(pg_temp.reads_denied('profiles') and pg_temp.writes_denied('profiles', 'id'), 'anon cannot read or write profiles');
select ok(pg_temp.reads_denied('record_versions') and pg_temp.writes_denied('record_versions', 'table_name'), 'anon cannot read or write record_versions');
select ok(pg_temp.reads_denied('recurring_templates') and pg_temp.writes_denied('recurring_templates', 'id'), 'anon cannot read or write recurring_templates');
select ok(pg_temp.denied('select * from private.settings') and pg_temp.denied('select * from cron.job'),
  'anon reads neither private.settings nor cron.job');
reset role;
select ok(
  not exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
              where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  'Row Level Security is enabled on every public table');
select ok(
  not exists (select 1 from pg_policies where schemaname = 'public'
              and (cmd <> 'SELECT' or 'anon' = any (roles) or 'public' = any (roles))),
  'public tables have SELECT policies for signed-in users only: no write policy, nothing for anon');

-- ================================================================== 9. Storage path tricks
select pg_temp.as_user('b1');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name) values ('receipts', '10000000-0000-4000-8000-000000000001/x.jpg') $$),
  'x1 cannot upload into a victim receipts folder');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name)
  values ('receipts', '10000000-0000-4000-8000-000000000001/30000000-0000-4000-8000-000000000001/dddddddd-dddd-4ddd-8ddd-dddddddddddd.jpg') $$),
  'x1 cannot upload a receipt for a victim expense');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name) values ('group-covers', '10000000-0000-4000-8000-000000000001/x.jpg') $$),
  'x1 cannot upload a victim group cover');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name) values ('avatars', '00000000-0000-4000-8000-0000000000a1/x.jpg') $$),
  'x1 cannot upload into the victim avatar folder');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name) values ('receipts', '../x.jpg') $$),
  'a path starting with ../ is refused');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name) values ('receipts', 'x.jpg') $$),
  'a file outside any folder is refused');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name) values ('receipts', '/10000000-0000-4000-8000-000000000002/x.jpg') $$),
  'a path with a leading slash is refused');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name) values ('receipts', '10000000-0000-4000-8000-000000000002/../10000000-0000-4000-8000-000000000001/x.jpg') $$),
  'my group folder followed by ../ and the victim folder is refused (receipts)');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name)
  values ('group-covers', '10000000-0000-4000-8000-000000000002/../10000000-0000-4000-8000-000000000001/x.jpg') $$), 'the same ../ trick is refused for group covers');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name)
  values ('avatars', '00000000-0000-4000-8000-0000000000b1/../00000000-0000-4000-8000-0000000000a1/x.jpg') $$), 'the same ../ trick is refused for avatars');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name) values ('receipts', '10000000-0000-4000-8000-000000000002//x.jpg') $$),
  'an empty path segment is refused');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name) values ('receipts', '10000000-0000-4000-8000-000000000002/./x.jpg') $$),
  'a ./ path segment is refused');
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name)
  values ('receipts', '10000000-0000-4000-8000-000000000002/..\10000000-0000-4000-8000-000000000001\x.jpg') $$), 'a backslash in a path is refused');
select is(pg_temp.err($$ insert into storage.objects (bucket_id, name) values ('receipts', '10000000-0000-4000-8000-000000000002/30000000-0000-4000-8000-000000000002/dddddddd-dddd-4ddd-8ddd-dddddddddddd.jpg') $$),
  'OK', 'a normal receipt in my own group folder is accepted (control)');
select is(pg_temp.err($$ insert into storage.objects (bucket_id, name) values ('avatars', '00000000-0000-4000-8000-0000000000b1/eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee.jpg') $$),
  'OK', 'my own avatar upload is accepted (control)');
select is((select count(*) from storage.objects where bucket_id = 'receipts' and name like '10000000-0000-4000-8000-000000000001/%'), 0::bigint,
  'x1 lists no victim receipts');
select is((select count(*) from storage.objects where bucket_id = 'group-covers' and name like '10000000-0000-4000-8000-000000000001/%'), 0::bigint,
  'x1 lists no victim group covers');
select is((select count(*) from storage.objects where bucket_id = 'avatars' and name like '00000000-0000-4000-8000-0000000000a1/%'), 0::bigint,
  'x1 lists no avatar of a stranger');
select is((select count(*) from storage.objects where bucket_id = 'receipts' and name like '10000000-0000-4000-8000-000000000002/%'), 2::bigint,
  'x1 lists his own group files (control)');
select ok(pg_temp.denied($$ update storage.objects set name = '10000000-0000-4000-8000-000000000001/stolen.jpg'
  where bucket_id = 'receipts' and name = '10000000-0000-4000-8000-000000000002/own1.jpg' $$),
  'x1 cannot move his file into a victim folder (rename)');
select ok(pg_temp.denied($$ update storage.objects set name = '10000000-0000-4000-8000-000000000002/../10000000-0000-4000-8000-000000000001/stolen.jpg'
  where bucket_id = 'receipts' and name = '10000000-0000-4000-8000-000000000002/own1.jpg' $$),
  'x1 cannot rename his file to a ../ path');
select ok(pg_temp.denied($$ update storage.objects set bucket_id = 'avatars'
  where bucket_id = 'receipts' and name = '10000000-0000-4000-8000-000000000002/own1.jpg' $$),
  'x1 cannot move his file into another bucket');
select is((select count(*) from (select 1 from storage.objects where name like '10000000-0000-4000-8000-000000000001/%' or name like '00000000-0000-4000-8000-0000000000a1/%') s),
  0::bigint, 'no victim object is visible in any bucket');
select pg_temp.as_anon();
select ok(pg_temp.denied($$ insert into storage.objects (bucket_id, name) values ('receipts', '10000000-0000-4000-8000-000000000002/anon.jpg') $$),
  'anon cannot upload');
select is(pg_temp.cnt($$ select count(*) from storage.objects where bucket_id in ('receipts', 'group-covers', 'avatars') $$),
  0::bigint, 'anon sees no stored file');
reset role;
select ok(
  (select qual like '%is_member%' from pg_policies where schemaname = 'storage' and policyname = 'group_files_delete')
  and (select qual like '%auth.uid%' from pg_policies where schemaname = 'storage' and policyname = 'avatars_delete')
  and not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
                  and ('anon' = any (roles) or 'public' = any (roles))),
  'delete policies are folder/owner scoped and no Storage policy is open to anon or public');
select ok(
  not exists (select 1 from storage.buckets where id in ('receipts', 'group-covers', 'avatars') and public),
  'all three buckets are private');
select ok(
  exists (select 1 from pg_policies where schemaname = 'realtime' and policyname = 'sync_topics_select'
          and qual like '%is_member%')
  or to_regclass('realtime.messages') is null,
  'private Realtime channels are limited to group members and the user''s own topic');

-- ================================================================== 10. oversized and absurd payloads
select pg_temp.as_user('b1');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000030', '10000000-0000-4000-8000-000000000002', pg_temp.exp(jsonb_build_object('description', repeat('d', 120)))),
  'applied', 'a 120 character description is accepted (control)');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002', pg_temp.exp(jsonb_build_object('description', repeat('d', 121)))),
  'INVALID_VALUE', 'a 121 character description is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"description": "   "}')),
  'INVALID_VALUE', 'a blank description is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp(jsonb_build_object('description', repeat(' ', 200000) || 'a'))),
  'INVALID_VALUE', 'a description padded with 200000 spaces is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002', pg_temp.exp(jsonb_build_object('notes', repeat('n', 1001)))),
  'INVALID_VALUE', 'notes over 1000 characters are refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002', pg_temp.exp(jsonb_build_object('notes', repeat('n', 2000000)))),
  'INVALID_VALUE', '2 MB of notes is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp(jsonb_build_object('split_values', jsonb_build_object('pad', repeat('x', 300000))))),
  'INVALID_VALUE', 'a 300 KB split_values object is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"date": "2026-13-45"}')),
  'INVALID_VALUE', 'an impossible date is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"date": "9999-12-31"}')),
  'INVALID_VALUE', 'a date in the year 9999 is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"date": "0001-01-01"}')),
  'INVALID_VALUE', 'a date in the year 1 is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"total": 1000000000000, "payers": {"20000000-0000-4000-8000-0000000000b1": 1000000000000}, "shares": {"20000000-0000-4000-8000-0000000000b1": 1000000000000}}')),
  'AMOUNT_TOO_LARGE', 'a total above 999,999,999,999 minor units is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"total": 99999999999999999999, "payers": {"20000000-0000-4000-8000-0000000000b1": 99999999999999999999},
                "shares": {"20000000-0000-4000-8000-0000000000b1": 99999999999999999999}}')),
  'INVALID_VALUE', 'a total beyond bigint is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"total": 999999999999, "payers": {"20000000-0000-4000-8000-0000000000b1": 999999999999}, "shares": {"20000000-0000-4000-8000-0000000000b1": 999999999999}}')),
  'applied', 'the largest allowed total is accepted (control)');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"total": 0, "payers": {"20000000-0000-4000-8000-0000000000b1": 0}, "shares": {"20000000-0000-4000-8000-0000000000b1": 0}}')),
  'AMOUNT_NOT_POSITIVE', 'a zero total is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"total": -5, "payers": {"20000000-0000-4000-8000-0000000000b1": -5}, "shares": {"20000000-0000-4000-8000-0000000000b1": -5}}')),
  'AMOUNT_NOT_POSITIVE', 'a negative total is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"total": 10.5}')),
  'INVALID_VALUE', 'a fractional total is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"total": "lots"}')),
  'INVALID_VALUE', 'a non-numeric total is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"payers": {"20000000-0000-4000-8000-0000000000b1": 1500, "20000000-0000-4000-8000-0000000000b2": -500}}')), 'INVALID_AMOUNT', 'a negative payer amount is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"shares": {"20000000-0000-4000-8000-0000000000b1": 500.5, "20000000-0000-4000-8000-0000000000b2": 499.5}}')), 'INVALID_AMOUNT', 'a fractional share is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"currency": "ZZZ"}')),
  'INVALID_REFERENCE', 'an unknown currency code is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"currency": "inr"}')),
  'INVALID_REFERENCE', 'a lowercase currency code is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"currency": "INRR"}')),
  'INVALID_VALUE', 'a four letter currency code is refused, not cut to three');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"currency": ""}')),
  'INVALID_REFERENCE', 'an empty currency code is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"category": "evil.cat"}')),
  'INVALID_REFERENCE', 'an unknown category is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002',
  pg_temp.exp('{"fx_rate": 1e30, "fx_rate_date": "2026-11-01", "fx_source": "manual", "fx_currency": "USD",
                "fx_total": 12, "fx_payers": {"20000000-0000-4000-8000-0000000000b1": 12}, "fx_shares": {"20000000-0000-4000-8000-0000000000b1": 6, "20000000-0000-4000-8000-0000000000b2": 6}}')),
  'INVALID_VALUE', 'an exchange rate beyond numeric(24,10) is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000032', '10000000-0000-4000-8000-000000000002', pg_temp.exp('{"split_kind": "evil"}')),
  'INVALID_VALUE', 'an unknown split kind is refused');
select is(pg_temp.ap('payment', 'upsert', 'f0000000-0000-4000-8000-000000000033', '10000000-0000-4000-8000-000000000002', pg_temp.pay(jsonb_build_object('note', repeat('n', 201)))),
  'INVALID_VALUE', 'a payment note over 200 characters is refused');
select is(pg_temp.ap('payment', 'upsert', 'f0000000-0000-4000-8000-000000000033', '10000000-0000-4000-8000-000000000002', pg_temp.pay('{"amount": 1000000000000}')),
  'AMOUNT_TOO_LARGE', 'a payment above the maximum is refused');
select is(pg_temp.ap('payment', 'upsert', 'f0000000-0000-4000-8000-000000000033', '10000000-0000-4000-8000-000000000002', pg_temp.pay('{"to_member": "20000000-0000-4000-8000-0000000000b2"}')),
  'INVALID_VALUE', 'a payment from a member to himself is refused');
select is(pg_temp.ap('payment', 'upsert', 'f0000000-0000-4000-8000-000000000033', '10000000-0000-4000-8000-000000000002', pg_temp.pay('{"date": "9999-12-31"}')),
  'INVALID_VALUE', 'a payment dated in the year 9999 is refused');
select is(pg_temp.ap('comment', 'upsert', 'f0000000-0000-4000-8000-000000000034', '10000000-0000-4000-8000-000000000002',
  jsonb_build_object('target_type', 'expense', 'target_id', '30000000-0000-4000-8000-000000000002', 'body', repeat('c', 1001))),
  'INVALID_VALUE', 'a comment over 1000 characters is refused');
select is(pg_temp.ap('comment', 'upsert', 'f0000000-0000-4000-8000-000000000034', '10000000-0000-4000-8000-000000000002',
  jsonb_build_object('target_type', 'expense', 'target_id', '30000000-0000-4000-8000-000000000002', 'body', repeat(' ', 200000) || 'c')),
  'INVALID_VALUE', 'a comment padded with 200000 spaces is refused');
select is(pg_temp.ap('group', 'upsert', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', jsonb_build_object('name', repeat('g', 61))),
  'INVALID_VALUE', 'a 61 character group name is refused');
select is(pg_temp.ap('group', 'upsert', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', jsonb_build_object('name', repeat(' ', 200000) || 'g')),
  'INVALID_VALUE', 'a group name padded with 200000 spaces is refused');
select is(pg_temp.ap('group', 'upsert', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002',
  jsonb_build_object('default_split', jsonb_build_object('pad', repeat('x', 300000)))),
  'INVALID_VALUE', 'a 300 KB default_split is refused');
select is(pg_temp.ap('group', 'upsert', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', '{"main_currency": "ZZZ"}'), 'INVALID_REFERENCE',
  'a group with an unknown main currency is refused');
select is(pg_temp.ap('member', 'upsert', 'f0000000-0000-4000-8000-000000000035', '10000000-0000-4000-8000-000000000002', jsonb_build_object('display_name', repeat('m', 51), 'position', 8)),
  'INVALID_VALUE', 'a 51 character member name is refused');
select is(pg_temp.ap('member', 'upsert', 'f0000000-0000-4000-8000-000000000035', '10000000-0000-4000-8000-000000000002',
  jsonb_build_object('display_name', repeat(' ', 200000) || 'm', 'position', 8)),
  'INVALID_VALUE', 'a member name padded with 200000 spaces is refused');
select is(pg_temp.ap('member', 'upsert', 'f0000000-0000-4000-8000-000000000035', '10000000-0000-4000-8000-000000000002', '{"display_name": "M", "position": -1}'),
  'INVALID_VALUE', 'a negative member position is refused');
select is(pg_temp.ap('member', 'upsert', 'f0000000-0000-4000-8000-000000000035', '10000000-0000-4000-8000-000000000002', '{"display_name": "M", "position": 8, "tint": 9}'),
  'INVALID_VALUE', 'an out of range tint is refused');
select is(pg_temp.ap('member', 'upsert', 'f0000000-0000-4000-8000-000000000035', '10000000-0000-4000-8000-000000000002', '{"display_name": "M", "position": 0}'),
  'DUPLICATE', 'a duplicate member position is refused');
select is(pg_temp.ap('member', 'upsert', 'f0000000-0000-4000-8000-000000000036', '10000000-0000-4000-8000-000000000007', '{"display_name": "One too many", "position": 100}'),
  'GROUP_FULL', 'a group cannot grow past 100 members through sync either');
select is(pg_temp.ap('recurring', 'upsert', 'f0000000-0000-4000-8000-000000000037', '10000000-0000-4000-8000-000000000002', pg_temp.rec(jsonb_build_object('template',
  pg_temp.exp(jsonb_build_object('split_values', jsonb_build_object('pad', repeat('x', 300000))))))),
  'INVALID_VALUE', 'a recurring template with a 300 KB split_values is refused');
select is(pg_temp.ap('recurring', 'upsert', 'f0000000-0000-4000-8000-000000000037', '10000000-0000-4000-8000-000000000002', pg_temp.rec(jsonb_build_object('template',
  pg_temp.exp(jsonb_build_object('notes', repeat('n', 1001)))))),
  'INVALID_TEMPLATE', 'a recurring template with long notes is refused');
select is(pg_temp.ap('recurring', 'upsert', 'f0000000-0000-4000-8000-000000000037', '10000000-0000-4000-8000-000000000002', pg_temp.rec('{"interval": "hourly"}')),
  'UNKNOWN_INTERVAL', 'an unknown repeat interval is refused');
select is(pg_temp.ap('widget', 'upsert', 'f0000000-0000-4000-8000-000000000038', '10000000-0000-4000-8000-000000000002'), 'INVALID_MUTATION', 'an unknown entity is refused');
select is(pg_temp.ap('expense', 'drop', 'f0000000-0000-4000-8000-000000000038', '10000000-0000-4000-8000-000000000002'), 'INVALID_MUTATION', 'an unknown operation is refused');
select is(pg_temp.ap('expense', 'upsert', 'not-a-uuid', '10000000-0000-4000-8000-000000000002', pg_temp.exp()), 'INVALID_MUTATION',
  'a mutation id that is no uuid is refused');
select is(pg_temp.ap('expense', 'upsert', 'f0000000-0000-4000-8000-000000000038', '10000000-0000-4000-8000-000000000002', '"a string"'::jsonb), 'INVALID_MUTATION',
  'a non-object data field is refused');
select is(pg_temp.err($$ select public.apply_mutations((select jsonb_agg('{}'::jsonb) from generate_series(1, 101))) $$),
  'BATCH_TOO_LARGE', 'a batch of 101 mutations is refused');
select is(pg_temp.err($$ select public.apply_mutations('{"a": 1}') $$), 'INVALID_BATCH', 'a non-array batch is refused');
select is(pg_temp.err($$ select public.apply_mutations(null) $$), 'INVALID_BATCH', 'a null batch is refused');
select is(
  (select r ->> 'code' from jsonb_array_elements(
     public.apply_mutations('["x", 5, null, {"entity": "expense"}]') -> 'results') r limit 1),
  'INVALID_MUTATION', 'junk batch items are rejected one by one');
select is(
  (select count(*) from jsonb_array_elements(
     public.apply_mutations((select jsonb_agg('"junk"'::jsonb) from generate_series(1, 100))) -> 'results') r
   where r ->> 'status' = 'rejected'),
  100::bigint, 'a full batch of junk is answered item by item');
select is(pg_temp.err($$ select public.apply_mutations(('[{"mutation_id": "' || gen_random_uuid() || '", "entity": "expense",
  "op": "upsert", "id": "f0000000-0000-4000-8000-000000000039", "group_id": "10000000-0000-4000-8000-000000000002", "client_updated_at": "not a time", "data": {}}]')::jsonb) $$), 'OK',
  'a malformed client_updated_at does not crash the batch');

-- ================================================================== 11. account deletion touches only the caller
select pg_temp.as_user('b2');
select is(public.prepare_account_deletion() ->> 'groups', '1', 'w1 deletes his account: his one membership is converted');
select is(public.prepare_account_deletion() ->> 'groups', '0', 'a second call converts nothing (idempotent)');
reset role;
select ok(
  (select user_id is null and display_name = 'Wanda (left)' from public.group_members where id = '20000000-0000-4000-8000-0000000000b2')
  and (select user_id = '00000000-0000-4000-8000-0000000000b1' and display_name = 'Xavier' from public.group_members where id = '20000000-0000-4000-8000-0000000000b1')
  and (select count(*) = 0 from public.group_members where group_id = '10000000-0000-4000-8000-000000000001' and display_name like '%(left)')
  and (select display_name = 'Deleted user' and deleted_at is not null from public.profiles where id = '00000000-0000-4000-8000-0000000000b2')
  and (select display_name = 'Victim' and deleted_at is null from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'),
  'only the caller''s memberships and profile changed; other users and groups are untouched');

select * from finish();
rollback;
