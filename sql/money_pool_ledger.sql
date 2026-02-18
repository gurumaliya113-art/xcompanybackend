-- Money Pool Ledger
-- Run this in Supabase Dashboard -> SQL Editor

create extension if not exists "pgcrypto";

create table if not exists public.money_pool_ledger (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  source text not null check (source in ('CASH','BANK')),
  type text not null check (type in ('ADD','MINUS')),
  amount numeric not null default 0,
  from_text text null,
  reason text null
);

-- Ensure API roles can access the table (RLS still applies).
grant select, insert, update, delete on table public.money_pool_ledger to authenticated;

-- Basic RLS: authenticated users only.
alter table public.money_pool_ledger enable row level security;

drop policy if exists "mpl_select" on public.money_pool_ledger;
drop policy if exists "mpl_insert" on public.money_pool_ledger;
drop policy if exists "mpl_update" on public.money_pool_ledger;
drop policy if exists "mpl_delete" on public.money_pool_ledger;

create policy "mpl_select" on public.money_pool_ledger for select to authenticated using (true);
create policy "mpl_insert" on public.money_pool_ledger for insert to authenticated with check (true);
create policy "mpl_update" on public.money_pool_ledger for update to authenticated using (true) with check (true);
create policy "mpl_delete" on public.money_pool_ledger for delete to authenticated using (true);
