-- 0029 Expense attachments (D-034 P-7, wave 2 package W2-Y, S-430..S-433): several photos and PDFs per expense.
--
--   * public.expense_attachments: a synced entity (`entity: 'attachment'` in apply_mutations, `expense_attachments`
--     in pull_changes). One row per file; the bytes live in the private `expense-files` bucket:
--       photo: <group_id>/<expense_id>/<id>.jpg (high resolution) + <group_id>/<expense_id>/<id>-thumb.jpg
--       pdf:   <group_id>/<expense_id>/<id>.pdf
--     Rows are immutable apart from `name`, `position` and the soft delete (rule 9: a removed file stays, so it can
--     be restored). An attachment follows its expense: the expense's own soft delete hides and restores them all.
--   * Limits (free plan: 1 GB of storage for the whole project): a photo <= 3 MB (the app sends <= 1.5 MB), a PDF
--     <= 5 MB (bucket limit), at most 10 live files and 25 MB per expense. Uploads are allowed only for a path an
--     attachment row of the uploader's group registered first, so the bucket can't be used as free file hosting.
--   * The legacy single receipt (`expenses.receipt_path`, `receipts` bucket) is unchanged and still shown.
--   * Activity: attachment_added / attachment_removed / attachment_restored (in-app only: no notification kind).
--     The activity type list is extended from the live constraint, so other migrations' types are kept.
-- public.apply_mutations and public.pull_changes are redefined from their dev bodies (0023 / 0019) with only the
-- attachment additions.

-- ------------------------------------------------------------------ table

create table public.expense_attachments (
  id uuid primary key,
  group_id uuid not null references public.groups (id),
  expense_id uuid not null references public.expenses (id),
  kind text not null check (kind in ('photo', 'pdf')),
  path text not null unique,
  thumb_path text unique,
  name text check (name is null or (char_length(name) between 1 and 120 and name !~ '[[:cntrl:]]')),
  size_bytes integer not null check (size_bytes between 1 and 5242880),
  width integer check (width is null or width between 1 and 20000),
  height integer check (height is null or height between 1 and 20000),
  position integer not null default 0 check (position between 0 and 1000),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz,
  updated_by uuid,
  client_updated_at timestamptz,
  deleted_at timestamptz,
  deleted_by uuid,
  seq bigint not null
);

comment on table public.expense_attachments is
  'Photos and PDFs of an expense (D-034 P-7); files in the private expense-files bucket.';

create index expense_attachments_group_seq_idx on public.expense_attachments (group_id, seq);
create index expense_attachments_expense_idx on public.expense_attachments (expense_id);

create trigger expense_attachments_bump_seq before insert or update on public.expense_attachments
  for each row execute function private.bump_seq();
create trigger expense_attachments_broadcast after insert or update on public.expense_attachments
  for each row execute function private.broadcast_change();

alter table public.expense_attachments enable row level security;
create policy expense_attachments_select on public.expense_attachments for select to authenticated
  using (private.is_member(group_id));
revoke all on public.expense_attachments from anon, authenticated;
grant select on public.expense_attachments to authenticated;

-- ------------------------------------------------------------------ validation + limits

create or replace function private.validate_attachment()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_base text;
  v_count int;
  v_total bigint;
