-- Group RPCs (0010): invite code format/normalise (TC-3-01 server side), preview/join/rotate/rate limit (TC-3-02),
-- claim/unlink rules (TC-4-01), cannot claim a linked member (TC-4-02), archived group rejects expenses (TC-1-03),
-- only the creator deletes/restores (TC-1-07), leave/remove need zero nets, activity rows, auth and grants.
begin;
select plan(44);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000a1', 'grp-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000000b1', 'grp-b@splitify.test', '{"full_name": "Bina"}'),
  ('00000000-0000-4000-8000-0000000000c1', 'grp-c@splitify.test', '{"full_name": "Chirag"}'),
  ('00000000-0000-4000-8000-0000000000d1', 'grp-d@splitify.test', '{"full_name": "Dev"}'),
  ('00000000-0000-4000-8000-0000000000e1', 'grp-e@splitify.test', '{"full_name": "Esha"}');

create temp table res (k text primary key, v jsonb);

create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000000' || p || '","role":"authenticated"}', true);
$$;
create function pg_temp.m(p_mid text, p_entity text, p_op text, p_id text, p_data jsonb default '{}'::jsonb)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', '45000000-0000-4000-8000-0000000000' || p_mid, 'entity', p_entity, 'op', p_op, 'id', p_id,
    'group_id', '50000000-0000-4000-8000-000000000001', 'base_seq', null, 'client_updated_at', now(),
    'source', 'app', 'data', p_data);
$$;
create function pg_temp.apply(p jsonb) returns jsonb language sql as $$
  select public.apply_mutations(jsonb_build_array(p)) -> 'results' -> 0;
$$;
create function pg_temp.code() returns text language sql stable as $$
  select invite_code from public.groups where id = '50000000-0000-4000-8000-000000000001';
$$;
create function pg_temp.mem(p text) returns uuid language sql stable as $$
  select ('51000000-0000-4000-8000-0000000000' || p)::uuid;
$$;

-- A creates "Goa trip" with name-only Rahul (e1) and Priya (e2).
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('01', 'group', 'upsert', '50000000-0000-4000-8000-000000000001',
  '{"name": "Goa trip", "type": "trip",
    "owner_member": {"id": "51000000-0000-4000-8000-0000000000a1", "display_name": "Asha"}}'));
select pg_temp.apply(pg_temp.m('02', 'member', 'upsert', '51000000-0000-4000-8000-0000000000e1',
  '{"display_name": "Rahul", "position": 1}'));
select pg_temp.apply(pg_temp.m('03', 'member', 'upsert', '51000000-0000-4000-8000-0000000000e2',
  '{"display_name": "Priya", "position": 2}'));

select matches(pg_temp.code(), '^[0-9A-HJKMNP-TV-Z]{8}$', 'a new group gets an 8-char Crockford code');
select is(private.normalize_invite_code('abcd-efgh'), 'ABCDEFGH', 'codes ignore case and dashes');
select is(private.normalize_invite_code(' o1l-i '), '0111', 'O reads as 0, I and L as 1');
insert into res values ('code1', to_jsonb(pg_temp.code()));

-- B previews with a lowercase, dashed code.
select pg_temp.as_user('b1');
insert into res select 'preview', public.preview_join(lower(left(pg_temp.code(), 4) || '-' || right(pg_temp.code(), 4)));
select is((select v -> 'group' ->> 'name' from res where k = 'preview'), 'Goa trip', 'preview shows the group');
select is((select v -> 'group' ->> 'member_count' from res where k = 'preview'), '3', 'preview counts members');
select is((select jsonb_path_query_array(v, '$.unclaimed[*].display_name') from res where k = 'preview'),
  '["Rahul", "Priya"]'::jsonb, 'preview lists unclaimed name-only spots in order');
select is((select v ->> 'already_member' from res where k = 'preview'), 'false', 'B is not a member yet');
select is(public.preview_join('ZZZZ-ZZZZ') ->> 'error', 'INVALID_CODE', 'a wrong code is INVALID_CODE');

