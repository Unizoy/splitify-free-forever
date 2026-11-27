-- 0026 Group extras (D-034 WP-C: C4 trip dates + settle-up reminders, C5 the group whiteboard).
--   * groups gains trip_starts_on / trip_ends_on (end >= start when both are set; no end = "no end"),
--     settle_reminder ('off' | 'weekly' | 'monthly', default 'off') and whiteboard (free text, <= 5,000
--     characters). Read through the existing member-only select policy (RLS, rule 7); written only through
--     apply_mutations (the column list below), so offline edits keep last-save-wins + record_versions (rule 6).
--   * activity types gain `settle_nudge` (system, no actor) and `whiteboard_updated`.
--   * private.send_settle_nudges(): the `settle-nudges` cron (10:00 Asia/Kolkata) writes one settle_nudge per due
--     group and day (weekly on the group's creation weekday, monthly on the 1st, the day after trip_ends_on), only
--     while somebody has a non-zero balance; private.settle_nudges_sent makes it idempotent per group per day.
--   * fan-out (0016): settle_nudge -> kind `reminders`, sent to members with a balance (muted groups: in-app only);
--     whiteboard_updated -> kind `groups`, in-app only (never pushed); a reminder setting change reads
--     "turned on weekly settle-up reminders". Every 0009/0014/0016 line is kept; additions are marked 0026.

-- ------------------------------------------------------------------ columns

alter table public.groups
  add column if not exists trip_starts_on date,
  add column if not exists trip_ends_on date,
  add column if not exists settle_reminder text not null default 'off',
  add column if not exists whiteboard text;

alter table public.groups drop constraint if exists groups_trip_dates_check;
alter table public.groups add constraint groups_trip_dates_check
  check (trip_starts_on is null or trip_ends_on is null or trip_ends_on >= trip_starts_on);
alter table public.groups drop constraint if exists groups_settle_reminder_check;
alter table public.groups add constraint groups_settle_reminder_check
  check (settle_reminder in ('off', 'weekly', 'monthly'));
alter table public.groups drop constraint if exists groups_whiteboard_check;
alter table public.groups add constraint groups_whiteboard_check
  check (whiteboard is null or char_length(whiteboard) <= 5000);

comment on column public.groups.trip_starts_on is 'Trip dates (D-034 C4): first day; null = not set.';
comment on column public.groups.trip_ends_on is 'Trip dates (D-034 C4): last day; null = no end. The day after, members with a balance get a settle-up nudge.';
comment on column public.groups.settle_reminder is 'Settle-up reminders (D-034 C4): off | weekly (creation weekday) | monthly (the 1st).';
comment on column public.groups.whiteboard is 'Group notes (D-034 C5): free text, at most 5,000 characters.';

-- ------------------------------------------------------------------ activity types

alter table public.activity drop constraint if exists activity_type_check;
alter table public.activity add constraint activity_type_check check (type in (
  'group_created', 'group_updated', 'group_archived', 'group_unarchived', 'group_deleted', 'group_restored',
  'member_added', 'member_joined', 'member_claimed', 'member_left', 'member_removed',
  'expense_added', 'expense_edited', 'expense_deleted', 'expense_restored',
  'payment_added', 'payment_edited', 'payment_deleted', 'payment_restored',
  'comment_added', 'comment_deleted', 'reminder_sent', 'settings_changed',
  'recurring_created', 'recurring_updated', 'recurring_stopped', 'import_completed',
  'settle_nudge', 'whiteboard_updated'));

-- ------------------------------------------------------------------ apply_mutations: the new group columns

-- private.sync_apply_one as in 0009 (unchanged on dev since), plus the four columns, the "off" default and the
-- `whiteboard_updated` activity type. public.apply_mutations (0023) dispatches here unchanged.
create or replace function private.sync_apply_one(m jsonb, uid uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_entity text := coalesce(m ->> 'entity', '');
  v_op text := coalesce(m ->> 'op', '');
  v_id uuid := private.try_uuid(m ->> 'id');
  v_group uuid := private.try_uuid(m ->> 'group_id');
  v_data jsonb := coalesce(nullif(m -> 'data', 'null'::jsonb), '{}'::jsonb);
  v_source text := coalesce(m ->> 'source', 'app');
  v_t timestamptz;
  v_table text;
  v_cols text[];
  v_defaults jsonb;
  v_row jsonb;
  v_src jsonb;
  v_new jsonb;
  v_filtered jsonb;
  v_upd text[];
  v_vop text;
  v_type text;
  v_adata jsonb;
  v_actor uuid;
  v_owner jsonb;
  v_owner_id uuid;
begin
  if v_entity not in ('group', 'member', 'expense', 'payment', 'comment')
     or v_op not in ('upsert', 'delete', 'restore')
     or v_id is null or v_group is null
     or jsonb_typeof(v_data) <> 'object'
     or v_source not in ('app', 'import')
     or (v_entity = 'group' and v_id <> v_group) then
    perform private.fail('INVALID_MUTATION');
  end if;
  -- Last-write-wins time, clamped so a phone clock in the future can't win every conflict.
  v_t := least(coalesce((m ->> 'client_updated_at')::timestamptz, now()), now());

  v_table := case v_entity
    when 'group' then 'groups' when 'member' then 'group_members' when 'expense' then 'expenses'
    when 'payment' then 'payments' else 'comments' end;
  v_cols := case v_entity
    when 'group' then array['name', 'type', 'main_currency', 'cover_kind', 'cover_path', 'simplify_debts',
                            'default_split', 'archived_at', 'trip_starts_on', 'trip_ends_on', 'settle_reminder',
                            'whiteboard']
    when 'member' then array['display_name', 'position', 'tint']
    when 'expense' then array['kind', 'description', 'notes', 'category', 'date', 'currency', 'total', 'payers',
                              'shares', 'split_kind', 'split_values', 'fx_rate', 'fx_rate_date', 'fx_source',
                              'fx_currency', 'fx_total', 'fx_payers', 'fx_shares', 'receipt_path']
    when 'payment' then array['from_member', 'to_member', 'amount', 'currency', 'date', 'method', 'note', 'fx_rate',
                              'fx_rate_date', 'fx_source', 'fx_currency', 'fx_amount']
    else array['target_type', 'target_id', 'body'] end;

  execute format('select to_jsonb(t) from public.%I t where t.id = $1', v_table) into v_row using v_id;

  -- Membership: creating a group needs none (the creator becomes its owner); everything else does.
  if not (v_entity = 'group' and v_row is null) and not private.is_member(v_group) then
    perform private.fail('NOT_MEMBER');
  end if;
  if v_row is not null and v_entity <> 'group' and (v_row ->> 'group_id')::uuid <> v_group then
    perform private.fail('ID_CONFLICT');
  end if;
  if v_row is null and v_op <> 'upsert' then
    perform private.fail('NOT_FOUND');
  end if;
  if v_entity = 'member' and v_op = 'delete' and v_row ->> 'user_id' is not null then
    perform private.fail('MEMBER_LINKED');   -- linked members leave/are removed via the group RPCs (phase 07)
  end if;

  -- Only client-writable columns are taken from data (null keys dropped on insert so defaults apply).
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into v_filtered
  from jsonb_each(v_data)
  where key = any (v_cols) and (v_row is not null or jsonb_typeof(value) <> 'null');

  -- Older than the stored version: keep the row, keep the loser in history (rule 6).
  if v_row is not null and v_t < coalesce((v_row ->> 'client_updated_at')::timestamptz, '-infinity') then
    insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
    values (v_table, v_id, v_group, 'conflict_lost',
            v_row || v_filtered || jsonb_build_object('client_updated_at', v_t, 'lost_op', v_op), uid, v_t);
    return jsonb_build_object('status', 'superseded', 'seq', (v_row ->> 'seq')::bigint);
  end if;

  if v_row is null then
    v_vop := 'insert';
    v_defaults := case v_entity
      when 'group' then '{"type": "other", "main_currency": "INR", "cover_kind": "generated",
                          "simplify_debts": false, "settle_reminder": "off"}'::jsonb
      when 'member' then '{"role": "member", "status": "active"}'::jsonb
      when 'expense' then jsonb_build_object('kind', 'expense', 'category', 'other.general', 'split_kind', 'equal',
                                             'source', v_source)
      when 'payment' then '{"method": "cash"}'::jsonb
      else '{}'::jsonb end;
    v_src := v_defaults || v_filtered || jsonb_build_object(
      'id', v_id, 'created_at', now(), 'created_by', uid, 'updated_at', now(), 'updated_by', uid,
      'client_updated_at', v_t, 'seq', 0);
    if v_entity <> 'group' then
      v_src := v_src || jsonb_build_object('group_id', v_group);
    end if;
    execute format('insert into public.%1$I select * from jsonb_populate_record(null::public.%1$I, $1)', v_table)
      using v_src;

    if v_entity = 'group' then
      v_owner := coalesce(nullif(v_data -> 'owner_member', 'null'::jsonb), '{}'::jsonb);
      v_owner_id := coalesce(private.try_uuid(v_owner ->> 'id'), gen_random_uuid());
      insert into public.group_members (id, group_id, user_id, display_name, position, role, status, tint,
                                        created_by, updated_at, updated_by, client_updated_at)
      values (v_owner_id, v_id, uid,
              left(coalesce(nullif(btrim(v_owner ->> 'display_name'), ''),
                            (select p.display_name from public.profiles p where p.id = uid), 'Me'), 50),
              0, 'owner', 'active', (v_owner ->> 'tint')::smallint, uid, now(), uid, v_t);
      insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
      select 'group_members', gm.id, gm.group_id, 'insert', to_jsonb(gm), uid, v_t
      from public.group_members gm where gm.id = v_owner_id;
    end if;
  else
    if v_op = 'upsert' then
      v_vop := 'update';
      v_upd := v_cols;
      v_src := v_row || v_filtered;
    elsif v_op = 'delete' then
      v_vop := 'delete';
      v_upd := array['deleted_at', 'deleted_by'];
      v_src := v_row || jsonb_build_object('deleted_at', now(), 'deleted_by', uid);
    else
      v_vop := 'restore';
      v_upd := array['deleted_at', 'deleted_by'];
      v_src := v_row || jsonb_build_object('deleted_at', null, 'deleted_by', null);
    end if;
    v_upd := v_upd || array['updated_at', 'updated_by', 'client_updated_at'];
    v_src := v_src || jsonb_build_object('updated_at', now(), 'updated_by', uid, 'client_updated_at', v_t);
    execute format(
      'update public.%1$I t set (%2$s) = (select %3$s from jsonb_populate_record(null::public.%1$I, $1) r) '
      'where t.id = $2',
      v_table,
      (select string_agg(quote_ident(u.c), ', ' order by u.i) from unnest(v_upd) with ordinality u(c, i)),
      (select string_agg('r.' || quote_ident(u.c), ', ' order by u.i) from unnest(v_upd) with ordinality u(c, i)))
      using v_src, v_id;
  end if;

  execute format('select to_jsonb(t) from public.%I t where t.id = $1', v_table) into v_new using v_id;

  insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
  values (v_table, v_id, v_group, v_vop, v_new, uid, v_t);

  -- Activity (rule 9); imports write one summary later instead of a row per record.
  if v_source <> 'import' then
    v_type := case v_entity
      when 'group' then case v_vop
        when 'insert' then 'group_created' when 'delete' then 'group_deleted' when 'restore' then 'group_restored'
        else case
          when v_row ->> 'archived_at' is null and v_new ->> 'archived_at' is not null then 'group_archived'
          when v_row ->> 'archived_at' is not null and v_new ->> 'archived_at' is null then 'group_unarchived'
          -- 0026: an edit of the group notes alone is its own entry (in-app only, D-034 C5).
          when v_row -> 'whiteboard' is distinct from v_new -> 'whiteboard'
               and not exists (select 1 from unnest(v_cols) c
                               where c <> 'whiteboard' and v_row -> c is distinct from v_new -> c)
            then 'whiteboard_updated'
          else 'group_updated' end
        end
      when 'member' then case v_vop when 'delete' then 'member_removed' when 'update' then 'group_updated'
                                    else 'member_added' end
      when 'comment' then case v_vop when 'delete' then 'comment_deleted' else 'comment_added' end
      else v_entity || '_' || case v_vop when 'insert' then 'added' when 'update' then 'edited'
                                         when 'delete' then 'deleted' else 'restored' end
    end;
    v_adata := case v_entity
      when 'group' then jsonb_build_object('name', v_new ->> 'name')
      when 'member' then jsonb_build_object('member_id', v_id, 'name', v_new ->> 'display_name')
      when 'expense' then jsonb_build_object(
        'description', v_new ->> 'description', 'total', (v_new ->> 'total')::bigint,
        'currency', v_new ->> 'currency',
        'members', (select coalesce(jsonb_agg(k order by k), '[]'::jsonb)
                    from (select jsonb_object_keys(v_new -> 'payers') as k
                          union select jsonb_object_keys(v_new -> 'shares')) s))
      when 'payment' then jsonb_build_object(
        'amount', (v_new ->> 'amount')::bigint, 'currency', v_new ->> 'currency',
        'from_member', v_new ->> 'from_member', 'to_member', v_new ->> 'to_member')
      else jsonb_build_object('target_type', v_new ->> 'target_type', 'target_id', v_new ->> 'target_id')
    end;
    if v_entity = 'comment' and v_vop = 'update' then
      v_adata := v_adata || '{"edited": true}'::jsonb;
    elsif v_vop = 'restore' then
      v_adata := v_adata || '{"restored": true}'::jsonb;
    end if;
    select gm.id into v_actor from public.group_members gm
    where gm.group_id = v_group and gm.user_id = uid and gm.status = 'active' and gm.deleted_at is null
    limit 1;
    insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
    values (v_group, uid, v_actor, v_type, v_entity, v_id, v_adata);
  end if;

  return jsonb_build_object('status', 'applied', 'seq', (v_new ->> 'seq')::bigint);
end;
$$;

-- 0014 trigger: the new columns count as group edits; a reminder change alone is a setting.
create or replace function private.group_settings_note()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if row(new.name, new.type, new.main_currency, new.cover_kind, new.cover_path, new.archived_at, new.deleted_at,
         new.trip_starts_on, new.trip_ends_on, new.whiteboard)
     is not distinct from
     row(old.name, old.type, old.main_currency, old.cover_kind, old.cover_path, old.archived_at, old.deleted_at,
         old.trip_starts_on, old.trip_ends_on, old.whiteboard) then
    if new.simplify_debts is distinct from old.simplify_debts then
      perform set_config('splitify.settings_changed', jsonb_build_object(
        'group_id', new.id, 'setting', 'simplify_debts', 'simplify_debts', new.simplify_debts)::text, true);
    elsif new.default_split is distinct from old.default_split then
      perform set_config('splitify.settings_changed', jsonb_build_object(
        'group_id', new.id, 'setting', 'default_split')::text, true);
    elsif new.settle_reminder is distinct from old.settle_reminder then
      -- 0026: "turned on weekly settle-up reminders" (D-034 C4).
      perform set_config('splitify.settings_changed', jsonb_build_object(
        'group_id', new.id, 'setting', 'settle_reminder', 'settle_reminder', new.settle_reminder)::text, true);
    end if;
  end if;
  return null;
end;
$$;

-- ------------------------------------------------------------------ settle-up nudges (C4)

-- One row per group and day a nudge went out (idempotent cron, also when it is run by hand). Server only: RLS on,
-- no policies, no grants.
create table if not exists private.settle_nudges_sent (
  group_id uuid not null references public.groups (id) on delete cascade,
  day date not null,
  reason text not null check (reason in ('weekly', 'monthly', 'trip_end')),
  created_at timestamptz not null default now(),
  primary key (group_id, day)
);
alter table private.settle_nudges_sent enable row level security;
revoke all on table private.settle_nudges_sent from public, anon, authenticated;

-- A member's non-zero nets in words, main currency first: "you owe ₹200 · you're owed $10" (same sums as
-- private.member_has_balance, 0010: paid - share per expense, + paid / - received per payment).
create or replace function private.balance_words(p_group uuid, p_member uuid, p_main text)
returns text
language sql
stable
set search_path = ''
as $$
  select string_agg(case when s.v < 0 then 'you owe ' else 'you''re owed ' end
                    || private.format_money(abs(s.v)::bigint, s.currency), ' · '
                    order by (s.currency = p_main) desc, s.currency)
  from (
    select x.currency::text as currency, sum(x.v) as v
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
    ) x
    group by x.currency
    having sum(x.v) <> 0
  ) s;
