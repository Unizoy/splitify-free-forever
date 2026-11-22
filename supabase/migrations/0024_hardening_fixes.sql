-- 0024 Hardening fixes found by the phase 19 full regression (S-202; 0022 was already applied when they turned up).
--   1. private.check_fx (0017) ran jsonb_object_keys on a missing conversion: a partial conversion (rate set, parts
--      missing) failed with 22023 "cannot call jsonb_object_keys on a scalar" instead of the all-or-nothing check
--      constraint's 23514 (supabase/tests/031_validation.test.sql). An incomplete conversion is now left to that
--      constraint; a complete one is checked exactly as before.

create or replace function private.check_fx()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_record jsonb := to_jsonb(new);
  v_amount bigint;
  v_fx bigint;
begin
  if new.fx_rate is null or new.fx_currency is null then
    return new;
  end if;
  if tg_table_name = 'expenses' then
    if jsonb_typeof(v_record -> 'fx_total') is distinct from 'number'
       or jsonb_typeof(v_record -> 'fx_payers') is distinct from 'object'
       or jsonb_typeof(v_record -> 'fx_shares') is distinct from 'object' then
      return new;  -- incomplete: the table's check constraint refuses it (23514)
    end if;
    v_amount := (v_record ->> 'total')::bigint;
    v_fx := (v_record ->> 'fx_total')::bigint;
    if array(select jsonb_object_keys(v_record -> 'fx_payers') order by 1)
         <> array(select jsonb_object_keys(v_record -> 'payers') order by 1)
       or array(select jsonb_object_keys(v_record -> 'fx_shares') order by 1)
         <> array(select jsonb_object_keys(v_record -> 'shares') order by 1) then
      perform private.fail('FX_MEMBERS_MISMATCH');
    end if;
  else
    if jsonb_typeof(v_record -> 'fx_amount') is distinct from 'number' then
      return new;  -- incomplete: the table's check constraint refuses it (23514)
    end if;
    v_amount := (v_record ->> 'amount')::bigint;
    v_fx := (v_record ->> 'fx_amount')::bigint;
  end if;
  if v_fx is distinct from money.convert(v_amount, new.currency, new.fx_currency, new.fx_rate) then
    perform private.fail('FX_TOTAL_MISMATCH',
      jsonb_build_object('expected', money.convert(v_amount, new.currency, new.fx_currency, new.fx_rate)));
  end if;
  return new;
end;
$$;

revoke all on function private.check_fx() from public, anon, authenticated;
