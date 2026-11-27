-- 0025 Personal friend codes (D-034 WP-B B4; planning/research/11-splitwise-gap-plan.md F7).
--
-- Every account can have one friend code: 8 Crockford base32 characters like group invite codes (0010), shown
-- ABCD-EFGH, QR / link `splitify://friend?code=ABCDEFGH`. Scanning or opening someone's code adds them as a
-- friend: the one `direct` group of the two accounts is found or created with BOTH members linked (unlike
-- find_or_create_direct_group, 0014, no shared group is needed first: the code is the consent). Online-only
-- RPCs; wrong codes count against the same 10-an-hour limit as group joins (`join_attempts`, 0010).
--
-- RLS: a user can read only their own row; nobody writes the table directly (the RPCs are security definer).

-- ------------------------------------------------------------------ table

create table public.friend_codes (
  user_id uuid primary key references auth.users (id) on delete cascade,
  code text not null unique check (code ~ '^[0-9A-HJKMNP-TV-Z]{8}$'),
  created_at timestamptz not null default now(),
  rotated_at timestamptz not null default now()
);

alter table public.friend_codes enable row level security;

create policy friend_codes_select_own on public.friend_codes for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.friend_codes from public, anon, authenticated;
grant select on public.friend_codes to authenticated;

-- ------------------------------------------------------------------ helpers

-- Same alphabet and distribution as private.new_invite_code (0010), unique among friend codes.
create or replace function private.new_friend_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alpha constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_bytes bytea;
  v_code text;
  i int;
begin
  loop
    v_bytes := extensions.gen_random_bytes(8);
    v_code := '';
    for i in 0..7 loop
      v_code := v_code || substr(v_alpha, (get_byte(v_bytes, i) % 32) + 1, 1);
    end loop;
    exit when not exists (select 1 from public.friend_codes f where f.code = v_code);
  end loop;
  return v_code;
end;
$$;

-- ------------------------------------------------------------------ RPCs

-- The caller's code, made on first use. Returns the code text.
create or replace function public.my_friend_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_code text;
begin
  select f.code into v_code from public.friend_codes f where f.user_id = v_uid;
  if v_code is null then
    insert into public.friend_codes (user_id, code) values (v_uid, private.new_friend_code())
    on conflict (user_id) do nothing;
    select f.code into v_code from public.friend_codes f where f.user_id = v_uid;
  end if;
  return v_code;
end;
$$;

-- A new code for the caller; the old one stops working at once. Returns the new code.
create or replace function public.rotate_friend_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_code text := private.new_friend_code();
begin
  insert into public.friend_codes as f (user_id, code) values (v_uid, v_code)
  on conflict (user_id) do update set code = excluded.code, rotated_at = now();
  return v_code;
end;
$$;