$$;

-- Writes the day's settle_nudge activity rows (the fan-out turns them into notifications) and returns how many.
-- Due: the day after trip_ends_on (any reminder setting), weekly reminders on the weekday the group was created
-- (not on that first day), monthly reminders on the 1st. Skipped: deleted / archived groups, groups where every
-- net is 0, groups already nudged that day. p_today = the day in Asia/Kolkata unless given (tests).
create or replace function private.send_settle_nudges(p_today date default null)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := coalesce(p_today, (now() at time zone 'Asia/Kolkata')::date);
  g record;
  v_reason text;
  v_count int := 0;
begin
  for g in
    select gg.id, gg.name, gg.settle_reminder, gg.trip_ends_on,
           (gg.created_at at time zone 'Asia/Kolkata')::date as created_day
    from public.groups gg
    where gg.deleted_at is null and gg.archived_at is null
      and (gg.settle_reminder in ('weekly', 'monthly') or gg.trip_ends_on = v_today - 1)
    order by gg.id
  loop
    v_reason := case
      when g.trip_ends_on = v_today - 1 then 'trip_end'
      when g.settle_reminder = 'weekly' and g.created_day < v_today
           and extract(isodow from g.created_day) = extract(isodow from v_today) then 'weekly'
      when g.settle_reminder = 'monthly' and extract(day from v_today) = 1 then 'monthly'
    end;
    continue when v_reason is null;
    continue when not exists (select 1 from public.group_members gm
                              where gm.group_id = g.id and gm.deleted_at is null
                                and private.member_has_balance(g.id, gm.id));
    insert into private.settle_nudges_sent (group_id, day, reason) values (g.id, v_today, v_reason)
    on conflict (group_id, day) do nothing;
    continue when not found;
    insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
    values (g.id, null, null, 'settle_nudge', 'group', g.id, jsonb_build_object('reason', v_reason, 'name', g.name));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ------------------------------------------------------------------ notification fan-out (0016 bodies + 0026)

