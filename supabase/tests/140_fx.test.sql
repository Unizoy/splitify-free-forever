-- Phase 14: fx_rates (RLS read-only, keys, checks), currency parity with the app, saved-conversion checks on
-- expenses/payments, cross rate from stored rows (TC-32-03), fetch-rates cron wiring (TC-32-02 server side).
begin;
select plan(22);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000014a1', 'p14-a@splitify.test'),
  ('00000000-0000-4000-8000-0000000014b1', 'p14-b@splitify.test');
insert into public.groups (id, name) values ('11400000-0000-4000-8000-000000000001', 'P14 Bali');
insert into public.group_members (id, group_id, user_id, display_name, position) values
  ('21400000-0000-4000-8000-0000000000a1', '11400000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000014a1', 'A', 0),
  ('21400000-0000-4000-8000-0000000000b1', '11400000-0000-4000-8000-000000000001', null, 'B', 1);
insert into public.fx_rates (date, currency, rate, fetched_at) values
  ('2000-01-03', 'USD', 1.0834, '2000-01-03T01:15:00Z'),
  ('2000-01-03', 'INR', 97.12, '2000-01-03T01:15:00Z'),
  ('2000-01-03', 'EUR', 1, '2000-01-03T01:15:00Z');

-- Currencies: the app's list (lib/core/money/currencies.dart) with Frankfurter flags from /v2/currencies.
select is((select count(*) from public.currencies), 160::bigint, 'currencies match the app list (160)');
select is((select count(*) from public.currencies where frankfurter), 159::bigint,
  'every currency but VED has Frankfurter rates');
select ok((select not frankfurter and exponent = 2 from public.currencies where code = 'VED'),
  'VED is listed for manual rates only');
select ok((select bool_and(frankfurter) from public.currencies where code in ('CNH', 'GGP', 'IMP', 'JEP')),
  'CNH, GGP, IMP, JEP added with Frankfurter rates');

-- fx_rates shape and checks.
select ok((select relrowsecurity from pg_class where oid = 'public.fx_rates'::regclass), 'fx_rates has RLS on');
select throws_ok($$ insert into public.fx_rates (date, currency, rate) values ('2000-01-03', 'USD', 1.1) $$,
  '23505', null, 'one rate per (date, currency)');
select throws_ok($$ insert into public.fx_rates (date, currency, rate) values ('2000-01-04', 'USD', 0) $$,
  '23514', null, 'rate must be > 0');
select throws_ok($$ insert into public.fx_rates (date, currency, rate) values ('2000-01-04', 'CMD', 1) $$,
  '23503', null, 'only known currencies');

-- TC-32-03: the cross rate from stored rows equals the shared vector FX-CROSS-01 (Dart crossRate).
select is(
  (select money.cross_rate(jsonb_object_agg(currency, rate), 'USD', 'INR')::text
   from public.fx_rates where date = '2000-01-03'),
  '89.6437142330',
  'TC-32-03 cross rate USD->INR from fx_rates rows');

-- Saved conversions must match the money engine (rule 4).
select lives_ok($$
  insert into public.expenses (id, group_id, description, date, currency, total, payers, shares,
                               fx_rate, fx_rate_date, fx_source, fx_currency, fx_total, fx_payers, fx_shares)
  values ('31400000-0000-4000-8000-000000000001', '11400000-0000-4000-8000-000000000001', 'Scooters',
          '2026-11-20', 'USD', 10001,
          '{"21400000-0000-4000-8000-0000000000a1": 10001}',
          '{"21400000-0000-4000-8000-0000000000a1": 5001, "21400000-0000-4000-8000-0000000000b1": 5000}',
          89.643714233, '2026-11-20', 'frankfurter', 'INR', 896527,
          '{"21400000-0000-4000-8000-0000000000a1": 896527}',
          '{"21400000-0000-4000-8000-0000000000a1": 448308, "21400000-0000-4000-8000-0000000000b1": 448219}') $$,
  'an expense with a matching conversion saves');
