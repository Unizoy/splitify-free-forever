-- 0030 Monthly summary push and one push per batch settle-up (D-034 wave 2, W2-Y, S-434 / S-435).
--
--   * Batch settle-up: the phone tags each payment of one "Settle everything" with the same `data.batch_id` (not a
--     column). apply_mutations keeps it in the transaction setting `splitify.push_batch` while the payment is
--     applied, so the notification fan-out still writes one bell row per group (per-user settings, mutes and
--     "never the actor" unchanged) but marks their pushes 'batched' instead of 'pending'. After the batch,
--     private.flush_push_batches sends ONE push per person and batch: the first row's push goes out, worded for
--     the whole batch ("Asha settled up with you in 3 groups · ₹1,200") when there was more than one; the others
--     stay 'batched' (= covered by that push).
--   * Monthly summary (F14): notification kind 'summary', opt-in (push off unless `kinds.summary.push = true`). On
--     the 1st at 09:00 IST a cron job writes one bell row + push per person who asked for it: what they spent
--     last month (their shares, per currency, IOUs left out) across how many groups, and their balances now.
--     Sent once per person and month (private.monthly_summaries_sent).
--   * send-push reads `push_title` / `push_body` when set (the batch wording) and falls back to title / body.
-- public.apply_mutations, private.fanout_notifications and public.upsert_notification_settings are redefined from
-- their dev bodies (0029 / 0026 / 0016) with only these additions.

-- ------------------------------------------------------------------ notifications: kind, push states, push text

alter table public.notifications add column if not exists push_title text
  check (push_title is null or char_length(push_title) between 1 and 200);
alter table public.notifications add column if not exists push_body text
  check (push_body is null or char_length(push_body) between 1 and 600);

-- Both lists are extended from the live constraints, so values other migrations added are kept.
do $$
declare
  v_list text[];
  r record;
begin
  for r in select * from (values
      ('notifications_kind_check', 'kind', array['summary']),
      ('notifications_push_status_check', 'push_status', array['batched']))
      as x(con, col, extra)
  loop
    select array_agg(distinct t order by t) into v_list
    from (
      select (regexp_matches(pg_get_constraintdef(c.oid), '''([a-z_]+)''', 'g'))[1] as t
      from pg_constraint c
      where c.conrelid = 'public.notifications'::regclass and c.conname = r.con
      union all
      select unnest(r.extra)
    ) s;
    execute format('alter table public.notifications drop constraint if exists %I', r.con);
    execute format('alter table public.notifications add constraint %I check (%I = any (%L::text[]))',
                   r.con, r.col, v_list);
  end loop;
end;
$$;

-- A batched push that is released ('batched' -> 'pending') goes to send-push like a new one.
create trigger notifications_queue_push_released after update of push_status on public.notifications
  for each row when (old.push_status = 'batched' and new.push_status = 'pending')
  execute function private.queue_push();

-- ------------------------------------------------------------------ settings: the 'summary' kind

-- Body as on dev (0016); the only change is the allowed 'summary' kind.
create or replace function public.upsert_notification_settings(kinds jsonb default null, muted_group_ids uuid[] default null)
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
                  where k.key not in ('expenses', 'payments', 'reminders', 'comments', 'groups', 'summary')
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

-- ------------------------------------------------------------------ fan-out: batched pushes

-- Body as on dev (0026); a payment added inside a batch (`splitify.push_batch`) gets push_status 'batched' and the
-- batch id in its data.
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
  v_batch uuid := case when new.type = 'payment_added'
                       then private.try_uuid(nullif(current_setting('splitify.push_batch', true), '')) end;
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
              (v_content -> 'data') || case when v_batch is not null
                                            then jsonb_build_object('batch_id', v_batch) else '{}'::jsonb end,
              v_inapp,
              case when v_push and coalesce(v_url, '') <> '' then
                     case when v_batch is not null then 'batched' else 'pending' end
                   else 'skipped' end)
      on conflict (activity_id, user_id) do nothing;
    end loop;
  exception when others then
    raise warning 'fanout_notifications(%) failed: % %', new.id, sqlstate, sqlerrm;
  end;
  return null;
end;
$$;

