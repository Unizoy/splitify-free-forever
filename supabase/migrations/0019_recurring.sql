-- 0019 Recurring bills (phase 16; planning/08-feature-specs.md #12, 03-backend.md §2 §6). Numbered 0019 per S-099
-- (the phase file's "0012" is superseded).
--   * next-date rules = lib/domain/rules/recurrence.dart (shared vectors: test/fixtures/recurring_vectors.json)
--   * recurring_templates: a synced entity (`entity: 'recurring'` in apply_mutations, `recurring_templates` in
--     pull_changes); apply_mutations dispatches it to private.sync_apply_recurring, every other entity still goes
--     to private.sync_apply_one (0009) untouched
--   * private.generate_recurring(): the `generate-recurring` cron (00:10 Asia/Kolkata) adds the copies with
--     deterministic ids md5(template_id || date), source 'recurring', activity expense_added {recurring: true}

-- ------------------------------------------------------------------ next-date rules

-- `YYYY-MM-DD` text -> date; NOT_A_DATE for any other text or an impossible date (2026-02-30).
create or replace function private.recurring_date(t text)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  d date;
begin
  if t is null then
    return null;
  end if;
  if t !~ '^\d{4}-\d{2}-\d{2}$' then
    perform private.fail('NOT_A_DATE', jsonb_build_object('value', t));
  end if;
  begin
    d := t::date;
  exception when others then
    perform private.fail('NOT_A_DATE', jsonb_build_object('value', t));
  end;
  if to_char(d, 'YYYY-MM-DD') <> t then
    perform private.fail('NOT_A_DATE', jsonb_build_object('value', t));
  end if;
  return d;
end;
$$;

-- UNKNOWN_INTERVAL / ENDS_BEFORE_ANCHOR (ends_on is inclusive and may equal the anchor).
create or replace function private.recurring_check(p_interval text, p_anchor date, p_ends_on date)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_interval is null or p_interval not in ('weekly', 'fortnightly', 'monthly', 'yearly') then
    perform private.fail('UNKNOWN_INTERVAL', jsonb_build_object('interval', coalesce(p_interval, '')));
  end if;
  if p_anchor is null then
    perform private.fail('NOT_A_DATE', jsonb_build_object('value', ''));
  end if;
  if p_ends_on is not null and p_ends_on < p_anchor then
    perform private.fail('ENDS_BEFORE_ANCHOR');
  end if;
end;
$$;

-- Date of occurrence p_index (0 = the anchor), always counted from the anchor. `date + n months` clamps to the
-- month end (31st -> 28/29/30), so a 31st returns to the 31st the month after a short one.
create or replace function private.recurring_occurrence(p_interval text, p_anchor date, p_index int)
returns date
language plpgsql
immutable
set search_path = ''
as $$
begin
  return case p_interval
    when 'weekly' then p_anchor + 7 * p_index
    when 'fortnightly' then p_anchor + 14 * p_index
    when 'monthly' then (p_anchor + make_interval(months => p_index))::date
    when 'yearly' then (p_anchor + make_interval(years => p_index))::date
  end;
end;
$$;

-- Smallest copy index (>= 1) whose date is on or after p_date.
create or replace function private.recurring_first_index(p_interval text, p_anchor date, p_date date)
returns int
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_step int;
  v_days int;
  v_guess int;
begin
  if p_interval in ('weekly', 'fortnightly') then
    v_step := case p_interval when 'weekly' then 7 else 14 end;
    v_days := p_date - p_anchor;
    return case when v_days <= v_step then 1 else (v_days + v_step - 1) / v_step end;
  end if;
  v_guess := case p_interval
    when 'monthly' then (extract(year from p_date)::int - extract(year from p_anchor)::int) * 12
                        + extract(month from p_date)::int - extract(month from p_anchor)::int
    else extract(year from p_date)::int - extract(year from p_anchor)::int
  end;
  v_guess := greatest(v_guess, 1);
  if private.recurring_occurrence(p_interval, p_anchor, v_guess) < p_date then
    return v_guess + 1;
  end if;
  return v_guess;
end;
$$;

-- First copy strictly after p_after and not after p_ends_on; null when none is left.
create or replace function private.recurring_next_after(p_interval text, p_anchor date, p_ends_on date,
                                                         p_after date)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  d date;
begin
  perform private.recurring_check(p_interval, p_anchor, p_ends_on);
  d := private.recurring_occurrence(p_interval, p_anchor,
                                    private.recurring_first_index(p_interval, p_anchor, p_after + 1));
  return case when p_ends_on is not null and d > p_ends_on then null else d end;
end;
$$;

-- One generator run on p_today: every copy from p_next_date up to p_today (catch-up), oldest first, and the new
-- next_date (null = the template ends). Running again with the returned next on the same day adds nothing.
create or replace function private.recurring_run(p_interval text, p_anchor date, p_ends_on date, p_next_date date,
                                                 p_today date, out dates date[], out next_copy date)
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_i int;
  d date;
begin
  perform private.recurring_check(p_interval, p_anchor, p_ends_on);
  dates := '{}';
  v_i := private.recurring_first_index(p_interval, p_anchor, p_next_date);
  loop
    d := private.recurring_occurrence(p_interval, p_anchor, v_i);
    if p_ends_on is not null and d > p_ends_on then
      next_copy := null;
      return;
    end if;
    if d > p_today then
      next_copy := d;
      return;
    end if;
    dates := dates || d;
    v_i := v_i + 1;
  end loop;
end;
$$;

-- ------------------------------------------------------------------ table

-- One repeat rule per row. `template` holds the expense fields every copy gets (kind, description, notes,
-- category, currency, total, payers, shares, split_kind, split_values); no conversion and no receipt (those
-- belong to one record). `expense_id` = the expense it was started from. `next_date` is kept by the server
-- (null = no copies left); `active = false` = stopped ("Stop repeating").
create table public.recurring_templates (
  id uuid primary key,
  group_id uuid not null references public.groups (id),
  expense_id uuid,
  "interval" text not null check ("interval" in ('weekly', 'fortnightly', 'monthly', 'yearly')),
  anchor_date date not null,
  next_date date,
  ends_on date check (ends_on is null or ends_on >= anchor_date),
  active boolean not null default true,
  template jsonb not null check (jsonb_typeof(template) = 'object'),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz,
  updated_by uuid,
  client_updated_at timestamptz,
  deleted_at timestamptz,
  deleted_by uuid,
  seq bigint not null
);

comment on table public.recurring_templates is 'Recurring bills (#12): repeat rules; copies are added by the generate-recurring cron.';

create index recurring_templates_group_seq_idx on public.recurring_templates (group_id, seq);
create index recurring_templates_due_idx on public.recurring_templates (next_date)
  where active and deleted_at is null;
create index recurring_templates_expense_idx on public.recurring_templates (expense_id);
create index expenses_recurring_idx on public.expenses (recurring_id);

alter table public.expenses
  add constraint expenses_recurring_id_fkey foreign key (recurring_id) references public.recurring_templates (id);

create trigger recurring_templates_bump_seq before insert or update on public.recurring_templates
  for each row execute function private.bump_seq();
create trigger recurring_templates_broadcast after insert or update on public.recurring_templates
  for each row execute function private.broadcast_change();

alter table public.recurring_templates enable row level security;
create policy recurring_templates_select on public.recurring_templates for select to authenticated
  using (private.is_member(group_id));
revoke all on public.recurring_templates from anon, authenticated;
grant select on public.recurring_templates to authenticated;

-- ------------------------------------------------------------------ template validation

-- The client's template -> the stored template (only known keys; money rules checked like an expense).
create or replace function private.recurring_template(p_group uuid, t jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_total bigint;
  v_desc text;
  v_notes text;
  v_out jsonb;
begin
  if t is null or jsonb_typeof(t) <> 'object' then
    perform private.fail('INVALID_TEMPLATE');
  end if;
  if coalesce(t ->> 'kind', 'expense') <> 'expense' then
    perform private.fail('INVALID_TEMPLATE', jsonb_build_object('field', 'kind'));
  end if;
  v_desc := btrim(coalesce(t ->> 'description', ''));
  if char_length(v_desc) not between 1 and 120 then
    perform private.fail('INVALID_TEMPLATE', jsonb_build_object('field', 'description'));
  end if;
  v_notes := nullif(btrim(coalesce(t ->> 'notes', '')), '');
  if char_length(v_notes) > 1000 then
    perform private.fail('INVALID_TEMPLATE', jsonb_build_object('field', 'notes'));
  end if;
  if not exists (select 1 from public.categories c where c.key = coalesce(t ->> 'category', 'other.general')) then
    perform private.fail('INVALID_REFERENCE', jsonb_build_object('field', 'category'));
  end if;
  if not exists (select 1 from public.currencies c where c.code = t ->> 'currency') then
    perform private.fail('INVALID_REFERENCE', jsonb_build_object('field', 'currency'));
  end if;
  if jsonb_typeof(t -> 'total') is distinct from 'number'
     or (t ->> 'total')::numeric <> trunc((t ->> 'total')::numeric) then
    perform private.fail('INVALID_AMOUNT');
  end if;
  v_total := (t ->> 'total')::numeric;
  perform money.check_amount(v_total);
  perform private.assert_parts(p_group, t -> 'payers', v_total, 'PAYERS_SUM_MISMATCH');
  perform private.assert_parts(p_group, t -> 'shares', v_total, 'SPLIT_SUM_MISMATCH');
  if coalesce(t ->> 'split_kind', 'equal') not in ('equal', 'exact', 'percent', 'shares', 'adjust') then
    perform private.fail('INVALID_TEMPLATE', jsonb_build_object('field', 'split_kind'));
  end if;
  if t ? 'split_values' and jsonb_typeof(t -> 'split_values') not in ('object', 'null') then
    perform private.fail('INVALID_TEMPLATE', jsonb_build_object('field', 'split_values'));
  end if;
  v_out := jsonb_build_object(
    'kind', 'expense', 'description', v_desc, 'notes', v_notes,
    'category', coalesce(t ->> 'category', 'other.general'), 'currency', t ->> 'currency', 'total', v_total,
    'payers', t -> 'payers', 'shares', t -> 'shares', 'split_kind', coalesce(t ->> 'split_kind', 'equal'),
    'split_values', coalesce(t -> 'split_values', 'null'::jsonb));
  return v_out;
end;
$$;

-- ------------------------------------------------------------------ sync: apply one template mutation

-- Same contract as private.sync_apply_one (0009): membership, id/group checks, last-write-wins with the loser
-- kept in history, record_versions, activity. upsert creates or edits (active=false stops, true resumes);
-- delete/restore are soft. next_date is the server's: on create and on a schedule change (interval, anchor,
-- end date, resume) it becomes the first copy on or after the day of the save (Asia/Kolkata) — copies are never
-- back-filled before that day, and a copy already made for that day is not made again (deterministic id).
create or replace function private.sync_apply_recurring(m jsonb, uid uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_op text := coalesce(m ->> 'op', '');
  v_id uuid := private.try_uuid(m ->> 'id');
  v_group uuid := private.try_uuid(m ->> 'group_id');
  v_data jsonb := coalesce(nullif(m -> 'data', 'null'::jsonb), '{}'::jsonb);
  v_t timestamptz;
  v_day date;
  v_row public.recurring_templates;
  v_new public.recurring_templates;
  v_old jsonb;
  v_interval text;
  v_anchor date;
  v_ends date;
  v_active boolean;
  v_template jsonb;
  v_next date;
  v_vop text;
  v_type text;
  v_actor uuid;
begin
  if v_op not in ('upsert', 'delete', 'restore') or v_id is null or v_group is null
     or jsonb_typeof(v_data) <> 'object' or coalesce(m ->> 'source', 'app') <> 'app' then
    perform private.fail('INVALID_MUTATION');
  end if;
  v_t := least(coalesce((m ->> 'client_updated_at')::timestamptz, now()), now());
  v_day := (v_t at time zone 'Asia/Kolkata')::date;

  select * into v_row from public.recurring_templates t where t.id = v_id;
  if not private.is_member(v_group) then
    perform private.fail('NOT_MEMBER');
  end if;
  if v_row.id is not null and v_row.group_id <> v_group then
    perform private.fail('ID_CONFLICT');
  end if;
  if v_row.id is null and v_op <> 'upsert' then
    perform private.fail('NOT_FOUND');
  end if;

  if v_row.id is not null and v_t < coalesce(v_row.client_updated_at, '-infinity') then
    insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
    values ('recurring_templates', v_id, v_group, 'conflict_lost',
            to_jsonb(v_row) || (v_data - 'next_date') || jsonb_build_object('client_updated_at', v_t, 'lost_op', v_op),
            uid, v_t);
    return jsonb_build_object('status', 'superseded', 'seq', v_row.seq);
  end if;

  perform private.assert_group_writable(v_group);
  v_old := to_jsonb(v_row);

  if v_op = 'upsert' then
    v_interval := case when v_data ? 'interval' then v_data ->> 'interval' else v_row."interval" end;
    v_anchor := case when v_data ? 'anchor_date' then private.recurring_date(v_data ->> 'anchor_date')
                     else v_row.anchor_date end;
    v_ends := case when v_data ? 'ends_on' then private.recurring_date(v_data ->> 'ends_on') else v_row.ends_on end;
    v_active := case when jsonb_typeof(v_data -> 'active') = 'boolean' then (v_data ->> 'active')::boolean
                     else coalesce(v_row.active, true) end;
    v_template := case when v_data ? 'template' then private.recurring_template(v_group, v_data -> 'template')
                       else v_row.template end;
    if v_template is null then
      perform private.fail('INVALID_TEMPLATE');
    end if;
    perform private.recurring_check(v_interval, v_anchor, v_ends);
    if v_row.id is null
       or v_interval is distinct from v_row."interval" or v_anchor is distinct from v_row.anchor_date
       or v_ends is distinct from v_row.ends_on or (v_active and not v_row.active) then
      v_next := private.recurring_next_after(v_interval, v_anchor, v_ends, v_day - 1);
    else
      v_next := v_row.next_date;
    end if;

    if v_row.id is null then
      v_vop := 'insert';
      insert into public.recurring_templates (id, group_id, expense_id, "interval", anchor_date, next_date, ends_on,
                                              active, template, created_at, created_by, updated_at, updated_by,
                                              client_updated_at, seq)
      values (v_id, v_group, private.try_uuid(v_data ->> 'expense_id'), v_interval, v_anchor, v_next, v_ends,
              v_active, v_template, now(), uid, now(), uid, v_t, 0)
      returning * into v_new;
    else
      v_vop := 'update';
      update public.recurring_templates t
      set "interval" = v_interval, anchor_date = v_anchor, next_date = v_next, ends_on = v_ends, active = v_active,
          template = v_template, updated_at = now(), updated_by = uid, client_updated_at = v_t
      where t.id = v_id
      returning * into v_new;
    end if;
  else
    v_vop := v_op;
    update public.recurring_templates t
    set deleted_at = case when v_op = 'delete' then now() end,
        deleted_by = case when v_op = 'delete' then uid end,
        updated_at = now(), updated_by = uid, client_updated_at = v_t
    where t.id = v_id
    returning * into v_new;
  end if;

  insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
  values ('recurring_templates', v_id, v_group, v_vop, to_jsonb(v_new), uid, v_t);

  v_type := case
    when v_vop = 'insert' then 'recurring_created'
    when v_vop = 'delete' or (v_vop = 'update' and (v_old ->> 'active')::boolean and not v_new.active)
      then 'recurring_stopped'
    else 'recurring_updated'
  end;
  select gm.id into v_actor from public.group_members gm
  where gm.group_id = v_group and gm.user_id = uid and gm.status = 'active' and gm.deleted_at is null
  limit 1;
  insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
  values (v_group, uid, v_actor, v_type, 'recurring', v_id, jsonb_build_object(
    'description', v_new.template ->> 'description', 'total', (v_new.template ->> 'total')::bigint,
    'currency', v_new.template ->> 'currency', 'interval', v_new."interval", 'active', v_new.active,
    'next_date', v_new.next_date, 'expense_id', v_new.expense_id)
    || case when v_vop = 'restore' then '{"restored": true}'::jsonb
            when v_vop = 'update' and not (v_old ->> 'active')::boolean and v_new.active
              then '{"resumed": true}'::jsonb
            else '{}'::jsonb end);

  return jsonb_build_object('status', 'applied', 'seq', v_new.seq);
end;
$$;

-- ------------------------------------------------------------------ apply_mutations (dispatch)

-- Body as in 0009; the only change is the dispatch of `entity: 'recurring'` to private.sync_apply_recurring.
create or replace function public.apply_mutations(batch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_results jsonb := '[]'::jsonb;
  v_m jsonb;
  v_mid uuid;
  v_res jsonb;
  v_state text;
  v_msg text;
begin
  if v_uid is null then
    perform private.fail('NOT_AUTHENTICATED');
  end if;
  if batch is null or jsonb_typeof(batch) <> 'array' then
    perform private.fail('INVALID_BATCH');
  end if;
  if jsonb_array_length(batch) > 100 then
    perform private.fail('BATCH_TOO_LARGE');
  end if;

  for v_m in select e.value from jsonb_array_elements(batch) with ordinality as e(value, i) order by e.i loop
    v_mid := case when jsonb_typeof(v_m) = 'object' then private.try_uuid(v_m ->> 'mutation_id') end;
    if v_mid is null then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'mutation_id', case when jsonb_typeof(v_m) = 'object' then v_m -> 'mutation_id' end,
        'status', 'rejected', 'code', 'INVALID_MUTATION'));
      continue;
    end if;

    select l.result into v_res from public.mutation_log l where l.mutation_id = v_mid;
    if found then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'mutation_id', v_mid, 'status', 'duplicate', 'result', v_res, 'seq', v_res -> 'seq'));
      continue;
    end if;

    begin
      if v_m ->> 'entity' = 'recurring' then
        v_res := private.sync_apply_recurring(v_m, v_uid);
      else
        v_res := private.sync_apply_one(v_m, v_uid);
      end if;
      insert into public.mutation_log (mutation_id, user_id, result) values (v_mid, v_uid, v_res);
      v_results := v_results || jsonb_build_array(jsonb_build_object('mutation_id', v_mid) || v_res);
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'mutation_id', v_mid, 'status', 'rejected', 'code', private.sync_error_code(v_state, v_msg)));
    end;
  end loop;

  return jsonb_build_object('server_time', now(), 'results', v_results);