select is(
  (select fx_total from public.expenses where id = '31400000-0000-4000-8000-000000000001'),
  money.convert(10001, 'USD', 'INR', 89.643714233),
  'saved fx_total = convert(total, rate)');
select throws_ok($$
  update public.expenses set fx_total = 896528,
    fx_payers = '{"21400000-0000-4000-8000-0000000000a1": 896528}',
    fx_shares = '{"21400000-0000-4000-8000-0000000000a1": 448310, "21400000-0000-4000-8000-0000000000b1": 448218}'
  where id = '31400000-0000-4000-8000-000000000001' $$,
  'P0001', 'FX_TOTAL_MISMATCH', 'a converted total that is not convert(total, rate) is rejected');
select throws_ok($$
  update public.expenses set total = 20000,
    payers = '{"21400000-0000-4000-8000-0000000000a1": 20000}',
    shares = '{"21400000-0000-4000-8000-0000000000a1": 10000, "21400000-0000-4000-8000-0000000000b1": 10000}'
  where id = '31400000-0000-4000-8000-000000000001' $$,
  'P0001', 'FX_TOTAL_MISMATCH', 'editing the amount without re-converting is rejected');
select throws_ok($$
  update public.expenses set
    fx_shares = '{"21400000-0000-4000-8000-0000000000a1": 896527}'
  where id = '31400000-0000-4000-8000-000000000001' $$,
  'P0001', 'FX_MEMBERS_MISMATCH', 'converted parts must name the same people');
select lives_ok($$
  update public.expenses set fx_rate = null, fx_rate_date = null, fx_source = null, fx_currency = null,
    fx_total = null, fx_payers = null, fx_shares = null
  where id = '31400000-0000-4000-8000-000000000001' $$,
  'a conversion can be removed');
select lives_ok($$
  insert into public.payments (id, group_id, from_member, to_member, amount, currency, date,
                               fx_rate, fx_rate_date, fx_source, fx_currency, fx_amount)
  values ('41400000-0000-4000-8000-000000000001', '11400000-0000-4000-8000-000000000001',
          '21400000-0000-4000-8000-0000000000b1', '21400000-0000-4000-8000-0000000000a1', 2500, 'USD',
          '2026-11-21', 83.5, '2026-11-21', 'manual', 'INR', 208750) $$,
  'a payment with a matching manual conversion saves');
select throws_ok($$
  update public.payments set fx_amount = 208751 where id = '41400000-0000-4000-8000-000000000001' $$,
  'P0001', 'FX_TOTAL_MISMATCH', 'a payment fx_amount must be convert(amount, rate)');

-- Users read rates, never write them; anon gets nothing.
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-0000000014b1","role":"authenticated"}';
select is((select count(*) from public.fx_rates where date = '2000-01-03'), 3::bigint,
  'any signed-in user reads fx_rates');
select throws_ok($$ insert into public.fx_rates (date, currency, rate) values ('2000-01-04', 'USD', 1.1) $$,
  '42501', null, 'users cannot write fx_rates');
reset role;
set local role anon;
select throws_ok($$ select * from public.fx_rates $$, '42501', null, 'anon cannot read fx_rates');
reset role;

-- Cron wiring (03-backend.md §6): two daily runs, a no-op without project_url, never callable by clients.
select is(
  (select array_agg(schedule || ' ' || command order by schedule) from cron.job
   where jobname in ('fetch-rates-morning', 'fetch-rates-evening')),
  array['15 1 * * * select private.invoke_fetch_rates()', '15 13 * * * select private.invoke_fetch_rates()'],
  'fetch-rates runs at 01:15 and 13:15 UTC');
update private.settings set value = '' where key = 'project_url';
select is(private.invoke_fetch_rates(), null::bigint, 'no project_url: the job does nothing');

select * from finish();
rollback;
