-- 0029 (W2-Y, D-034 P-7, S-430..S-433): several photos and PDFs per expense. RLS on the table, the private
-- expense-files bucket (members of the group read; only registered paths can be written; no deletes), the
-- per-file and per-expense limits, soft delete + restore with activity, and attack cases.
begin;
select plan(47);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000029a1', 'att-a@splitify.test', '{"full_name": "Asha"}'),
  ('00000000-0000-4000-8000-0000000029b1', 'att-b@splitify.test', '{"full_name": "Bina"}'),
  ('00000000-0000-4000-8000-0000000029c1', 'att-c@splitify.test', '{"full_name": "Chetan"}'),
  ('00000000-0000-4000-8000-0000000029d1', 'att-d@splitify.test', '{"full_name": "Dev"}');

-- G1: A, B active, D left. G2: C only. G3: A, archived.
insert into public.groups (id, name) values
  ('c2900000-0000-4000-8000-000000000001', 'Goa'),
  ('c2900000-0000-4000-8000-000000000002', 'Other'),
  ('c2900000-0000-4000-8000-000000000003', 'Old trip');
insert into public.group_members (id, group_id, user_id, display_name, position, status, role) values
  ('c2910000-0000-4000-8000-0000000000a1', 'c2900000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000029a1', 'Asha', 0, 'active', 'owner'),
  ('c2910000-0000-4000-8000-0000000000b1', 'c2900000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000029b1', 'Bina', 1, 'active', 'member'),
  ('c2910000-0000-4000-8000-0000000000d1', 'c2900000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000029d1', 'Dev', 2, 'left', 'member'),
  ('c2910000-0000-4000-8000-0000000000c2', 'c2900000-0000-4000-8000-000000000002',
   '00000000-0000-4000-8000-0000000029c1', 'Chetan', 0, 'active', 'owner'),
  ('c2910000-0000-4000-8000-0000000000a3', 'c2900000-0000-4000-8000-000000000003',
   '00000000-0000-4000-8000-0000000029a1', 'Asha', 0, 'active', 'owner');
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares) values
  ('c2920000-0000-4000-8000-000000000001', 'c2900000-0000-4000-8000-000000000001', 'Hotel', '2026-11-20', 'INR',
   10000, '{"c2910000-0000-4000-8000-0000000000a1": 10000}',
   '{"c2910000-0000-4000-8000-0000000000a1": 5000, "c2910000-0000-4000-8000-0000000000b1": 5000}'),
  ('c2920000-0000-4000-8000-000000000002', 'c2900000-0000-4000-8000-000000000002', 'Lunch', '2026-11-20', 'INR',
   600, '{"c2910000-0000-4000-8000-0000000000c2": 600}', '{"c2910000-0000-4000-8000-0000000000c2": 600}'),
  ('c2920000-0000-4000-8000-000000000003', 'c2900000-0000-4000-8000-000000000003', 'Cab', '2026-10-02', 'INR',
   600, '{"c2910000-0000-4000-8000-0000000000a3": 600}', '{"c2910000-0000-4000-8000-0000000000a3": 600}'),
  ('c2920000-0000-4000-8000-000000000004', 'c2900000-0000-4000-8000-000000000001', 'Flights', '2026-11-21', 'INR',
   10000, '{"c2910000-0000-4000-8000-0000000000a1": 10000}', '{"c2910000-0000-4000-8000-0000000000a1": 10000}');
update public.groups set archived_at = now() where id = 'c2900000-0000-4000-8000-000000000003';

create function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000000029' || p || '","role":"authenticated"}', true);
$$;
-- Attachment n of G1's expense e (ids c293…0n), its paths and a mutation for it.
create function pg_temp.aid(n int) returns text language sql immutable as $$
  select 'c2930000-0000-4000-8000-' || lpad(n::text, 12, '0');
$$;
create function pg_temp.base(n int, e int default 1, g int default 1) returns text language sql immutable as $$
  select 'c2900000-0000-4000-8000-00000000000' || g || '/c2920000-0000-4000-8000-00000000000' || e || '/'
         || pg_temp.aid(n);
