-- 0022 Hardening (phase 19, T1 security; planning/03-backend.md §3 §6; tests: 190_attack, 191_housekeeping).
-- Holes found by the attack tests, closed WITHOUT touching apply_mutations / pull_changes (other phases redefine
-- them): triggers and policies only.
--   1. Text padded with spaces got past the btrim length checks (a 5 MB "description"); jsonb blobs
--      (split_values, default_split, recurring template) and dates had no limit. -> private.guard_payload_limits
--   2. A group could grow past 100 members through sync (join_group capped it, apply_mutations did not).
--   3. A user could register unlimited device tokens. -> keep the newest 20 per user.
--   4. avatar_path had no maximum length (update_profile only checks the prefix).
--   5. Storage object names with "..", ".", empty segments, backslashes or control characters were accepted under
--      a folder the user owns. -> restrictive policies on storage.objects.
-- Plus the weekly housekeeping job (03-backend.md §6).
-- Known, left to the owner of apply_mutations (0023): the idempotency lookup `select ... from mutation_log where
-- mutation_id = v_mid` is not limited to the caller (add `and l.user_id = v_uid`); an attacker needs a victim's
-- random mutation uuid, so this is low risk.

-- ------------------------------------------------------------------ 1-4. size and shape limits

-- Generous caps (the app's own limits are far lower); 23514 maps to INVALID_VALUE in the sync results.
create or replace function private.guard_payload_limits()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_json constant int := 32768;
  v_bad boolean := false;
begin
  if tg_table_name = 'expenses' then
    v_bad := char_length(new.description) > 500 or char_length(coalesce(new.notes, '')) > 2000
             or length(new.split_values::text) > v_json
             or new.date < date '1970-01-01' or new.date > date '2100-12-31';
  elsif tg_table_name = 'payments' then
    v_bad := char_length(coalesce(new.note, '')) > 800
             or new.date < date '1970-01-01' or new.date > date '2100-12-31';
  elsif tg_table_name = 'comments' then
    v_bad := char_length(new.body) > 4000;
  elsif tg_table_name = 'groups' then
    v_bad := char_length(new.name) > 240 or length(new.default_split::text) > v_json;
  elsif tg_table_name = 'group_members' then
    v_bad := char_length(new.display_name) > 200;
    if not v_bad and tg_op = 'INSERT' and new.status = 'active' and new.deleted_at is null
       and (select count(*) from public.group_members m
            where m.group_id = new.group_id and m.status = 'active' and m.deleted_at is null) >= 100 then
      perform private.fail('GROUP_FULL');
    end if;
  elsif tg_table_name = 'recurring_templates' then
    v_bad := length(new.template::text) > 2 * v_json;
  elsif tg_table_name = 'profiles' then
    if char_length(new.avatar_path) > 200 then
      perform private.fail('INVALID_AVATAR_PATH');
    end if;
    v_bad := char_length(new.display_name) > 200;
  end if;
  if v_bad then
    raise exception using errcode = '23514', message = 'PAYLOAD_LIMIT';
  end if;
  return new;
end;
$$;

revoke all on function private.guard_payload_limits() from public, anon, authenticated;

-- "a_limits" sorts before the other BEFORE triggers, so oversized rows are refused first.
create trigger expenses_a_limits before insert or update on public.expenses
  for each row execute function private.guard_payload_limits();
create trigger payments_a_limits before insert or update on public.payments
  for each row execute function private.guard_payload_limits();
create trigger comments_a_limits before insert or update on public.comments
  for each row execute function private.guard_payload_limits();
create trigger groups_a_limits before insert or update on public.groups
  for each row execute function private.guard_payload_limits();
create trigger group_members_a_limits before insert or update on public.group_members
  for each row execute function private.guard_payload_limits();
create trigger recurring_templates_a_limits before insert or update on public.recurring_templates
  for each row execute function private.guard_payload_limits();
create trigger profiles_a_limits before insert or update on public.profiles
  for each row execute function private.guard_payload_limits();

-- ------------------------------------------------------------------ 3. device tokens: newest 20 per user

create or replace function private.cap_device_tokens()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  delete from public.device_tokens d
  where d.user_id = new.user_id
    and d.id in (select t.id from public.device_tokens t where t.user_id = new.user_id
                 order by t.last_seen_at desc, t.created_at desc offset 19);
  return new;
end;
$$;

revoke all on function private.cap_device_tokens() from public, anon, authenticated;

create trigger device_tokens_cap before insert on public.device_tokens
  for each row execute function private.cap_device_tokens();

-- ------------------------------------------------------------------ 5. Storage object names

-- Restrictive policies are ANDed with the folder policies of 0007: a name must have no empty, "." or ".."
-- segment, no backslash and no control character (an object key is a literal string, but nothing downstream
-- should ever have to resolve one).
create policy storage_safe_names_insert on storage.objects as restrictive for insert to authenticated
  with check (name !~ '(^|/)\.{0,2}(/|$)' and strpos(name, chr(92)) = 0 and name !~ '[[:cntrl:]]');
create policy storage_safe_names_update on storage.objects as restrictive for update to authenticated
  using (name is not null)
  with check (name !~ '(^|/)\.{0,2}(/|$)' and strpos(name, chr(92)) = 0 and name !~ '[[:cntrl:]]');

-- ------------------------------------------------------------------ housekeeping (03-backend.md §6)

create or replace function private.housekeeping()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.mutation_log where received_at < now() - interval '30 days';
  delete from public.join_attempts where at < now() - interval '1 day';
  delete from cron.job_run_details where coalesce(end_time, start_time) < now() - interval '14 days';
  delete from public.device_tokens where last_seen_at < now() - interval '270 days';
end;
$$;

revoke all on function private.housekeeping() from public, anon, authenticated;

-- Sundays 20:00 UTC (01:30 IST Monday). Re-running the migration replaces the job.
select cron.schedule('housekeeping', '0 20 * * 0', 'select private.housekeeping()');
