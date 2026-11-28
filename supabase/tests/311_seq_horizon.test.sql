-- R4 (S-467, 0031): the seq / commit-order race. Every writing transaction holds ONE shared advisory lock whose key
-- (0x5EC0 << 48 + n) is a lower bound of every seq it takes; pull_changes hands out only rows below other backends'
-- keys, so rows of a transaction that commits late are never skipped by a cursor.
-- Note: the "own rows are not held back" case assumes no OTHER session holds an older seq lock on dev at that moment
-- (another agent's test transaction); rerun if it fails while others write.
begin;
select plan(20);

create function pg_temp.my_seq_locks() returns bigint language sql volatile as $$
  select count(*) from pg_catalog.pg_locks l
  where l.pid = pg_catalog.pg_backend_pid() and l.locktype = 'advisory' and l.mode = 'ShareLock'
    and l.objsubid = 1 and ((l.classid::bigint << 32) | l.objid::bigint) > 6827457035093671936;
$$;
create function pg_temp.my_key() returns bigint language sql volatile as $$
  select min(((l.classid::bigint << 32) | l.objid::bigint) - 6827457035093671936) from pg_catalog.pg_locks l
  where l.pid = pg_catalog.pg_backend_pid() and l.locktype = 'advisory' and l.mode = 'ShareLock'
    and l.objsubid = 1 and ((l.classid::bigint << 32) | l.objid::bigint) > 6827457035093671936;
$$;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000311a1', 'seq-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000311b1', 'seq-b@splitify.test');

select is(pg_temp.my_seq_locks(), 1::bigint, 'the first synced write takes one seq lock');
select ok(pg_temp.my_key() <= (select min(seq) from public.profiles
                               where id in ('00000000-0000-4000-8000-0000000311a1',
                                            '00000000-0000-4000-8000-0000000311b1')),
  'its key is a lower bound of the seq taken');

insert into public.groups (id, name) values ('10000000-0000-4000-8000-000000031101', 'Seq race');
insert into public.group_members (id, group_id, user_id, display_name, position, status) values
  ('20000000-0000-4000-8000-0000000311a1', '10000000-0000-4000-8000-000000031101',
   '00000000-0000-4000-8000-0000000311a1', 'A', 0, 'active'),
  ('20000000-0000-4000-8000-0000000311b1', '10000000-0000-4000-8000-000000031101',
   '00000000-0000-4000-8000-0000000311b1', 'B', 1, 'active');
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares) values
  ('30000000-0000-4000-8000-000000031101', '10000000-0000-4000-8000-000000031101', 'E1', '2026-11-01', 'INR', 1000,
   '{"20000000-0000-4000-8000-0000000311a1": 1000}',
   '{"20000000-0000-4000-8000-0000000311a1": 500, "20000000-0000-4000-8000-0000000311b1": 500}');
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares) values
  ('30000000-0000-4000-8000-000000031102', '10000000-0000-4000-8000-000000031101', 'E2', '2026-11-01', 'INR', 1000,
   '{"20000000-0000-4000-8000-0000000311a1": 1000}',
   '{"20000000-0000-4000-8000-0000000311a1": 500, "20000000-0000-4000-8000-0000000311b1": 500}');
insert into public.expenses (id, group_id, description, date, currency, total, payers, shares) values
  ('30000000-0000-4000-8000-000000031103', '10000000-0000-4000-8000-000000031101', 'E3', '2026-11-01', 'INR', 1000,
   '{"20000000-0000-4000-8000-0000000311a1": 1000}',
   '{"20000000-0000-4000-8000-0000000311a1": 500, "20000000-0000-4000-8000-0000000311b1": 500}');
update public.expenses set description = 'E1 edited' where id = '30000000-0000-4000-8000-000000031101';

create temp table mine as
  select seq from public.profiles where id in ('00000000-0000-4000-8000-0000000311a1',
                                               '00000000-0000-4000-8000-0000000311b1')
  union all select seq from public.groups where id = '10000000-0000-4000-8000-000000031101'
  union all select seq from public.group_members where group_id = '10000000-0000-4000-8000-000000031101'
  union all select seq from public.expenses where group_id = '10000000-0000-4000-8000-000000031101';
create function pg_temp.eseq(p_id text) returns bigint language sql stable as $$
  select seq from public.expenses where id = p_id::uuid;
$$;

select is(pg_temp.my_seq_locks(), 1::bigint, 'more writes and updates in the same transaction take no more locks');
select ok(pg_temp.my_key() <= (select min(seq) from mine), 'the key is below every seq of the transaction');
select is(pg_catalog.current_setting('splitify.seq_lock', true), '1', 'the once-per-transaction mark is set');
select ok(private.sync_seq_limit() <= (select last_value from public.sync_seq), 'the limit never passes the sequence');
select ok(private.sync_seq_limit(-1) < (select min(seq) from mine),
  'counting this backend too, its in-flight rows are held back');
