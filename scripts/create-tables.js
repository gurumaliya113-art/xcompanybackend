import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

async function createTables() {
  // Instead of raw SQL, use Supabase REST API to create rows that implicitly create tables
  // But Supabase JS client can't create tables. So we'll use the approach of 
  // inserting into existing tables or using fetch to the SQL endpoint.

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_KEY;

  const sql = `
    CREATE TABLE IF NOT EXISTS public.pool_otp_config (
      id integer PRIMARY KEY DEFAULT 1,
      totp_secret text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      CONSTRAINT single_row CHECK (id = 1)
    );

    ALTER TABLE public.pool_otp_config ENABLE ROW LEVEL SECURITY;
    
    CREATE POLICY IF NOT EXISTS "Allow all for service role" ON public.pool_otp_config
      FOR ALL USING (true) WITH CHECK (true);

    CREATE TABLE IF NOT EXISTS public.pool_transactions (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      type text NOT NULL CHECK (type IN ('request', 'submit')),
      amount numeric NOT NULL,
      business_id uuid,
      pm_employee_id uuid,
      status text NOT NULL DEFAULT 'completed',
      created_at timestamptz NOT NULL DEFAULT now()
    );

    ALTER TABLE public.pool_transactions ENABLE ROW LEVEL SECURITY;

    CREATE POLICY IF NOT EXISTS "Allow all for service role" ON public.pool_transactions
      FOR ALL USING (true) WITH CHECK (true);
  `;

  // Try multiple Supabase endpoints for SQL execution
  const endpoints = [
    '/rest/v1/rpc/exec_sql',
    '/pg/query', 
  ];

  // Method 1: Try using the Supabase Management API (database query endpoint)
  console.log('Trying Supabase SQL execution...');
  
  const resp = await fetch(url + '/rest/v1/rpc/', {
    method: 'POST',
    headers: {
      'apikey': key,
      'Authorization': 'Bearer ' + key,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql })
  });
  
  console.log('RPC Status:', resp.status);
  const txt = await resp.text();
  console.log('RPC Response:', txt.slice(0, 500));

  // If that didn't work, let's just try creating each table individually via PostgREST
  // Actually, let's try a different approach - use the Supabase SQL API
  console.log('\nTrying direct SQL via pg endpoint...');
  
  const resp2 = await fetch(url.replace('.supabase.co', '.supabase.co') + '/pg/query', {
    method: 'POST', 
    headers: {
      'apikey': key,
      'Authorization': 'Bearer ' + key,
      'Content-Type': 'application/json',
      'X-Supabase-Api-Version': '2024-01-01'
    },
    body: JSON.stringify({ query: sql })
  });

  console.log('PG Status:', resp2.status);
  const txt2 = await resp2.text();
  console.log('PG Response:', txt2.slice(0, 500));
}

createTables().catch(console.error);
