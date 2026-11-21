-- 0017 Currencies and conversion (phase 14; planning/03-backend.md §2, §6; 05-money-engine.md §6).
-- fx_rates (Frankfurter EUR-based daily rates, read-only for users), currency list parity with the app,
-- saved-conversion checks on expenses/payments, and the twice-daily `fetch-rates` cron (pg_cron → pg_net →
-- Edge Function). Numbered 0017 per S-099 (the phase file's "0011" is superseded).

-- ------------------------------------------------------------------ currencies

-- Codes the app offers (lib/core/money/currencies.dart) that 0003 did not seed. VED has no Frankfurter rate
-- (manual rate only).
insert into public.currencies (code, exponent, name, symbol, frankfurter)
select c.code, money.exponent(c.code), c.name, c.symbol, c.frankfurter
from (values
  ('CNH', 'Chinese Yuan (offshore)', 'CNH', true),
  ('GGP', 'Guernsey Pound', 'GGP', true),
  ('IMP', 'Manx Pound', 'IMP', true),
  ('JEP', 'Jersey Pound', 'JEP', true),
  ('VED', 'Venezuelan Digital Bolívar', 'VED', false)
) as c(code, name, symbol, frankfurter)
on conflict (code) do nothing;

-- `frankfurter` = listed by GET https://api.frankfurter.dev/v2/currencies with type "currency" (checked
-- 2026-11-22: 161 codes; CMD and XDR are not spendable and are not in the app).
with listed (codes) as (select array[
  'AED', 'AFN', 'ALL', 'AMD', 'ANG', 'AOA', 'ARS', 'AUD', 'AWG', 'AZN', 'BAM', 'BBD', 'BDT', 'BHD', 'BIF', 'BMD',
  'BND', 'BOB', 'BRL', 'BSD', 'BTN', 'BWP', 'BYN', 'BZD', 'CAD', 'CDF', 'CHF', 'CLP', 'CNH', 'CNY', 'COP', 'CRC',
  'CUP', 'CVE', 'CZK', 'DJF', 'DKK', 'DOP', 'DZD', 'EGP', 'ERN', 'ETB', 'EUR', 'FJD', 'FKP', 'GBP', 'GEL', 'GGP',
  'GHS', 'GIP', 'GMD', 'GNF', 'GTQ', 'GYD', 'HKD', 'HNL', 'HTG', 'HUF', 'IDR', 'ILS', 'IMP', 'INR', 'IQD', 'IRR',
  'ISK', 'JEP', 'JMD', 'JOD', 'JPY', 'KES', 'KGS', 'KHR', 'KMF', 'KPW', 'KRW', 'KWD', 'KYD', 'KZT', 'LAK', 'LBP',
  'LKR', 'LRD', 'LSL', 'LYD', 'MAD', 'MDL', 'MGA', 'MKD', 'MMK', 'MNT', 'MOP', 'MRU', 'MUR', 'MVR', 'MWK', 'MXN',
  'MYR', 'MZN', 'NAD', 'NGN', 'NIO', 'NOK', 'NPR', 'NZD', 'OMR', 'PAB', 'PEN', 'PGK', 'PHP', 'PKR', 'PLN', 'PYG',
  'QAR', 'RON', 'RSD', 'RUB', 'RWF', 'SAR', 'SBD', 'SCR', 'SDG', 'SEK', 'SGD', 'SHP', 'SLE', 'SOS', 'SRD', 'SSP',
  'STN', 'SVC', 'SYP', 'SZL', 'THB', 'TJS', 'TMT', 'TND', 'TOP', 'TRY', 'TTD', 'TWD', 'TZS', 'UAH', 'UGX', 'USD',
  'UYU', 'UZS', 'VES', 'VND', 'VUV', 'WST', 'XAF', 'XCD', 'XCG', 'XOF', 'XPF', 'YER', 'ZAR', 'ZMW', 'ZWG'
]::bpchar[])
update public.currencies c
set frankfurter = c.code = any (l.codes)
from listed l
where c.frankfurter is distinct from (c.code = any (l.codes));

-- ------------------------------------------------------------------ fx_rates

