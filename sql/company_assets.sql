-- Company Assets table
-- Run this in Supabase Dashboard -> SQL Editor

create extension if not exists "pgcrypto";

create table if not exists public.company_assets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  current_value numeric not null default 0,
  category text,
  condition text not null default 'Good',
  -- New fields (added later via ALTER TABLE below for existing installs)
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now()
);

-- Add new fields safely (for existing tables)
alter table public.company_assets
  add column if not exists category text,
  add column if not exists condition text not null default 'Good',
  add column if not exists purchase_date date,
  add column if not exists purchase_value numeric,
  add column if not exists depreciation_amount numeric;

-- Ensure depreciation generated columns exist with the correct expression.
-- Postgres requires drop+add to change a generated column expression.
alter table public.company_assets
  drop column if exists depreciation_amount,
  drop column if exists depreciation_percent;

alter table public.company_assets
  add column depreciation_amount numeric generated always as (
    (coalesce(purchase_value, current_value) - current_value)
  ) stored,
  add column depreciation_percent numeric generated always as (
    case
      when coalesce(purchase_value, current_value) = 0 then null
      else ((coalesce(purchase_value, current_value) - current_value) / coalesce(purchase_value, current_value)) * 100
    end
  ) stored;

-- Condition enum-like constraint
alter table public.company_assets
  drop constraint if exists company_assets_condition_check;
alter table public.company_assets
  add constraint company_assets_condition_check
  check (condition in ('Excellent','Good','Fair'));

-- Backfill existing rows (keeps old data working)
update public.company_assets
set
  purchase_value = coalesce(purchase_value, current_value),
  purchase_date = coalesce(purchase_date, (created_at at time zone 'UTC')::date),
  category = coalesce(category, 'General'),
  condition = coalesce(condition, 'Good')
where purchase_value is null
   or purchase_date is null
   or category is null
   or condition is null;

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
