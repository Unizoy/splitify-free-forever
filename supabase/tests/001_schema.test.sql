-- Schema shape: tables, RLS on every table, no client write grants, money functions pure (03-backend.md §1, §3).
begin;
select plan(32);

select has_table('public', 'currencies', 'table currencies');
select has_table('public', 'categories', 'table categories');
select has_table('public', 'profiles', 'table profiles');
select has_table('public', 'groups', 'table groups');
select has_table('public', 'group_members', 'table group_members');
select has_table('public', 'expenses', 'table expenses');
select has_table('public', 'payments', 'table payments');
select has_table('public', 'comments', 'table comments');
select has_table('public', 'activity', 'table activity');
select has_table('public', 'record_versions', 'table record_versions');
select has_table('public', 'mutation_log', 'table mutation_log');
select has_table('public', 'join_attempts', 'table join_attempts');

select has_extension('pgcrypto', 'pgcrypto installed');
select has_extension('pg_net', 'pg_net installed');
select has_extension('pg_cron', 'pg_cron installed');
select has_extension('pgtap', 'pgtap installed');
select has_schema('private', 'schema private');
select has_schema('money', 'schema money');
select has_sequence('public', 'sync_seq', 'global change-feed sequence');

-- Rule 7: RLS on every table.
select is(
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  0::bigint,
  'RLS is enabled on every public table');

-- 03 §1: clients never write tables directly.
select is(
  (select count(*) from information_schema.role_table_grants
   where table_schema = 'public' and grantee in ('anon', 'authenticated')
     and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER')),
  0::bigint,
  'anon/authenticated have no write grants on public tables');
select is(
  (select count(*) from information_schema.role_table_grants
   where table_schema = 'public' and grantee = 'anon'),
  0::bigint,
  'anon has no table grants at all');
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
     and has_function_privilege('anon', p.oid, 'execute')),
  0::bigint,
  'anon cannot execute any app function');

-- Money engine: immutable + security invoker (05 §8); every app function pins search_path.
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'money' and (p.provolatile <> 'i' or p.prosecdef)),
  0::bigint,
  'money functions are immutable and security invoker');
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'private', 'money')
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
     and not exists (select 1 from unnest(p.proconfig) as c where c like 'search_path=%')),
  0::bigint,
  'every app function sets search_path');
select is(
  (select count(*) from pg_trigger where tgfoid = 'private.bump_seq'::regproc and not tgisinternal),
  10::bigint,
  'seq trigger on every synced table (+ notifications, phase 13; recurring_templates, phase 16)');

-- Reference data.
select is(
  (select count(*) from public.currencies where exponent <> money.exponent(code)),
  0::bigint,
  'currency exponents match the money engine');
select ok(
  exists (select 1 from public.currencies where code = 'INR' and exponent = 2 and symbol = '₹'),
  'INR is seeded');
select is(
  (select count(*) from public.categories where parent_key is not null),
  30::bigint,
  '30 sub-categories (08-feature-specs #13)');
select ok(
  exists (select 1 from public.categories where key = 'other.general' and parent_key = 'other'),
  'default category other.general exists');

-- seq is assigned on insert and bumped on update.
insert into public.groups (id, name) values ('10000000-0000-4000-8000-000000000001', 'Seq test');
select ok(
  (select seq from public.groups where id = '10000000-0000-4000-8000-000000000001') is not null,
  'seq set on insert');
create temp table seq_before as select seq from public.groups where id = '10000000-0000-4000-8000-000000000001';
update public.groups set name = 'Seq test 2' where id = '10000000-0000-4000-8000-000000000001';
select ok(
  (select seq from public.groups where id = '10000000-0000-4000-8000-000000000001') > (select seq from seq_before),
  'seq increases on update');

select * from finish();
rollback;