$$;
create function pg_temp.photo(n int, e int default 1, g int default 1, p_size int default 800000) returns jsonb
language sql immutable as $$
  select jsonb_build_object('expense_id', 'c2920000-0000-4000-8000-00000000000' || e, 'kind', 'photo',
    'path', pg_temp.base(n, e, g) || '.jpg', 'thumb_path', pg_temp.base(n, e, g) || '-thumb.jpg',
    'size_bytes', p_size, 'width', 3072, 'height', 2304, 'position', n);
$$;
create function pg_temp.pdf(n int, p_size int default 2000000) returns jsonb language sql immutable as $$
  select jsonb_build_object('expense_id', 'c2920000-0000-4000-8000-000000000001', 'kind', 'pdf',
    'path', pg_temp.base(n) || '.pdf', 'name', 'Hotel invoice.pdf', 'size_bytes', p_size, 'position', n);
$$;
create function pg_temp.m(p_mid int, p_op text, p_n int, p_data jsonb default '{}'::jsonb, p_group int default 1,
                          p_at timestamptz default now())
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'mutation_id', 'c2950000-0000-4000-8000-' || lpad(p_mid::text, 12, '0'), 'entity', 'attachment', 'op', p_op,
    'id', pg_temp.aid(p_n), 'group_id', 'c2900000-0000-4000-8000-00000000000' || p_group, 'base_seq', null,
    'client_updated_at', p_at, 'source', 'app', 'data', p_data);
$$;
create function pg_temp.apply(p jsonb) returns jsonb language sql as $$
  select public.apply_mutations(jsonb_build_array(p)) -> 'results' -> 0;
$$;
create function pg_temp.code(p jsonb) returns text language sql as $$
  select coalesce(r ->> 'code', r ->> 'status') from (select pg_temp.apply(p) as r) s;
$$;

-- ------------------------------------------------------------------ schema
select ok((select relrowsecurity from pg_class where oid = 'public.expense_attachments'::regclass),
  'RLS is on for expense_attachments');
select is((select count(*) from storage.buckets
           where id = 'expense-files' and not public and file_size_limit = 5242880
             and allowed_mime_types = array['image/jpeg', 'application/pdf']),
  1::bigint, 'expense-files is a private 5 MB bucket for JPEG and PDF only');
select ok((select pg_get_constraintdef(oid) like '%attachment_added%' and pg_get_constraintdef(oid) like '%whiteboard_updated%'
             and pg_get_constraintdef(oid) like '%expense_added%'
           from pg_constraint where conrelid = 'public.activity'::regclass and conname = 'activity_type_check'),
  'activity types gained attachment_* and kept the earlier ones');
select ok(not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
                        and cmd = 'DELETE' and qual like '%expense-files%'),
  'no client can delete attachment files (rule 9)');

set local role authenticated;

-- ------------------------------------------------------------------ A adds a photo and a PDF
select pg_temp.as_user('a1');
select is(pg_temp.apply(pg_temp.m(1, 'upsert', 1, pg_temp.photo(1))) ->> 'status', 'applied', 'member adds a photo');
select is(pg_temp.apply(pg_temp.m(2, 'upsert', 2, pg_temp.pdf(2))) ->> 'status', 'applied', 'member adds a PDF');
select is((select kind || ':' || size_bytes || ':' || coalesce(name, '-') || ':' || created_by::text
           from public.expense_attachments where id = pg_temp.aid(2)::uuid),
  'pdf:2000000:Hotel invoice.pdf:00000000-0000-4000-8000-0000000029a1', 'the PDF row is stored with its creator');
select is((select count(*) from public.activity
           where group_id = 'c2900000-0000-4000-8000-000000000001' and type = 'attachment_added'
             and target_type = 'expense' and target_id = 'c2920000-0000-4000-8000-000000000001'
             and data ->> 'description' = 'Hotel'),
  2::bigint, 'each add is logged on the expense (rule 9)');
select is((select count(*) from public.notifications n join public.activity a on a.id = n.activity_id
           where a.type like 'attachment_%'),
  0::bigint, 'attachments stay in the app: no notification rows');
select is((select count(*) from public.record_versions
           where table_name = 'expense_attachments' and record_id = pg_temp.aid(1)::uuid and op = 'insert'),
  1::bigint, 'the add has a version row');