select ok(not has_function_privilege('authenticated', 'private.sync_seq_limit(integer)', 'execute')
          and not has_function_privilege('anon', 'private.sync_seq_limit(integer)', 'execute'),
  'clients cannot call the limit helper');

-- A lock first taken inside a subtransaction that rolls back goes with the mark; the outer lock stays.
create temp table sub_res (v text);
do $d$
declare
  v text;
begin
  begin
    perform pg_catalog.set_config('splitify.seq_lock', '', true);
    begin
      update public.groups set name = 'Seq race 2' where id = '10000000-0000-4000-8000-000000031101';
      v := pg_temp.my_seq_locks()::text || '/' || pg_catalog.current_setting('splitify.seq_lock', true);
      raise exception 'inner';
    exception when others then
      v := v || ' -> ' || pg_temp.my_seq_locks()::text || '/'
           || coalesce(pg_catalog.current_setting('splitify.seq_lock', true), '');
    end;
    raise exception '%', v;
  exception when others then
    insert into sub_res values (sqlerrm);
  end;
end
$d$;
select is((select v from sub_res), '2/1 -> 1/',
  'a write with the mark cleared takes a second lock; its rollback releases it and clears the mark again');
select is(pg_temp.my_seq_locks(), 1::bigint, 'after the rollbacks only the first lock is held');
select is(pg_catalog.current_setting('splitify.seq_lock', true), '1', 'and the mark is back');

create temp table res (k text primary key, v jsonb);
create function pg_temp.n(p_k text, p_tbl text) returns int language sql stable as $$
  select jsonb_array_length(v -> 'rows' -> p_tbl) from res where k = p_k;
$$;
create function pg_temp.cur(p_k text) returns bigint language sql stable as $$
  select (v -> 'next_cursors' ->> '10000000-0000-4000-8000-000000031101')::bigint from res where k = p_k;
$$;

set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000311a1","role":"authenticated"}';
insert into res select 'p0', public.pull_changes('{}'::jsonb, 0, 500);
select is(pg_temp.n('p0', 'expenses'), 3, 'this backend''s own rows are not held back (it is excluded)');

-- pull_changes honours the limit (helper replaced inside this rolled-back transaction).
create or replace function private.sync_seq_limit(p_exclude_pid integer default pg_catalog.pg_backend_pid())
returns bigint language sql volatile set search_path = '' as $$
  select coalesce(nullif(pg_catalog.current_setting('r4.limit', true), '')::bigint, 9223372036854775807);
$$;
select set_config('r4.limit', pg_temp.eseq('30000000-0000-4000-8000-000000031103')::text, true);
-- E1 was edited after E3, so with the limit at E3's seq the page has E2 and E3 only.
insert into res select 'p1', public.pull_changes('{}'::jsonb, 0, 500);
select is(pg_temp.n('p1', 'expenses'), 2, 'a row above the limit (E1 edited later) is held back');
select is(pg_temp.cur('p1'), pg_temp.eseq('30000000-0000-4000-8000-000000031103'), 'the cursor stops at the limit');
select is((select v ->> 'has_more' from res where k = 'p1'), 'false', 'held-back rows do not ask for another page now');
select ok((select (v ->> 'user_seq')::bigint from res where k = 'p1')
          <= pg_temp.eseq('30000000-0000-4000-8000-000000031103'), 'the user cursor stops at the limit too');

select set_config('r4.limit', '', true);
insert into res select 'p2', public.pull_changes(
  (select v -> 'next_cursors' from res where k = 'p1'), (select (v ->> 'user_seq')::bigint from res where k = 'p1'), 500);
select is(pg_temp.n('p2', 'expenses'), 1, 'the held-back row comes with the next pull');
select is((select v -> 'rows' -> 'expenses' -> 0 ->> 'description' from res where k = 'p2'), 'E1 edited',
  'it is the edited E1');

-- Limit below everything of this test: nothing of it, cursors stay where they were.
select set_config('r4.limit', ((select min(seq) from mine) - 1)::text, true);
insert into res select 'p3', public.pull_changes('{}'::jsonb, 0, 500);
select is(pg_temp.n('p3', 'expenses') + pg_temp.n('p3', 'group_members') + pg_temp.n('p3', 'groups'), 0,
  'no group rows above the limit');
select ok(not exists (select 1 from res, jsonb_array_elements(res.v -> 'rows' -> 'profiles') p
                      where res.k = 'p3' and (p ->> 'seq')::bigint > (select min(seq) from mine) - 1
                        and p ->> 'id' in ('00000000-0000-4000-8000-0000000311a1',
                                           '00000000-0000-4000-8000-0000000311b1')),
  'no profile above the limit');

select * from finish();
rollback;
