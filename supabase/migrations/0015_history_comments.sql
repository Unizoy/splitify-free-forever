-- 0015 Edit history, restore, comments (phase 12; 08-feature-specs #13 #20). Expense/payment versions, restore
-- and the *_restored / comment_* activity already come from apply_mutations (0009); this adds the one rule the
-- server did not enforce yet: only a comment's author may change, delete or restore it (TC-13-04, S-131).

create or replace function private.guard_comment_author()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  -- Writes without a signed-in user (service role, maintenance) are not limited.
  if v_uid is not null
     and old.created_by is distinct from v_uid
     and (new.body is distinct from old.body or new.deleted_at is distinct from old.deleted_at) then
    perform private.fail('NOT_AUTHOR');
  end if;
  return new;
end;
$$;

create trigger comments_author_guard before update on public.comments
  for each row execute function private.guard_comment_author();

revoke all on function private.guard_comment_author() from public, anon, authenticated;