begin
  if tg_op = 'UPDATE' and (new.group_id, new.expense_id, new.kind, new.path, new.thumb_path, new.size_bytes,
                           new.width, new.height)
                          is distinct from (old.group_id, old.expense_id, old.kind, old.path, old.thumb_path,
                                            old.size_bytes, old.width, old.height) then
    perform private.fail('ATTACHMENT_IMMUTABLE');
  end if;
  if tg_op = 'INSERT' then
    if not exists (select 1 from public.expenses e where e.id = new.expense_id and e.group_id = new.group_id) then
      perform private.fail('INVALID_ATTACHMENT');
    end if;
    v_base := new.group_id::text || '/' || new.expense_id::text || '/' || new.id::text;
    if new.kind = 'photo' and (new.path <> v_base || '.jpg' or new.thumb_path is distinct from v_base || '-thumb.jpg'
                               or new.size_bytes > 3145728) then
      perform private.fail('INVALID_ATTACHMENT');
    end if;
    if new.kind = 'pdf' and (new.path <> v_base || '.pdf' or new.thumb_path is not null
                             or new.width is not null or new.height is not null) then
      perform private.fail('INVALID_ATTACHMENT');
    end if;
  end if;
  -- A new or restored file counts against its expense's limits (the expense row lock serialises two phones).
  if new.deleted_at is null and (tg_op = 'INSERT' or old.deleted_at is not null) then
    perform 1 from public.expenses e where e.id = new.expense_id for update;
    select count(*), coalesce(sum(a.size_bytes), 0) into v_count, v_total
    from public.expense_attachments a
    where a.expense_id = new.expense_id and a.deleted_at is null and a.id <> new.id;
    if v_count >= 10 then
      perform private.fail('TOO_MANY_ATTACHMENTS');
    end if;
    if v_total + new.size_bytes > 26214400 then
      perform private.fail('ATTACHMENTS_TOO_LARGE');
    end if;
  end if;
  return new;
end;
$$;

create trigger expense_attachments_validate before insert or update on public.expense_attachments
  for each row execute function private.validate_attachment();

revoke all on function private.validate_attachment() from public, anon, authenticated;

-- ------------------------------------------------------------------ activity types, version tables

-- Both lists are extended from the live constraints, so values other migrations added are kept.
do $$
declare
  v_list text[];
  r record;
begin
  for r in select * from (values
      ('public.activity', 'activity_type_check', 'type',
       array['attachment_added', 'attachment_removed', 'attachment_restored']),
      ('public.record_versions', 'record_versions_table_name_check', 'table_name', array['expense_attachments']))
      as x(tbl, con, col, extra)
  loop
    select array_agg(distinct t order by t) into v_list
    from (
      select (regexp_matches(pg_get_constraintdef(c.oid), '''([a-z_]+)''', 'g'))[1] as t
      from pg_constraint c
      where c.conrelid = r.tbl::regclass and c.conname = r.con
      union all
      select unnest(r.extra)
    ) s;
    execute format('alter table %s drop constraint if exists %I', r.tbl, r.con);
    execute format('alter table %s add constraint %I check (%I = any (%L::text[]))', r.tbl, r.con, r.col, v_list);
  end loop;
end;
$$;

-- ------------------------------------------------------------------ apply (entity 'attachment')

create or replace function private.sync_apply_attachment(m jsonb, uid uuid)
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
  v_row public.expense_attachments;
  v_new public.expense_attachments;
  v_vop text;
  v_actor uuid;
  v_desc text;
