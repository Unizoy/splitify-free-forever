-- Housekeeping job (0022, planning/03-backend.md §6): old log rows, join attempts, cron history and stale device
-- tokens are pruned, recent ones kept; only the job (postgres) can run it.
begin;
select plan(15);

insert into auth.users (id, email) values ('00000000-0000-4000-8000-0000000000f1', 'hk-a@splitify.test');
insert into public.mutation_log (mutation_id, user_id, received_at) values
  ('91000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000f1', now() - interval '31 days'),
  ('91000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000f1', now() - interval '29 days');
insert into public.join_attempts (user_id, at) values
  ('00000000-0000-4000-8000-0000000000f1', now() - interval '25 hours'),
  ('00000000-0000-4000-8000-0000000000f1', now() - interval '23 hours');
insert into cron.job_run_details (runid, jobid, status, start_time, end_time) values
  (9990001, 999001, 'succeeded', now() - interval '15 days', now() - interval '15 days'),
  (9990002, 999002, 'succeeded', now() - interval '13 days', now() - interval '13 days');
insert into public.device_tokens (user_id, token, last_seen_at) values
  ('00000000-0000-4000-8000-0000000000f1', 'hk-old', now() - interval '271 days'),
  ('00000000-0000-4000-8000-0000000000f1', 'hk-new', now() - interval '269 days');

select lives_ok($$ select private.housekeeping() $$, 'housekeeping runs');
select is((select count(*) from public.mutation_log where mutation_id = '91000000-0000-4000-8000-000000000001'),
  0::bigint, 'a mutation log row older than 30 days is deleted');
select is((select count(*) from public.mutation_log where mutation_id = '91000000-0000-4000-8000-000000000002'),
  1::bigint, 'a mutation log row of 29 days is kept');
select is((select count(*) from public.join_attempts
           where user_id = '00000000-0000-4000-8000-0000000000f1' and at < now() - interval '24 hours'),
  0::bigint, 'join attempts older than a day are deleted');
select is((select count(*) from public.join_attempts where user_id = '00000000-0000-4000-8000-0000000000f1'),
  1::bigint, 'a join attempt of 23 hours is kept');
select is((select count(*) from cron.job_run_details where jobid = 999001), 0::bigint,
  'cron run history older than 14 days is deleted');
select is((select count(*) from cron.job_run_details where jobid = 999002), 1::bigint,
  'cron run history of 13 days is kept');
select is((select count(*) from public.device_tokens where token = 'hk-old'), 0::bigint,
  'a device token not seen for 270 days is deleted');
select is((select count(*) from public.device_tokens where token = 'hk-new'), 1::bigint,
  'a device token seen 269 days ago is kept');
select lives_ok($$ select private.housekeeping() $$, 'a second run changes nothing and does not fail');
select is((select count(*) from cron.job where jobname = 'housekeeping' and schedule = '0 20 * * 0'
           and command = 'select private.housekeeping()'), 1::bigint, 'the job is scheduled for Sundays 20:00 UTC');
select ok(not has_function_privilege('anon', 'private.housekeeping()', 'execute')
  and not has_function_privilege('authenticated', 'private.housekeeping()', 'execute'),
  'anon and signed-in users cannot run housekeeping');
select ok((select coalesce(proacl::text, '') not like '%=X/%' from pg_proc where oid = 'private.housekeeping()'::regproc),
  'housekeeping is not executable by PUBLIC either');
select ok((select prosecdef and proconfig::text like '%search_path=%' from pg_proc
           where oid = 'private.housekeeping()'::regproc), 'housekeeping is security definer with a pinned search_path');

set local role authenticated;
select throws_ok($$ select private.housekeeping() $$, '42501', null, 'a signed-in user calling it is refused');
reset role;

select * from finish();
rollback;
