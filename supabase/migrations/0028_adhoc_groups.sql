-- 0028 Ad-hoc groups (Wave 2 F11, S-420..S-423): "With you and" takes several friends without a group, like
-- Splitwise. The expense goes into a hidden ad-hoc group (hidden from the Groups grid and pickers on the phone;
-- shown under each friend's page and in their totals). Members, RLS (groups_select / is_member, 0005), sync,
-- activity and notifications are the normal group ones, so an ad-hoc group is only visible to its members.
-- Additive only: a new column, new functions and new triggers; the 0004 type check and every older function stay.
--   * groups.is_adhoc (S-420). The phone makes the group offline through apply_mutations with type 'adhoc'
--     (rule 6); a BEFORE trigger stores it as type 'other' + is_adhoc, so the type check is unchanged. The flag
--     never changes afterwards, and a normal group can't become ad-hoc or direct (or stop being direct): a member
--     can't hide a group from everyone's grid (S-422).
--   * A person picked from another group gets the member id `origin member id XOR ad-hoc group id` (S-421), so
--     every phone that knows the origin shows them as the same friend. When the origin has an account and the
--     person adding shares the origin's live group, the new member is linked to that account at once
--     (apply_mutations never sets user_id itself). No groups with strangers: an origin from a group the adder is
--     not in stays a name-only member.
--   * Claims follow (S-423): when a name-only member is claimed by an account (join with claim), the ad-hoc
--     members derived from it are claimed for that account too, if the person who added them is an active member
--     of the claimed member's group. Each claim is logged (member_claimed) and can cascade one level further.
--   * A day cap of 100 new ad-hoc groups per person (the phone reuses the group of the same people).

-- ------------------------------------------------------------------ column

alter table public.groups add column if not exists is_adhoc boolean not null default false;

create index if not exists groups_adhoc_created_by_idx on public.groups (created_by, created_at) where is_adhoc;

-- ------------------------------------------------------------------ helpers

-- Bitwise XOR of two ids (the derived member id of a person picked from another group, S-421).
create or replace function private.uuid_xor(a uuid, b uuid)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select (lpad(to_hex(('x' || substr(x.ha, 1, 16))::bit(64)::bigint # ('x' || substr(x.hb, 1, 16))::bit(64)::bigint),
               16, '0')
       || lpad(to_hex(('x' || substr(x.ha, 17, 16))::bit(64)::bigint # ('x' || substr(x.hb, 17, 16))::bit(64)::bigint),
               16, '0'))::uuid
  from (select replace(a::text, '-', '') as ha, replace(b::text, '-', '') as hb) x;
$$;

-- ------------------------------------------------------------------ groups: type 'adhoc' -> is_adhoc

create or replace function private.groups_adhoc_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.is_adhoc := coalesce(new.type = 'adhoc', false);
    if new.is_adhoc then
      new.type := 'other';
      new.direct_key := null;
      if new.created_by is not null
         and (select count(*) from public.groups g
              where g.created_by = new.created_by and g.is_adhoc and g.created_at > now() - interval '1 day') >= 100 then
        perform private.fail('RATE_LIMITED');
      end if;
    end if;
    return new;
  end if;
  new.is_adhoc := old.is_adhoc;
  if old.is_adhoc then
    -- The phone keeps 'adhoc' as the type; the server keeps 'other'.
    new.type := 'other';
  elsif new.type = 'adhoc' or ((new.type = 'direct') <> (old.type = 'direct')) then
    perform private.fail('TYPE_LOCKED');
  end if;
  return new;
end;
$$;

-- "0_" sorts before groups_a_limits / groups_guard: the row is mapped before any other check.
create or replace trigger groups_0_adhoc before insert or update on public.groups
  for each row execute function private.groups_adhoc_guard();

-- ------------------------------------------------------------------ members: a picked person keeps their account

create or replace function private.adhoc_member_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_origin public.group_members;
begin
  if new.user_id is not null or v_uid is null
     or not exists (select 1 from public.groups g where g.id = new.group_id and g.is_adhoc) then
    return new;
  end if;
  select o.* into v_origin from public.group_members o where o.id = private.uuid_xor(new.id, new.group_id);
  if v_origin.id is null or v_origin.user_id is null or v_origin.user_id = v_uid
     or v_origin.group_id = new.group_id or v_origin.status <> 'active' or v_origin.deleted_at is not null then
    return new;
  end if;
  -- Only someone who shares the origin's live group links that person (no groups with strangers by id).
  if not exists (select 1 from public.group_members me
                 join public.groups og on og.id = me.group_id
                 where me.group_id = v_origin.group_id and me.user_id = v_uid and me.status = 'active'
                   and me.deleted_at is null and og.deleted_at is null) then
    return new;
  end if;
  if exists (select 1 from public.group_members x
             where x.group_id = new.group_id and x.user_id = v_origin.user_id) then
    return new;
  end if;
  new.user_id := v_origin.user_id;
  new.claimed_at := now();
  return new;
end;
$$;

create or replace trigger group_members_0_adhoc_link before insert on public.group_members
  for each row execute function private.adhoc_member_link();

-- ------------------------------------------------------------------ claims follow into ad-hoc groups

create or replace function private.claim_adhoc_people()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  for r in
    select distinct gm.id
    from public.group_members c
    join public.group_members a on a.user_id = c.user_id and a.status = 'active' and a.deleted_at is null
    join public.groups g on g.id = a.group_id and g.is_adhoc and g.deleted_at is null
    join public.group_members gm on gm.id = private.uuid_xor(new.id, g.id) and gm.group_id = g.id
    where c.group_id = new.group_id and c.user_id is not null and c.user_id <> new.user_id
      and c.status = 'active' and c.deleted_at is null
      and gm.created_by = c.user_id and gm.user_id is null and gm.status = 'active' and gm.deleted_at is null
      and not exists (select 1 from public.group_members x where x.group_id = g.id and x.user_id = new.user_id)
  loop
    update public.group_members
    set user_id = new.user_id, claimed_at = now(), updated_at = now(), updated_by = new.user_id,
        client_updated_at = now()
    where id = r.id and user_id is null;
    perform private.member_changed(r.id, new.user_id, r.id, 'member_claimed', '{"adhoc": true}'::jsonb);
  end loop;
  return null;
end;
$$;

create or replace trigger group_members_claim_adhoc after update of user_id on public.group_members
  for each row when (old.user_id is null and new.user_id is not null)
  execute function private.claim_adhoc_people();

-- ------------------------------------------------------------------ grants

revoke all on function private.uuid_xor(uuid, uuid) from public, anon, authenticated;
revoke all on function private.groups_adhoc_guard() from public, anon, authenticated;
revoke all on function private.adhoc_member_link() from public, anon, authenticated;
revoke all on function private.claim_adhoc_people() from public, anon, authenticated;
