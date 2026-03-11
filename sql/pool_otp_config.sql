-- Pool OTP Config (TOTP secret for Microsoft Authenticator)
-- Run this in Supabase Dashboard -> SQL Editor

create table if not exists public.pool_otp_config (
  id integer primary key default 1,
  totp_secret text not null,
  created_at timestamptz not null default now()
);

-- Only allow one row (the active config)
create unique index if not exists pool_otp_config_singleton on public.pool_otp_config ((true));

grant select, insert, update on table public.pool_otp_config to service_role;

alter table public.pool_otp_config enable row level security;

-- Only service_role (backend) can read/write this — NOT the anon key
drop policy if exists "otp_service_only" on public.pool_otp_config;
create policy "otp_service_only" on public.pool_otp_config
  for all to service_role using (true) with check (true);

-- Pool Transactions Log
create table if not exists public.pool_transactions (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('request', 'submit')),
  amount numeric not null,
  business_id uuid,
  pm_employee_id uuid,
  created_at timestamptz not null default now()
);

grant select, insert on table public.pool_transactions to authenticated;
grant select, insert on table public.pool_transactions to service_role;

alter table public.pool_transactions enable row level security;

drop policy if exists "pt_select" on public.pool_transactions;
drop policy if exists "pt_insert" on public.pool_transactions;
create policy "pt_select" on public.pool_transactions for select to authenticated using (true);
create policy "pt_insert" on public.pool_transactions for insert to authenticated with check (true);

drop policy if exists "pt_service_all" on public.pool_transactions;
create policy "pt_service_all" on public.pool_transactions for all to service_role using (true) with check (true);