-- One push per person and batch: the earliest row of the batch carries it.
create or replace function private.flush_push_batches(p_batches uuid[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_amounts text;
  v_actor text;
  v_count int := 0;
begin
  for r in
    select n.user_id, n.data ->> 'batch_id' as batch, count(*)::int as cnt, min(n.seq) as first_seq
    from public.notifications n
    where n.push_status = 'batched' and private.try_uuid(n.data ->> 'batch_id') = any (p_batches)
    group by n.user_id, n.data ->> 'batch_id'
    order by n.user_id
  loop
    select string_agg(private.format_money(s.total, s.currency), ' + ' order by s.currency) into v_amounts
    from (select a.data ->> 'currency' as currency, sum((a.data ->> 'amount')::bigint)::bigint as total
          from public.notifications n join public.activity a on a.id = n.activity_id
          where n.user_id = r.user_id and n.push_status = 'batched' and n.data ->> 'batch_id' = r.batch
          group by 1) s;
    select n.data ->> 'actor_name' into v_actor
    from public.notifications n where n.user_id = r.user_id and n.seq = r.first_seq;
    update public.notifications n
    set push_title = case when r.cnt > 1 then left(coalesce(v_actor, 'Splitify'), 200) end,
        push_body = case when r.cnt > 1
                         then left(coalesce(v_actor, 'Someone') || ' settled up with you in ' || r.cnt
                                   || ' groups' || coalesce(' · ' || v_amounts, ''), 600) end,
        data = n.data || jsonb_build_object('batch_count', r.cnt),
        push_status = 'pending'
    where n.user_id = r.user_id and n.seq = r.first_seq and n.push_status = 'batched';
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function private.flush_push_batches(uuid[]) from public, anon, authenticated;

-- ------------------------------------------------------------------ apply_mutations: the batch setting

-- Body as on dev (0029); a payment's `data.batch_id` is kept in `splitify.push_batch` while it is applied, and the
-- batches seen are flushed at the end.
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
  v_push_batch uuid;
  v_batches uuid[] := '{}';
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

    v_push_batch := case when v_m ->> 'entity' = 'payment' and v_m ->> 'op' = 'upsert'
                              and jsonb_typeof(v_m -> 'data') = 'object'
                         then private.try_uuid(v_m -> 'data' ->> 'batch_id') end;
    perform set_config('splitify.push_batch', coalesce(v_push_batch::text, ''), true);
    begin
      if v_m ->> 'entity' = 'recurring' then
        v_res := private.sync_apply_recurring(v_m, v_uid);
      elsif v_m ->> 'entity' = 'attachment' then
        v_res := private.sync_apply_attachment(v_m, v_uid);
      elsif v_m ->> 'source' = 'capture' then
        v_res := private.sync_apply_capture(v_m, v_uid);
      else
        v_res := private.sync_apply_one(v_m, v_uid);
      end if;
      insert into public.mutation_log (mutation_id, user_id, result) values (v_mid, v_uid, v_res);
      v_results := v_results || jsonb_build_array(jsonb_build_object('mutation_id', v_mid) || v_res);
      if v_push_batch is not null and not v_push_batch = any (v_batches) then
        v_batches := v_batches || v_push_batch;
      end if;
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'mutation_id', v_mid, 'status', 'rejected', 'code', private.sync_error_code(v_state, v_msg)));
    end;
  end loop;
  perform set_config('splitify.push_batch', '', true);

  if cardinality(v_batches) > 0 then
    begin
      perform private.flush_push_batches(v_batches);
    exception when others then
      raise warning 'flush_push_batches failed: % %', sqlstate, sqlerrm;
    end;
  end if;

  return jsonb_build_object('server_time', now(), 'results', v_results);
end;
$$;

-- ------------------------------------------------------------------ monthly summary

create table private.monthly_summaries_sent (
  user_id uuid not null references auth.users (id) on delete cascade,
  month date not null,
  sent_at timestamptz not null default now(),
  primary key (user_id, month)
);
alter table private.monthly_summaries_sent enable row level security;
revoke all on private.monthly_summaries_sent from public, anon, authenticated;