-- Adds the code's owner as the caller's friend: their live direct group (both active members), or a new one
-- with both accounts linked. Returns {group_id, member_id (the friend's), my_member_id, friend_user_id,
-- friend_name, status: found|created}, or {error: INVALID_CODE} (a wrong code, counted for the rate limit) /
-- {error: OWN_CODE}. Raises RATE_LIMITED after 10 wrong codes or invite codes in an hour.
create or replace function public.add_friend_by_code(code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_friend uuid;
  v_key text;
  v_group uuid;
  v_me uuid;
  v_them uuid;
  v_my_name text;
  v_their_name text;
  v_currency text;
begin
  perform private.check_join_rate(v_uid);
  select f.user_id, coalesce(nullif(btrim(p.display_name), ''), 'Friend') into v_friend, v_their_name
  from public.friend_codes f
  join public.profiles p on p.id = f.user_id and p.deleted_at is null
  where f.code = private.normalize_invite_code(add_friend_by_code.code);
  if v_friend is null then
    insert into public.join_attempts (user_id) values (v_uid);
    return jsonb_build_object('error', 'INVALID_CODE');
  end if;
  if v_friend = v_uid then
    return jsonb_build_object('error', 'OWN_CODE');
  end if;

  -- Already friends: the live direct group where both are active members (the keyed one first, like 0014).
  select g.id, a.id, b.id into v_group, v_me, v_them
  from public.groups g
  join public.group_members a on a.group_id = g.id and a.user_id = v_uid and a.status = 'active'
    and a.deleted_at is null
  join public.group_members b on b.group_id = g.id and b.user_id = v_friend and b.status = 'active'
    and b.deleted_at is null
  where g.type = 'direct' and g.deleted_at is null
  order by (g.direct_key is null), g.created_at, g.id
  limit 1;
  if v_group is not null then
    return jsonb_build_object('group_id', v_group, 'member_id', v_them, 'my_member_id', v_me,
                              'friend_user_id', v_friend, 'friend_name', v_their_name, 'status', 'found');
  end if;

  -- Sorted pair of account ids; left out when an old (deleted or left) direct group still holds it.
  v_key := least(v_uid::text, v_friend::text) || ':' || greatest(v_uid::text, v_friend::text);
  if exists (select 1 from public.groups g where g.direct_key = v_key) then
    v_key := null;
  end if;
  select coalesce(nullif(btrim(p.display_name), ''), 'Me'), coalesce(p.default_currency::text, 'INR')
  into v_my_name, v_currency
  from public.profiles p where p.id = v_uid;
  v_my_name := coalesce(v_my_name, 'Me');
  v_currency := coalesce(v_currency, 'INR');

  v_group := gen_random_uuid();
  v_me := gen_random_uuid();
  v_them := gen_random_uuid();
  begin
    insert into public.groups (id, name, type, main_currency, direct_key, created_by, updated_at, updated_by,
                               client_updated_at)
    values (v_group, left(v_my_name || ' & ' || v_their_name, 60), 'direct', v_currency, v_key,
            v_uid, now(), v_uid, now());
  exception when unique_violation then
    -- The friend added us at the same moment: use theirs.
    select g.id into v_group from public.groups g where g.direct_key = v_key and g.deleted_at is null;
    select m.id into v_me from public.group_members m
    where m.group_id = v_group and m.user_id = v_uid and m.status = 'active' and m.deleted_at is null;
    select m.id into v_them from public.group_members m
    where m.group_id = v_group and m.user_id = v_friend and m.status = 'active' and m.deleted_at is null;
    if v_group is null or v_me is null or v_them is null then
      perform private.fail('DIRECT_GROUP_BUSY');
    end if;
    return jsonb_build_object('group_id', v_group, 'member_id', v_them, 'my_member_id', v_me,
                              'friend_user_id', v_friend, 'friend_name', v_their_name, 'status', 'found');
  end;
  insert into public.group_members (id, group_id, user_id, display_name, position, role, status, tint, created_by,
                                    updated_at, updated_by, client_updated_at)
  values
    (v_me, v_group, v_uid, left(v_my_name, 50), 0, 'owner', 'active', 0, v_uid, now(), v_uid, now()),
    (v_them, v_group, v_friend, left(v_their_name, 50), 1, 'member', 'active', 1, v_uid, now(), v_uid, now());

  insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
  select 'groups', g.id, g.id, 'insert', to_jsonb(g), v_uid, now() from public.groups g where g.id = v_group;
  insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
  select 'group_members', m.id, m.group_id, 'insert', to_jsonb(m), v_uid, now()
  from public.group_members m where m.group_id = v_group;
  -- The code's owner hears that someone added them (activity → notification, kind `groups`).
  insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
  values (v_group, v_uid, v_me, 'member_joined', 'member', v_me,
          jsonb_build_object('member_id', v_me, 'name', left(v_my_name, 50), 'via', 'friend_code'));

  return jsonb_build_object('group_id', v_group, 'member_id', v_them, 'my_member_id', v_me,
                            'friend_user_id', v_friend, 'friend_name', v_their_name, 'status', 'created');
end;
$$;

-- ------------------------------------------------------------------ grants

revoke all on function private.new_friend_code() from public, anon, authenticated;
revoke all on function public.my_friend_code() from public, anon;
revoke all on function public.rotate_friend_code() from public, anon;
revoke all on function public.add_friend_by_code(text) from public, anon;
grant execute on function public.my_friend_code() to authenticated;
grant execute on function public.rotate_friend_code() to authenticated;
grant execute on function public.add_friend_by_code(text) to authenticated;
