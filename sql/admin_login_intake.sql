-- Intake-style Admin Login (invite-code based)
-- Creates:
--   - public.admin_users
--   - public.admin_invite_codes
--   - public.claim_admin(invite_code text) RPC

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_invite_codes (
  code text primary key,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  max_uses integer,
  uses_count integer not null default 0,
  active boolean not null default true
);

alter table public.admin_users enable row level security;
alter table public.admin_invite_codes enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'admin_users' and policyname = 'admin_users_select_own'
  ) then
    create policy admin_users_select_own
      on public.admin_users
      for select
      to authenticated
      using (user_id = auth.uid());
  end if;
end
$$;

-- RPC used by the intake admin login flow.
-- Returns true when the invite code is valid and the current user is (now) an admin.
create or replace function public.claim_admin(invite_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_code text := trim(invite_code);
begin
  if current_user_id is null then
    return false;
  end if;

  if normalized_code is null or length(normalized_code) = 0 then
    return false;
  end if;

  -- Validate invite code (row locked to avoid over-using max_uses in concurrent requests)
  perform 1
  from public.admin_invite_codes
  where code = normalized_code
    and active = true
    and (expires_at is null or expires_at > now())
    and (max_uses is null or uses_count < max_uses)
  for update;

  if not found then
    return false;
  end if;

  insert into public.admin_users(user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  update public.admin_invite_codes
  set uses_count = uses_count + 1
  where code = normalized_code
    and (max_uses is null or uses_count < max_uses);

  return true;
end;
$$;

grant execute on function public.claim_admin(text) to authenticated;
grant select on table public.admin_users to authenticated;

-- Create an invite code (change the value). Example:
-- insert into public.admin_invite_codes (code, max_uses) values ('CHANGE_ME', null);

-- Default invite code for setup
insert into public.admin_invite_codes (code, max_uses)
values ('KALUA', null)
on conflict (code) do update
set max_uses = excluded.max_uses,
    active = true;
