-- 0031 R4 robustness (S-467..S-471): fixes found by the round-4 stress and attack tests. Additive only.
--
-- 1. Lost rows from the seq / commit-order race (S-467). Every synced row takes `seq` from one global sequence
--    when it is written, but transactions commit in another order: phone A's batch takes seq 100..150 and is still
--    running when phone B's single mutation takes 151 and commits; B's pull saw 151, moved its cursors to 151 and
--    never got 100..150 once A committed. Now every writing transaction holds a shared advisory lock whose key
--    (0x5EC0 << 48 + the sequence's last value + 1, taken once, before its first nextval) is a lower
--    bound of every seq it takes, and `pull_changes` returns only rows below the smallest such key held by another
--    backend (and not above the sequence's last value read before the locks). Held-back rows come with the next
--    pull: the writer's commit sends its Realtime nudge. Writers never wait on each other (shared locks).
-- 2. Attachment files can't be overwritten by another member (S-468): the expense-files UPDATE policy (an upload
--    with upsert over an existing object) now also needs the caller to own the object. A retry of one's own upload
--    still works; replacing a co-member's photo or PDF lost the original for good (rule 9: nothing is lost).
-- 3. A batch id can't release other people's pushes (S-469): private.flush_push_batches only looks at the bell rows
--    written by this apply_mutations call (same transaction) for the caller's own payments. Before, anyone who saw
--    a batch id in their bell could replay it in another payment and re-send the covered pushes of that batch to
--    its other recipients, and a batch split over two calls summed the first call's payments again.

-- Key space of the seq locks: 6827457035093671936 = 0x5EC0 << 48 (written out below, so the trigger needs no
-- grant on another function), so no other advisory lock (send_reminder's hashed exclusive keys, tools using small
-- integers) is ever taken for one.
create or replace function private.bump_seq()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Once per transaction (the setting and the lock both go back if a subtransaction rolls back).
  if coalesce(pg_catalog.current_setting('splitify.seq_lock', true), '') = '' then
    perform pg_catalog.pg_advisory_xact_lock_shared(
      6827457035093671936 + coalesce(pg_catalog.pg_sequence_last_value('public.sync_seq'::regclass), 0) + 1);
    perform pg_catalog.set_config('splitify.seq_lock', '1', true);
  end if;
  new.seq := nextval('public.sync_seq');
  return new;
end;
$$;

revoke all on function private.bump_seq() from public, anon, authenticated;

-- Highest seq a pull may hand out now: below every in-flight writer's lock key (other backends than
-- [p_exclude_pid]) and not above the sequence's last value, read FIRST (a writer that starts after the lock scan
-- takes higher values). Call it in its own statement before the reads (read committed: they see newer snapshots).
create or replace function private.sync_seq_limit(p_exclude_pid integer default pg_catalog.pg_backend_pid())
returns bigint
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_cap bigint;
  v_low bigint;
begin
  v_cap := coalesce(pg_catalog.pg_sequence_last_value('public.sync_seq'::regclass), 0);
  select min((l.classid::bigint << 32) | l.objid::bigint) into v_low
  from pg_catalog.pg_locks l
  where l.locktype = 'advisory' and l.objsubid = 1 and l.mode = 'ShareLock' and l.granted
    and l.pid is distinct from p_exclude_pid
    and l.database = (select d.oid from pg_catalog.pg_database d where d.datname = pg_catalog.current_database())
    and ((l.classid::bigint << 32) | l.objid::bigint)
        between 6827457035093671936 + 1 and 6827457035093671936 + v_cap + 1;
  return least(v_cap, coalesce(v_low - 6827457035093671936 - 1, v_cap));
end;
$$;

revoke all on function private.sync_seq_limit(integer) from public, anon, authenticated;

-- Body as on dev (0029, md5 0754048f5764ec580ea4444f78f1d8ad); the only change is `v_limit`.
create or replace function public.pull_changes(cursors jsonb default '{}'::jsonb, since_user_seq bigint default 0,
                                               page_size integer default 500)
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
  v_limit bigint;
begin
  if v_uid is null then
    perform private.fail('NOT_AUTHENTICATED');
  end if;

  -- R4 (S-467): rows of write transactions still in flight are held back (their seq can be below rows that
  -- committed first); computed before the reads below, which take newer snapshots.
  v_limit := private.sync_seq_limit();

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
      from public.groups x join mine on mine.id = x.id where x.seq > mine.cur and x.seq <= v_limit
    union all
    select 'group_members', x.seq, to_jsonb(x)
      from public.group_members x join mine on mine.id = x.group_id where x.seq > mine.cur and x.seq <= v_limit
    union all
    select 'expenses', x.seq, to_jsonb(x)
      from public.expenses x join mine on mine.id = x.group_id where x.seq > mine.cur and x.seq <= v_limit
    union all
    select 'expense_attachments', x.seq, to_jsonb(x)
      from public.expense_attachments x join mine on mine.id = x.group_id where x.seq > mine.cur and x.seq <= v_limit
    union all
    select 'payments', x.seq, to_jsonb(x)
      from public.payments x join mine on mine.id = x.group_id where x.seq > mine.cur and x.seq <= v_limit
    union all
    select 'comments', x.seq, to_jsonb(x)
      from public.comments x join mine on mine.id = x.group_id where x.seq > mine.cur and x.seq <= v_limit
    union all
    select 'recurring_templates', x.seq, to_jsonb(x)
      from public.recurring_templates x join mine on mine.id = x.group_id where x.seq > mine.cur and x.seq <= v_limit
    union all
    select 'activity', x.seq, to_jsonb(x)
      from public.activity x join mine on mine.id = x.group_id where x.seq > mine.cur and x.seq <= v_limit
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
      'expense_attachments',
        coalesce(jsonb_agg(p.r order by p.seq) filter (where p.tbl = 'expense_attachments' and p.rn <= v_size),
                 '[]'),
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
    where x.seq > v_since and x.seq <= v_limit order by x.seq limit v_size + 1
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

-- ------------------------------------------------------------------ 2. attachment files: owner-only overwrite

alter policy expense_files_update on storage.objects
  using (bucket_id = 'expense-files' and private.attachment_upload_ok(name)
         and owner_id = (select auth.uid())::text)
  with check (bucket_id = 'expense-files' and private.attachment_upload_ok(name)
              and owner_id = (select auth.uid())::text);

-- ------------------------------------------------------------------ 3. batch pushes: this call's rows only

-- Body as on dev (0030, md5 fd94bea54575ce300a1e6ddcd409ec55); the only change is the two 0031 conditions.
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
    join public.activity a on a.id = n.activity_id
    where n.push_status = 'batched' and private.try_uuid(n.data ->> 'batch_id') = any (p_batches)
      -- 0031 (S-469): only this call's rows (same transaction) of the caller's own payments.
      and n.created_at = now() and a.actor_user_id = (select auth.uid())
    group by n.user_id, n.data ->> 'batch_id'
    order by n.user_id
  loop
    select string_agg(private.format_money(s.total, s.currency), ' + ' order by s.currency) into v_amounts
    from (select a.data ->> 'currency' as currency, sum((a.data ->> 'amount')::bigint)::bigint as total
          from public.notifications n join public.activity a on a.id = n.activity_id
          where n.user_id = r.user_id and n.push_status = 'batched' and n.data ->> 'batch_id' = r.batch
            and n.created_at = now() and a.actor_user_id = (select auth.uid())
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