-- One row per (date, currency): `rate` units of `currency` per 1 EUR on `date` (the date Frankfurter reports for
-- that rate, which can lag a day for some currencies). EUR itself is stored as 1. Written only by the
-- `fetch-rates` Edge Function (secret key); users read it (the phone caches it for offline conversions).
create table public.fx_rates (
  date date not null,
  currency char(3) not null references public.currencies (code),
  rate numeric(24, 10) not null check (rate > 0),
  source text not null default 'frankfurter' check (source = 'frankfurter'),
  fetched_at timestamptz not null default now(),
  primary key (date, currency)
);

comment on table public.fx_rates is 'Daily Frankfurter rates per 1 EUR (05-money-engine.md §6); read-only for users.';

create index fx_rates_fetched_at_idx on public.fx_rates (fetched_at);
create index fx_rates_currency_date_idx on public.fx_rates (currency, date desc);

alter table public.fx_rates enable row level security;
create policy fx_rates_select on public.fx_rates for select to authenticated using (true);
revoke all on public.fx_rates from anon, authenticated;
grant select on public.fx_rates to authenticated;

-- ------------------------------------------------------------------ saved conversions (rule 4)

-- A saved conversion must be what the money engine gives for the saved rate (05 §6): converted total =
-- convert(total, rate), converted parts name the same people as the original parts (their sums are checked by
-- validate_expense). Separate trigger so the 0004 validators stay untouched.
create or replace function private.check_fx()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_record jsonb := to_jsonb(new);
  v_amount bigint;
  v_fx bigint;
begin
  if new.fx_rate is null then
    return new;
  end if;
  if tg_table_name = 'expenses' then
    v_amount := (v_record ->> 'total')::bigint;
    v_fx := (v_record ->> 'fx_total')::bigint;
    if array(select jsonb_object_keys(v_record -> 'fx_payers') order by 1)
         <> array(select jsonb_object_keys(v_record -> 'payers') order by 1)
       or array(select jsonb_object_keys(v_record -> 'fx_shares') order by 1)
         <> array(select jsonb_object_keys(v_record -> 'shares') order by 1) then
      perform private.fail('FX_MEMBERS_MISMATCH');
    end if;
  else
    v_amount := (v_record ->> 'amount')::bigint;
    v_fx := (v_record ->> 'fx_amount')::bigint;
  end if;
  if v_fx is distinct from money.convert(v_amount, new.currency, new.fx_currency, new.fx_rate) then
    perform private.fail('FX_TOTAL_MISMATCH',
      jsonb_build_object('expected', money.convert(v_amount, new.currency, new.fx_currency, new.fx_rate)));
  end if;
  return new;
end;
$$;

revoke all on function private.check_fx() from public, anon, authenticated;

create trigger expenses_fx_check before insert or update on public.expenses
  for each row execute function private.check_fx();
create trigger payments_fx_check before insert or update on public.payments
  for each row execute function private.check_fx();

-- ------------------------------------------------------------------ settings + cron

-- Project-specific, non-secret settings read by jobs (03-backend.md §5; phase 13 adds its keys here). Each
-- project sets its own URL once (never in Git):
--   insert into private.settings (key, value) values ('project_url', 'https://<project-ref>.supabase.co')
--   on conflict (key) do update set value = excluded.value;
create table if not exists private.settings (
  key text primary key,
  value text not null
);
alter table private.settings enable row level security;
revoke all on private.settings from public, anon, authenticated;

-- POSTs to the `fetch-rates` Edge Function (verify_jwt false; it is throttled and idempotent, so a stranger or
-- a double call can't do harm). Returns the pg_net request id, or null when `project_url` is not set yet.
create or replace function private.invoke_fetch_rates()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
begin
  select s.value into v_url from private.settings s where s.key = 'project_url';
  if v_url is null or v_url = '' then
    raise notice 'fetch-rates not called: private.settings project_url is not set';
    return null;
  end if;
  return net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/fetch-rates',
    body := '{}'::jsonb,
    headers := '{"Content-Type": "application/json"}'::jsonb,
    timeout_milliseconds := 30000);
end;
$$;

revoke all on function private.invoke_fetch_rates() from public, anon, authenticated;

-- 06:45 and 18:45 IST (03-backend.md §6). cron.schedule with an existing name updates that job.
select cron.schedule('fetch-rates-morning', '15 1 * * *', 'select private.invoke_fetch_rates()');
select cron.schedule('fetch-rates-evening', '15 13 * * *', 'select private.invoke_fetch_rates()');
