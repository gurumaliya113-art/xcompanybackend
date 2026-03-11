-- PM Login Users table
-- Stores credentials for PM panel access

CREATE TABLE IF NOT EXISTS public.pm_login_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.pm_login_users ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pm_login_users' AND policyname = 'pm_login_users_allow_all_anon'
  ) THEN
    CREATE POLICY pm_login_users_allow_all_anon
      ON public.pm_login_users
      FOR ALL
      TO anon
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;
