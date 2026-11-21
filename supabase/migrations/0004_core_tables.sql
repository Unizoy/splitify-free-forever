-- 0004 Core tables, validation triggers and indexes (planning/03-backend.md §2).
-- Writes come only from security-definer RPCs (later phases); clients only read (0005).
-- Common synced columns: id (client uuid), group_id, created_*/updated_*/deleted_* audit, client_updated_at, seq.

-- ------------------------------------------------------------------ profiles

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 50),
  avatar_path text,
  upi_id text check (upi_id ~ '^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z0-9.\-]{1,63}$'),
  default_currency char(3) not null default 'INR' references public.currencies (code),
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  deleted_at timestamptz,
  seq bigint not null
);

create index profiles_seq_idx on public.profiles (seq);
create trigger profiles_bump_seq before insert or update on public.profiles
  for each row execute function private.bump_seq();

-- New auth user -> profile. Name from Google metadata, else the email prefix (03 §2).
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  v_name := btrim(coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(btrim(split_part(coalesce(new.email, ''), '@', 1)), ''),
    'User'));
  insert into public.profiles (id, display_name)
  values (new.id, left(v_name, 50))
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- ------------------------------------------------------------------ groups

create table public.groups (
  id uuid primary key,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  type text not null default 'other' check (type in ('trip', 'home', 'couple', 'other', 'direct')),
  main_currency char(3) not null default 'INR' references public.currencies (code),
  cover_kind text not null default 'generated' check (cover_kind in ('generated', 'photo')),
  cover_path text,
  simplify_debts boolean not null default false,
  default_split jsonb check (default_split is null or jsonb_typeof(default_split) = 'object'),
  invite_code text unique,
  invite_rotated_at timestamptz,
  archived_at timestamptz,
  direct_key text unique,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz,
  updated_by uuid,
  client_updated_at timestamptz,
  deleted_at timestamptz,
  deleted_by uuid,
  seq bigint not null,
  check (direct_key is null or type = 'direct')
);

create index groups_seq_idx on public.groups (seq);
create trigger groups_bump_seq before insert or update on public.groups
  for each row execute function private.bump_seq();

-- ------------------------------------------------------------------ group members

create table public.group_members (
  id uuid primary key,
  group_id uuid not null references public.groups (id),
  user_id uuid references public.profiles (id) on delete set null,   -- null = name-only member (rule 8)
  display_name text not null check (char_length(btrim(display_name)) between 1 and 50),
  position int not null check (position >= 0),
  role text not null default 'member' check (role in ('owner', 'member')),
  status text not null default 'active' check (status in ('active', 'left', 'removed')),
  claimed_at timestamptz,
  tint smallint check (tint between 0 and 4),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz,
  updated_by uuid,
  client_updated_at timestamptz,
  deleted_at timestamptz,
  deleted_by uuid,
  seq bigint not null,
  unique (group_id, position)
);

create unique index group_members_group_user_key on public.group_members (group_id, user_id)
  where user_id is not null;
create index group_members_user_status_idx on public.group_members (user_id, status);
create index group_members_group_seq_idx on public.group_members (group_id, seq);
create trigger group_members_bump_seq before insert or update on public.group_members
  for each row execute function private.bump_seq();

-- ------------------------------------------------------------------ expenses

create table public.expenses (
  id uuid primary key,
  group_id uuid not null references public.groups (id),
  kind text not null default 'expense' check (kind in ('expense', 'iou')),
  description text not null check (char_length(btrim(description)) between 1 and 120),
  notes text check (char_length(notes) <= 1000),
  category text not null default 'other.general' references public.categories (key),
  date date not null,
  currency char(3) not null references public.currencies (code),
  total bigint not null check (total between 1 and 999999999999),
  payers jsonb not null check (jsonb_typeof(payers) = 'object'),
  shares jsonb not null check (jsonb_typeof(shares) = 'object'),
  split_kind text not null default 'equal' check (split_kind in ('equal', 'exact', 'percent', 'shares', 'adjust')),
  split_values jsonb check (split_values is null or jsonb_typeof(split_values) = 'object'),
  fx_rate numeric(24, 10) check (fx_rate > 0),
  fx_rate_date date,
  fx_source text check (fx_source in ('frankfurter', 'manual')),
  fx_currency char(3) references public.currencies (code),
  fx_total bigint check (fx_total between 1 and 999999999999),
  fx_payers jsonb check (fx_payers is null or jsonb_typeof(fx_payers) = 'object'),
  fx_shares jsonb check (fx_shares is null or jsonb_typeof(fx_shares) = 'object'),
  receipt_path text,
  recurring_id uuid,            -- FK to recurring_templates added in 0012
  source text not null default 'app' check (source in ('app', 'recurring', 'import')),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz,
  updated_by uuid,
  client_updated_at timestamptz,
  deleted_at timestamptz,
  deleted_by uuid,
  seq bigint not null,
  -- Saved conversion is all-or-nothing (rule 4).
  check ((fx_rate is null) = (fx_currency is null)
     and (fx_rate is null) = (fx_total is null)
     and (fx_rate is null) = (fx_payers is null)
     and (fx_rate is null) = (fx_shares is null)
     and (fx_rate is null) = (fx_rate_date is null)
     and (fx_rate is null) = (fx_source is null)),
  check (fx_currency is null or fx_currency <> currency)
);