end;
$$;

-- ------------------------------------------------------------------ pull_changes (+ recurring_templates)

-- Body as in 0009 plus the `recurring_templates` rows.
create or replace function public.pull_changes(cursors jsonb default '{}'::jsonb, since_user_seq bigint default 0,
                                               page_size int default 500)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_size int := least(greatest(coalesce(page_size, 500), 1), 1000);
  v_since bigint := coalesce(since_user_seq, 0);
  v_cursors jsonb := case when jsonb_typeof(cursors) = 'object' then cursors else '{}'::jsonb end;
  v_mine uuid[];
  v_rows jsonb;
  v_max bigint;
  v_more boolean;
  v_pmore boolean;
  v_user_seq bigint;
  v_profiles jsonb;
  v_next jsonb;
  v_lost jsonb;
begin
  if v_uid is null then
    perform private.fail('NOT_AUTHENTICATED');
  end if;

  select coalesce(array_agg(distinct m.group_id), '{}') into v_mine
  from public.group_members m
  where m.user_id = v_uid and m.status = 'active' and m.deleted_at is null;

  with mine as (
    select g as id,
           case when jsonb_typeof(v_cursors -> g::text) = 'number'
                then floor((v_cursors ->> g::text)::numeric)::bigint else 0 end as cur
    from unnest(v_mine) g
  ),
  changes as (
    select 'groups' as tbl, x.seq, to_jsonb(x) as r
      from public.groups x join mine on mine.id = x.id where x.seq > mine.cur
    union all
    select 'group_members', x.seq, to_jsonb(x)
      from public.group_members x join mine on mine.id = x.group_id where x.seq > mine.cur
    union all
    select 'expenses', x.seq, to_jsonb(x)
      from public.expenses x join mine on mine.id = x.group_id where x.seq > mine.cur
    union all
    select 'payments', x.seq, to_jsonb(x)
      from public.payments x join mine on mine.id = x.group_id where x.seq > mine.cur
    union all
    select 'comments', x.seq, to_jsonb(x)
      from public.comments x join mine on mine.id = x.group_id where x.seq > mine.cur
    union all
    select 'recurring_templates', x.seq, to_jsonb(x)
      from public.recurring_templates x join mine on mine.id = x.group_id where x.seq > mine.cur
    union all
    select 'activity', x.seq, to_jsonb(x)
      from public.activity x join mine on mine.id = x.group_id where x.seq > mine.cur
  ),
  page as (
    select c.tbl, c.seq, c.r, row_number() over (order by c.seq) as rn
    from changes c order by c.seq limit v_size + 1
  )
  select
    count(*) > v_size,
    max(p.seq) filter (where p.rn <= v_size),
    jsonb_build_object(
      'groups', coalesce(jsonb_agg(p.r order by p.seq) filter (where p.tbl = 'groups' and p.rn <= v_size), '[]'),
      'group_members',
        coalesce(jsonb_agg(p.r order by p.seq) filter (where p.tbl = 'group_members' and p.rn <= v_size), '[]'),
      'expenses', coalesce(jsonb_agg(p.r order by p.seq) filter (where p.tbl = 'expenses' and p.rn <= v_size), '[]'),
      'payments', coalesce(jsonb_agg(p.r order by p.seq) filter (where p.tbl = 'payments' and p.rn <= v_size), '[]'),
      'comments', coalesce(jsonb_agg(p.r order by p.seq) filter (where p.tbl = 'comments' and p.rn <= v_size), '[]'),
      'recurring_templates',
        coalesce(jsonb_agg(p.r order by p.seq) filter (where p.tbl = 'recurring_templates' and p.rn <= v_size),
                 '[]'),
      'activity', coalesce(jsonb_agg(p.r order by p.seq) filter (where p.tbl = 'activity' and p.rn <= v_size), '[]'))
  into v_more, v_max, v_rows
  from page p;

  select coalesce(jsonb_object_agg(
           g::text,
           greatest(case when jsonb_typeof(v_cursors -> g::text) = 'number'
                         then floor((v_cursors ->> g::text)::numeric)::bigint else 0 end,
                    coalesce(v_max, 0))), '{}'::jsonb)
  into v_next
  from unnest(v_mine) g;

  select coalesce(jsonb_agg(k order by k), '[]'::jsonb) into v_lost
  from jsonb_object_keys(v_cursors) k
  where private.try_uuid(k) is not null and not (private.try_uuid(k) = any (v_mine));

  with co as (
    select v_uid as id
    union
    select them.user_id from public.group_members me
    join public.group_members them on them.group_id = me.group_id
    where me.user_id = v_uid and me.status = 'active' and me.deleted_at is null and them.user_id is not null
  ),
  by_seq as (
    select x.seq, to_jsonb(x) as r, x.id, row_number() over (order by x.seq) as rn
    from public.profiles x join co on co.id = x.id
    where x.seq > v_since order by x.seq limit v_size + 1
  ),
  linked as (
    select x.seq, to_jsonb(x) as r
    from public.profiles x
    where x.id in (select (e ->> 'user_id')::uuid from jsonb_array_elements(v_rows -> 'group_members') e
                   where e ->> 'user_id' is not null)
      and x.id not in (select b.id from by_seq b where b.rn <= v_size)
  )
  select
    (select count(*) > v_size from by_seq),
    (select max(b.seq) from by_seq b where b.rn <= v_size),
    (select coalesce(jsonb_agg(u.r order by u.seq), '[]'::jsonb)
       from (select b.seq, b.r from by_seq b where b.rn <= v_size union all select l.seq, l.r from linked l) u)
  into v_pmore, v_user_seq, v_profiles;

  return jsonb_build_object(
    'server_time', now(),
    'rows', v_rows || jsonb_build_object('profiles', v_profiles),
    'next_cursors', v_next,
    'user_seq', greatest(v_since, coalesce(v_user_seq, v_since)),
    'lost_groups', v_lost,
    'has_more', v_more or v_pmore);
