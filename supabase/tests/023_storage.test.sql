-- Storage buckets and policies (03-backend.md §3): group folders for members only, avatars in own folder.
-- Phase 10 (T4, TC-29-02): receipts and covers are read/written/updated/deleted by folder membership only — a
-- member who left, a stranger and a member of another group are refused; a claimed name-only spot is a member.
begin;
select plan(24);

select is(
  (select count(*) from storage.buckets
   where id in ('receipts', 'group-covers', 'avatars') and not public and file_size_limit = 5242880
     and allowed_mime_types = array['image/jpeg', 'image/webp']),
  3::bigint,
  'three private buckets, 5 MB, JPEG/WebP only');

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'st-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000000b1', 'st-b@splitify.test'),
  ('00000000-0000-4000-8000-0000000000c1', 'st-c@splitify.test'),
  ('00000000-0000-4000-8000-0000000000d1', 'st-d@splitify.test'),
  ('00000000-0000-4000-8000-0000000000e1', 'st-e@splitify.test');
insert into public.groups (id, name) values
  ('10000000-0000-4000-8000-000000000001', 'G1'),
  ('10000000-0000-4000-8000-000000000002', 'G2');
insert into public.group_members (id, group_id, user_id, display_name, position, status, claimed_at) values
  ('20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000a1', 'A', 0, 'active', null),
  ('20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000b1', 'B', 1, 'active', null),
  -- D left G1; E claimed the name-only spot "Esha" in G1; C is only in G2.
  ('20000000-0000-4000-8000-0000000000d1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000d1', 'D', 2, 'left', null),
  ('20000000-0000-4000-8000-0000000000e1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000e1', 'Esha', 3, 'active', now()),
  ('20000000-0000-4000-8000-0000000000c2', '10000000-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-0000000000c1', 'C', 0, 'active', null);

-- Row count of an update the caller's policies allow (an upload with upsert updates the row).
create function pg_temp.n_upd(p_bucket text, p_prefix text) returns int language plpgsql as $$
declare n int;
begin
  update storage.objects set metadata = '{"touched": true}'::jsonb
  where bucket_id = p_bucket and name like p_prefix || '%';
  get diagnostics n = row_count;
  return n;
end $$;

-- Deletes: the app never deletes photos (history keeps them, rule 9); Storage only deletes through its
-- API, and the delete policy is the same folder-membership rule.
select ok(
  exists (select 1 from pg_policies
          where schemaname = 'storage' and tablename = 'objects' and policyname = 'group_files_delete'
            and cmd = 'DELETE' and qual like '%is_member%foldername%'),
  'group photo deletes are limited to members of the folder''s group');

set local role authenticated;

-- A: member of G1.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';
select lives_ok(
  $$ insert into storage.objects (bucket_id, name) values
     ('receipts', '10000000-0000-4000-8000-000000000001/30000000-0000-4000-8000-000000000001/r1.jpg') $$,
  'member can upload a receipt to their group folder');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name) values
     ('group-covers', '10000000-0000-4000-8000-000000000001/cover.jpg') $$,
  'member can upload a group cover');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values ('receipts', 'not-a-uuid/r2.jpg') $$,
  '42501', null, 'malformed group folder is rejected');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name) values
     ('avatars', '00000000-0000-4000-8000-0000000000a1/me.jpg') $$,
  'user can upload their own avatar');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values
     ('avatars', '00000000-0000-4000-8000-0000000000b1/fake.jpg') $$,
  '42501', null, 'user cannot write into another user''s avatar folder');

-- B: co-member.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}';
select is((select count(*) from storage.objects where bucket_id = 'receipts'), 1::bigint,
  'co-member can read the group receipt');
select is((select count(*) from storage.objects where bucket_id = 'group-covers'), 1::bigint,
  'co-member can read the group cover');
select is((select count(*) from storage.objects where bucket_id = 'avatars'), 1::bigint,
  'co-member can read a co-member avatar');
select is(pg_temp.n_upd('receipts', '10000000-0000-4000-8000-000000000001/'), 1,
  'co-member can replace (update) a receipt in the group folder (upload upsert)');

-- C: stranger to G1, member of G2.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}';
select is((select count(*) from storage.objects where bucket_id in ('receipts', 'group-covers')), 0::bigint,
  'non-member cannot read group files');
select is((select count(*) from storage.objects where bucket_id = 'avatars'), 0::bigint,
  'stranger cannot read avatars');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values
     ('receipts', '10000000-0000-4000-8000-000000000001/30000000-0000-4000-8000-000000000001/x.jpg') $$,
  '42501', null, 'non-member cannot upload into the group folder');
select is(
  (select count(*) from storage.objects
   where bucket_id = 'receipts' and name like '10000000-0000-4000-8000-000000000001/%'),
  0::bigint,
  'non-member sees no receipt even by path');
select is(pg_temp.n_upd('receipts', '10000000-0000-4000-8000-000000000001/'), 0,
  'non-member cannot update a group receipt');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name) values
     ('receipts', '10000000-0000-4000-8000-000000000002/30000000-0000-4000-8000-000000000002/c.jpg') $$,
  'C uploads a receipt into their own group G2');

-- D: left G1.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}';
select is((select count(*) from storage.objects where bucket_id in ('receipts', 'group-covers')), 0::bigint,
  'a member who left cannot read the group''s photos');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values
     ('receipts', '10000000-0000-4000-8000-000000000001/30000000-0000-4000-8000-000000000001/d.jpg') $$,
  '42501', null, 'a member who left cannot upload');

-- E: claimed a name-only spot in G1.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000e1","role":"authenticated"}';
select is(
  (select count(*) from storage.objects
   where bucket_id in ('receipts', 'group-covers') and name like '10000000-0000-4000-8000-000000000001/%'),
  2::bigint,
  'a claimed name-only member reads the group''s receipt and cover');

-- B again: member of G1 only, so G2's receipt is out of reach.
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}';
select is(
  (select count(*) from storage.objects where name like '10000000-0000-4000-8000-000000000002/%'),
  0::bigint,
  'a member of one group cannot read another group''s receipt');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values
     ('group-covers', '10000000-0000-4000-8000-000000000002/b.jpg') $$,
  '42501', null, 'a member of one group cannot put a cover into another group''s folder');
select is(pg_temp.n_upd('receipts', '10000000-0000-4000-8000-000000000002/'), 0,
  'a member of one group cannot update another group''s receipt');

-- A: even a member cannot delete rows directly (Storage API only).
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}';
select throws_ok(
  $$ delete from storage.objects where bucket_id = 'receipts'
     and name like '10000000-0000-4000-8000-000000000001/%' $$,
  '42501', null, 'photos are never deleted by SQL, only through the Storage API');

reset role;
select * from finish();
rollback;