create index expenses_group_seq_idx on public.expenses (group_id, seq);
create index expenses_group_date_idx on public.expenses (group_id, date);
create index expenses_shares_gin on public.expenses using gin (shares jsonb_path_ops);
create index expenses_payers_gin on public.expenses using gin (payers jsonb_path_ops);
create trigger expenses_bump_seq before insert or update on public.expenses
  for each row execute function private.bump_seq();

-- ------------------------------------------------------------------ payments

create table public.payments (
  id uuid primary key,
  group_id uuid not null references public.groups (id),
  from_member uuid not null references public.group_members (id),
  to_member uuid not null references public.group_members (id),
  amount bigint not null check (amount between 1 and 999999999999),
  currency char(3) not null references public.currencies (code),
  date date not null,
  method text not null default 'cash' check (method in ('cash', 'upi', 'bank', 'other')),
  note text check (char_length(note) <= 200),
  fx_rate numeric(24, 10) check (fx_rate > 0),
  fx_rate_date date,
  fx_source text check (fx_source in ('frankfurter', 'manual')),
  fx_currency char(3) references public.currencies (code),
  fx_amount bigint check (fx_amount between 1 and 999999999999),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz,
  updated_by uuid,
  client_updated_at timestamptz,
  deleted_at timestamptz,
  deleted_by uuid,
  seq bigint not null,
  check (from_member <> to_member),
  check ((fx_rate is null) = (fx_currency is null)
     and (fx_rate is null) = (fx_amount is null)
     and (fx_rate is null) = (fx_rate_date is null)
     and (fx_rate is null) = (fx_source is null)),
  check (fx_currency is null or fx_currency <> currency)
);

create index payments_group_seq_idx on public.payments (group_id, seq);
create index payments_from_member_idx on public.payments (from_member);
create index payments_to_member_idx on public.payments (to_member);
create trigger payments_bump_seq before insert or update on public.payments
  for each row execute function private.bump_seq();

-- ------------------------------------------------------------------ comments

create table public.comments (
  id uuid primary key,
  group_id uuid not null references public.groups (id),
  target_type text not null check (target_type in ('expense', 'payment')),
  target_id uuid not null,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz,
  updated_by uuid,
  client_updated_at timestamptz,
  deleted_at timestamptz,
  deleted_by uuid,
  seq bigint not null
);

create index comments_group_seq_idx on public.comments (group_id, seq);
create index comments_target_idx on public.comments (target_id);
create trigger comments_bump_seq before insert or update on public.comments
  for each row execute function private.bump_seq();

-- ------------------------------------------------------------------ activity (rule 9: never deleted)

create table public.activity (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  actor_user_id uuid,
  actor_member_id uuid,
  type text not null check (type in (
    'group_created', 'group_updated', 'group_archived', 'group_unarchived', 'group_deleted', 'group_restored',
    'member_added', 'member_joined', 'member_claimed', 'member_left', 'member_removed',
    'expense_added', 'expense_edited', 'expense_deleted', 'expense_restored',
    'payment_added', 'payment_edited', 'payment_deleted', 'payment_restored',
    'comment_added', 'comment_deleted', 'reminder_sent', 'settings_changed',
    'recurring_created', 'recurring_updated', 'recurring_stopped', 'import_completed')),
  target_type text,
  target_id uuid,
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  seq bigint not null
);

create index activity_group_seq_idx on public.activity (group_id, seq);
create trigger activity_bump_seq before insert or update on public.activity
  for each row execute function private.bump_seq();

-- ------------------------------------------------------------------ record versions (edit history, #20)

create table public.record_versions (
  id bigint generated always as identity primary key,
  table_name text not null check (table_name in ('groups', 'group_members', 'expenses', 'payments', 'comments',
                                                 'recurring_templates')),
  record_id uuid not null,
  group_id uuid not null references public.groups (id),
  op text not null check (op in ('insert', 'update', 'delete', 'restore', 'conflict_lost')),
  snapshot jsonb not null,
  changed_by uuid,
  changed_at timestamptz not null default now(),
  client_updated_at timestamptz,
  seq bigint not null
);

create index record_versions_group_seq_idx on public.record_versions (group_id, seq);
create index record_versions_record_idx on public.record_versions (record_id);
create trigger record_versions_bump_seq before insert or update on public.record_versions
  for each row execute function private.bump_seq();

-- ------------------------------------------------------------------ RPC-only housekeeping tables

create table public.mutation_log (
  mutation_id uuid primary key,
  user_id uuid not null,
  received_at timestamptz not null default now(),
  result jsonb
);

create index mutation_log_received_at_idx on public.mutation_log (received_at);

create table public.join_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  at timestamptz not null default now()
);

create index join_attempts_user_at_idx on public.join_attempts (user_id, at);

