-- 0013 Photo paths (phase 10: #29 receipts, S-073 group covers; S-112). A record may only point at a
-- file in its own Storage folder (03-backend.md §3), so it can never show another group's photo:
--   expenses.receipt_path = <group_id>/<expense_id>/<uuid>.jpg|webp
--   groups.cover_path     = <group_id>/<uuid>.jpg|webp, required when cover_kind = 'photo'
-- Separate triggers (not a change to validate_expense) so later phases replacing that function keep this.

create or replace function private.validate_file_paths()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_file constant text := '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|webp)$';
begin
  if tg_table_name = 'expenses' then
    if new.receipt_path is not null
       and new.receipt_path !~* ('^' || new.group_id::text || '/' || new.id::text || '/' || v_file) then
      perform private.fail('INVALID_RECEIPT_PATH');
    end if;
  elsif tg_table_name = 'groups' then
    if new.cover_kind = 'photo' and new.cover_path is null then
      perform private.fail('INVALID_COVER_PATH');
    end if;
    if new.cover_path is not null and new.cover_path !~* ('^' || new.id::text || '/' || v_file) then
      perform private.fail('INVALID_COVER_PATH');
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.validate_file_paths() from public, anon, authenticated;

create trigger expenses_validate_file_paths before insert or update of receipt_path on public.expenses
  for each row execute function private.validate_file_paths();

create trigger groups_validate_file_paths before insert or update of cover_kind, cover_path on public.groups
  for each row execute function private.validate_file_paths();