end;
$$;

-- ------------------------------------------------------------------ generator (cron)

-- Adds every due copy (next_date <= today in Asia/Kolkata unless p_today is given) and advances next_date.
-- Idempotent: copy id = md5(template id || date) and `on conflict do nothing`, so a double run (or a re-run after
-- a crash) makes one copy. At most 31 copies per template per run (a long outage catches up over a few days).
-- Archived or deleted groups get no copies (their templates just move on). A template whose copy is refused
-- (e.g. a person no longer in the group) stops, with the reason in a recurring_stopped activity row.
-- Returns the number of copies added.
create or replace function private.generate_recurring(p_today date default null)
returns int
language plpgsql
set search_path = ''
as $$
declare
  v_today date := coalesce(p_today, (now() at time zone 'Asia/Kolkata')::date);
  t public.recurring_templates;
  g record;
  r record;
  d date;
  v_dates date[];
  v_next date;
  v_id uuid;
  v_new public.expenses;
  v_actor uuid;
  v_count int := 0;
  v_state text;
  v_msg text;
begin
  for t in
    select * from public.recurring_templates x
    where x.active and x.deleted_at is null and x.next_date is not null and x.next_date <= v_today
    order by x.next_date, x.id
    for update skip locked
  loop
    begin
      select * into r from private.recurring_run(t."interval", t.anchor_date, t.ends_on, t.next_date, v_today);
      v_dates := r.dates;
      v_next := r.next_copy;
      if coalesce(array_length(v_dates, 1), 0) > 31 then
        v_next := v_dates[32];
        v_dates := v_dates[1:31];
      end if;
      select gg.archived_at, gg.deleted_at into g from public.groups gg where gg.id = t.group_id;
      if g.archived_at is null and g.deleted_at is null then
        select gm.id into v_actor from public.group_members gm
        where gm.group_id = t.group_id and gm.user_id = t.created_by and gm.deleted_at is null
        order by (gm.status = 'active') desc
        limit 1;
        foreach d in array v_dates loop
          v_id := md5(t.id::text || to_char(d, 'YYYY-MM-DD'))::uuid;
          v_new := null;
          insert into public.expenses (id, group_id, kind, description, notes, category, date, currency, total,
                                       payers, shares, split_kind, split_values, recurring_id, source, created_at,
                                       created_by, updated_at, updated_by, client_updated_at, seq)
          values (v_id, t.group_id, 'expense', t.template ->> 'description', t.template ->> 'notes',
                  coalesce(t.template ->> 'category', 'other.general'), d, t.template ->> 'currency',
                  (t.template ->> 'total')::bigint, t.template -> 'payers', t.template -> 'shares',
                  coalesce(t.template ->> 'split_kind', 'equal'), nullif(t.template -> 'split_values', 'null'::jsonb),
                  t.id, 'recurring', now(), t.created_by, now(), t.created_by, now(), 0)
          on conflict (id) do nothing
          returning * into v_new;
          if v_new.id is not null then
            v_count := v_count + 1;
            insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by,
                                                client_updated_at)
            values ('expenses', v_new.id, v_new.group_id, 'insert', to_jsonb(v_new), t.created_by, now());
            insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id,
                                         data)
            values (t.group_id, t.created_by, v_actor, 'expense_added', 'expense', v_new.id, jsonb_build_object(
              'description', v_new.description, 'total', v_new.total, 'currency', v_new.currency,
              'members', (select coalesce(jsonb_agg(k order by k), '[]'::jsonb)
                          from (select jsonb_object_keys(v_new.payers) as k
                                union select jsonb_object_keys(v_new.shares)) s),
              'recurring', true, 'recurring_id', t.id));
          end if;
        end loop;
      end if;
      update public.recurring_templates x set next_date = v_next where x.id = t.id;
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
      update public.recurring_templates x set active = false where x.id = t.id;
      insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
      values (t.group_id, null, null, 'recurring_stopped', 'recurring', t.id, jsonb_build_object(
        'description', t.template ->> 'description', 'total', (t.template ->> 'total')::bigint,
        'currency', t.template ->> 'currency', 'interval', t."interval", 'active', false,
        'reason', private.sync_error_code(v_state, v_msg)));
    end;
  end loop;
  return v_count;