select is(jsonb_array_length(public.pull_changes() -> 'rows' -> 'expense_attachments'), 2,
  'pull_changes sends the attachments');

-- ------------------------------------------------------------------ shape and limits
select is(pg_temp.code(pg_temp.m(3, 'upsert', 3, pg_temp.photo(3) || '{"path": "c2900000-0000-4000-8000-000000000001/c2920000-0000-4000-8000-000000000001/other.jpg"}')),
  'INVALID_ATTACHMENT', 'a path that is not <group>/<expense>/<id>.jpg is refused');
select is(pg_temp.code(pg_temp.m(4, 'upsert', 4, pg_temp.photo(4) - 'thumb_path')),
  'INVALID_ATTACHMENT', 'a photo needs its thumbnail path');
select is(pg_temp.code(pg_temp.m(5, 'upsert', 5, pg_temp.pdf(5) || jsonb_build_object('thumb_path', pg_temp.base(5) || '-thumb.jpg'))),
  'INVALID_ATTACHMENT', 'a PDF has no thumbnail');
select is(pg_temp.code(pg_temp.m(6, 'upsert', 6, pg_temp.photo(6, p_size => 3145729))),
  'INVALID_ATTACHMENT', 'a photo over 3 MB is refused');
select is(pg_temp.code(pg_temp.m(7, 'upsert', 7, pg_temp.pdf(7, 5242881))),
  'INVALID_VALUE', 'a file over 5 MB is refused');
select is(pg_temp.code(pg_temp.m(8, 'upsert', 8, pg_temp.photo(8) || '{"kind": "exe"}')),
  'INVALID_VALUE', 'only photos and PDFs');
select is(pg_temp.code(pg_temp.m(9, 'upsert', 9, pg_temp.photo(9, 2, 2))),
  'INVALID_ATTACHMENT', 'attack: an expense of another group cannot be attached to from my group');
select is(pg_temp.code(pg_temp.m(10, 'upsert', 10, pg_temp.photo(10) || '{"name": "a\u0001b"}')),
  'INVALID_VALUE', 'control characters in a name are refused');
select is(pg_temp.code(pg_temp.m(11, 'upsert', 11, pg_temp.photo(11, 3, 3), 3)),
  'GROUP_ARCHIVED', 'an archived group takes no attachments');

-- 10 live files per expense: 2 exist, 8 more fit, the 11th is refused.
select is((select count(*) from generate_series(12, 19) n
           where pg_temp.apply(pg_temp.m(n, 'upsert', n, pg_temp.photo(n, p_size => 100000))) ->> 'status' = 'applied'),
  8::bigint, 'up to 10 files per expense');
select is(pg_temp.code(pg_temp.m(20, 'upsert', 20, pg_temp.photo(20, p_size => 100000))),
  'TOO_MANY_ATTACHMENTS', 'the 11th live file is refused');

-- 25 MB per expense (expense 4): five PDFs of 5 MB fit, a sixth file does not.
select is((select count(*) from generate_series(31, 35) n
           where pg_temp.apply(pg_temp.m(n, 'upsert', n,
                   pg_temp.pdf(n, 5242880) || jsonb_build_object('expense_id', 'c2920000-0000-4000-8000-000000000004',
                     'path', pg_temp.base(n, 4) || '.pdf'))) ->> 'status' = 'applied'),
  5::bigint, 'five 5 MB PDFs fit in one expense');
select is(pg_temp.code(pg_temp.m(36, 'upsert', 36, pg_temp.photo(36, 4, p_size => 1000))),
  'ATTACHMENTS_TOO_LARGE', 'more than 25 MB per expense is refused');

-- ------------------------------------------------------------------ remove, restore, conflicts
select is(pg_temp.apply(pg_temp.m(40, 'delete', 12)) ->> 'status', 'applied', 'a file is removed (soft)');
select ok((select deleted_at is not null and deleted_by = '00000000-0000-4000-8000-0000000029a1'::uuid
           from public.expense_attachments where id = pg_temp.aid(12)::uuid), 'the row stays, marked deleted');
select is(pg_temp.apply(pg_temp.m(41, 'upsert', 20, pg_temp.photo(20, p_size => 100000))) ->> 'status', 'applied',
  'a removed file frees its place');
