-- 0014 Friends and simplify debts (phase 11; planning/08-feature-specs.md #2 #16 #17, 03-backend.md §4).
--
-- find_or_create_direct_group(friend_user_id): the one hidden `direct` group of two accounts (TC-2-01). Online
-- RPC, because the friend's member row is linked to their account (apply_mutations never sets user_id). A friend
-- who has no account (name-only) gets a direct group created offline through apply_mutations like any group
-- (S-120). Only people you already share a group with can be picked (no groups with strangers by id).
--
-- settings_changed (T3): a group edit that only changes simplify debts or the default split is logged as
-- `settings_changed` with the new value instead of `group_updated`. Done with two triggers (groups → a
-- transaction-local note → activity), so private.sync_apply_one (0009) stays untouched (other phases extend it).

-- ------------------------------------------------------------------ direct groups

-- Returns {group_id, member_id (the friend's), my_member_id, status: found|created}.
create or replace function public.find_or_create_direct_group(friend_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_friend uuid := find_or_create_direct_group.friend_user_id;
  v_key text;
  v_group uuid;
  v_me uuid;
  v_them uuid;
  v_my_name text;
  v_their_name text;
  v_currency text;
begin
  if v_friend is null or v_friend = v_uid then
    perform private.fail('INVALID_FRIEND');
  end if;
  -- The friend must share a live group with the caller.
  select coalesce(p.display_name, b.display_name) into v_their_name
  from public.group_members a
  join public.group_members b on b.group_id = a.group_id
  join public.groups g on g.id = a.group_id
  left join public.profiles p on p.id = b.user_id
  where a.user_id = v_uid and a.status = 'active' and a.deleted_at is null
    and b.user_id = v_friend and b.status = 'active' and b.deleted_at is null
    and g.deleted_at is null
  order by g.created_at, g.id
  limit 1;
  if v_their_name is null then
    perform private.fail('NOT_FRIEND');
  end if;

  -- Already there: the live direct group where both are active members (the keyed one first).
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
    return jsonb_build_object('group_id', v_group, 'member_id', v_them, 'my_member_id', v_me, 'status', 'found');
  end if;

  -- Sorted pair of account ids; left out when an old (deleted or left) direct group still holds it.
  v_key := least(v_uid::text, v_friend::text) || ':' || greatest(v_uid::text, v_friend::text);
  if exists (select 1 from public.groups g where g.direct_key = v_key) then
    v_key := null;
  end if;
  select coalesce(p.display_name, 'Me'), coalesce(p.default_currency::text, 'INR') into v_my_name, v_currency
  from public.profiles p where p.id = v_uid;
  v_my_name := coalesce(v_my_name, 'Me');
  v_currency := coalesce(v_currency, 'INR');

  v_group := gen_random_uuid();
  v_me := gen_random_uuid();
  v_them := gen_random_uuid();
  begin
    insert into public.groups (id, name, type, main_currency, direct_key, created_by, updated_at, updated_by,
                               client_updated_at)
    values (v_group, left(btrim(v_my_name) || ' & ' || btrim(v_their_name), 60), 'direct', v_currency, v_key,
            v_uid, now(), v_uid, now());
  exception when unique_violation then
    -- The friend created it at the same moment: use theirs.
    select g.id into v_group from public.groups g where g.direct_key = v_key and g.deleted_at is null;
    select m.id into v_me from public.group_members m
    where m.group_id = v_group and m.user_id = v_uid and m.status = 'active' and m.deleted_at is null;
    select m.id into v_them from public.group_members m
    where m.group_id = v_group and m.user_id = v_friend and m.status = 'active' and m.deleted_at is null;
    if v_group is null or v_me is null or v_them is null then
      perform private.fail('DIRECT_GROUP_BUSY');
    end if;
    return jsonb_build_object('group_id', v_group, 'member_id', v_them, 'my_member_id', v_me, 'status', 'found');
  end;
  insert into public.group_members (id, group_id, user_id, display_name, position, role, status, tint, created_by,
                                    updated_at, updated_by, client_updated_at)
  values
    (v_me, v_group, v_uid, left(btrim(v_my_name), 50), 0, 'owner', 'active', 0, v_uid, now(), v_uid, now()),
    (v_them, v_group, v_friend, left(btrim(v_their_name), 50), 1, 'member', 'active', 1, v_uid, now(), v_uid, now());

  insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
  select 'groups', g.id, g.id, 'insert', to_jsonb(g), v_uid, now() from public.groups g where g.id = v_group;
  insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
  select 'group_members', m.id, m.group_id, 'insert', to_jsonb(m), v_uid, now()
  from public.group_members m where m.group_id = v_group;
  insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
  select g.id, v_uid, v_me, 'group_created', 'group', g.id,
         jsonb_build_object('name', g.name, 'direct', true, 'friend_member_id', v_them)
  from public.groups g where g.id = v_group;

  return jsonb_build_object('group_id', v_group, 'member_id', v_them, 'my_member_id', v_me, 'status', 'created');
end;
$$;

-- ------------------------------------------------------------------ settings_changed activity

-- A group update that changes only simplify debts or the default split leaves a note for this transaction
-- (cleared by the activity trigger below, rolled back with a failed mutation's savepoint).
create or replace function private.group_settings_note()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if row(new.name, new.type, new.main_currency, new.cover_kind, new.cover_path, new.archived_at, new.deleted_at)
     is not distinct from
     row(old.name, old.type, old.main_currency, old.cover_kind, old.cover_path, old.archived_at, old.deleted_at) then
    if new.simplify_debts is distinct from old.simplify_debts then
      perform set_config('splitify.settings_changed', jsonb_build_object(
        'group_id', new.id, 'setting', 'simplify_debts', 'simplify_debts', new.simplify_debts)::text, true);
    elsif new.default_split is distinct from old.default_split then
      perform set_config('splitify.settings_changed', jsonb_build_object(
        'group_id', new.id, 'setting', 'default_split')::text, true);
    end if;
  end if;
  return null;
end;
$$;

create trigger groups_settings_note after update on public.groups
  for each row execute function private.group_settings_note();

-- The `group_updated` activity of such an update becomes `settings_changed` with the new value.
create or replace function private.activity_settings_type()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_note jsonb := nullif(current_setting('splitify.settings_changed', true), '')::jsonb;
begin
  if v_note is null or new.type <> 'group_updated' or new.target_type is distinct from 'group'
     or new.target_id is distinct from (v_note ->> 'group_id')::uuid then
    return new;
  end if;
  perform set_config('splitify.settings_changed', '', true);
  new.type := 'settings_changed';
  new.data := new.data || (v_note - 'group_id');
  return new;
end;
$$;

create trigger activity_settings_type before insert on public.activity
  for each row execute function private.activity_settings_type();

-- ------------------------------------------------------------------ grants

revoke all on function private.group_settings_note() from public, anon, authenticated;
revoke all on function private.activity_settings_type() from public, anon, authenticated;
revoke all on function public.find_or_create_direct_group(uuid) from public, anon;
grant execute on function public.find_or_create_direct_group(uuid) to authenticated;
