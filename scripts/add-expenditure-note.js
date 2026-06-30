import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import pg from "pg";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, "..", ".env") });

// Additive, nullable column so the simplified Money tab can store a note per spend.
const sql = `ALTER TABLE public.dce_expenditures ADD COLUMN IF NOT EXISTS note TEXT;`;

const ref = "ecjxynuccpncwsogezos";
const key = process.env.SUPABASE_SERVICE_KEY;

const urls = [
  `postgresql://postgres.${ref}:${key}@aws-0-ap-south-1.pooler.supabase.com:5432/postgres`,
  `postgresql://postgres:${key}@db.${ref}.supabase.co:5432/postgres`,
];

for (const url of urls) {
  const safeUrl = url.replace(/:[^:@]{20,}@/, ":***@");
  console.log("Trying:", safeUrl);
  const client = new pg.Client({ connectionString: url, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 10000 });
  try {
    await client.connect();
    console.log("Connected! Running SQL...");
    await client.query(sql);
    console.log("SUCCESS - note column ready on dce_expenditures!");
    await client.end();
    process.exit(0);
  } catch (e) {
    console.log("Failed:", e.message.substring(0, 160));
    try { await client.end(); } catch (_) {}
  }
  console.log("---");
}
console.log("Could not connect. Run this in Supabase SQL Editor:\n" + sql);
process.exit(1);
