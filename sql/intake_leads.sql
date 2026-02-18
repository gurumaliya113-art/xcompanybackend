-- Intake Landing Leads
-- Tables used by the intake landing bundle:
--   - public.enquiries
--   - public.partners
--
-- Design goals:
--   - Anyone (anon/authenticated) can submit (insert)
--   - Only admins (auth + present in public.admin_users) can view/delete

create extension if not exists "pgcrypto";

create table if not exists public.enquiries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  company text not null,
  phone text not null,
  email text not null,
  project_details text not null,
  budget text not null,
  timeline text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  company text not null,
  phone text not null,
  email text not null,
  city text not null,
  work_type text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists enquiries_created_at_idx on public.enquiries (created_at desc);
create index if not exists partners_created_at_idx on public.partners (created_at desc);

alter table public.enquiries enable row level security;
alter table public.partners enable row level security;

-- Grants: PostgREST uses anon/authenticated roles.
grant insert on table public.enquiries to anon, authenticated;
grant insert on table public.partners to anon, authenticated;
grant select, delete on table public.enquiries to authenticated;
grant select, delete on table public.partners to authenticated;

-- Policies
drop policy if exists enquiries_insert_public on public.enquiries;
drop policy if exists enquiries_admin_select on public.enquiries;
drop policy if exists enquiries_admin_delete on public.enquiries;

drop policy if exists partners_insert_public on public.partners;
drop policy if exists partners_admin_select on public.partners;
drop policy if exists partners_admin_delete on public.partners;

create policy enquiries_insert_public
  on public.enquiries
  for insert
  to anon, authenticated
  with check (true);

create policy partners_insert_public
  on public.partners
  for insert
  to anon, authenticated
  with check (true);

create policy enquiries_admin_select
  on public.enquiries
  for select
  to authenticated
  using (exists (select 1 from public.admin_users au where au.user_id = auth.uid()));

create policy partners_admin_select
  on public.partners
  for select
  to authenticated
  using (exists (select 1 from public.admin_users au where au.user_id = auth.uid()));

create policy enquiries_admin_delete
  on public.enquiries
  for delete
  to authenticated
  using (exists (select 1 from public.admin_users au where au.user_id = auth.uid()));

create policy partners_admin_delete
  on public.partners
  for delete
  to authenticated
  using (exists (select 1 from public.admin_users au where au.user_id = auth.uid()));