select is(pg_temp.code(pg_temp.m(42, 'restore', 12)), 'TOO_MANY_ATTACHMENTS',
  'a restore counts against the limit too');
select is(pg_temp.apply(pg_temp.m(43, 'delete', 20)) ->> 'status', 'applied', 'another file is removed');
select is(pg_temp.apply(pg_temp.m(44, 'restore', 12)) ->> 'status', 'applied', 'a removed file comes back');
select is((select string_agg(type, ',' order by seq) from public.activity
           where data ->> 'attachment_id' = pg_temp.aid(12)),
  'attachment_added,attachment_removed,attachment_restored', 'remove and restore are logged');
select is(pg_temp.apply(pg_temp.m(45, 'upsert', 1, jsonb_build_object('name', 'Bill', 'position', 7,
            'path', 'c2900000-0000-4000-8000-000000000001/x.jpg', 'size_bytes', 1, 'kind', 'pdf'))) ->> 'status',
  'applied', 'an edit of a stored file is accepted');
select is((select name || ':' || position || ':' || kind || ':' || size_bytes || ':' || (path = pg_temp.base(1) || '.jpg')::text
           from public.expense_attachments where id = pg_temp.aid(1)::uuid),
  'Bill:7:photo:800000:true', 'an edit changes only the name and order; the file stays as stored');
select is(pg_temp.apply(pg_temp.m(46, 'upsert', 1, '{"name": "Old"}'::jsonb, 1, now() - interval '1 hour')) ->> 'status',
  'superseded', 'an older edit loses (last save wins) and is kept in history');
select is(pg_temp.code(pg_temp.m(47, 'delete', 99)), 'NOT_FOUND', 'removing an unknown file is refused');

-- ------------------------------------------------------------------ other people
select pg_temp.as_user('c1');
select is((select count(*) from public.expense_attachments), 0::bigint, 'a stranger sees no attachments');
select is(pg_temp.code(pg_temp.m(50, 'upsert', 50, pg_temp.photo(50))), 'NOT_MEMBER',
  'attack: a stranger cannot attach to another group''s expense');
select is(pg_temp.code(pg_temp.m(51, 'upsert', 1, pg_temp.photo(1, 2, 2), 2)), 'ID_CONFLICT',
  'attack: a stranger cannot take over an attachment id from another group');
select throws_ok($$ update public.expense_attachments set name = 'x' $$, '42501', null,
  'direct writes to the table are denied');

select pg_temp.as_user('d1');
select is((select count(*) from public.expense_attachments), 0::bigint, 'a member who left sees no attachments');

-- ------------------------------------------------------------------ storage
select pg_temp.as_user('a1');
select lives_ok(format($$ insert into storage.objects (bucket_id, name) values ('expense-files', %L) $$,
                       pg_temp.base(1) || '.jpg'),
  'the member uploads a registered photo');
select throws_ok(format($$ insert into storage.objects (bucket_id, name) values ('expense-files', %L) $$,
                        'c2900000-0000-4000-8000-000000000001/c2920000-0000-4000-8000-000000000001/free-hosting.jpg'),
  '42501', null, 'attack: an unregistered file cannot be uploaded, even into my own group');

select pg_temp.as_user('b1');
select lives_ok(format($$ insert into storage.objects (bucket_id, name) values ('expense-files', %L) $$,
                       pg_temp.base(1) || '-thumb.jpg'),
  'a co-member can upload the registered thumbnail');
select is((select count(*) from storage.objects where bucket_id = 'expense-files'), 2::bigint,
  'a co-member reads the group''s attachment files');

select pg_temp.as_user('c1');
select is((select count(*) from storage.objects where bucket_id = 'expense-files'), 0::bigint,
  'a stranger reads no attachment files');
select throws_ok(format($$ insert into storage.objects (bucket_id, name) values ('expense-files', %L) $$,
                        pg_temp.base(2) || '.pdf'),
  '42501', null, 'attack: a stranger cannot upload over another group''s registered file');

select pg_temp.as_user('d1');
select is((select count(*) from storage.objects where bucket_id = 'expense-files'), 0::bigint,
  'a member who left reads no attachment files');

select * from finish();
rollback;
