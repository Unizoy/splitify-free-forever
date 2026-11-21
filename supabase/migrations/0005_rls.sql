-- 0005 Row Level Security on every table, helpers, and revokes (planning/03-backend.md §3, rule 7).
-- Clients (anon/authenticated) get SELECT only, filtered by RLS; every write goes through security-definer RPCs.

-- ------------------------------------------------------------------ helpers

-- Active, non-deleted membership of the caller in group g.
create or replace function private.is_member(g uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = g
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.deleted_at is null);
$$;

-- The caller is an active member of a group in which `other` is (or was) a linked member.
create or replace function private.shares_group(other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_members me
    join public.group_members them on them.group_id = me.group_id
    where me.user_id = (select auth.uid())
      and me.status = 'active'
      and me.deleted_at is null
      and them.user_id = other);
$$;

-- Text -> uuid, null when malformed (storage paths come from clients).
create or replace function private.try_uuid(t text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case when t ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then t::uuid end;
$$;

grant usage on schema private to authenticated;
revoke all on function private.is_member(uuid) from public, anon;
revoke all on function private.shares_group(uuid) from public, anon;
revoke all on function private.try_uuid(text) from public, anon;
grant execute on function private.is_member(uuid) to authenticated;
grant execute on function private.shares_group(uuid) to authenticated;
grant execute on function private.try_uuid(text) to authenticated;

-- ------------------------------------------------------------------ enable RLS everywhere

alter table public.currencies enable row level security;
alter table public.categories enable row level security;
alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.expenses enable row level security;
alter table public.payments enable row level security;
alter table public.comments enable row level security;
alter table public.activity enable row level security;
alter table public.record_versions enable row level security;
alter table public.mutation_log enable row level security;
alter table public.join_attempts enable row level security;

-- ------------------------------------------------------------------ policies (select only)

create policy currencies_select on public.currencies for select to authenticated using (true);
create policy categories_select on public.categories for select to authenticated using (true);

create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.shares_group(id));

create policy groups_select on public.groups for select to authenticated
  using (private.is_member(id));
create policy group_members_select on public.group_members for select to authenticated
  using (private.is_member(group_id));
create policy expenses_select on public.expenses for select to authenticated
  using (private.is_member(group_id));
create policy payments_select on public.payments for select to authenticated
  using (private.is_member(group_id));
create policy comments_select on public.comments for select to authenticated
  using (private.is_member(group_id));
create policy activity_select on public.activity for select to authenticated
  using (private.is_member(group_id));
create policy record_versions_select on public.record_versions for select to authenticated
  using (private.is_member(group_id));

-- mutation_log, join_attempts: RLS on, no policies (RPC only).

-- ------------------------------------------------------------------ grants

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select on public.currencies, public.categories, public.profiles, public.groups, public.group_members,
  public.expenses, public.payments, public.comments, public.activity, public.record_versions
  to authenticated;

-- Future objects created by migrations (role postgres) start without client write access: anon gets nothing,
-- authenticated only SELECT (RLS still filters). Written as revoke all + grant select (no privilege list).
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  grant select on tables to authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
-- (PUBLIC's global EXECUTE default on functions cannot be revoked per schema: every RPC revokes it explicitly.)
alter default privileges for role postgres in schema public
  revoke execute on functions from anon;
