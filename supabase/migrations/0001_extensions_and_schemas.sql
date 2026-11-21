-- 0001 Extensions, schemas, global change-feed sequence (planning/03-backend.md §1, §8).

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_net with schema extensions;
-- pg_cron is not relocatable: it always lives in pg_catalog and creates the `cron` schema.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pgtap with schema extensions;

-- `private`: helpers and trigger functions, never exposed by the API.
-- `money`: the money engine (planning/05-money-engine.md), pure functions only.
create schema if not exists private;
create schema if not exists money;
revoke all on schema private from public, anon, authenticated;
revoke all on schema money from public, anon, authenticated;

-- One global sequence for the change feed: every synced row carries `seq` = nextval at insert/update.
create sequence if not exists public.sync_seq as bigint;
revoke all on sequence public.sync_seq from public, anon, authenticated;

create or replace function private.bump_seq()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.seq := nextval('public.sync_seq');
  return new;
end;
$$;

revoke all on function private.bump_seq() from public, anon, authenticated;
