-- Housekeeping job (0022, planning/03-backend.md §6, S-200): join attempts older than a day are pruned, recent
-- ones and everything else kept; only the job (postgres) can run it.
begin;
select plan(10);

insert into auth.users (id, email) values ('00000000-0000-4000-8000-0000000000f1', 'hk-a@splitify.test');
insert into public.mutation_log (mutation_id, user_id, received_at) values
  ('91000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000f1', now() - interval '31 days'),
  ('91000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000f1', now() - interval '29 days');
insert into public.join_attempts (user_id, at) values
  ('00000000-0000-4000-8000-0000000000f1', now() - interval '25 hours'),
  ('00000000-0000-4000-8000-0000000000f1', now() - interval '23 hours');

select lives_ok($$ select private.housekeeping() $$, 'housekeeping runs');
select is((select count(*) from public.mutation_log where user_id = '00000000-0000-4000-8000-0000000000f1'),
  2::bigint, 'mutation log rows are kept (owner snippet, S-200)');
select is((select count(*) from public.join_attempts
           where user_id = '00000000-0000-4000-8000-0000000000f1' and at < now() - interval '24 hours'),
  0::bigint, 'join attempts older than a day are deleted');
select is((select count(*) from public.join_attempts where user_id = '00000000-0000-4000-8000-0000000000f1'),
  1::bigint, 'a join attempt of 23 hours is kept');
select lives_ok($$ select private.housekeeping() $$, 'a second run changes nothing and does not fail');
select is((select count(*) from cron.job where jobname = 'housekeeping' and schedule = '0 20 * * 0'
           and command = 'select private.housekeeping()'), 1::bigint, 'the job is scheduled for Sundays 20:00 UTC');
select ok(not has_function_privilege('anon', 'private.housekeeping()', 'execute')
  and not has_function_privilege('authenticated', 'private.housekeeping()', 'execute'),
  'anon and signed-in users cannot run housekeeping');
select ok((select coalesce(proacl::text, '') !~ '[{,]=X/' from pg_proc where oid = 'private.housekeeping()'::regprocedure),
  'housekeeping is not executable by PUBLIC either');
select ok((select prosecdef and proconfig::text like '%search_path=%' from pg_proc
           where oid = 'private.housekeeping()'::regprocedure), 'housekeeping is security definer with a pinned search_path');

set local role authenticated;
select throws_ok($$ select private.housekeeping() $$, '42501', null, 'a signed-in user calling it is refused');
reset role;

select * from finish();
rollback;
