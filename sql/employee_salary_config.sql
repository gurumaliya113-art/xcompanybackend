-- Employee Salary Config
-- Run this in Supabase Dashboard -> SQL Editor

create extension if not exists "pgcrypto";

create table if not exists public.employee_salary_config (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null,
  salary_fixed boolean not null default false,
  basic_pay numeric not null default 0,
  start_date date not null default current_date,
  annual_rate numeric not null default 0.06,
  created_at timestamptz not null default now()
);

-- Ensure API roles can access the table (RLS still applies).
grant select, insert, update, delete on table public.employee_salary_config to authenticated;

alter table public.employee_salary_config enable row level security;

drop policy if exists "esc_select" on public.employee_salary_config;
drop policy if exists "esc_insert" on public.employee_salary_config;
drop policy if exists "esc_update" on public.employee_salary_config;
drop policy if exists "esc_delete" on public.employee_salary_config;

create policy "esc_select" on public.employee_salary_config for select to authenticated using (true);
create policy "esc_insert" on public.employee_salary_config for insert to authenticated with check (true);
create policy "esc_update" on public.employee_salary_config for update to authenticated using (true) with check (true);
create policy "esc_delete" on public.employee_salary_config for delete to authenticated using (true);
