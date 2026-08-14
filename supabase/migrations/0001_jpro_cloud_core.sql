-- JPro ERP Cloud Pilot v0.2
-- Multi-tenant core with RLS, optimistic versions, audit trail and Storage policies.
create extension if not exists pgcrypto;
create schema if not exists private;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  title text,
  unit_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  join_code text not null default upper(substr(encode(gen_random_bytes(8),'hex'),1,8)),
  created_by uuid not null references auth.users(id),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(created_by,code),
  unique(join_code)
);

create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  parent_id uuid references public.units(id) on delete set null,
  code text not null,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(company_id,code)
);

create table if not exists public.company_memberships (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'finance' check (role in ('admin','finance','requester','seller','sales_manager','cashier','accountant','treasury','warehouse','logistics','ceo','auditor')),
  unit_id uuid references public.units(id) on delete set null,
  permissions jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key(company_id,user_id)
);

create table if not exists public.erp_records (
  company_id uuid not null references public.companies(id) on delete cascade,
  record_type text not null,
  record_id text not null,
  payload jsonb not null default '{}'::jsonb,
  version bigint not null default 1,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key(company_id,record_type,record_id)
);
create index if not exists erp_records_company_type_idx on public.erp_records(company_id,record_type) where deleted_at is null;
create index if not exists erp_records_updated_idx on public.erp_records(company_id,updated_at desc);