-- B claims Rahul.
insert into res select 'claim', public.join_group(pg_temp.code(), pg_temp.mem('e1'));
select is((select v ->> 'status' from res where k = 'claim'), 'claimed', 'B claims Rahul');
select is((select user_id::text || ':' || (claimed_at is not null)::text from public.group_members
           where id = pg_temp.mem('e1')),
  '00000000-0000-4000-8000-0000000000b1:true', 'the claimed spot is linked to B');
select is((select count(*)::int from public.activity
           where target_id = pg_temp.mem('e1') and type = 'member_claimed' and actor_user_id = (select auth.uid())),
  1, 'member_claimed activity');
select is(public.join_group(pg_temp.code()) ->> 'status', 'already_member', 'joining again is idempotent');

-- C cannot take a linked spot, joins as new.
select pg_temp.as_user('c1');
select throws_ok(format('select public.join_group(%L, %L)', pg_temp.code(), pg_temp.mem('e1')),
  'P0001', 'ALREADY_CLAIMED', 'a linked member cannot be claimed again');
insert into res select 'joinc', public.join_group(pg_temp.code());
select is((select v ->> 'status' from res where k = 'joinc'), 'joined', 'C joins as a new member');
select is((select display_name || ':' || role || ':' || position from public.group_members
           where id = (select (v ->> 'member_id')::uuid from res where k = 'joinc')),
  'Chirag:member:3', 'the new member takes the profile name and the next position');
select is((select count(*)::int from public.activity where type = 'member_joined'
           and target_id = (select (v ->> 'member_id')::uuid from res where k = 'joinc')), 1, 'member_joined activity');
select ok(private.is_member('50000000-0000-4000-8000-000000000001'), 'C is now a member');