-- ------------------------------------------------------------------ validation (money engine rules re-checked)

create or replace function private.fail(code text, data jsonb default null)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  raise exception using errcode = 'P0001', message = code, detail = coalesce(data::text, '');
end;
$$;

-- Group must exist, not be soft-deleted and not be archived (archived groups are read-only, TC-1-03).
create or replace function private.assert_group_writable(p_group uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  g record;
begin
  select archived_at, deleted_at into g from public.groups where id = p_group;
  if not found or g.deleted_at is not null then
    perform private.fail('GROUP_NOT_FOUND');
  end if;
  if g.archived_at is not null then
    perform private.fail('GROUP_ARCHIVED');
  end if;
end;
$$;

-- Every key of `parts` must be a non-negative integer amount keyed by a member of the group; sum = total.
create or replace function private.assert_parts(p_group uuid, parts jsonb, total bigint, mismatch_code text)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  s numeric := 0;
  kv record;
begin
  if parts is null or jsonb_typeof(parts) <> 'object' or parts = '{}'::jsonb then
    perform private.fail(mismatch_code, jsonb_build_object('remaining', total));
  end if;
  for kv in select * from jsonb_each(parts) loop
    if jsonb_typeof(kv.value) <> 'number' or (kv.value #>> '{}')::numeric <> trunc((kv.value #>> '{}')::numeric)
       or (kv.value #>> '{}')::numeric < 0 then
      perform private.fail('INVALID_AMOUNT', jsonb_build_object('member', kv.key));
    end if;
    if kv.key !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or not exists (select 1 from public.group_members m where m.id = kv.key::uuid and m.group_id = p_group) then
      perform private.fail('FOREIGN_MEMBER', jsonb_build_object('member', kv.key));
    end if;
    s := s + (kv.value #>> '{}')::numeric;
  end loop;
  if s <> total then
    perform private.fail(mismatch_code, jsonb_build_object('remaining', total - s));
  end if;
end;
$$;

create or replace function private.validate_expense()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.group_id <> old.group_id then
    perform private.fail('GROUP_CHANGE_NOT_ALLOWED');
  end if;
  perform private.assert_group_writable(new.group_id);
  perform money.check_amount(new.total);
  perform private.assert_parts(new.group_id, new.payers, new.total, 'PAYERS_SUM_MISMATCH');
  perform private.assert_parts(new.group_id, new.shares, new.total, 'SPLIT_SUM_MISMATCH');
  if new.kind = 'iou' and (
       (select count(*) from jsonb_object_keys(new.payers)) <> 1
       or (select count(*) from jsonb_object_keys(new.shares)) <> 1
       or new.payers ?| array(select jsonb_object_keys(new.shares))) then
    perform private.fail('INVALID_IOU');
  end if;
  -- Completeness of a saved conversion is a table check; here the converted parts must add up.
  if new.fx_total is not null and new.fx_payers is not null and new.fx_shares is not null then
    perform private.assert_parts(new.group_id, new.fx_payers, new.fx_total, 'FX_PAYERS_SUM_MISMATCH');
    perform private.assert_parts(new.group_id, new.fx_shares, new.fx_total, 'FX_SPLIT_SUM_MISMATCH');
  end if;
  return new;
end;
$$;

create trigger expenses_validate before insert or update on public.expenses
  for each row execute function private.validate_expense();

create or replace function private.validate_payment()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.group_id <> old.group_id then
    perform private.fail('GROUP_CHANGE_NOT_ALLOWED');
  end if;
  perform private.assert_group_writable(new.group_id);
  perform money.check_amount(new.amount);
  if not exists (select 1 from public.group_members m where m.id = new.from_member and m.group_id = new.group_id)
     or not exists (select 1 from public.group_members m where m.id = new.to_member and m.group_id = new.group_id) then
    perform private.fail('FOREIGN_MEMBER');
  end if;
  return new;
end;
$$;

create trigger payments_validate before insert or update on public.payments
  for each row execute function private.validate_payment();

create or replace function private.validate_comment()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.group_id <> old.group_id then
    perform private.fail('GROUP_CHANGE_NOT_ALLOWED');
  end if;
  perform private.assert_group_writable(new.group_id);
  if (new.target_type = 'expense'
        and not exists (select 1 from public.expenses e where e.id = new.target_id and e.group_id = new.group_id))
     or (new.target_type = 'payment'
        and not exists (select 1 from public.payments p where p.id = new.target_id and p.group_id = new.group_id)) then
    perform private.fail('TARGET_NOT_FOUND');
  end if;
  return new;
end;
$$;

create trigger comments_validate before insert or update on public.comments
  for each row execute function private.validate_comment();

revoke all on function private.fail(text, jsonb) from public, anon, authenticated;
revoke all on function private.assert_group_writable(uuid) from public, anon, authenticated;
revoke all on function private.assert_parts(uuid, jsonb, bigint, text) from public, anon, authenticated;
revoke all on function private.validate_expense() from public, anon, authenticated;
revoke all on function private.validate_payment() from public, anon, authenticated;
revoke all on function private.validate_comment() from public, anon, authenticated;
