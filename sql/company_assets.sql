-- Company Assets table
-- Run this in Supabase Dashboard -> SQL Editor

create extension if not exists "pgcrypto";

create table if not exists public.company_assets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  current_value numeric not null default 0,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now()
);

-- Ensure API roles can access the table (RLS still applies).
grant select, insert, update, delete on table public.company_assets to authenticated;

-- Basic RLS: authenticated users only.
alter table public.company_assets enable row level security;

drop policy if exists "assets_select" on public.company_assets;
drop policy if exists "assets_insert" on public.company_assets;
drop policy if exists "assets_update" on public.company_assets;
drop policy if exists "assets_delete" on public.company_assets;

create policy "assets_select" on public.company_assets for select to authenticated using (true);
create policy "assets_insert" on public.company_assets for insert to authenticated with check (true);
create policy "assets_update" on public.company_assets for update to authenticated using (true) with check (true);
create policy "assets_delete" on public.company_assets for delete to authenticated using (true);