-- Rotate: any member; the old code stops working.
select isnt(public.rotate_invite_code('50000000-0000-4000-8000-000000000001'), (select v #>> '{}' from res where k = 'code1'),
  'rotate gives a new code');
select is(public.preview_join((select v #>> '{}' from res where k = 'code1')) ->> 'error', 'INVALID_CODE',
  'the old code no longer works');
select pg_temp.as_user('d1');
select throws_ok($$select public.rotate_invite_code('50000000-0000-4000-8000-000000000001')$$,
  'P0001', 'NOT_MEMBER', 'a non-member cannot rotate the code');

-- Rate limit: 10 wrong codes per hour.
select is((select count(*)::int from generate_series(1, 10) s, lateral (select public.preview_join('ZZZZZZZZ')) x),
  10, 'ten wrong tries run');
select is((select count(*)::int from public.join_attempts where user_id = '00000000-0000-4000-8000-0000000000d1'),
  10, 'wrong tries are recorded');
select throws_ok(format('select public.preview_join(%L)', pg_temp.code()), 'P0001', 'RATE_LIMITED',
  'the 11th try is rate limited, even with a valid code');
select throws_ok(format('select public.join_group(%L)', pg_temp.code()), 'P0001', 'RATE_LIMITED',
  'join is rate limited too');

-- Unlink a wrong claim.
select pg_temp.as_user('a1');
select is(public.unlink_member('50000000-0000-4000-8000-000000000001', pg_temp.mem('e1')) ->> 'status', 'unlinked',
  'any member can unlink a claim');
select is((select (user_id is null and claimed_at is null)::text from public.group_members where id = pg_temp.mem('e1')),
  'true', 'the spot is name-only again');
select is((select count(*)::int from public.activity where target_id = pg_temp.mem('e1') and type = 'group_updated'
           and data ->> 'unlinked' = 'true'), 1, 'unlink is in the activity log');
select throws_ok($$select public.unlink_member('50000000-0000-4000-8000-000000000001',
  '51000000-0000-4000-8000-0000000000a1')$$, 'P0001', 'NOT_CLAIMED', 'the creator spot was never claimed');
select pg_temp.as_user('b1');
select ok(not private.is_member('50000000-0000-4000-8000-000000000001'), 'B lost access after the unlink');

-- Leave/remove need zero nets: A paid 1000 split with C.
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('04', 'expense', 'upsert', '52000000-0000-4000-8000-000000000001',
  jsonb_build_object('description', 'Dinner', 'date', '2026-11-01', 'currency', 'INR', 'total', 1000,
    'payers', jsonb_build_object(pg_temp.mem('a1'), 1000),
    'shares', jsonb_build_object(pg_temp.mem('a1'), 500, (select v ->> 'member_id' from res where k = 'joinc'), 500))));
select throws_ok(format('select public.remove_member(%L, %L)', '50000000-0000-4000-8000-000000000001',
  (select v ->> 'member_id' from res where k = 'joinc')), 'P0001', 'NONZERO_BALANCE', 'cannot remove someone who owes');
select is(public.remove_member('50000000-0000-4000-8000-000000000001', pg_temp.mem('e2')) ->> 'status', 'removed',
  'a settled name-only member can be removed');
select is((select count(*)::int from public.activity where target_id = pg_temp.mem('e2') and type = 'member_removed'),
  1, 'member_removed activity');
select pg_temp.as_user('c1');
select throws_ok($$select public.leave_group('50000000-0000-4000-8000-000000000001')$$, 'P0001', 'NONZERO_BALANCE',
  'cannot leave while owing');
select pg_temp.apply(pg_temp.m('05', 'payment', 'upsert', '53000000-0000-4000-8000-000000000001',
  jsonb_build_object('from_member', (select v ->> 'member_id' from res where k = 'joinc'), 'to_member', pg_temp.mem('a1'),
    'amount', 500, 'currency', 'INR', 'date', '2026-11-02')));
select is(public.leave_group('50000000-0000-4000-8000-000000000001') ->> 'status', 'left', 'settled: C can leave');
select is(public.join_group(pg_temp.code()) ->> 'member_id', (select v ->> 'member_id' from res where k = 'joinc'),
  'rejoining brings the old spot back');

-- Archived: no new expenses (TC-1-03), but people can still join.
select pg_temp.as_user('a1');
select pg_temp.apply(pg_temp.m('06', 'group', 'upsert', '50000000-0000-4000-8000-000000000001',
  jsonb_build_object('archived_at', now())));
select is(pg_temp.apply(pg_temp.m('07', 'expense', 'upsert', '52000000-0000-4000-8000-000000000002',
  jsonb_build_object('description', 'Taxi', 'date', '2026-11-03', 'currency', 'INR', 'total', 100,
    'payers', jsonb_build_object(pg_temp.mem('a1'), 100), 'shares', jsonb_build_object(pg_temp.mem('a1'), 100))))
  ->> 'code', 'GROUP_ARCHIVED', 'an archived group rejects new expenses');
select pg_temp.as_user('e1');
select is(public.preview_join(pg_temp.code()) -> 'group' ->> 'archived', 'true', 'preview flags an archived group');
select is(public.join_group(pg_temp.code()) ->> 'status', 'joined', 'an archived group can still be joined');

-- Delete/restore: creator only (TC-1-07).
select is(pg_temp.apply(pg_temp.m('08', 'group', 'delete', '50000000-0000-4000-8000-000000000001')) ->> 'code',
  'NOT_CREATOR', 'a member who did not create the group cannot delete it');
select pg_temp.as_user('a1');
select is(pg_temp.apply(pg_temp.m('09', 'group', 'delete', '50000000-0000-4000-8000-000000000001')) ->> 'status',
  'applied', 'the creator deletes the group');
select is(pg_temp.apply(pg_temp.m('10', 'group', 'restore', '50000000-0000-4000-8000-000000000001')) ->> 'status',
  'applied', 'the creator restores it');

-- Auth and grants.
select ok(not has_function_privilege('anon', 'public.join_group(text, uuid)', 'execute'), 'anon cannot join');
select ok(has_function_privilege('authenticated', 'public.preview_join(text)', 'execute'), 'users can preview');
select set_config('request.jwt.claims', '{}', true);
select throws_ok($$select public.preview_join('ABCDEFGH')$$, 'P0001', 'NOT_AUTHENTICATED', 'needs a signed-in user');

select * from finish();
rollback;
