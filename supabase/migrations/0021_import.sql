-- 0021 Import from Splitwise (X1, phase 18, S-190): one `import_completed` activity per import instead of a row per
-- record. apply_mutations already writes no activity (and so no notification) for `source = 'import'` mutations
-- (0009). The phone puts the import's summary into the LAST expense's split_values (`import_summary`, with the batch
-- id in `import_batch_id`); "Delete this import" first puts an `import_undo` note into the first live expense of the
-- batch, then deletes the batch with `source = 'import'`. This trigger turns those notes into the activity rows, so
-- private.sync_apply_one (0009) stays untouched (parallel phases extend it, see 0014).

create or replace function private.import_activity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_batch uuid := private.try_uuid(new.split_values ->> 'import_batch_id');
  v_note jsonb;
  v_undone boolean := tg_op = 'UPDATE';
  v_user uuid;
begin
  if new.source is distinct from 'import' or v_batch is null then
    return null;
  end if;
  if v_undone then
    v_note := new.split_values -> 'import_undo';
    if old.split_values -> 'import_undo' is not null then
      return null;   -- noted before
    end if;
    v_user := new.updated_by;
  else
    v_note := new.split_values -> 'import_summary';
    v_user := new.created_by;
  end if;
  if jsonb_typeof(v_note) is distinct from 'object' then
    return null;
  end if;
  -- One entry per batch and direction, even when a phone sends the note twice.
  if exists (select 1 from public.activity a
             where a.group_id = new.group_id and a.type = 'import_completed' and a.target_id = v_batch
               and coalesce(a.data ->> 'undone', 'false') = v_undone::text) then
    return null;
  end if;
  insert into public.activity (group_id, actor_user_id, actor_member_id, type, target_type, target_id, data)
  values (
    new.group_id,
    v_user,
    (select gm.id from public.group_members gm
     where gm.group_id = new.group_id and gm.user_id = v_user and gm.status = 'active' and gm.deleted_at is null
     limit 1),
    'import_completed',
    'import',
    v_batch,
    jsonb_build_object(
      'batch_id', v_batch,
      'source', case when v_note ->> 'source' = 'splitify' then 'splitify' else 'splitwise' end,
      'expenses', private.import_count(v_note -> 'expenses'),
      'payments', private.import_count(v_note -> 'payments'),
      'undone', v_undone));
  return null;
end;
$$;

-- A count from the phone's note: a whole number 0..1,000,000, anything else 0.
create or replace function private.import_count(v jsonb)
returns int
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(v) = 'number' and (v #>> '{}')::numeric between 0 and 1000000
              then floor((v #>> '{}')::numeric)::int else 0 end;
$$;

create trigger expenses_import_activity after insert or update of split_values on public.expenses
  for each row execute function private.import_activity();

revoke all on function private.import_activity() from public, anon, authenticated;
revoke all on function private.import_count(jsonb) from public, anon, authenticated;
