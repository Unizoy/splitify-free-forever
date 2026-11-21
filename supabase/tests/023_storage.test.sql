-- Storage buckets and policies (03-backend.md §3): group folders for members only, avatars in own folder.
begin;
select plan(13);

select is(
  (select count(*) from storage.buckets
   where id in ('receipts', 'group-covers', 'avatars') and not public and file_size_limit = 5242880
     and allowed_mime_types = array['image/jpeg', 'image/webp']),
  3::bigint,
  'three private buckets, 5 MB, JPEG/WebP only');

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'st-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000000b1', 'st-b@splitify.test'),
  ('00000000-0000-4000-8000-0000000000c1', 'st-c@splitify.test');
insert into public.groups (id, name) values ('10000000-0000-4000-8000-000000000001', 'G1');
insert into public.group_members (id, group_id, user_id, display_name, position) values
  ('20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000a1', 'A', 0),
  ('20000000-0000-4000-8000-0000000000b1', '10000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000b1', 'B', 1);

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

-- C: stranger.
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

reset role;
select * from finish();
rollback;
