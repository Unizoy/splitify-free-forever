-- R4 attack suite (S-467..S-471) for what came after D-032: ad-hoc groups (0028), friend codes (0025), attachment
-- files (0029), the whiteboard (0026), reminders, batch settle-up pushes and the monthly summary (0030). Every case
-- here is new (190/250/260/280/290/300 keep theirs). Bugs it found are fixed in 0031: co-members could overwrite
-- another member's attachment file (S-468), a known batch id replayed another user's covered pushes (S-469).
begin;
select plan(43);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000310a1', 'r4-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000310b1', 'r4-b@splitify.test', '{"full_name": "Bina"}'),
  ('00000000-0000-4000-8000-0000000310c1', 'r4-c@splitify.test', '{"full_name": "Chetan"}'),
  ('00000000-0000-4000-8000-0000000310d1', 'r4-d@splitify.test', '{"full_name": "Dev"}');

create function pg_temp.uid(u text) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-0000000310' || u || '1')::uuid;
$$;
create function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || pg_temp.uid(u) || '","role":"authenticated"}', true);
$$;
create function pg_temp.g(n int) returns uuid language sql immutable as $$
  select ('c3100000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid;
$$;
create function pg_temp.mem(u text, n int) returns uuid language sql immutable as $$
  select ('c3110000-0000-4000-8000-0000000' || u || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.e(n int) returns uuid language sql immutable as $$
  select ('c3120000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid;
$$;
create function pg_temp.att(n int) returns uuid language sql immutable as $$
  select ('c3130000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid;
$$;
create function pg_temp.xpath(n int) returns text language sql immutable as $$
  select pg_temp.g(1) || '/' || pg_temp.e(1) || '/' || pg_temp.att(n) || '.jpg';
$$;
create function pg_temp.m(p_mid int, p_entity text, p_op text, p_id uuid, p_group uuid, p_data jsonb)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', 'c3150000-0000-4000-8000-' || lpad(p_mid::text, 12, '0'), 'entity', p_entity, 'op', p_op,
    'id', p_id, 'group_id', p_group, 'base_seq', null, 'client_updated_at', now(), 'source', 'app', 'data', p_data);
$$;
create function pg_temp.apply(p jsonb) returns jsonb language sql as $$
  select public.apply_mutations(jsonb_build_array(p)) -> 'results' -> 0;
$$;
create function pg_temp.code(p jsonb) returns text language sql as $$
  select coalesce(r ->> 'code', r ->> 'status') from (select pg_temp.apply(p) as r) s;
$$;
create function pg_temp.err(q text) returns text language plpgsql as $$
begin
  execute q;
  return 'no error';
exception when others then
  return sqlerrm;
end;
$$;
-- A photo of expense 1 (group 1) with the given paths.
create function pg_temp.photo(n int, p_path text default null, p_thumb text default null, p_size int default 800000)
returns jsonb language sql immutable as $$
  select jsonb_build_object('expense_id', pg_temp.e(1), 'kind', 'photo',
    'path', coalesce(p_path, pg_temp.xpath(n)),
    'thumb_path', coalesce(p_thumb, replace(pg_temp.xpath(n), '.jpg', '-thumb.jpg')),
    'size_bytes', p_size, 'width', 1600, 'height', 1200, 'position', n);
$$;
-- A payment f -> t in group n, inside batch b.
create function pg_temp.pay(p_mid int, n int, f text, t text, p_amount int, p_batch text) returns jsonb
language sql stable as $$
  select pg_temp.m(p_mid, 'payment', 'upsert', ('c3140000-0000-4000-8000-' || lpad(p_mid::text, 12, '0'))::uuid,
    pg_temp.g(n), jsonb_build_object('from_member', pg_temp.mem(f, n), 'to_member', pg_temp.mem(t, n),
      'amount', p_amount, 'currency', 'INR', 'date', '2026-11-28', 'method', 'upi', 'batch_id', p_batch));
$$;
-- Push states of user u's bell rows in batch b, sorted (read as the server).
create function pg_temp.states(u text, p_batch text) returns text language sql stable as $$
  select coalesce(string_agg(n.push_status, ',' order by n.push_status), '-') from public.notifications n
  where n.user_id = pg_temp.uid(u) and n.data ->> 'batch_id' = p_batch;
$$;
-- Rows of storage.objects the caller could change.
create function pg_temp.touch(p_name text) returns int language plpgsql as $$
declare
  n int;
begin
  update storage.objects set user_metadata = '{"touched": true}'::jsonb
  where bucket_id = 'expense-files' and name = p_name;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Groups: 1 Trip (Asha, Bina, Chetan left, Nina name-only), 2 Old (Asha, Dev; deleted), 3 Flat (Asha, Bina),
-- 4 Archived (Asha, Bina), 5 Gym (Bina, Chetan), 6/7 Dev 1/2 (Asha, Dev), 8 Left (Asha, Bina left),
-- 9 Gone (Asha, Bina; deleted), 10 a direct group of Asha and Bina. Bina paid her own share in group 8 (a member
-- with a balance can't leave).
insert into public.groups (id, name, type) values
  (pg_temp.g(1), 'Trip', 'trip'), (pg_temp.g(2), 'Old', 'trip'), (pg_temp.g(3), 'Flat', 'home'),
  (pg_temp.g(4), 'Archived', 'other'), (pg_temp.g(5), 'Gym', 'other'), (pg_temp.g(6), 'Dev 1', 'other'),
  (pg_temp.g(7), 'Dev 2', 'other'), (pg_temp.g(8), 'Left', 'other'), (pg_temp.g(9), 'Gone', 'other'),
  (pg_temp.g(10), 'Asha & Bina', 'direct');
insert into public.group_members (id, group_id, user_id, display_name, position, status, role)
select pg_temp.mem(x.u, x.n), pg_temp.g(x.n), case when x.u = 'e' then null else pg_temp.uid(x.u) end,
       case x.u when 'a' then 'Asha' when 'b' then 'Bina' when 'c' then 'Chetan' when 'd' then 'Dev' else 'Nina' end,
       x.pos, x.status, case when x.pos = 0 then 'owner' else 'member' end
from (values ('a', 1, 0, 'active'), ('b', 1, 1, 'active'), ('c', 1, 2, 'left'), ('e', 1, 3, 'active'),
             ('a', 2, 0, 'active'), ('d', 2, 1, 'active'), ('a', 3, 0, 'active'), ('b', 3, 1, 'active'),
             ('a', 4, 0, 'active'), ('b', 4, 1, 'active'), ('b', 5, 0, 'active'), ('c', 5, 1, 'active'),
             ('a', 6, 0, 'active'), ('d', 6, 1, 'active'), ('a', 7, 0, 'active'), ('d', 7, 1, 'active'),
             ('a', 8, 0, 'active'), ('b', 8, 1, 'active'), ('a', 9, 0, 'active'), ('b', 9, 1, 'active'),
             ('a', 10, 0, 'active'), ('b', 10, 1, 'active')) x(u, n, pos, status);
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares)
select pg_temp.e(x.n), pg_temp.g(x.n), x.d, x.dt::date, 'INR', x.t,
       case when x.n = 8 then jsonb_build_object(pg_temp.mem('a', x.n), x.t / 2, pg_temp.mem('b', x.n), x.t / 2)
            else jsonb_build_object(pg_temp.mem('a', x.n), x.t) end,
       jsonb_build_object(pg_temp.mem('a', x.n), x.t / 2, pg_temp.mem('b', x.n), x.t / 2)
from (values (1, 'Hotel', '2026-11-10', 1000), (8, 'Left trip', '2026-11-15', 1400),
             (9, 'Gone trip', '2026-11-16', 1800)) x(n, d, dt, t);
update public.group_members set status = 'left' where id = pg_temp.mem('b', 8);
update public.groups set deleted_at = now() where id in (pg_temp.g(2), pg_temp.g(9));
update public.groups set archived_at = now() where id = pg_temp.g(4);

-- Derived member ids (origin XOR ad-hoc group) and money words, computed as the server.
create temp table x (k text primary key, id uuid);
insert into x values
  ('b1@101', private.uuid_xor(pg_temp.mem('b', 1), pg_temp.g(101))),
  ('c1@101', private.uuid_xor(pg_temp.mem('c', 1), pg_temp.g(101))),
  ('d2@101', private.uuid_xor(pg_temp.mem('d', 2), pg_temp.g(101))),
  ('a1@101', private.uuid_xor(pg_temp.mem('a', 1), pg_temp.g(101))),
  ('b3@101', private.uuid_xor(pg_temp.mem('b', 3), pg_temp.g(101))),
  ('b1@102', private.uuid_xor(pg_temp.mem('b', 1), pg_temp.g(102)));
create function pg_temp.x(p text) returns uuid language sql stable as $$ select id from x where k = p; $$;
create temp table fm as select private.format_money(500, 'INR') as s500;
create temp table codes (u text primary key, c text);
create temp table res (k text primary key, v jsonb);
grant all on x, fm, codes, res to public;

set local role authenticated;

-- ------------------------------------------------------------------ ad-hoc groups (0028)
select pg_temp.as_user('a');
select pg_temp.apply(pg_temp.m(1, 'group', 'upsert', pg_temp.g(100), pg_temp.g(100),
  jsonb_build_object('name', 'Visible', 'type', 'trip', 'is_adhoc', true,
    'owner_member', jsonb_build_object('id', pg_temp.mem('a', 100), 'display_name', 'Asha'))));
select is((select is_adhoc from public.groups where id = pg_temp.g(100)), false,
  'is_adhoc sent with a new group is ignored (only type adhoc makes one)');
select pg_temp.apply(pg_temp.m(2, 'group', 'upsert', pg_temp.g(101), pg_temp.g(101),
  jsonb_build_object('name', 'Asha, Bina & co', 'type', 'adhoc', 'main_currency', 'INR',
    'direct_key', pg_temp.uid('b') || ':' || pg_temp.uid('d'),
    'owner_member', jsonb_build_object('id', pg_temp.mem('a', 101), 'display_name', 'Asha'))));
select is((select type || ':' || is_adhoc || ':' || coalesce(direct_key, '-') from public.groups
           where id = pg_temp.g(101)), 'other:true:-', 'an ad-hoc group can not squat a friend pair''s direct key');
select pg_temp.apply(pg_temp.m(3, 'member', 'upsert', pg_temp.x('b1@101'), pg_temp.g(101),
  jsonb_build_object('display_name', 'Bina', 'position', 1, 'user_id', pg_temp.uid('d'))));
select is((select user_id from public.group_members where id = pg_temp.x('b1@101')), pg_temp.uid('b'),
  'attack: a user_id in the mutation is ignored; the origin decides the account');
select pg_temp.apply(pg_temp.m(4, 'member', 'upsert', pg_temp.x('c1@101'), pg_temp.g(101),
  '{"display_name": "Chetan", "position": 2}'));
select is((select user_id from public.group_members where id = pg_temp.x('c1@101')), null::uuid,
  'an origin who left the group is not linked');
select pg_temp.apply(pg_temp.m(5, 'member', 'upsert', pg_temp.x('d2@101'), pg_temp.g(101),
  '{"display_name": "Dev", "position": 3}'));
select is((select user_id from public.group_members where id = pg_temp.x('d2@101')), null::uuid,
  'an origin in a deleted group is not linked');
select pg_temp.apply(pg_temp.m(6, 'member', 'upsert', pg_temp.x('a1@101'), pg_temp.g(101),
  '{"display_name": "Asha again", "position": 4}'));
select is((select user_id from public.group_members where id = pg_temp.x('a1@101')), null::uuid,
  'the adder is never linked a second time');
select pg_temp.apply(pg_temp.m(7, 'member', 'upsert', pg_temp.x('b3@101'), pg_temp.g(101),
  '{"display_name": "Bina (flat)", "position": 5}'));
select is((select user_id from public.group_members where id = pg_temp.x('b3@101')), null::uuid,
  'an account already in the group is not linked twice');

select pg_temp.as_user('c');
select pg_temp.apply(pg_temp.m(8, 'group', 'upsert', pg_temp.g(102), pg_temp.g(102),
  jsonb_build_object('name', 'Chetan & Bina', 'type', 'adhoc',
    'owner_member', jsonb_build_object('id', pg_temp.mem('c', 102), 'display_name', 'Chetan'))));
select pg_temp.apply(pg_temp.m(9, 'member', 'upsert', pg_temp.x('b1@102'), pg_temp.g(102),
  '{"display_name": "Bina", "position": 1}'));
select is((select user_id from public.group_members where id = pg_temp.x('b1@102')), null::uuid,
  'attack: someone who left the origin group links nobody');

select pg_temp.as_user('d');
select is((select count(*) from public.groups where id = pg_temp.g(101)), 0::bigint,
  'the spoofed user_id gave Dev no access to the ad-hoc group');

select pg_temp.as_user('a');
select is(pg_temp.code(pg_temp.m(10, 'group', 'upsert', pg_temp.g(10), pg_temp.g(10), '{"type": "trip"}')),
  'TYPE_LOCKED', 'a friend (direct) group can not stop being direct');

-- ------------------------------------------------------------------ friend codes (0025)
select pg_temp.as_user('b');
insert into codes select 'b', public.my_friend_code();

select pg_temp.as_user('c');
select is(public.add_friend_by_code(public.my_friend_code()) ->> 'error', 'OWN_CODE',
  'your own code says so and is not a wrong try');
select is(public.add_friend_by_code(null) ->> 'error', 'INVALID_CODE', 'a missing code is a wrong code');
select is(public.add_friend_by_code(repeat('A', 10000)) ->> 'error', 'INVALID_CODE',
  'a 10,000-character code is a wrong code');
select is(public.add_friend_by_code('АВСD-ЕFGН') ->> 'error', 'INVALID_CODE',
  'look-alike letters from another script match nothing');
reset role;
select is((select count(*) from public.join_attempts where user_id = pg_temp.uid('c')), 3::bigint,
  'each wrong code counts against the rate limit (your own code does not)');
set local role authenticated;
select pg_temp.as_user('c');
select is(public.add_friend_by_code(lower((select c from codes where u = 'b'))) ->> 'status', 'created',
  'Chetan adds Bina with her code (typed in lower case)');
insert into res select 'c', public.pull_changes('{}'::jsonb, 0, 500);
select ok(not exists (select 1 from res, jsonb_array_elements(res.v -> 'rows' -> 'groups') g
                      where res.k = 'c' and (g ->> 'id')::uuid in (pg_temp.g(1), pg_temp.g(3), pg_temp.g(4),
                                                                  pg_temp.g(8), pg_temp.g(10), pg_temp.g(101))),
  'attack: a friend code shares none of the friend''s other groups');
select is((select jsonb_array_length(v -> 'rows' -> 'expenses') from res where k = 'c'), 0,
  'nor their expenses');

-- ------------------------------------------------------------------ attachment files (0029)
select pg_temp.as_user('a');
select is(pg_temp.code(pg_temp.m(20, 'attachment', 'upsert', pg_temp.att(1), pg_temp.g(1), pg_temp.photo(1))),
  'applied', 'Asha attaches a photo');
select is(pg_temp.code(pg_temp.m(21, 'attachment', 'upsert', pg_temp.att(2), pg_temp.g(1),
  pg_temp.photo(2, null, pg_temp.g(3) || '/' || pg_temp.e(1) || '/' || pg_temp.att(2) || '-thumb.jpg'))),
  'INVALID_ATTACHMENT', 'attack: a thumbnail path in another group''s folder is refused');
select is(pg_temp.code(pg_temp.m(22, 'attachment', 'upsert', pg_temp.att(3), pg_temp.g(1),
  pg_temp.photo(3, pg_temp.g(1) || '/../' || pg_temp.g(3) || '/' || pg_temp.e(1) || '/' || pg_temp.att(3) || '.jpg'))),
  'INVALID_ATTACHMENT', 'attack: a path with .. segments is refused');
select is(pg_temp.code(pg_temp.m(23, 'attachment', 'upsert', pg_temp.att(4), pg_temp.g(1),
  pg_temp.photo(4, null, null, 0))), 'INVALID_VALUE', 'an empty file is refused');
select lives_ok(format($$ insert into storage.objects (bucket_id, name, owner_id) values ('expense-files', %L, %L) $$,
                       pg_temp.xpath(1), pg_temp.uid('a')),
  'Asha uploads her photo');
select pg_temp.as_user('b');
select is(pg_temp.touch(pg_temp.xpath(1)), 0,
  'attack: a co-member can not overwrite another member''s file (rule 9)');
select pg_temp.as_user('a');
select is(pg_temp.touch(pg_temp.xpath(1)), 1, 'the uploader can still replace her own file (an upload retry)');
select pg_temp.as_user('c');
select throws_ok(format($$ insert into storage.objects (bucket_id, name, owner_id) values ('expense-files', %L, %L) $$,
                        replace(pg_temp.xpath(1), '.jpg', '-thumb.jpg'), pg_temp.uid('c')),
  '42501', null, 'attack: a member who left can not upload a registered file');

-- ------------------------------------------------------------------ whiteboard (0026)
select pg_temp.as_user('a');
select is(pg_temp.code(pg_temp.m(30, 'group', 'upsert', pg_temp.g(4), pg_temp.g(4), '{"whiteboard": "x"}')),
  'applied', 'an archived group''s whiteboard stays editable (group settings, like unarchiving; no money moves)');
select pg_temp.as_user('c');
select is(pg_temp.code(pg_temp.m(31, 'group', 'upsert', pg_temp.g(1), pg_temp.g(1), '{"whiteboard": "hijack"}')),
  'NOT_MEMBER', 'attack: a member who left can not edit the whiteboard');
select pg_temp.as_user('a');
select is((select whiteboard from public.groups where id = pg_temp.g(1)), null::text, 'the whiteboard is unchanged');

-- ------------------------------------------------------------------ reminders (0016 with 0026/0028 groups)
select is(pg_temp.err(format('select public.send_reminder(%L, %L)', pg_temp.g(1), pg_temp.mem('c', 1))),
  'MEMBER_NOT_FOUND', 'a member who left can not be reminded');
select is(pg_temp.err(format('select public.send_reminder(%L, %L)', pg_temp.g(4), pg_temp.mem('b', 4))),
  'GROUP_ARCHIVED', 'no reminders in an archived group');
select is(pg_temp.err(format('select public.send_reminder(%L, %L)', pg_temp.g(1), pg_temp.mem('b', 3))),
  'MEMBER_NOT_FOUND', 'attack: a member id of another group is not found');

-- ------------------------------------------------------------------ batch settle-up pushes (0030)
select is((select string_agg(r ->> 'status', ',' order by i) from jsonb_array_elements(public.apply_mutations(
             jsonb_build_array(
               pg_temp.pay(41, 1, 'a', 'b', 1000, 'c3160000-0000-4000-8000-000000000001'),
               pg_temp.pay(42, 3, 'a', 'b', 2000, 'c3160000-0000-4000-8000-000000000001'),
               pg_temp.pay(43, 6, 'a', 'd', 3000, 'c3160000-0000-4000-8000-000000000001'),
               pg_temp.pay(44, 7, 'a', 'd', 4000, 'c3160000-0000-4000-8000-000000000001'),
               pg_temp.pay(45, 5, 'b', 'c', 500, 'c3160000-0000-4000-8000-000000000001'))) -> 'results')
             with ordinality as t(r, i)),
  'applied,applied,applied,applied,rejected', 'a batch with a payment in a group Asha is not in: that one is refused');
reset role;
select is(pg_temp.states('b', 'c3160000-0000-4000-8000-000000000001'), 'batched,pending',
  'Bina: one push for her two payments');
select is(pg_temp.states('d', 'c3160000-0000-4000-8000-000000000001'), 'batched,pending',
  'Dev: one push for his two');
select is(pg_temp.states('c', 'c3160000-0000-4000-8000-000000000001'), '-', 'the refused payment told nobody');
set local role authenticated;
select pg_temp.as_user('b');
select is(pg_temp.code(pg_temp.pay(46, 5, 'b', 'c', 700, 'c3160000-0000-4000-8000-000000000001')), 'applied',
  'Bina replays the batch id from her bell in another group');
reset role;
select is(pg_temp.states('d', 'c3160000-0000-4000-8000-000000000001'), 'batched,pending',
  'attack: Dev''s covered row is not pushed again');
select is(pg_temp.states('b', 'c3160000-0000-4000-8000-000000000001'), 'batched,pending', 'nor Bina''s own');
select is(pg_temp.states('c', 'c3160000-0000-4000-8000-000000000001'), 'pending',
  'Chetan gets one ordinary push for the replayed payment');

-- ------------------------------------------------------------------ monthly summary (0030)
set local role authenticated;
select pg_temp.as_user('b');
select lives_ok($$ select public.upsert_notification_settings('{"summary": {"push": true}}'::jsonb, null) $$,
  'Bina asks for the monthly summary');
reset role;
select ok(private.send_monthly_summaries('2026-12-01') >= 1, 'the summary job runs');
select is((select n.body like 'You spent ' || fm.s500 || ' across 1 group %' from public.notifications n, fm
           where n.user_id = pg_temp.uid('b') and n.kind = 'summary'), true,
  'Bina''s summary counts only live groups she is still in (not the one she left, not a deleted one)');

select * from finish();
rollback;