begin
  if v_op not in ('upsert', 'delete', 'restore') or v_id is null or v_group is null
     or jsonb_typeof(v_data) <> 'object' or coalesce(m ->> 'source', 'app') <> 'app' then
    perform private.fail('INVALID_MUTATION');
  end if;
  v_t := least(coalesce((m ->> 'client_updated_at')::timestamptz, now()), now());

  select * into v_row from public.expense_attachments a where a.id = v_id;
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
    values ('expense_attachments', v_id, v_group, 'conflict_lost',
            to_jsonb(v_row) || jsonb_build_object('client_updated_at', v_t, 'lost_op', v_op), uid, v_t);
    return jsonb_build_object('status', 'superseded', 'seq', v_row.seq);
  end if;

  perform private.assert_group_writable(v_group);

  if v_op = 'upsert' and v_row.id is null then
    v_vop := 'insert';
    insert into public.expense_attachments (id, group_id, expense_id, kind, path, thumb_path, name, size_bytes, width,
                                            height, position, created_at, created_by, updated_at, updated_by,
                                            client_updated_at, seq)
    values (v_id, v_group, private.try_uuid(v_data ->> 'expense_id'), v_data ->> 'kind', v_data ->> 'path',
            v_data ->> 'thumb_path', nullif(btrim(v_data ->> 'name'), ''), (v_data ->> 'size_bytes')::integer,
            (v_data ->> 'width')::integer, (v_data ->> 'height')::integer,
            coalesce((v_data ->> 'position')::integer, 0), now(), uid, now(), uid, v_t, 0)
    returning * into v_new;
  elsif v_op = 'upsert' then
    -- Only the name and the order change; everything else about a stored file is fixed.
    v_vop := 'update';
    update public.expense_attachments a
    set name = case when v_data ? 'name' then nullif(btrim(v_data ->> 'name'), '') else a.name end,
        position = case when jsonb_typeof(v_data -> 'position') = 'number' then (v_data ->> 'position')::integer
                        else a.position end,
        updated_at = now(), updated_by = uid, client_updated_at = v_t
    where a.id = v_id
    returning * into v_new;
  else
    v_vop := v_op;
    update public.expense_attachments a
    set deleted_at = case when v_op = 'delete' then now() end,
        deleted_by = case when v_op = 'delete' then uid end,
        updated_at = now(), updated_by = uid, client_updated_at = v_t
    where a.id = v_id
    returning * into v_new;
  end if;

  insert into public.record_versions (table_name, record_id, group_id, op, snapshot, changed_by, client_updated_at)
  values ('expense_attachments', v_id, v_group, v_vop, to_jsonb(v_new), uid, v_t);

  if v_vop <> 'update' then
    select e.description into v_desc from public.expenses e where e.id = v_new.expense_id;
    select gm.id into v_actor from public.group_members gm
    where gm.group_id = v_group and gm.user_id = uid and gm.status = 'active' and gm.deleted_at is null
    limit 1;
    insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
    values (v_group, uid, v_actor,
            case v_vop when 'insert' then 'attachment_added' when 'delete' then 'attachment_removed'
                       else 'attachment_restored' end,
            'expense', v_new.expense_id,
            jsonb_build_object('attachment_id', v_id, 'kind', v_new.kind, 'name', v_new.name,
                               'description', v_desc));
  end if;

  return jsonb_build_object('status', 'applied', 'seq', v_new.seq);
end;
$$;

revoke all on function private.sync_apply_attachment(jsonb, uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------ apply_mutations (dispatch)

-- Body as on dev (0023); the only change is the dispatch of `entity: 'attachment'`.
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
      elsif v_m ->> 'entity' = 'attachment' then
        v_res := private.sync_apply_attachment(v_m, v_uid);
      elsif v_m ->> 'source' = 'capture' then
        v_res := private.sync_apply_capture(v_m, v_uid);
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

-- ------------------------------------------------------------------ pull_changes (+ expense_attachments)

-- Body as on dev (0019); the only change is the `expense_attachments` rows.
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
    select 'expense_attachments', x.seq, to_jsonb(x)
      from public.expense_attachments x join mine on mine.id = x.group_id where x.seq > mine.cur
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

-- ------------------------------------------------------------------ storage: the expense-files bucket

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('expense-files', 'expense-files', false, 5242880, array['image/jpeg', 'application/pdf'])
on conflict (id) do nothing;

-- True when an attachment row of a group the caller belongs to registered `p_name` (its file or thumbnail).
-- Removed attachments still take their upload (a phone may come online after the removal; Undo needs the file).
create or replace function private.attachment_upload_ok(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.expense_attachments a
    where (a.path = p_name or a.thumb_path = p_name)
      and private.is_member(a.group_id));
$$;

revoke all on function private.attachment_upload_ok(text) from public, anon;
grant execute on function private.attachment_upload_ok(text) to authenticated;

create policy expense_files_select on storage.objects for select to authenticated
  using (bucket_id = 'expense-files'
         and private.is_member(private.try_uuid((storage.foldername(name))[1])));

create policy expense_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'expense-files' and private.attachment_upload_ok(name));

create policy expense_files_update on storage.objects for update to authenticated
  using (bucket_id = 'expense-files' and private.attachment_upload_ok(name))
  with check (bucket_id = 'expense-files' and private.attachment_upload_ok(name));

-- No delete policy: files stay for restore and history (rule 9).
