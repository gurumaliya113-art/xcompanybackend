import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import pg from "pg";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, "..", ".env") });

const sql = `
CREATE TABLE IF NOT EXISTS employee_ledger (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('AR', 'AP')),
  description TEXT NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE employee_ledger ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS allow_all_anon ON employee_ledger;
CREATE POLICY allow_all_anon ON employee_ledger FOR ALL USING (true) WITH CHECK (true);
`;

const ref = 'ecjxynuccpncwsogezos';
const key = process.env.SUPABASE_SERVICE_KEY;

const urls = [
  `postgresql://postgres.${ref}:${key}@aws-0-ap-south-1.pooler.supabase.com:5432/postgres`,
  `postgresql://postgres:${key}@db.${ref}.supabase.co:5432/postgres`,
];

for (const url of urls) {
  const safeUrl = url.replace(/:[^:@]{20,}@/, ':***@');
  console.log('Trying:', safeUrl);
  const client = new pg.Client({ connectionString: url, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 10000 });
  try {
    await client.connect();
    console.log('Connected! Running SQL...');
    await client.query(sql);
    console.log('SUCCESS - Table created!');
    await client.end();
    process.exit(0);
  } catch(e) {
    console.log('Failed:', e.message.substring(0, 120));
    try { await client.end(); } catch(_){}
  }
  console.log('---');
}
console.log('Could not connect. Please create the table manually via Supabase Dashboard SQL Editor.');
