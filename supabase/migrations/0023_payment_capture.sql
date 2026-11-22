-- 0023_payment_capture.sql — phase 18b (X4 payment bubble, S-226).
--
-- An expense added from a captured UPI payment is saved with `source = 'capture'`. Nothing else about captures
-- reaches the server: the captures themselves live only on the phone (Drift `payment_captures`, never synced).
--   * expenses.source accepts 'capture';
--   * public.apply_mutations (0019 body: keeps the `recurring` dispatch) sends `source = 'capture'` mutations to
--     private.sync_apply_capture, which runs the unchanged private.sync_apply_one as 'app' (same membership,
--     conflict, history and activity rules) with a transaction-local setting naming the record; a BEFORE INSERT
--     trigger turns that new row's source into 'capture'. Edits of an existing row are ordinary edits.
-- Later phases that redefine apply_mutations must keep both dispatch lines (see phase-19 amendment).

alter table public.expenses drop constraint if exists expenses_source_check;
alter table public.expenses add constraint expenses_source_check
  check (source in ('app', 'recurring', 'import', 'capture'));

-- ------------------------------------------------------------------ source marker

create or replace function private.expenses_capture_source()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.source = 'app' and current_setting('splitify.capture_id', true) = new.id::text then
    new.source := 'capture';
  end if;
  return new;
end;
$$;

create or replace trigger expenses_capture_source before insert on public.expenses
  for each row execute function private.expenses_capture_source();

-- Same contract as private.sync_apply_one (raises private.fail codes; returns {status, seq}).
create or replace function private.sync_apply_capture(m jsonb, uid uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_res jsonb;
begin
  if coalesce(m ->> 'entity', '') <> 'expense' then
    perform private.fail('INVALID_MUTATION');
  end if;
  perform set_config('splitify.capture_id', coalesce(m ->> 'id', ''), true);
  v_res := private.sync_apply_one(jsonb_set(m, '{source}', '"app"'), uid);
  perform set_config('splitify.capture_id', '', true);
  return v_res;
end;
$$;

revoke all on function private.expenses_capture_source() from public, anon, authenticated;
revoke all on function private.sync_apply_capture(jsonb, uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------ apply_mutations (dispatch)

-- Body as in 0019; the only change is the `source = 'capture'` dispatch.
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
revoke all on function public.apply_mutations(jsonb) from public, anon;
grant execute on function public.apply_mutations(jsonb) to authenticated;