create or replace function private.notification_kind(p_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_type in ('expense_added', 'expense_edited', 'expense_deleted', 'expense_restored') then 'expenses'
    when p_type in ('payment_added', 'payment_edited', 'payment_deleted', 'payment_restored') then 'payments'
    when p_type in ('reminder_sent', 'settle_nudge') then 'reminders'
    when p_type = 'comment_added' then 'comments'
    when p_type in ('member_joined', 'member_claimed', 'member_left', 'member_removed', 'settings_changed',
                    'whiteboard_updated')
      then 'groups'
  end;
$$;

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
  elsif v_kind = 'reminders' and a.type = 'settle_nudge' then
    -- 0026: a settle-up nudge goes to everyone who still owes or is owed something in the group.
    v_members := array(select gm.id from public.group_members gm
                       where gm.group_id = a.group_id and private.member_has_balance(a.group_id, gm.id));
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
  elsif a.type = 'settle_nudge' then
    -- 0026: "Time to settle up: you owe ₹200 · you're owed $10" (D-034 C4), the reader's own balance.
    v_body := case when d ->> 'reason' = 'trip_end' then 'Your trip is over. Time to settle up: '
                   else 'Time to settle up: ' end
      || coalesce(private.balance_words(a.group_id, p_member, g.main_currency), 'see who owes whom');
    v_target_type := 'balances';
  elsif a.type = 'whiteboard_updated' then
    v_body := v_actor || ' updated the group notes';
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
      when d ->> 'setting' = 'settle_reminder' and d ->> 'settle_reminder' in ('weekly', 'monthly')
        then v_actor || ' turned on ' || (d ->> 'settle_reminder') || ' settle-up reminders'
      when d ->> 'setting' = 'settle_reminder' then v_actor || ' turned off settle-up reminders'
      else v_actor || ' changed the group settings'
    end;
  end if;

  v_title := case when a.type = 'settle_nudge' and g.type = 'direct' then 'Splitify'
                  when g.type = 'direct' then v_actor else coalesce(g.name, 'Splitify') end;
  return jsonb_build_object(
    'title', left(v_title, 200),
    'body', left(v_body, 600),
    'data', jsonb_build_object(
      'target_type', v_target_type, 'target_id', v_target, 'group_id', a.group_id,
      'actor_member_id', a.actor_member_id, 'actor_name', v_actor));
end;
$$;

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
      v_push := private.kind_on(v_kinds, v_kind, 'push') and not (new.group_id = any (coalesce(v_muted, '{}')))
                and new.type <> 'whiteboard_updated';   -- 0026: notes edits stay in the app (D-034 C5)
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

-- ------------------------------------------------------------------ cron + grants

-- 10:00 IST = 04:30 UTC (03-backend.md §6). cron.schedule with an existing name updates that job.
select cron.schedule('settle-nudges', '30 4 * * *', 'select private.send_settle_nudges()');

revoke all on function private.balance_words(uuid, uuid, text) from public, anon, authenticated;
revoke all on function private.send_settle_nudges(date) from public, anon, authenticated;
