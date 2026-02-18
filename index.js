import "dotenv/config";

import express from "express";
import cors from "cors";
import { createClient } from "@supabase/supabase-js";

const app = express();
app.use(cors());
app.use(express.json());

const port = Number(process.env.PORT) || 3000;

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.warn(
    "Supabase env missing: set SUPABASE_URL and SUPABASE_SERVICE_KEY to enable DB routes"
  );
}

const supabase =
  supabaseUrl && supabaseServiceKey
    ? createClient(supabaseUrl, supabaseServiceKey)
    : null;

app.get("/health", (req, res) => {
  res.json({ ok: true });
});

/* ================= DAILY REPORT (fallback for missing RPC) ================= */
app.post("/daily-report", async (req, res) => {
  try {
    const { business_id, date, income, expense, pool_taken } = req.body || {};

    if (!business_id || !date) {
      return res.status(400).json({ ok: false, error: "business_id and date required" });
    }

    const incomeNum = Number(income || 0);
    const expenseNum = Number(expense || 0);
    const poolTakenNum = Number(pool_taken || 0);
    if (!Number.isFinite(incomeNum) || !Number.isFinite(expenseNum) || !Number.isFinite(poolTakenNum)) {
      return res.status(400).json({ ok: false, error: "Invalid numbers" });
    }

    if (!supabase) {
      return res.status(500).json({ ok: false, error: "Server not configured" });
    }

    const month = typeof date === "string" && date.includes("-") ? date.slice(0, 7) : null;
    const profit = incomeNum - expenseNum;

    // Insert report with schema fallbacks
    const reportCandidates = [
      {
        business_id,
        report_date: date,
        month,
        income: incomeNum,
        expense: expenseNum,
        pool_taken: poolTakenNum,
        profit,
      },
      {
        business_id,
        month,
        income: incomeNum,
        expense: expenseNum,
        profit,
      },
      {
        business_id,
        income: incomeNum,
        expense: expenseNum,
      },
    ];

    let inserted = false;
    let insertErr = null;
    for (const payload of reportCandidates) {
      const { error } = await supabase.from("reports").insert([payload]);
      if (!error) {
        inserted = true;
        insertErr = null;
        break;
      }
      insertErr = error;
      if (/column .* does not exist|invalid input syntax|violates not-null constraint/i.test(error.message || "")) {
        continue;
      }
      break;
    }

    if (!inserted) {
      return res.status(500).json({ ok: false, error: "Report insert failed", details: insertErr?.message });
    }

    // Best-effort: update company_money_pool if pool_taken was provided.
    // This mirrors other code paths that append a new pool row.
    let poolUpdated = false;
    if (poolTakenNum > 0) {
      const { data: poolRows, error: poolErr } = await supabase
        .from("company_money_pool")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(1);

      if (!poolErr && poolRows && poolRows[0]) {
        const latest = poolRows[0];
        const l1 = Number(latest.layer1_amount || 0);
        const l2 = Number(latest.layer2_amount || 0);
        if (poolTakenNum > l1) {
          return res.status(400).json({ ok: false, error: "Pool insufficient" });
        }

        const { error: updErr } = await supabase.from("company_money_pool").insert([
          {
            layer1_amount: l1 - poolTakenNum,
            layer2_amount: l2,
          },
        ]);

        if (!updErr) poolUpdated = true;
      }
    }

    return res.json({ ok: true, pool_updated: poolUpdated });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok: false, error: "Unexpected server error" });
  }
});

/* ================= SELL SHARES ================= */
app.post("/sell-shares", async (req, res) => {
  try {
    const { employee_id, shares } = req.body;

    if (!employee_id || shares === undefined || shares === null) {
      return res.status(400).json({ error: "Invalid input" });
    }

    const sharesNum = Number(shares);
    if (!Number.isFinite(sharesNum) || sharesNum <= 0) {
      return res.status(400).json({ error: "Invalid shares" });
    }

    if (!supabase) {
      return res.status(500).json({ error: "Server not configured" });
    }

    // 1️⃣ total available shares
    const { data: ledger, error: ledgerErr } = await supabase
      .from("shares_ledger")
      .select("shares, locked")
      .eq("employee_id", employee_id);

    if (ledgerErr) {
      return res.status(500).json({ error: "Ledger query failed" });
    }

    let available = 0;
    (ledger || []).forEach((entry) => {
      if (!entry.locked) available += Number(entry.shares);
    });

    if (sharesNum > available) {
      return res.status(400).json({ error: "Not enough shares" });
    }

    // 2️⃣ live share price
    const { data: company, error: companyErr } = await supabase
      .from("company_live_value")
      .select("*")
      .single();

    if (companyErr || !company) {
      return res.status(500).json({ error: "Company value not found" });
    }

    const { data: cfg, error: cfgErr } = await supabase
      .from("company_shares_config")
      .select("total_shares")
      .single();

    if (cfgErr || !cfg || !cfg.total_shares) {
      return res.status(500).json({ error: "Share config not found" });
    }

    const price = Number(company.company_value) / Number(cfg.total_shares);
    const amount = sharesNum * price;

    if (!Number.isFinite(price) || price <= 0) {
      return res.status(500).json({ error: "Invalid share price" });
    }

    // 3️⃣ company cash check
    const { data: pool, error: poolErr } = await supabase
      .from("company_money_pool")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(1);

    if (poolErr) {
      return res.status(500).json({ error: "Money pool query failed" });
    }

    const latestPool = (pool || [])[0];
    if (!latestPool) {
      return res.status(500).json({ error: "Money pool empty" });
    }

    if (amount > Number(latestPool.layer1_amount)) {
      return res.status(400).json({ error: "Company cash insufficient" });
    }

    // 4️⃣ update ledger
    const { error: insertLedgerErr } = await supabase.from("shares_ledger").insert([
      {
        employee_id,
        shares: -sharesNum,
        locked: false,
      },
    ]);

    if (insertLedgerErr) {
      return res.status(500).json({ error: "Failed to update ledger" });
    }

    // 5️⃣ update money pool
    const { error: insertPoolErr } = await supabase.from("company_money_pool").insert([
      {
        layer1_amount: Number(latestPool.layer1_amount) - amount,
        layer2_amount: Number(latestPool.layer2_amount),
      },
    ]);

    if (insertPoolErr) {
      return res.status(500).json({ error: "Failed to update money pool" });
    }

    res.json({
      success: true,
      sold_shares: sharesNum,
      price,
      amount,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Unexpected server error" });
  }
});

app.listen(port, () => {
  console.log(`Backend running on port ${port}`);
});
