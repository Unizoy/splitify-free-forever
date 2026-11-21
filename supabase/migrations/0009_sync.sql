-- 0009 Offline sync (planning/04-sync-engine.md §3-4, 03-backend.md §4): apply_mutations (the only client write
-- path for groups, members, expenses, payments, comments), pull_changes (seq cursors), Realtime "changed" nudges.
-- Numbered 0009 because phase 05 owns 0008 (S-040).

-- ------------------------------------------------------------------ helpers

-- Caught error -> rejected code shown on the Sync issues screen.
create or replace function private.sync_error_code(state text, msg text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when state = 'P0001' then msg
    when state = '23514' then 'INVALID_VALUE'
    when state = '23503' then 'INVALID_REFERENCE'
    when state = '23505' then 'DUPLICATE'
    when state = '23502' then 'MISSING_FIELD'
    when state like '22%' then 'INVALID_VALUE'
    else 'SERVER_ERROR'
  end;
$$;

-- Applies one mutation for user `uid`; raises (private.fail) to reject. Returns {status, seq}.
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
                            'default_split', 'archived_at']
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
                          "simplify_debts": false}'::jsonb
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

-- ------------------------------------------------------------------ apply_mutations

-- batch: [{mutation_id, entity, op, id, group_id, base_seq, client_updated_at, source, data}] (max 100).
-- Each mutation runs in its own savepoint; results come back in input order.
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
      v_res := private.sync_apply_one(v_m, v_uid);
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

-- ------------------------------------------------------------------ pull_changes

-- cursors: {"<group id>": seq}. Rows of my groups with seq > cursor, in global seq order, at most page_size.
-- Every cursor advances to the page's max seq: rows are taken in global order, so nothing below it is skipped.
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

  -- Profiles: self + co-members by user seq, plus every linked member in this page (newly shared profiles
  -- can be older than the user cursor).
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

-- ------------------------------------------------------------------ Realtime nudges (guarded)

-- "changed" broadcast on group:<id> (and user:<uid> for linked members). Realtime may be absent (local CI runs
-- without it), and a nudge must never break a write.
create or replace function private.broadcast_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_row jsonb;
  v_group text;
  v_payload jsonb;
begin
  if to_regprocedure('realtime.send(jsonb,text,text,boolean)') is null then
    return null;
  end if;
  v_row := to_jsonb(new);
  v_group := coalesce(v_row ->> 'group_id', v_row ->> 'id');   -- groups has no group_id
  v_payload := jsonb_build_object('table', tg_table_name, 'seq', (v_row ->> 'seq')::bigint, 'group_id', v_group);
  begin
    execute 'select realtime.send($1, $2, $3, $4)' using v_payload, 'changed', 'group:' || v_group, true;
    if tg_table_name = 'group_members' and v_row ->> 'user_id' is not null then
      execute 'select realtime.send($1, $2, $3, $4)'
        using v_payload, 'changed', 'user:' || (v_row ->> 'user_id'), true;
    end if;
  exception when others then
    null;
  end;
  return null;
end;
$$;

create trigger groups_broadcast after insert or update on public.groups
  for each row execute function private.broadcast_change();
create trigger group_members_broadcast after insert or update on public.group_members
  for each row execute function private.broadcast_change();
create trigger expenses_broadcast after insert or update on public.expenses
  for each row execute function private.broadcast_change();
create trigger payments_broadcast after insert or update on public.payments
  for each row execute function private.broadcast_change();
create trigger comments_broadcast after insert or update on public.comments
  for each row execute function private.broadcast_change();
create trigger activity_broadcast after insert on public.activity
  for each row execute function private.broadcast_change();

-- Private topics: user:<my id>, group:<id> of an active membership (03 §3).
do $$
begin
  if to_regclass('realtime.messages') is not null and to_regprocedure('realtime.topic()') is not null then
    execute $p$
      create policy sync_topics_select on realtime.messages for select to authenticated
      using (
        (select realtime.topic()) = 'user:' || (select auth.uid())::text
        or ((select realtime.topic()) like 'group:%'
            and private.is_member(private.try_uuid(substr((select realtime.topic()), 7))))
      )
    $p$;
  end if;
end;
$$;

-- ------------------------------------------------------------------ grants

revoke all on function private.sync_error_code(text, text) from public, anon, authenticated;
revoke all on function private.sync_apply_one(jsonb, uuid) from public, anon, authenticated;
revoke all on function private.broadcast_change() from public, anon, authenticated;
revoke all on function public.apply_mutations(jsonb) from public, anon;
revoke all on function public.pull_changes(jsonb, bigint, int) from public, anon;
grant execute on function public.apply_mutations(jsonb) to authenticated;
grant execute on function public.pull_changes(jsonb, bigint, int) to authenticated;
