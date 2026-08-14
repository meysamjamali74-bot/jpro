-- JPro ERP Cloud Pilot v0.1
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text, full_name text, title text, unit_name text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(), code text not null, name text not null,
  created_by uuid not null references auth.users(id), active boolean not null default true,
  created_at timestamptz not null default now(), unique(created_by,code)
);
create table if not exists public.units (
  id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete cascade,
  parent_id uuid references public.units(id) on delete set null, code text not null, name text not null,
  active boolean not null default true, created_at timestamptz not null default now(), unique(company_id,code)
);
create table if not exists public.company_memberships (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'finance', unit_id uuid references public.units(id) on delete set null,
  permissions jsonb not null default '{}'::jsonb, active boolean not null default true,
  created_at timestamptz not null default now(), primary key(company_id,user_id)
);
create table if not exists public.erp_records (
  company_id uuid not null references public.companies(id) on delete cascade,
  record_type text not null, record_id text not null, payload jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id), updated_at timestamptz not null default now(), deleted_at timestamptz,
  primary key(company_id,record_type,record_id)
);
create index if not exists erp_records_company_type_idx on public.erp_records(company_id,record_type) where deleted_at is null;
create table if not exists public.audit_events (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid references auth.users(id), action text not null, record_type text, record_id text,
  details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.units enable row level security;
alter table public.company_memberships enable row level security;
alter table public.erp_records enable row level security;
alter table public.audit_events enable row level security;

grant select,insert,update on public.profiles to authenticated;
grant select,insert,update,delete on public.companies to authenticated;
grant select,insert,update,delete on public.units to authenticated;
grant select,insert,update,delete on public.company_memberships to authenticated;
grant select,insert,update,delete on public.erp_records to authenticated;
grant select,insert on public.audit_events to authenticated;

drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_self on public.profiles for select to authenticated using ((select auth.uid())=id);
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles for insert to authenticated with check ((select auth.uid())=id);
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated using ((select auth.uid())=id) with check ((select auth.uid())=id);

drop policy if exists companies_select_member_or_creator on public.companies;
create policy companies_select_member_or_creator on public.companies for select to authenticated using (
 created_by=(select auth.uid()) or exists(select 1 from public.company_memberships m where m.company_id=companies.id and m.user_id=(select auth.uid()) and m.active)
);
drop policy if exists companies_insert_creator on public.companies;
create policy companies_insert_creator on public.companies for insert to authenticated with check (created_by=(select auth.uid()));
drop policy if exists companies_update_creator on public.companies;
create policy companies_update_creator on public.companies for update to authenticated using (created_by=(select auth.uid())) with check (created_by=(select auth.uid()));

drop policy if exists memberships_select_self_or_creator on public.company_memberships;
create policy memberships_select_self_or_creator on public.company_memberships for select to authenticated using (
 user_id=(select auth.uid()) or exists(select 1 from public.companies c where c.id=company_memberships.company_id and c.created_by=(select auth.uid()))
);
drop policy if exists memberships_insert_creator on public.company_memberships;
create policy memberships_insert_creator on public.company_memberships for insert to authenticated with check (
 user_id=(select auth.uid()) and exists(select 1 from public.companies c where c.id=company_memberships.company_id and c.created_by=(select auth.uid()))
);
drop policy if exists memberships_update_creator on public.company_memberships;
create policy memberships_update_creator on public.company_memberships for update to authenticated using (
 exists(select 1 from public.companies c where c.id=company_memberships.company_id and c.created_by=(select auth.uid()))
) with check (
 exists(select 1 from public.companies c where c.id=company_memberships.company_id and c.created_by=(select auth.uid()))
);

drop policy if exists units_select_member on public.units;
create policy units_select_member on public.units for select to authenticated using (
 exists(select 1 from public.company_memberships m where m.company_id=units.company_id and m.user_id=(select auth.uid()) and m.active)
 or exists(select 1 from public.companies c where c.id=units.company_id and c.created_by=(select auth.uid()))
);
drop policy if exists units_write_creator on public.units;
create policy units_write_creator on public.units for all to authenticated using (
 exists(select 1 from public.companies c where c.id=units.company_id and c.created_by=(select auth.uid()))
) with check (
 exists(select 1 from public.companies c where c.id=units.company_id and c.created_by=(select auth.uid()))
);

drop policy if exists records_select_member on public.erp_records;
create policy records_select_member on public.erp_records for select to authenticated using (
 exists(select 1 from public.company_memberships m where m.company_id=erp_records.company_id and m.user_id=(select auth.uid()) and m.active)
);
drop policy if exists records_insert_member on public.erp_records;
create policy records_insert_member on public.erp_records for insert to authenticated with check (
 updated_by=(select auth.uid()) and exists(select 1 from public.company_memberships m where m.company_id=erp_records.company_id and m.user_id=(select auth.uid()) and m.active and m.role<>'auditor')
);
drop policy if exists records_update_member on public.erp_records;
create policy records_update_member on public.erp_records for update to authenticated using (
 exists(select 1 from public.company_memberships m where m.company_id=erp_records.company_id and m.user_id=(select auth.uid()) and m.active and m.role<>'auditor')
) with check (
 updated_by=(select auth.uid()) and exists(select 1 from public.company_memberships m where m.company_id=erp_records.company_id and m.user_id=(select auth.uid()) and m.active and m.role<>'auditor')
);
drop policy if exists records_delete_member on public.erp_records;
create policy records_delete_member on public.erp_records for delete to authenticated using (
 exists(select 1 from public.company_memberships m where m.company_id=erp_records.company_id and m.user_id=(select auth.uid()) and m.active and m.role in ('admin','ceo','finance','accountant'))
);

drop policy if exists audit_select_member on public.audit_events;
create policy audit_select_member on public.audit_events for select to authenticated using (
 exists(select 1 from public.company_memberships m where m.company_id=audit_events.company_id and m.user_id=(select auth.uid()) and m.active)
);
drop policy if exists audit_insert_member on public.audit_events;
create policy audit_insert_member on public.audit_events for insert to authenticated with check (
 user_id=(select auth.uid()) and exists(select 1 from public.company_memberships m where m.company_id=audit_events.company_id and m.user_id=(select auth.uid()) and m.active)
);
