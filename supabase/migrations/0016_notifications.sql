-- 0016 Notifications and reminders (phase 13; 03-backend.md §4 §5, 08-feature-specs.md #19 #23, rule 10).
--
-- activity insert -> private.fanout_notifications() -> one `notifications` row per recipient: linked active
-- members involved in the record (payer or share > 0, both sides of a payment, the reminded person,
-- participants of a commented record; every member for `groups`), never the actor (S-140).
--   in-app off and push off for the kind      -> no row
--   in-app off, push on                       -> row with inapp = false (push only, hidden from the bell)
--   push on, group not muted, project_url set -> push_status 'pending' -> private.queue_push() ->
--                                                net.http_post(<project_url>/functions/v1/send-push)
--   otherwise                                 -> push_status 'skipped' (muted groups: in-app yes, push no)
-- send-push (verify_jwt false, idempotent) moves 'pending' to sent / skipped / failed; without the
-- FCM_SERVICE_ACCOUNT_JSON secret (D-020 dummy mode) it marks 'skipped'.
-- Clients only read their own rows (RLS) and write through the RPCs at the end of this file.
-- `private.settings.project_url` is per project and never in Git (also used by 0017 fetch-rates):
--   insert into private.settings (key, value) values ('project_url', 'https://<project-ref>.supabase.co')
--   on conflict (key) do update set value = excluded.value;

-- ------------------------------------------------------------------ settings (same shape as 0017)

create table if not exists private.settings (
  key text primary key,
  value text not null
);
alter table private.settings enable row level security;
revoke all on private.settings from public, anon, authenticated;

-- ------------------------------------------------------------------ tables

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  group_id uuid references public.groups (id),
  activity_id uuid references public.activity (id),
  kind text not null check (kind in ('expenses', 'payments', 'reminders', 'comments', 'groups')),
  type text not null,
  title text not null check (char_length(title) between 1 and 200),
  body text not null check (char_length(body) between 1 and 600),
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  inapp boolean not null default true,
  read_at timestamptz,
  push_status text not null default 'pending' check (push_status in ('pending', 'sent', 'skipped', 'failed')),
  created_at timestamptz not null default now(),
  seq bigint not null
);

create unique index notifications_activity_user_idx on public.notifications (activity_id, user_id);
create index notifications_user_seq_idx on public.notifications (user_id, seq);
create index notifications_group_idx on public.notifications (group_id);
-- seq moves on insert and when read_at changes (the bell refetches by seq); push_status updates by
-- send-push don't need a client refetch.
create trigger notifications_bump_seq before insert or update of read_at on public.notifications
  for each row execute function private.bump_seq();

-- One row per user, created on first save; a missing row or entry means "on".
create table public.notification_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  kinds jsonb not null default '{}'::jsonb check (jsonb_typeof(kinds) = 'object'),
  muted_group_ids uuid[] not null default '{}',
  updated_at timestamptz not null default now()
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null unique check (char_length(token) between 1 and 4096),
  platform text not null default 'android' check (platform in ('android', 'ios')),
  app_version text check (app_version is null or char_length(app_version) <= 40),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index device_tokens_user_idx on public.device_tokens (user_id);

-- ------------------------------------------------------------------ RLS (own rows only, read only)

alter table public.notifications enable row level security;
alter table public.notification_settings enable row level security;
alter table public.device_tokens enable row level security;

create policy notifications_select on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));
create policy notification_settings_select on public.notification_settings for select to authenticated
  using (user_id = (select auth.uid()));
create policy device_tokens_select on public.device_tokens for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.notifications, public.notification_settings, public.device_tokens from anon, authenticated;
grant select on public.notifications, public.notification_settings, public.device_tokens to authenticated;

-- ------------------------------------------------------------------ helpers

