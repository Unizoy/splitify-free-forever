-- 0007 Storage buckets and policies (planning/03-backend.md §3). All buckets private, 5 MB, JPEG/WebP only.
-- receipts:     <group_id>/<expense_id>/<uuid>.jpg   read/write if member of folder[1]
-- group-covers: <group_id>/<uuid>.jpg                read/write if member of folder[1]
-- avatars:      <user_id>/<uuid>.jpg                 write own folder; read self or shares a group

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('receipts', 'receipts', false, 5242880, array['image/jpeg', 'image/webp']),
  ('group-covers', 'group-covers', false, 5242880, array['image/jpeg', 'image/webp']),
  ('avatars', 'avatars', false, 5242880, array['image/jpeg', 'image/webp'])
on conflict (id) do nothing;

-- Group folders ------------------------------------------------------------------------------------------

create policy group_files_select on storage.objects for select to authenticated
  using (bucket_id in ('receipts', 'group-covers')
         and private.is_member(private.try_uuid((storage.foldername(name))[1])));

create policy group_files_insert on storage.objects for insert to authenticated
  with check (bucket_id in ('receipts', 'group-covers')
              and private.is_member(private.try_uuid((storage.foldername(name))[1])));

create policy group_files_update on storage.objects for update to authenticated
  using (bucket_id in ('receipts', 'group-covers')
         and private.is_member(private.try_uuid((storage.foldername(name))[1])))
  with check (bucket_id in ('receipts', 'group-covers')
              and private.is_member(private.try_uuid((storage.foldername(name))[1])));

create policy group_files_delete on storage.objects for delete to authenticated
  using (bucket_id in ('receipts', 'group-covers')
         and private.is_member(private.try_uuid((storage.foldername(name))[1])));

-- Avatars ------------------------------------------------------------------------------------------------

create policy avatars_select on storage.objects for select to authenticated
  using (bucket_id = 'avatars'
         and ((storage.foldername(name))[1] = (select auth.uid())::text
              or private.shares_group(private.try_uuid((storage.foldername(name))[1]))));

create policy avatars_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
