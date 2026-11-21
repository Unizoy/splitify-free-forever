-- Money guards beyond the oracle vectors that the Dart engine also enforces (S-029).
begin;
select plan(7);

create function pg_temp.run(q text) returns jsonb language plpgsql as $f$
declare
  r jsonb;
  msg text;
begin
  execute q into r;
  return jsonb_build_object('ok', r);
exception when sqlstate 'P0001' then
  get stacked diagnostics msg = message_text;
  return jsonb_build_object('error', msg);
end;
$f$;

select is(pg_temp.run($q$select money.split(100, 'equal', array['A', 'A']::text[])$q$),
  '{"error": "DUPLICATE_MEMBER"}'::jsonb, 'duplicate member is rejected');
select is(pg_temp.run($q$select money.split(100, 'adjust', array['A', 'B']::text[],
    '{"A": 1000000000000, "B": -999999999950}')$q$),
  '{"error": "AMOUNT_TOO_LARGE"}'::jsonb, 'per-member value above the max is rejected');
select is(pg_temp.run($q$select to_jsonb(money.check_payers(100, '{"A": 1000000000000}'))$q$),
  '{"error": "AMOUNT_TOO_LARGE"}'::jsonb, 'payer amount above the max is rejected');
select is(pg_temp.run($q$select to_jsonb(money.convert(100, 'USD', 'INR', 1.00000000001))$q$),
  '{"error": "INVALID_RATE"}'::jsonb, 'rate with more than 10 decimals is rejected');
select is(pg_temp.run($q$select to_jsonb(money.convert(100, 'USD', 'INR', 2.000000000000))$q$),
  '{"ok": 200}'::jsonb, 'trailing zeros do not count as decimals');
select is(money.cross_rate('{"AAA": "3", "BBB": "1"}'::jsonb, 'AAA', 'BBB')::text, '0.3333333333',
  'cross rate is fixed-point with 10 decimals');
select is(money.cross_rate('{"AAA": "3", "BBB": "0.0000000002"}'::jsonb, 'AAA', 'BBB')::text, '0.0000000001',
  'tiny cross rate rounds half away and keeps fixed-point form');

select * from finish();
rollback;