-- Shown name of a member: the linked profile's name, else the member's own name.
create or replace function private.member_name(p_member uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(nullif(btrim(p.display_name), ''), gm.display_name)
  from public.group_members gm
  left join public.profiles p on p.id = gm.user_id
  where gm.id = p_member;
$$;

-- List-style amount, same rules as the app's MoneyFormatter.list (05 §7): Indian grouping for every currency,
-- all-zero fraction hidden, a unit ending in a letter followed by a no-break space (`₹1,200`, `AED 50`).
create or replace function private.format_money(p_amount bigint, p_currency text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_exp int;
  v_unit text;
  v_digits text;
  v_whole text;
  v_frac text;
  v_head text;
  v_out text;
begin
  select c.exponent, c.symbol into v_exp, v_unit from public.currencies c where c.code = upper(btrim(p_currency));
  v_exp := coalesce(v_exp, 2);
  v_unit := coalesce(v_unit, upper(btrim(p_currency)), '');
  v_digits := abs(p_amount)::text;
  if length(v_digits) <= v_exp then
    v_digits := lpad(v_digits, v_exp + 1, '0');   -- lpad cuts longer text, so pad only short amounts
  end if;
  v_whole := left(v_digits, length(v_digits) - v_exp);
  v_frac := right(v_digits, v_exp);
  v_out := right(v_whole, 3);
  v_head := left(v_whole, greatest(length(v_whole) - 3, 0));
  while length(v_head) > 0 loop
    v_out := right(v_head, 2) || ',' || v_out;
    v_head := left(v_head, greatest(length(v_head) - 2, 0));
  end loop;
  if v_frac <> '' and v_frac !~ '^0+$' then
    v_out := v_out || '.' || v_frac;
  end if;
  -- "Ends in a letter": ASCII, or any cased letter (zł, Kč).
  return case when p_amount < 0 then chr(8722) else '' end
    || v_unit
    || case when v_unit ~ '[A-Za-z]$' or upper(right(v_unit, 1)) <> lower(right(v_unit, 1)) then chr(160) else '' end
    || v_out;
end;
$$;

-- Per-currency amounts {"INR": 50000, "USD": 2000} as `₹500 · $20`, the group's main currency first.
create or replace function private.format_amounts(p_amounts jsonb, p_main text)
returns text
language sql
stable
set search_path = ''
as $$
  select string_agg(private.format_money((e.value)::bigint, e.key), ' · '
                    order by (e.key = p_main) desc, e.key)
  from jsonb_each(coalesce(p_amounts, '{}'::jsonb)) e
  where jsonb_typeof(e.value) = 'number';
$$;

-- Notification kind (= Android channel, settings row) of an activity type; null = no notification (08 #19).
create or replace function private.notification_kind(p_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_type in ('expense_added', 'expense_edited', 'expense_deleted', 'expense_restored') then 'expenses'
    when p_type in ('payment_added', 'payment_edited', 'payment_deleted', 'payment_restored') then 'payments'
    when p_type = 'reminder_sent' then 'reminders'
    when p_type = 'comment_added' then 'comments'
    when p_type in ('member_joined', 'member_claimed', 'member_left', 'member_removed', 'settings_changed')
      then 'groups'
  end;
$$;

-- {kind: {push, inapp}} lookup; anything but an explicit false means on.
create or replace function private.kind_on(p_kinds jsonb, p_kind text, p_channel text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(p_kinds -> p_kind -> p_channel) = 'boolean'
              then (p_kinds -> p_kind -> p_channel)::boolean else true end;
$$;

-- Members with a payer or share amount > 0 in an expense row (as jsonb).
create or replace function private.expense_member_ids(p_row jsonb)
returns setof uuid
language sql
immutable
set search_path = ''
as $$
  select distinct private.try_uuid(e.key)
  from (select * from jsonb_each(coalesce(p_row -> 'payers', '{}'::jsonb))
        union all
        select * from jsonb_each(coalesce(p_row -> 'shares', '{}'::jsonb))) e
  where jsonb_typeof(e.value) = 'number' and (e.value)::numeric > 0 and private.try_uuid(e.key) is not null;
$$;

-- Who hears about an activity row: (user, member) of every linked member involved, never the actor (a
-- recurring copy is the exception: its "actor" is the template's creator, who did not just do it).
create or replace function private.notification_recipients(a public.activity)
returns table (user_id uuid, member_id uuid)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_kind text := private.notification_kind(a.type);
  v_members uuid[] := '{}';
  v_row jsonb;
  v_target uuid;
begin
  if v_kind = 'expenses' then
    select to_jsonb(e) into v_row from public.expenses e where e.id = a.target_id;
    v_members := array(select private.expense_member_ids(v_row));
    if a.type = 'expense_edited' then
      -- People taken out of the split hear about it too: participants of the version before this edit.
      select rv.snapshot into v_row from public.record_versions rv
      where rv.table_name = 'expenses' and rv.record_id = a.target_id and rv.op <> 'conflict_lost'
      order by rv.id desc offset 1 limit 1;
      v_members := v_members || array(select private.expense_member_ids(v_row));
    end if;
  elsif v_kind = 'payments' then
    select array[p.from_member, p.to_member] into v_members from public.payments p where p.id = a.target_id;
  elsif v_kind = 'reminders' then
    v_members := array[private.try_uuid(a.data ->> 'to_member')];
  elsif v_kind = 'comments' then
    v_target := private.try_uuid(a.data ->> 'target_id');
    if a.data ->> 'target_type' = 'expense' then
      select to_jsonb(e) into v_row from public.expenses e where e.id = v_target;
      v_members := array(select private.expense_member_ids(v_row));
    elsif a.data ->> 'target_type' = 'payment' then
      select array[p.from_member, p.to_member] into v_members from public.payments p where p.id = v_target;
    end if;
  elsif v_kind = 'groups' then
    v_members := array(select gm.id from public.group_members gm where gm.group_id = a.group_id);
  else
    return;
  end if;

  return query
  select gm.user_id, gm.id
  from public.group_members gm
  where gm.id = any (coalesce(v_members, '{}'))
    and gm.group_id = a.group_id
    and gm.user_id is not null
    and ((gm.status = 'active' and gm.deleted_at is null)
         or (a.type = 'member_removed' and gm.id = a.target_id))
    and (gm.user_id is distinct from a.actor_user_id or coalesce(a.data ->> 'recurring', '') = 'true');
end;
$$;

-- Title, body (for push and the bell, from the recipient's side) and data (what a tap opens) of one
-- notification. English only, like the rest of the app (D-009).
create or replace function private.notification_content(a public.activity, p_member uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  g record;
  d jsonb := a.data;
  v_actor text;
  v_amount text;
  v_desc text;
  v_body text;
  v_title text;
  v_from uuid;
  v_to uuid;
  v_target_type text := 'group';
  v_target uuid := a.group_id;
  v_snippet text;
begin
  select gg.name, gg.type, gg.main_currency::text as main_currency into g
  from public.groups gg where gg.id = a.group_id;
  v_actor := coalesce(private.member_name(a.actor_member_id),
                      (select nullif(btrim(p.display_name), '') from public.profiles p where p.id = a.actor_user_id),
                      'Someone');
  v_amount := case
    when jsonb_typeof(d -> 'total') = 'number' then private.format_money((d ->> 'total')::bigint, d ->> 'currency')
    when jsonb_typeof(d -> 'amount') = 'number' then private.format_money((d ->> 'amount')::bigint, d ->> 'currency')
  end;
  v_desc := '“' || coalesce(nullif(d ->> 'description', ''), 'an expense') || '”';

  if a.type like 'expense_%' then
    v_body := case
      when a.type = 'expense_added' and coalesce(d ->> 'recurring', '') = 'true'
        then v_desc || ' was added (recurring)'
      when a.type = 'expense_added' then v_actor || ' added ' || v_desc
      when a.type = 'expense_edited' then v_actor || ' edited ' || v_desc
      when a.type = 'expense_deleted' then v_actor || ' deleted ' || v_desc
      else v_actor || ' restored ' || v_desc
    end || coalesce(' · ' || v_amount, '');
    if a.type <> 'expense_deleted' then
      v_target_type := 'expense';
      v_target := a.target_id;
    end if;
  elsif a.type like 'payment_%' then
    v_from := private.try_uuid(d ->> 'from_member');
    v_to := private.try_uuid(d ->> 'to_member');
    v_body := case
      when a.type = 'payment_added' and p_member = v_to and a.actor_member_id = v_from
        then v_actor || ' paid you ' || coalesce(v_amount, '')
      when a.type = 'payment_added' and p_member = v_to
        then v_actor || ' recorded that ' || coalesce(private.member_name(v_from), 'someone') || ' paid you '
             || coalesce(v_amount, '')
      when a.type = 'payment_added' and p_member = v_from and a.actor_member_id = v_to
        then v_actor || ' recorded your payment of ' || coalesce(v_amount, '')
      when a.type = 'payment_added' and p_member = v_from
        then v_actor || ' recorded that you paid ' || coalesce(private.member_name(v_to), 'someone') || ' '
             || coalesce(v_amount, '')
      when a.type = 'payment_added' then v_actor || ' recorded a payment' || coalesce(' · ' || v_amount, '')
      when a.type = 'payment_edited' then v_actor || ' edited a payment' || coalesce(' · ' || v_amount, '')
      when a.type = 'payment_deleted' then v_actor || ' deleted a payment' || coalesce(' · ' || v_amount, '')
      else v_actor || ' restored a payment' || coalesce(' · ' || v_amount, '')
    end;
    if a.type <> 'payment_deleted' then
      v_target_type := 'payment';
      v_target := a.target_id;
    end if;
  elsif a.type = 'reminder_sent' then
    -- 08 #23 copy: "Mohit reminded you about ₹500 in “Goa trip”".
    v_body := v_actor || ' reminded you about '
      || coalesce(private.format_amounts(d -> 'amounts', g.main_currency), v_amount, 'what you owe')
      || case when g.type = 'direct' then '' else ' in “' || g.name || '”' end;
    v_target_type := 'balances';
  elsif a.type = 'comment_added' then
    select left(regexp_replace(btrim(c.body), '\s+', ' ', 'g'), 80)
           || case when char_length(btrim(c.body)) > 80 then '…' else '' end
    into v_snippet
    from public.comments c where c.id = a.target_id;
    if d ->> 'target_type' = 'expense' then
      select '“' || e.description || '”' into v_desc from public.expenses e
      where e.id = private.try_uuid(d ->> 'target_id');
      v_body := v_actor || ' commented on ' || coalesce(v_desc, 'an expense');
    else
      v_body := v_actor || ' commented on a payment';
    end if;
    v_body := v_body || coalesce(': “' || v_snippet || '”', '');
    if d ->> 'target_type' in ('expense', 'payment') and private.try_uuid(d ->> 'target_id') is not null then
      v_target_type := d ->> 'target_type';
      v_target := private.try_uuid(d ->> 'target_id');
    end if;
  elsif a.type = 'member_joined' then
    v_body := v_actor || ' joined the group';
  elsif a.type = 'member_claimed' then
    v_body := v_actor || ' joined the group as ' || coalesce(d ->> 'name', 'a member');
  elsif a.type = 'member_left' then
    v_body := coalesce(private.member_name(a.target_id), v_actor) || ' left the group';
  elsif a.type = 'member_removed' then
    v_body := case when p_member = a.target_id then v_actor || ' removed you from the group'
                   else v_actor || ' removed ' || coalesce(d ->> 'name', 'a member') || ' from the group' end;
  else
    v_body := case
      when d ->> 'setting' = 'simplify_debts' and d ->> 'simplify_debts' = 'true'
        then v_actor || ' turned on simplify debts'
      when d ->> 'setting' = 'simplify_debts' then v_actor || ' turned off simplify debts'
      when d ->> 'setting' = 'default_split' then v_actor || ' changed the default split'
      else v_actor || ' changed the group settings'
    end;
  end if;

  v_title := case when g.type = 'direct' then v_actor else coalesce(g.name, 'Splitify') end;
  return jsonb_build_object(
    'title', left(v_title, 200),
    'body', left(v_body, 600),
    'data', jsonb_build_object(
      'target_type', v_target_type, 'target_id', v_target, 'group_id', a.group_id,
      'actor_member_id', a.actor_member_id, 'actor_name', v_actor));
end;
$$;

-- ------------------------------------------------------------------ fan-out + push queue

create or replace function private.fanout_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind text := private.notification_kind(new.type);
  v_url text;
  r record;
  v_kinds jsonb;
  v_muted uuid[];
  v_inapp boolean;
  v_push boolean;
  v_content jsonb;
begin
  if v_kind is null then
    return null;
  end if;
  -- A notification problem must never undo the write that caused it (rule 9 keeps the activity row).
  begin
    select s.value into v_url from private.settings s where s.key = 'project_url';
    for r in select * from private.notification_recipients(new) loop
      select ns.kinds, ns.muted_group_ids into v_kinds, v_muted
      from public.notification_settings ns where ns.user_id = r.user_id;
      if not found then
        v_kinds := null;
        v_muted := null;
      end if;
      v_inapp := private.kind_on(v_kinds, v_kind, 'inapp');
      v_push := private.kind_on(v_kinds, v_kind, 'push') and not (new.group_id = any (coalesce(v_muted, '{}')));
      continue when not v_inapp and not v_push;
      v_content := private.notification_content(new, r.member_id);
      insert into public.notifications (user_id, group_id, activity_id, kind, type, title, body, data, inapp,
                                        push_status)
      values (r.user_id, new.group_id, new.id, v_kind, new.type, v_content ->> 'title', v_content ->> 'body',
              v_content -> 'data', v_inapp,
              case when v_push and coalesce(v_url, '') <> '' then 'pending' else 'skipped' end)
      on conflict (activity_id, user_id) do nothing;
    end loop;
  exception when others then
    raise warning 'fanout_notifications(%) failed: % %', new.id, sqlstate, sqlerrm;
  end;
  return null;
end;
$$;

create trigger activity_fanout_notifications after insert on public.activity
  for each row execute function private.fanout_notifications();

-- Pending push -> send-push via pg_net (asynchronous, sent after commit; a rolled-back test sends nothing).
create or replace function private.queue_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
begin
  select s.value into v_url from private.settings s where s.key = 'project_url';
  if coalesce(v_url, '') = '' then
    return null;
  end if;
  begin
    perform net.http_post(
      url := rtrim(v_url, '/') || '/functions/v1/send-push',
      body := jsonb_build_object('notification_id', new.id),
      headers := '{"Content-Type": "application/json"}'::jsonb,
      timeout_milliseconds := 10000);
  exception when others then
    raise warning 'queue_push(%) failed: % %', new.id, sqlstate, sqlerrm;
  end;
  return null;
end;
$$;

create trigger notifications_queue_push after insert on public.notifications
  for each row when (new.push_status = 'pending') execute function private.queue_push();

-- Realtime nudge on user:<id> so an open app refreshes its bell (same guard as 0009 broadcast_change).
create or replace function private.notification_nudge()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if to_regprocedure('realtime.send(jsonb,text,text,boolean)') is null then
    return null;
  end if;
  begin
    execute 'select realtime.send($1, $2, $3, $4)'
      using jsonb_build_object('table', 'notifications', 'seq', new.seq), 'changed', 'user:' || new.user_id, true;
  exception when others then
    null;
  end;
  return null;
end;
$$;

create trigger notifications_broadcast after insert or update of read_at on public.notifications
  for each row execute function private.notification_nudge();

-- ------------------------------------------------------------------ RPCs

-- Bell: mark the given notifications (null = all of mine) read; returns how many changed.
create or replace function public.mark_notifications_read(ids uuid[] default null)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_count int;
begin
  update public.notifications n
  set read_at = now()
  where n.user_id = v_uid and n.read_at is null
    and (mark_notifications_read.ids is null or n.id = any (mark_notifications_read.ids));
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Settings (08 #19): kinds = {kind: {push: bool, inapp: bool}} for the five kinds, muted_group_ids = groups
-- whose pushes are muted (in-app stays). A null argument keeps the saved value. Returns the saved settings.
create or replace function public.upsert_notification_settings(kinds jsonb default null,
                                                               muted_group_ids uuid[] default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  v_uid uuid := private.require_uid();
  v_kinds jsonb := upsert_notification_settings.kinds;
  v_muted uuid[];
  v_row public.notification_settings;
begin
  if v_kinds is not null and (
       jsonb_typeof(v_kinds) <> 'object'
       or exists (select 1 from jsonb_each(v_kinds) k
                  where k.key not in ('expenses', 'payments', 'reminders', 'comments', 'groups')
                     or jsonb_typeof(k.value) <> 'object'
                     or exists (select 1 from jsonb_each(k.value) c
                                where c.key not in ('push', 'inapp') or jsonb_typeof(c.value) <> 'boolean'))) then
    perform private.fail('INVALID_SETTINGS');
  end if;
  if upsert_notification_settings.muted_group_ids is not null then
    if cardinality(upsert_notification_settings.muted_group_ids) > 500 then
      perform private.fail('INVALID_SETTINGS');
    end if;
    -- Only groups the caller belongs to; duplicates dropped.
    v_muted := array(select distinct g from unnest(upsert_notification_settings.muted_group_ids) g
                     where private.is_member(g) order by g);
  end if;
  insert into public.notification_settings as ns (user_id, kinds, muted_group_ids, updated_at)
  values (v_uid, coalesce(v_kinds, '{}'::jsonb), coalesce(v_muted, '{}'), now())
  on conflict (user_id) do update
    set kinds = coalesce(v_kinds, ns.kinds),
        muted_group_ids = coalesce(v_muted, ns.muted_group_ids),
        updated_at = now()
  returning * into v_row;
  return jsonb_build_object('kinds', v_row.kinds, 'muted_group_ids', to_jsonb(v_row.muted_group_ids),
                            'updated_at', v_row.updated_at);
end;
$$;

-- This phone's FCM token (rule 10). A token seen under another account moves to the caller (the phone
-- changed hands); re-registering refreshes last_seen_at.
create or replace function public.register_device(token text, app_version text default null,
                                                  platform text default 'android')
returns void
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := private.require_uid();
  v_token text := btrim(coalesce(register_device.token, ''));
  v_platform text := coalesce(register_device.platform, 'android');
begin
  if char_length(v_token) not between 1 and 4096 then
    perform private.fail('INVALID_TOKEN');
  end if;
  if v_platform not in ('android', 'ios') then
    perform private.fail('INVALID_PLATFORM');
  end if;
  insert into public.device_tokens as dt (user_id, token, platform, app_version, last_seen_at)
  values (v_uid, v_token, v_platform, left(register_device.app_version, 40), now())
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, app_version = excluded.app_version,
        last_seen_at = now();
end;
$$;

-- Sign-out removes this phone's token (rule 10). True when a token of the caller was removed.
create or replace function public.unregister_device(token text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_count int;
begin
  delete from public.device_tokens dt where dt.token = btrim(unregister_device.token) and dt.user_id = v_uid;
  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

-- Remind (08 #23): activity `reminder_sent` -> notification to that member's account. Only a linked member who
-- owes the caller in this group right now (pairs, or the suggested payments when simplify is on); at most one
-- reminder per pair per 24 h. Returns {status: 'sent', activity_id, amounts {CUR: minor}, retry_at}.
create or replace function public.send_reminder(group_id uuid, to_member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_group uuid := send_reminder.group_id;
  v_me uuid := private.my_member(v_group, v_uid);
  v_to public.group_members;
  v_last timestamptz;
  v_bal jsonb;
  v_view text;
  v_cur text;
  v_block jsonb;
  v_pair jsonb;
  v_amounts jsonb := '{}'::jsonb;
  v_data jsonb;
  v_activity uuid;
begin
  perform private.assert_group_writable(v_group);
  select * into v_to from public.group_members gm
  where gm.id = send_reminder.to_member_id and gm.group_id = v_group and gm.status = 'active'
    and gm.deleted_at is null;
  if not found then
    perform private.fail('MEMBER_NOT_FOUND');
  end if;
  if v_to.id = v_me then
    perform private.fail('CANNOT_REMIND_SELF');
  end if;
  if v_to.user_id is null then
    perform private.fail('NAME_ONLY_MEMBER');
  end if;

  -- One at a time per pair, then the 24 h throttle.
  perform pg_advisory_xact_lock(hashtextextended('send_reminder:' || v_me || ':' || v_to.id, 0));
  select max(a.created_at) into v_last from public.activity a
  where a.group_id = v_group and a.type = 'reminder_sent' and a.actor_member_id = v_me
    and a.data ->> 'to_member' = v_to.id::text and a.created_at > now() - interval '24 hours';
  if v_last is not null then
    perform private.fail('REMINDER_THROTTLED', jsonb_build_object('retry_at', v_last + interval '24 hours'));
  end if;

  v_bal := private.group_balances(v_group);
  v_view := case when coalesce((v_bal ->> 'simplify_debts')::boolean, false) then 'simplified' else 'pairs' end;
  for v_cur, v_block in select k.key, k.value from jsonb_each(coalesce(v_bal -> 'currencies', '{}'::jsonb)) k loop
    for v_pair in select p.value from jsonb_array_elements(coalesce(v_block -> v_view, '[]'::jsonb)) p loop
      if v_pair ->> 0 = v_to.id::text and v_pair ->> 1 = v_me::text and (v_pair ->> 2)::bigint > 0 then
        v_amounts := v_amounts || jsonb_build_object(v_cur, (v_pair ->> 2)::bigint);
      end if;
    end loop;
  end loop;
  if v_amounts = '{}'::jsonb then
    perform private.fail('NOTHING_OWED');
  end if;

  v_data := jsonb_build_object('member_id', v_to.id, 'to_member', v_to.id, 'name', v_to.display_name,
                               'amounts', v_amounts);
  if (select count(*) from jsonb_object_keys(v_amounts)) = 1 then
    select v_data || jsonb_build_object('amount', k.value, 'currency', k.key) into v_data
    from jsonb_each(v_amounts) k;
  end if;
  insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
  values (v_group, v_uid, v_me, 'reminder_sent', 'member', v_to.id, v_data)
  returning id into v_activity;
  return jsonb_build_object('status', 'sent', 'activity_id', v_activity, 'amounts', v_amounts,
                            'retry_at', now() + interval '24 hours');
end;
$$;

-- ------------------------------------------------------------------ grants

revoke all on function private.member_name(uuid) from public, anon, authenticated;
revoke all on function private.format_money(bigint, text) from public, anon, authenticated;
revoke all on function private.format_amounts(jsonb, text) from public, anon, authenticated;
revoke all on function private.notification_kind(text) from public, anon, authenticated;
revoke all on function private.kind_on(jsonb, text, text) from public, anon, authenticated;
revoke all on function private.expense_member_ids(jsonb) from public, anon, authenticated;
revoke all on function private.notification_recipients(public.activity) from public, anon, authenticated;
revoke all on function private.notification_content(public.activity, uuid) from public, anon, authenticated;
revoke all on function private.fanout_notifications() from public, anon, authenticated;
revoke all on function private.queue_push() from public, anon, authenticated;
revoke all on function private.notification_nudge() from public, anon, authenticated;
revoke all on function public.mark_notifications_read(uuid[]) from public, anon;
revoke all on function public.upsert_notification_settings(jsonb, uuid[]) from public, anon;
revoke all on function public.register_device(text, text, text) from public, anon;
revoke all on function public.unregister_device(text) from public, anon;
revoke all on function public.send_reminder(uuid, uuid) from public, anon;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;
grant execute on function public.upsert_notification_settings(jsonb, uuid[]) to authenticated;
grant execute on function public.register_device(text, text, text) to authenticated;
grant execute on function public.unregister_device(text) to authenticated;
grant execute on function public.send_reminder(uuid, uuid) to authenticated;
