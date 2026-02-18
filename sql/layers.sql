-- Create tables for Founder Layer management UI
-- Run this in Supabase Dashboard -> SQL Editor

create extension if not exists "pgcrypto";

create table if not exists public.layer1_founders (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  share_value numeric not null default 0,
  created_at timestamptz not null default now()
);

grant select, insert, update, delete on table public.layer1_founders to authenticated;

create table if not exists public.layer2_members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  share_value numeric not null default 0,
  created_at timestamptz not null default now()
);

grant select, insert, update, delete on table public.layer2_members to authenticated;

create table if not exists public.layer4_investors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  amount numeric not null default 0,
  invested_on date not null default current_date,
  annual_rate numeric not null default 0.12,
  layer_tag text not null default 'LAYER 4',
  created_at timestamptz not null default now()
);

grant select, insert, update, delete on table public.layer4_investors to authenticated;

-- For existing projects: add columns if table already exists
alter table if exists public.layer4_investors
  add column if not exists invested_on date not null default current_date;

alter table if exists public.layer4_investors
  add column if not exists annual_rate numeric not null default 0.12;

alter table if exists public.layer4_investors
  add column if not exists layer_tag text not null default 'LAYER 4';

-- Basic RLS: authenticated users only.
-- Tighten later if you want Founder-only access.
alter table public.layer1_founders enable row level security;
alter table public.layer2_members enable row level security;
alter table public.layer4_investors enable row level security;

drop policy if exists "layer1_select" on public.layer1_founders;
drop policy if exists "layer1_insert" on public.layer1_founders;
drop policy if exists "layer1_update" on public.layer1_founders;
drop policy if exists "layer1_delete" on public.layer1_founders;

create policy "layer1_select" on public.layer1_founders for select to authenticated using (true);
create policy "layer1_insert" on public.layer1_founders for insert to authenticated with check (true);
create policy "layer1_update" on public.layer1_founders for update to authenticated using (true) with check (true);
create policy "layer1_delete" on public.layer1_founders for delete to authenticated using (true);

drop policy if exists "layer2_select" on public.layer2_members;
drop policy if exists "layer2_insert" on public.layer2_members;
drop policy if exists "layer2_update" on public.layer2_members;
drop policy if exists "layer2_delete" on public.layer2_members;

create policy "layer2_select" on public.layer2_members for select to authenticated using (true);
create policy "layer2_insert" on public.layer2_members for insert to authenticated with check (true);
create policy "layer2_update" on public.layer2_members for update to authenticated using (true) with check (true);
create policy "layer2_delete" on public.layer2_members for delete to authenticated using (true);

drop policy if exists "layer4_select" on public.layer4_investors;
drop policy if exists "layer4_insert" on public.layer4_investors;
drop policy if exists "layer4_update" on public.layer4_investors;
drop policy if exists "layer4_delete" on public.layer4_investors;

create policy "layer4_select" on public.layer4_investors for select to authenticated using (true);
create policy "layer4_insert" on public.layer4_investors for insert to authenticated with check (true);
create policy "layer4_update" on public.layer4_investors for update to authenticated using (true) with check (true);
create policy "layer4_delete" on public.layer4_investors for delete to authenticated using (true);
