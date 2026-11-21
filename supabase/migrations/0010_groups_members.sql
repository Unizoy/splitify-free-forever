-- 0010 Groups, members, invites (phase 07; planning/03-backend.md §4, 08-feature-specs.md #1 #3 #4).
-- Invite codes (8-char Crockford base32), preview/join/claim with a rate limit, rotate code, leave/remove with the
-- zero-balance rule, unlink a wrong claim, creator-only group delete/restore. All online-only RPCs.

-- ------------------------------------------------------------------ invite codes

-- Crockford base32 without I L O U; 256 % 32 = 0 so every symbol is equally likely.
create or replace function private.new_invite_code()
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
    exit when not exists (select 1 from public.groups g where g.invite_code = v_code);
  end loop;
  return v_code;
end;
$$;

-- What people type: any case, dashes/spaces, O for 0, I/L for 1 (TC-3-01, same as lib/domain/rules/invite_code.dart).
create or replace function private.normalize_invite_code(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select translate(regexp_replace(upper(coalesce(p, '')), '[^0-9A-Z]', '', 'g'), 'OIL', '011');
$$;

-- ------------------------------------------------------------------ guards (triggers)

-- True when the member's net is not zero in some currency (Splitwise rule for leave/remove).
create or replace function private.member_has_balance(p_group uuid, p_member uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from (
      select e.currency, coalesce((e.payers ->> p_member::text)::bigint, 0)
                         - coalesce((e.shares ->> p_member::text)::bigint, 0) as v
      from public.expenses e
      where e.group_id = p_group and e.deleted_at is null
      union all
      select p.currency, case when p.from_member = p_member then p.amount
                              when p.to_member = p_member then -p.amount else 0 end
      from public.payments p
      where p.group_id = p_group and p.deleted_at is null
    ) s
    group by s.currency
    having sum(s.v) <> 0);
$$;

-- New groups get a code; delete/restore is for the creator only, restore within 30 days (TC-1-07).
create or replace function private.groups_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.invite_code is null then
      new.invite_code := private.new_invite_code();
    end if;
    return new;
  end if;
  if (old.deleted_at is null) <> (new.deleted_at is null) then
    if old.created_by is distinct from (select auth.uid()) then
      perform private.fail('NOT_CREATOR');
    end if;
    if new.deleted_at is null and old.deleted_at < now() - interval '30 days' then
      perform private.fail('RESTORE_EXPIRED');
    end if;
  end if;
  return new;
end;
$$;

create trigger groups_guard before insert or update on public.groups
  for each row execute function private.groups_guard();

-- A member leaves the group's balances only when every net is zero (sync deletes and the RPCs alike).
create or replace function private.group_members_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if ((old.deleted_at is null and new.deleted_at is not null)
      or (old.status = 'active' and new.status <> 'active'))
     and private.member_has_balance(new.group_id, new.id) then
    perform private.fail('NONZERO_BALANCE');
  end if;
  return new;
end;
$$;

create trigger group_members_guard before update on public.group_members
  for each row execute function private.group_members_guard();

-- Existing groups (created before this migration) get codes too.
update public.groups set invite_code = private.new_invite_code() where invite_code is null;

-- ------------------------------------------------------------------ helpers

create or replace function private.require_uid()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v uuid := (select auth.uid());
begin
  if v is null then
    perform private.fail('NOT_AUTHENTICATED');
  end if;
  return v;
end;
$$;

-- The caller's active member id in the group, or NOT_MEMBER.
create or replace function private.my_member(p_group uuid, uid uuid)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v uuid;
begin
  select gm.id into v from public.group_members gm
  where gm.group_id = p_group and gm.user_id = uid and gm.status = 'active' and gm.deleted_at is null;
  if v is null then
    perform private.fail('NOT_MEMBER');
  end if;
  return v;
end;
$$;

-- History + activity for a member row the RPCs just changed (rule 9).
create or replace function private.member_changed(p_member uuid, uid uuid, p_actor uuid, p_type text,
                                                  p_extra jsonb default '{}'::jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  gm public.group_members;
begin
  select * into gm from public.group_members where id = p_member;
  insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
  values ('group_members', gm.id, gm.group_id, 'update', to_jsonb(gm), uid, now());
  insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
  values (gm.group_id, uid, p_actor, p_type, 'member', gm.id,
          jsonb_build_object('member_id', gm.id, 'name', gm.display_name) || p_extra);
end;
$$;

-- Rate limit: 10 wrong codes per user per hour (08 #3). Wrong tries are recorded, so callers return (not raise).
create or replace function private.check_join_rate(uid uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if (select count(*) from public.join_attempts a where a.user_id = uid and a.at > now() - interval '1 hour') >= 10
  then
    perform private.fail('RATE_LIMITED');
  end if;
end;
$$;

create or replace function private.group_by_code(p_code text, uid uuid)
returns public.groups
language plpgsql
set search_path = ''
as $$
declare
  g public.groups;
begin
  perform private.check_join_rate(uid);
  select * into g from public.groups x
  where x.invite_code = private.normalize_invite_code(p_code) and x.deleted_at is null;
  if g.id is null then
    insert into public.join_attempts (user_id) values (uid);
  end if;
  return g;
end;
$$;

-- ------------------------------------------------------------------ RPCs

-- Group card + unclaimed name-only spots for the join screen. {error: INVALID_CODE} for a wrong code.
create or replace function public.preview_join(code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  g public.groups;
begin
  g := private.group_by_code(code, v_uid);
  if g.id is null then
    return jsonb_build_object('error', 'INVALID_CODE');
  end if;
  return jsonb_build_object(
    'group', jsonb_build_object(
      'id', g.id, 'name', g.name, 'type', g.type, 'main_currency', g.main_currency, 'cover_kind', g.cover_kind,
      'cover_path', g.cover_path, 'archived', g.archived_at is not null,
      'member_count', (select count(*) from public.group_members m
                       where m.group_id = g.id and m.status = 'active' and m.deleted_at is null)),
    'already_member', exists (select 1 from public.group_members m
                              where m.group_id = g.id and m.user_id = v_uid and m.status = 'active'
                                and m.deleted_at is null),
    'unclaimed', (select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'display_name', m.display_name,
                                                               'tint', m.tint) order by m.position), '[]'::jsonb)
                  from public.group_members m
                  where m.group_id = g.id and m.user_id is null and m.status = 'active' and m.deleted_at is null));
end;
$$;

-- Join as a new member, or claim a name-only spot (#3, #4). Idempotent for current members.
-- Returns {group_id, member_id, status: joined|claimed|rejoined|already_member} or {error: INVALID_CODE}.
create or replace function public.join_group(code text, claim_member_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  g public.groups;
  v_mine public.group_members;
  v_claim public.group_members;
  v_id uuid;
  v_pos int;
begin
  g := private.group_by_code(code, v_uid);
  if g.id is null then
    return jsonb_build_object('error', 'INVALID_CODE');
  end if;

  select * into v_mine from public.group_members m where m.group_id = g.id and m.user_id = v_uid;
  if v_mine.id is not null and v_mine.status = 'active' and v_mine.deleted_at is null then
    return jsonb_build_object('group_id', g.id, 'member_id', v_mine.id, 'status', 'already_member');
  end if;

  if (select count(*) from public.group_members m
      where m.group_id = g.id and m.status = 'active' and m.deleted_at is null) >= 100 then
    perform private.fail('GROUP_FULL');
  end if;

  -- Came back after leaving / being removed: the old spot (and its history) comes back (one member per user).
  if v_mine.id is not null then
    update public.group_members
    set status = 'active', deleted_at = null, deleted_by = null, updated_at = now(), updated_by = v_uid,
        client_updated_at = now()
    where id = v_mine.id;
    perform private.member_changed(v_mine.id, v_uid, v_mine.id, 'member_joined', '{"rejoined": true}'::jsonb);
    return jsonb_build_object('group_id', g.id, 'member_id', v_mine.id, 'status', 'rejoined');
  end if;

  if claim_member_id is not null then
    select * into v_claim from public.group_members m where m.id = claim_member_id and m.group_id = g.id
    for update;
    if v_claim.id is null or v_claim.status <> 'active' or v_claim.deleted_at is not null then
      perform private.fail('MEMBER_NOT_FOUND');
    end if;
    if v_claim.user_id is not null then
      perform private.fail('ALREADY_CLAIMED');
    end if;
    update public.group_members
    set user_id = v_uid, claimed_at = now(), updated_at = now(), updated_by = v_uid, client_updated_at = now()
    where id = v_claim.id;
    perform private.member_changed(v_claim.id, v_uid, v_claim.id, 'member_claimed');
    return jsonb_build_object('group_id', g.id, 'member_id', v_claim.id, 'status', 'claimed');
  end if;

  if g.type = 'direct' then
    perform private.fail('CLAIM_REQUIRED');   -- a friend group has exactly two members (#2)
  end if;

  v_id := gen_random_uuid();
  select coalesce(max(m.position), -1) + 1 into v_pos from public.group_members m where m.group_id = g.id;
  insert into public.group_members (id, group_id, user_id, display_name, position, role, status, tint, claimed_at,
                                    created_by, updated_at, updated_by, client_updated_at)
  values (v_id, g.id, v_uid,
          left(coalesce((select p.display_name from public.profiles p where p.id = v_uid), 'Member'), 50),
          v_pos, 'member', 'active', (v_pos % 5)::smallint, null, v_uid, now(), v_uid, now());
  insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
  select 'group_members', m.id, m.group_id, 'insert', to_jsonb(m), v_uid, now()
  from public.group_members m where m.id = v_id;
  insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
  select g.id, v_uid, v_id, 'member_joined', 'member', v_id, jsonb_build_object('member_id', v_id, 'name', m.display_name)
  from public.group_members m where m.id = v_id;
  return jsonb_build_object('group_id', g.id, 'member_id', v_id, 'status', 'joined');
end;
$$;

-- Any member; the old code stops working at once. Returns the new code.
create or replace function public.rotate_invite_code(group_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_actor uuid := private.my_member(group_id, v_uid);
  v_code text := private.new_invite_code();
  g public.groups;
begin
  update public.groups x
  set invite_code = v_code, invite_rotated_at = now(), updated_at = now(), updated_by = v_uid
  where x.id = rotate_invite_code.group_id
  returning * into g;
  insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
  values ('groups', g.id, g.id, 'update', to_jsonb(g), v_uid, now());
  insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
  values (g.id, v_uid, v_actor, 'group_updated', 'group', g.id,
          jsonb_build_object('name', g.name, 'invite_reset', true));
  return v_code;
end;
$$;

-- Leave: only with zero nets in every currency (trigger raises NONZERO_BALANCE).
create or replace function public.leave_group(group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_me uuid := private.my_member(group_id, v_uid);
begin
  update public.group_members
  set status = 'left', updated_at = now(), updated_by = v_uid, client_updated_at = now()
  where id = v_me;
  perform private.member_changed(v_me, v_uid, v_me, 'member_left');
  return jsonb_build_object('member_id', v_me, 'status', 'left');
end;
$$;

-- Any member removes another (name-only or linked) member with zero nets.
create or replace function public.remove_member(group_id uuid, member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_me uuid := private.my_member(group_id, v_uid);
begin
  if not exists (select 1 from public.group_members m
                 where m.id = remove_member.member_id and m.group_id = remove_member.group_id
                   and m.status = 'active' and m.deleted_at is null) then
    perform private.fail('MEMBER_NOT_FOUND');
  end if;
  update public.group_members m
  set status = 'removed', updated_at = now(), updated_by = v_uid, client_updated_at = now()
  where m.id = remove_member.member_id;
  perform private.member_changed(member_id, v_uid, v_me, 'member_removed');
  return jsonb_build_object('member_id', member_id, 'status', 'removed');
end;
$$;

-- Undo a wrong claim: the spot becomes name-only again and keeps its history (#4). Activity `group_updated`
-- with `unlinked: true` (S-071).
create or replace function public.unlink_member(group_id uuid, member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_me uuid := private.my_member(group_id, v_uid);
begin
  if not exists (select 1 from public.group_members m
                 where m.id = unlink_member.member_id and m.group_id = unlink_member.group_id
                   and m.status = 'active' and m.deleted_at is null) then
    perform private.fail('MEMBER_NOT_FOUND');
  end if;
  if not exists (select 1 from public.group_members m
                 where m.id = unlink_member.member_id and m.claimed_at is not null and m.user_id is not null) then
    perform private.fail('NOT_CLAIMED');
  end if;
  update public.group_members m
  set user_id = null, claimed_at = null, updated_at = now(), updated_by = v_uid, client_updated_at = now()
  where m.id = unlink_member.member_id;
  perform private.member_changed(member_id, v_uid, v_me, 'group_updated', '{"unlinked": true}'::jsonb);
  return jsonb_build_object('member_id', member_id, 'status', 'unlinked');
end;
$$;

-- ------------------------------------------------------------------ grants

revoke all on function private.new_invite_code() from public, anon, authenticated;
revoke all on function private.normalize_invite_code(text) from public, anon, authenticated;
revoke all on function private.member_has_balance(uuid, uuid) from public, anon, authenticated;
revoke all on function private.groups_guard() from public, anon, authenticated;
revoke all on function private.group_members_guard() from public, anon, authenticated;
revoke all on function private.require_uid() from public, anon, authenticated;
revoke all on function private.my_member(uuid, uuid) from public, anon, authenticated;
revoke all on function private.member_changed(uuid, uuid, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function private.check_join_rate(uuid) from public, anon, authenticated;
revoke all on function private.group_by_code(text, uuid) from public, anon, authenticated;
revoke all on function public.preview_join(text) from public, anon;
revoke all on function public.join_group(text, uuid) from public, anon;
revoke all on function public.rotate_invite_code(uuid) from public, anon;
revoke all on function public.leave_group(uuid) from public, anon;
revoke all on function public.remove_member(uuid, uuid) from public, anon;
revoke all on function public.unlink_member(uuid, uuid) from public, anon;
grant execute on function public.preview_join(text) to authenticated;
grant execute on function public.join_group(text, uuid) to authenticated;
grant execute on function public.rotate_invite_code(uuid) to authenticated;
grant execute on function public.leave_group(uuid) to authenticated;
grant execute on function public.remove_member(uuid, uuid) to authenticated;
grant execute on function public.unlink_member(uuid, uuid) to authenticated;
