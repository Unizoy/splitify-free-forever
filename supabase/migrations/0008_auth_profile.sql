-- 0008 Profile RPCs for phase 05 (planning/03-backend.md §4 update_profile, §7 delete-account).
--
-- update_profile(p_display_name, p_upi_id, p_default_currency, p_avatar_path) ->
--   { id, display_name, avatar_path, upi_id, default_currency, updated_at }
--   Self only, full replace: a null/blank UPI id or avatar path removes it.
-- prepare_account_deletion() -> { avatar_path: <old path or null>, groups: <memberships converted> }
--   Called by the delete-account Edge Function with the user's own JWT, before it removes the avatar files and the
--   auth user. Idempotent: a second call converts nothing and returns { avatar_path: null, groups: 0 }.

create or replace function public.update_profile(
  p_display_name text,
  p_upi_id text,
  p_default_currency text,
  p_avatar_path text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_name text := btrim(coalesce(p_display_name, ''));
  v_upi text := nullif(btrim(coalesce(p_upi_id, '')), '');
  v_cur text := btrim(coalesce(p_default_currency, ''));
  v_avatar text := nullif(btrim(coalesce(p_avatar_path, '')), '');
  v_p record;
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'NOT_AUTHENTICATED';
  end if;
  if char_length(v_name) not between 1 and 50 then
    perform private.fail('INVALID_NAME', jsonb_build_object('min', 1, 'max', 50));
  end if;
  -- Same pattern as the profiles.upi_id check (0004).
  if v_upi is not null
     and v_upi !~ '^[a-zA-Z0-9.\-_]{2}[a-zA-Z0-9.\-_]{0,254}@[a-zA-Z][a-zA-Z0-9.\-]{1,63}$' then
    perform private.fail('INVALID_UPI');
  end if;
  -- Length first: an explicit cast to char(3) would silently cut a longer code.
  if char_length(v_cur) <> 3
     or not exists (select 1 from public.currencies c where c.code = v_cur::char(3)) then
    perform private.fail('UNKNOWN_CURRENCY', jsonb_build_object('currency', p_default_currency));
  end if;
  -- Avatars live in the caller's own folder of the avatars bucket: <user_id>/<file> (0007).
  if v_avatar is not null
     and (char_length(v_avatar) <= 37
          or left(v_avatar, 37) <> v_uid::text || '/'
          or position('..' in v_avatar) > 0) then
    perform private.fail('INVALID_AVATAR_PATH');
  end if;

  update public.profiles p
  set display_name = v_name,
      upi_id = v_upi,
      default_currency = v_cur::char(3),
      avatar_path = v_avatar,
      updated_at = now()
  where p.id = v_uid and p.deleted_at is null
  returning p.id, p.display_name, p.avatar_path, p.upi_id, p.default_currency, p.updated_at into v_p;
  if not found then
    perform private.fail('PROFILE_NOT_FOUND');
  end if;

  return jsonb_build_object(
    'id', v_p.id,
    'display_name', v_p.display_name,
    'avatar_path', v_p.avatar_path,
    'upi_id', v_p.upi_id,
    'default_currency', v_p.default_currency,
    'updated_at', v_p.updated_at);
end;
$$;

-- Every membership becomes a name-only member (keeps the name + " (left)" so others' history stays readable and
-- their balances are unchanged: member ids do not change), with a member_left activity per group. The profile is
-- cleared; deleting the auth user afterwards cascades to it. Phase 10 extends this to delete device tokens.
create or replace function public.prepare_account_deletion()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_avatar text;
  v_groups bigint;
begin
  if v_uid is null then
    raise exception using errcode = '42501', message = 'NOT_AUTHENTICATED';
  end if;

  with changed as (
    update public.group_members m
    set user_id = null,
        display_name = left(btrim(m.display_name), 43) || ' (left)',   -- 43 + 7 = 50, the column maximum
        updated_at = now(),
        updated_by = v_uid
    where m.user_id = v_uid
    returning m.id, m.group_id
  ), logged as (
    insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
    select c.group_id, v_uid, c.id, 'member_left', 'group_member', c.id,
           jsonb_build_object('reason', 'account_deleted')
    from changed c
    returning 1
  )
  select count(*) into v_groups from logged;

  select p.avatar_path into v_avatar from public.profiles p where p.id = v_uid for update;
  update public.profiles p
  set display_name = 'Deleted user',
      avatar_path = null,
      upi_id = null,
      updated_at = now(),
      deleted_at = coalesce(p.deleted_at, now())
  where p.id = v_uid;

  return jsonb_build_object('avatar_path', v_avatar, 'groups', v_groups);
end;
$$;

revoke all on function public.update_profile(text, text, text, text) from public, anon;
revoke all on function public.prepare_account_deletion() from public, anon;
grant execute on function public.update_profile(text, text, text, text) to authenticated;
grant execute on function public.prepare_account_deletion() to authenticated;