-- Spent = my shares of last month's expenses (IOUs left out) per currency; balances = my nets now per currency,
-- like the settle-up nudge's words (rule 4: never mixed). p_today = the day in Asia/Kolkata unless given (tests).
create or replace function private.send_monthly_summaries(p_today date default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := coalesce(p_today, (now() at time zone 'Asia/Kolkata')::date);
  v_from date := (date_trunc('month', v_today) - interval '1 month')::date;
  v_to date := (date_trunc('month', v_today) - interval '1 day')::date;
  v_url text;
  u record;
  v_spent text;
  v_groups int;
  v_balance text;
  v_body text;
  v_count int := 0;
begin
  select s.value into v_url from private.settings s where s.key = 'project_url';
  for u in
    select ns.user_id, ns.kinds,
           coalesce((select p.default_currency::text from public.profiles p where p.id = ns.user_id), 'INR') as main
    from public.notification_settings ns
    where jsonb_typeof(ns.kinds -> 'summary' -> 'push') = 'boolean' and (ns.kinds -> 'summary' ->> 'push')::boolean
    order by ns.user_id
  loop
    with mine as (
      select gm.id, gm.group_id from public.group_members gm join public.groups g on g.id = gm.group_id
      where gm.user_id = u.user_id and gm.status = 'active' and gm.deleted_at is null and g.deleted_at is null
    ),
    parts as (
      select e.currency::text as currency, e.group_id, (e.shares ->> m.id::text)::bigint as share
      from mine m join public.expenses e on e.group_id = m.group_id
      where e.deleted_at is null and e.kind <> 'iou' and e.date between v_from and v_to
        and jsonb_typeof(e.shares -> m.id::text) = 'number'
    ),
    totals as (
      select p.currency, sum(p.share)::bigint as total from parts p group by p.currency having sum(p.share) > 0
    )
    select (select string_agg(private.format_money(t.total, t.currency), ' + '
                              order by (t.currency = u.main) desc, t.currency) from totals t),
           (select count(distinct p.group_id)::int from parts p where p.share > 0)
    into v_spent, v_groups;
    continue when v_spent is null;

    with mine as (
      select gm.id, gm.group_id from public.group_members gm join public.groups g on g.id = gm.group_id
      where gm.user_id = u.user_id and gm.status = 'active' and gm.deleted_at is null and g.deleted_at is null
    )
    select string_agg(case when b.v < 0 then 'you owe ' else 'you''re owed ' end
                      || private.format_money(abs(b.v)::bigint, b.currency), ' · '
                      order by (b.currency = u.main) desc, b.currency)
    into v_balance
    from (
      select x.currency, sum(x.v) as v
      from (
        select e.currency::text as currency, coalesce((e.payers ->> m.id::text)::bigint, 0)
                                             - coalesce((e.shares ->> m.id::text)::bigint, 0) as v
        from mine m join public.expenses e on e.group_id = m.group_id
        where e.deleted_at is null
        union all
        select p.currency::text, case when p.from_member = m.id then p.amount
                                      when p.to_member = m.id then -p.amount else 0 end
        from mine m join public.payments p on p.group_id = m.group_id
        where p.deleted_at is null
      ) x
      group by x.currency
      having sum(x.v) <> 0
    ) b;

    insert into private.monthly_summaries_sent (user_id, month) values (u.user_id, v_from)
    on conflict (user_id, month) do nothing;
    continue when not found;

    v_body := 'You spent ' || v_spent || ' across ' || v_groups
              || case when v_groups = 1 then ' group' else ' groups' end
              || ' · ' || coalesce(v_balance, 'you''re all settled up');
    insert into public.notifications (user_id, group_id, activity_id, kind, type, title, body, data, inapp,
                                      push_status)
    values (u.user_id, null, null, 'summary', 'monthly_summary', 'Your ' || trim(to_char(v_from, 'Month')),
            left(v_body, 600),
            jsonb_build_object('target_type', 'insights', 'month', to_char(v_from, 'YYYY-MM')),
            private.kind_on(u.kinds, 'summary', 'inapp'),
            case when coalesce(v_url, '') <> '' then 'pending' else 'skipped' end);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function private.send_monthly_summaries(date) from public, anon, authenticated;

-- 09:00 IST on the 1st = 03:30 UTC (03-backend.md §6). cron.schedule with an existing name updates that job.
select cron.schedule('monthly-summary', '30 3 1 * *', 'select private.send_monthly_summaries()');
