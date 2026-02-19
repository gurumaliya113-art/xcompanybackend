-- Meesho Entries
-- Run this in Supabase Dashboard -> SQL Editor

create extension if not exists "pgcrypto";

create table if not exists public.meesho_entries (
  id uuid primary key default gen_random_uuid(),
  entry_datetime timestamptz not null default now(),
  sub_order_id text not null,
  cost_price numeric not null default 0,
  selling_price numeric not null default 0,
  dispatched boolean not null default false,
  delivered boolean not null default false,
  return_status text not null default 'NONE',
  cancelled_by text not null default 'NONE',
  image_url text null,
  bill_pdf_url text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Backward-compatible add (if table already existed)
alter table public.meesho_entries
  add column if not exists image_url text;

-- Backward-compatible add (if table already existed)
alter table public.meesho_entries
  add column if not exists bill_pdf_url text;

-- Backward-compatible add (if table already existed)
alter table public.meesho_entries
  add column if not exists cost_price numeric not null default 0;

alter table public.meesho_entries
  add column if not exists selling_price numeric not null default 0;

create index if not exists meesho_entries_entry_datetime_idx on public.meesho_entries (entry_datetime desc);
create index if not exists meesho_entries_sub_order_id_idx on public.meesho_entries (sub_order_id);

-- Ensure API roles can access the table (RLS still applies).
grant select, insert, update, delete on table public.meesho_entries to authenticated;

alter table public.meesho_entries enable row level security;

drop policy if exists "meesho_select" on public.meesho_entries;
drop policy if exists "meesho_insert" on public.meesho_entries;
drop policy if exists "meesho_update" on public.meesho_entries;
drop policy if exists "meesho_delete" on public.meesho_entries;

create policy "meesho_select" on public.meesho_entries for select to authenticated using (true);
create policy "meesho_insert" on public.meesho_entries for insert to authenticated with check (true);
create policy "meesho_update" on public.meesho_entries for update to authenticated using (true) with check (true);
create policy "meesho_delete" on public.meesho_entries for delete to authenticated using (true);

-- Auto-update updated_at
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_meesho_entries_updated_at on public.meesho_entries;
create trigger trg_meesho_entries_updated_at
before update on public.meesho_entries
for each row execute function public.set_updated_at();