create table if not exists public.audit_events (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid references auth.users(id),
  action text not null,
  record_type text,
  record_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_events_company_created_idx on public.audit_events(company_id,created_at desc);

-- RLS helper functions live outside exposed public schema.
create or replace function private.is_company_creator(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select (select auth.uid()) is not null
     and exists (
       select 1 from public.companies c
       where c.id = p_company_id and c.created_by = (select auth.uid())
     );
$$;

create or replace function private.is_active_member(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select (select auth.uid()) is not null
     and exists (
       select 1 from public.company_memberships m
       where m.company_id = p_company_id
         and m.user_id = (select auth.uid())
         and m.active
     );
$$;

create or replace function private.member_role(p_company_id uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select m.role
  from public.company_memberships m
  where m.company_id = p_company_id
    and m.user_id = (select auth.uid())
    and m.active
  limit 1;
$$;

revoke all on function private.is_company_creator(uuid) from public, anon;
revoke all on function private.is_active_member(uuid) from public, anon;
revoke all on function private.member_role(uuid) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_company_creator(uuid) to authenticated;
grant execute on function private.is_active_member(uuid) to authenticated;
grant execute on function private.member_role(uuid) to authenticated;

-- Automatically make the creator an admin member.
create or replace function private.add_company_creator_membership()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.created_by <> (select auth.uid()) then
    raise exception 'invalid company creator';
  end if;
  insert into public.company_memberships(company_id,user_id,role,active)
  values(new.id,new.created_by,'admin',true)
  on conflict (company_id,user_id) do update set role='admin',active=true;
  return new;
end;
$$;
revoke all on function private.add_company_creator_membership() from public, anon, authenticated;
drop trigger if exists trg_company_creator_membership on public.companies;
create trigger trg_company_creator_membership
after insert on public.companies
for each row execute function private.add_company_creator_membership();

alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.units enable row level security;
alter table public.company_memberships enable row level security;
alter table public.erp_records enable row level security;
alter table public.audit_events enable row level security;

revoke all on public.profiles,public.companies,public.units,public.company_memberships,public.erp_records,public.audit_events from anon;
grant select,insert,update on public.profiles to authenticated;
grant select,insert,update on public.companies to authenticated;
grant select,insert,update,delete on public.units to authenticated;
grant select,insert,update,delete on public.company_memberships to authenticated;
grant select,insert,update,delete on public.erp_records to authenticated;
grant select,insert on public.audit_events to authenticated;

-- Profiles
create policy profiles_select_self on public.profiles for select to authenticated using ((select auth.uid())=id);
create policy profiles_insert_self on public.profiles for insert to authenticated with check ((select auth.uid())=id);
create policy profiles_update_self on public.profiles for update to authenticated using ((select auth.uid())=id) with check ((select auth.uid())=id);

-- Companies
create policy companies_select_member_or_creator on public.companies for select to authenticated
using (created_by=(select auth.uid()) or (select private.is_active_member(id)));
create policy companies_insert_creator on public.companies for insert to authenticated
with check (created_by=(select auth.uid()));
create policy companies_update_admin on public.companies for update to authenticated
using (created_by=(select auth.uid()) or (select private.member_role(id))='admin')
with check (created_by=(select auth.uid()) or (select private.member_role(id))='admin');

-- Memberships. Users can read their own membership; company admin/creator can manage company membership.
create policy memberships_select_self_or_admin on public.company_memberships for select to authenticated
using (user_id=(select auth.uid()) or (select private.is_company_creator(company_id)) or (select private.member_role(company_id))='admin');
create policy memberships_insert_admin on public.company_memberships for insert to authenticated
with check ((select private.is_company_creator(company_id)) or (select private.member_role(company_id))='admin');
create policy memberships_update_admin on public.company_memberships for update to authenticated
using ((select private.is_company_creator(company_id)) or (select private.member_role(company_id))='admin')
with check ((select private.is_company_creator(company_id)) or (select private.member_role(company_id))='admin');
create policy memberships_delete_admin on public.company_memberships for delete to authenticated
using (((select private.is_company_creator(company_id)) or (select private.member_role(company_id))='admin') and user_id<>(select auth.uid()));

-- Units
create policy units_select_member on public.units for select to authenticated
using ((select private.is_active_member(company_id)) or (select private.is_company_creator(company_id)));
create policy units_write_admin on public.units for all to authenticated
using ((select private.is_company_creator(company_id)) or (select private.member_role(company_id))='admin')
with check ((select private.is_company_creator(company_id)) or (select private.member_role(company_id))='admin');

-- Generic ERP migration records. Auditor is read-only.
create policy records_select_member on public.erp_records for select to authenticated
using ((select private.is_active_member(company_id)));
create policy records_insert_member on public.erp_records for insert to authenticated
with check (updated_by=(select auth.uid()) and (select private.is_active_member(company_id)) and coalesce((select private.member_role(company_id)),'')<>'auditor');
create policy records_update_member on public.erp_records for update to authenticated
using ((select private.is_active_member(company_id)) and coalesce((select private.member_role(company_id)),'')<>'auditor')
with check (updated_by=(select auth.uid()) and (select private.is_active_member(company_id)) and coalesce((select private.member_role(company_id)),'')<>'auditor');
create policy records_delete_privileged on public.erp_records for delete to authenticated
using ((select private.member_role(company_id)) in ('admin','ceo','finance','accountant'));

-- Append-only audit from client. No UPDATE/DELETE grant exists.
create policy audit_select_member on public.audit_events for select to authenticated
using ((select private.is_active_member(company_id)));
create policy audit_insert_member on public.audit_events for insert to authenticated
with check (user_id=(select auth.uid()) and (select private.is_active_member(company_id)));

-- Private document attachments. Object path starts with company UUID.
insert into storage.buckets(id,name,public,file_size_limit)
values('jpro-private','jpro-private',false,26214400)
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit;

create policy jpro_storage_select_member on storage.objects for select to authenticated
using (bucket_id='jpro-private' and (select private.is_active_member(((storage.foldername(name))[1])::uuid)));
create policy jpro_storage_insert_member on storage.objects for insert to authenticated
with check (bucket_id='jpro-private' and (select private.is_active_member(((storage.foldername(name))[1])::uuid)) and coalesce((select private.member_role(((storage.foldername(name))[1])::uuid)),'')<>'auditor');
create policy jpro_storage_update_member on storage.objects for update to authenticated
using (bucket_id='jpro-private' and (select private.is_active_member(((storage.foldername(name))[1])::uuid)) and coalesce((select private.member_role(((storage.foldername(name))[1])::uuid)),'')<>'auditor')
with check (bucket_id='jpro-private' and (select private.is_active_member(((storage.foldername(name))[1])::uuid)) and coalesce((select private.member_role(((storage.foldername(name))[1])::uuid)),'')<>'auditor');
create policy jpro_storage_delete_privileged on storage.objects for delete to authenticated
using (bucket_id='jpro-private' and (select private.member_role(((storage.foldername(name))[1])::uuid)) in ('admin','ceo','finance','accountant'));

-- Realtime publication for synchronized records.
do $$ begin
  alter publication supabase_realtime add table public.erp_records;
exception when duplicate_object then null;
end $$;