end;
$$;

-- 00:10 IST = 18:40 UTC (03-backend.md §6). cron.schedule with an existing name updates that job.
select cron.schedule('generate-recurring', '40 18 * * *', 'select private.generate_recurring()');

-- ------------------------------------------------------------------ grants

revoke all on function private.recurring_date(text) from public, anon, authenticated;
revoke all on function private.recurring_check(text, date, date) from public, anon, authenticated;
revoke all on function private.recurring_occurrence(text, date, int) from public, anon, authenticated;
revoke all on function private.recurring_first_index(text, date, date) from public, anon, authenticated;
revoke all on function private.recurring_next_after(text, date, date, date) from public, anon, authenticated;
revoke all on function private.recurring_run(text, date, date, date, date) from public, anon, authenticated;
revoke all on function private.recurring_template(uuid, jsonb) from public, anon, authenticated;
revoke all on function private.sync_apply_recurring(jsonb, uuid) from public, anon, authenticated;
revoke all on function private.generate_recurring(date) from public, anon, authenticated;
revoke all on function public.apply_mutations(jsonb) from public, anon;
revoke all on function public.pull_changes(jsonb, bigint, int) from public, anon;
grant execute on function public.apply_mutations(jsonb) to authenticated;
grant execute on function public.pull_changes(jsonb, bigint, int) to authenticated;
