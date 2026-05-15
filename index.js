import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, ".env") });

import express from "express";
import cors from "cors";
import { createClient } from "@supabase/supabase-js";
import { Resend } from "resend";
import { randomInt, createHash } from "crypto";

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
const FOUNDER_EMAIL = process.env.FOUNDER_EMAIL || "";
const FAST2SMS_API_KEY = process.env.FAST2SMS_API_KEY || "";
const FAST2SMS_SENDER_ID = process.env.FAST2SMS_SENDER_ID || "FSTSMS";
const FAST2SMS_ROUTE = process.env.FAST2SMS_ROUTE || "v3";
const OTP_EXPIRY_MS = 2 * 60 * 1000; // 2 minutes
const MAX_OTP_ATTEMPTS = 3;

if (!RESEND_API_KEY) {
  console.warn("RESEND_API_KEY is not configured. Meeting email notifications will be disabled.");
}
if (!FAST2SMS_API_KEY) {
  console.warn("FAST2SMS_API_KEY is not configured. SMS notification route will be disabled.");
}

// In-memory OTP store: Map<orderId, { hash, amount, type, createdAt, expiresAt, used, attempts, ip, ... }>
const otpStore = new Map();

// Cleanup expired OTPs every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [id, entry] of otpStore) {
    if (now > entry.expiresAt + 60000) otpStore.delete(id);
  }
}, 5 * 60 * 1000);

function hashOtp(otp) {
  return createHash("sha256").update(String(otp)).digest("hex");
}

function generateOrderId() {
  const ts = Date.now().toString(36);
  const rand = randomInt(0, 0xfffff).toString(36);
  return `TXC-${ts}-${rand}`.toUpperCase();
}

function formatINR(n) {
  try { return "\u20B9" + Number(n).toLocaleString("en-IN"); } catch { return "\u20B9" + n; }
}

// Rate limit: max 5 OTP requests per IP per 10 minutes
const rateLimitMap = new Map();
function checkRateLimit(ip) {
  const now = Date.now();
  const window = 10 * 60 * 1000;
  const entry = rateLimitMap.get(ip) || [];
  const recent = entry.filter(ts => now - ts < window);
  if (recent.length >= 5) return false;
  recent.push(now);
  rateLimitMap.set(ip, recent);
  return true;
}

// POST /generate-otp — PM requests OTP, email sent to Founder
app.post("/generate-otp", async (req, res) => {
  try {
    if (!resend || !FOUNDER_EMAIL) {
      return res.status(500).json({ ok: false, error: "Email not configured. Set RESEND_API_KEY and FOUNDER_EMAIL in backend .env" });
    }

    const ip = req.headers["x-forwarded-for"] || req.socket?.remoteAddress || "unknown";
    if (!checkRateLimit(ip)) {
      return res.status(429).json({ ok: false, error: "Too many OTP requests. Wait a few minutes." });
    }

    const { amount, type, source, reason, business_id, pm_employee_id } = req.body || {};
    const amountNum = Number(amount);
    if (!Number.isFinite(amountNum) || amountNum <= 0) {
      return res.status(400).json({ ok: false, error: "Invalid amount" });
    }

    const requestType = type === "submit" ? "submit" : "request";
    const poolSource = source === "BANK" ? "BANK" : "CASH";
    const poolReason = typeof reason === "string" ? reason.trim().slice(0, 500) : "";
    const otp = String(randomInt(100000, 999999));
    const orderId = generateOrderId();
    const now = Date.now();

    // Store hashed OTP
    otpStore.set(orderId, {
      hash: hashOtp(otp),
      amount: amountNum,
      type: requestType,
      source: poolSource,
      reason: poolReason,
      business_id: business_id || null,
      pm_employee_id: pm_employee_id || null,
      createdAt: now,
      expiresAt: now + OTP_EXPIRY_MS,
      used: false,
      attempts: 0,
      ip,
    });

    // Send email to Founder
    const actionLabel = requestType === "request" ? "Money Request FROM Pool" : "Money Submit TO Pool";
    const sourceLabel = poolSource === "BANK" ? "Bank" : "Cash";
    const { error: emailErr } = await resend.emails.send({
      from: "The X Company <onboarding@resend.dev>",
      to: [FOUNDER_EMAIL],
      subject: `Payment Approval Required - ${formatINR(amountNum)} (${sourceLabel})`,
      html: `
        <div style="font-family:'Inter',Arial,sans-serif;max-width:500px;margin:0 auto;padding:32px 24px;border:1px solid #e2e8f0;border-radius:16px;">
          <h2 style="margin:0 0 20px;color:#0f172a;">Payment Confirmation Required</h2>
          <table style="width:100%;border-collapse:collapse;margin-bottom:20px;">
            <tr><td style="padding:8px 0;color:#64748b;">Type</td><td style="padding:8px 0;font-weight:700;">${actionLabel}</td></tr>
            <tr><td style="padding:8px 0;color:#64748b;">Source</td><td style="padding:8px 0;font-weight:700;">${sourceLabel}</td></tr>
            <tr><td style="padding:8px 0;color:#64748b;">Amount</td><td style="padding:8px 0;font-weight:700;font-size:1.3rem;color:#0ea5e9;">${formatINR(amountNum)}</td></tr>${poolReason ? `
            <tr><td style="padding:8px 0;color:#64748b;">Reason</td><td style="padding:8px 0;">${poolReason.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</td></tr>` : ''}
            <tr><td style="padding:8px 0;color:#64748b;">Order ID</td><td style="padding:8px 0;font-family:monospace;">${orderId}</td></tr>
            <tr><td style="padding:8px 0;color:#64748b;">Website</td><td style="padding:8px 0;">The X Company</td></tr>
          </table>
          <div style="background:#f0f9ff;border:2px solid #0ea5e9;border-radius:12px;padding:20px;text-align:center;margin-bottom:20px;">
            <div style="font-size:12px;color:#64748b;margin-bottom:6px;">OTP Code</div>
            <div style="font-size:2.5rem;font-weight:800;letter-spacing:8px;color:#0f172a;">${otp}</div>
          </div>
          <p style="color:#64748b;font-size:13px;margin:0;">Enter this OTP on the website to approve the payment.<br>This OTP will expire in <b>2 minutes</b>.</p>
        </div>
      `,
    });

    if (emailErr) {
      otpStore.delete(orderId);
      return res.status(500).json({ ok: false, error: "Failed to send email: " + (emailErr.message || JSON.stringify(emailErr)) });
    }

    return res.json({
      ok: true,
      order_id: orderId,
      message: "OTP sent to founder's email. Expires in 2 minutes.",
      expires_in: OTP_EXPIRY_MS / 1000,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok: false, error: "Unexpected error" });
  }
});

// POST /verify-otp — PM enters OTP, backend verifies and processes payment
app.post("/verify-otp", async (req, res) => {
  try {
    if (!supabase) return res.status(500).json({ ok: false, error: "Server not configured" });

    const { order_id, code } = req.body || {};

    if (!order_id || typeof order_id !== "string") {
      return res.status(400).json({ ok: false, error: "Order ID required" });
    }
    if (!code || typeof code !== "string" || !/^\d{6}$/.test(code.trim())) {
      return res.status(400).json({ ok: false, error: "Invalid OTP (must be 6 digits)" });
    }

    const entry = otpStore.get(order_id);
    if (!entry) {
      return res.status(400).json({ ok: false, error: "Invalid or expired Order ID. Generate a new OTP." });
    }

    if (Date.now() > entry.expiresAt) {
      otpStore.delete(order_id);
      return res.status(400).json({ ok: false, error: "OTP expired. Generate a new one." });
    }

    if (entry.used) {
      return res.status(400).json({ ok: false, error: "OTP already used. Generate a new one." });
    }

    entry.attempts++;
    if (entry.attempts > MAX_OTP_ATTEMPTS) {
      otpStore.delete(order_id);
      return res.status(400).json({ ok: false, error: "Too many wrong attempts. Generate a new OTP." });
    }

    if (hashOtp(code.trim()) !== entry.hash) {
      const remaining = MAX_OTP_ATTEMPTS - entry.attempts;
      return res.json({ ok: false, error: `Wrong OTP. ${remaining} attempt(s) remaining.` });
    }

    // OTP correct — mark used
    entry.used = true;

    const amountNum = entry.amount;
    const requestType = entry.type;

    // Read current pool
    const { data: poolRows, error: poolErr } = await supabase
      .from("company_money_pool")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(1);

    if (poolErr || !poolRows || !poolRows[0]) {
      return res.status(500).json({ ok: false, error: "Could not read money pool" });
    }

    const latest = poolRows[0];
    const l1 = Number(latest.layer1_amount || 0);
    const l2 = Number(latest.layer2_amount || 0);
    const isCash = entry.source === "CASH";

    if (requestType === "request") {
      const available = isCash ? l1 : l2;
      if (amountNum > available) {
        return res.status(400).json({ ok: false, error: `Pool insufficient. Available (${isCash ? 'Cash' : 'Bank'}): ${formatINR(available)}` });
      }
      const { error: insErr } = await supabase.from("company_money_pool").insert([{
        layer1_amount: isCash ? l1 - amountNum : l1,
        layer2_amount: isCash ? l2 : l2 - amountNum,
      }]);
      if (insErr) return res.status(500).json({ ok: false, error: "Failed to deduct from pool" });
    } else {
      const { error: insErr } = await supabase.from("company_money_pool").insert([{
        layer1_amount: isCash ? l1 + amountNum : l1,
        layer2_amount: isCash ? l2 : l2 + amountNum,
      }]);
      if (insErr) return res.status(500).json({ ok: false, error: "Failed to add to pool" });
    }

    // Log to money_pool_ledger — best effort
    const ledgerReason = entry.reason
      ? entry.reason
      : `PM pool ${requestType} (Email OTP, Order: ${order_id})${entry.business_id ? " - biz:" + entry.business_id : ""}`;
    try {
      await supabase.from("money_pool_ledger").insert([{
        source: entry.source || "CASH",
        type: requestType === "request" ? "MINUS" : "PLUS",
        amount: amountNum,
        from_text: entry.pm_employee_id || null,
        reason: ledgerReason,
      }]);
    } catch (_) {}

    otpStore.delete(order_id);

    return res.json({
      ok: true,
      message: requestType === "request"
        ? `${formatINR(amountNum)} taken from pool successfully`
        : `${formatINR(amountNum)} submitted to pool successfully`,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok: false, error: "Unexpected error" });
  }
});
function normalizePhoneNumbers(value) {
  const raw = String(value || '').trim().replace(/[\s,;]+/g, ' ');
  if (!raw) return '';
  const cleaned = raw.replace(/[^0-9+]/g, '');
  if (!cleaned) return '';
  if (cleaned.startsWith('+')) return cleaned;
  if (cleaned.startsWith('0') && cleaned.length > 1) return cleaned.slice(1);
  return cleaned;
}

app.post('/send-meeting-email', async (req, res) => {
  try {
    if (!resend) {
      return res.status(500).json({ ok: false, error: 'Email service not configured.' });
    }

    const {
      emails,
      title,
      meeting_date,
      meeting_time,
      platform,
      link,
      notes
    } = req.body || {};

    if (!emails) {
      return res.status(400).json({ ok: false, error: 'Email addresses are required.' });
    }

    let emailList = Array.isArray(emails) ? emails : String(emails).split(/[\s,;]+/);
    emailList = emailList.map(email => String(email || '').trim()).filter(Boolean);
    if (!emailList.length) {
      return res.status(400).json({ ok: false, error: 'No valid email addresses were provided.' });
    }

    const messageLines = [
      `Meeting Reminder: ${title || 'No title'}`,
      `Date: ${meeting_date || 'TBD'}`,
      `Time: ${meeting_time || 'TBD'}`,
      `Platform: ${platform || 'N/A'}`,
    ];
    if (link) messageLines.push(`Link: ${link}`);
    if (notes) messageLines.push(`Notes: ${notes}`);

    const emailBody = messageLines.join('\n\n');

    try {
      const { error: emailErr } = await resend.emails.send({
        from: SEND_EMAIL_FROM,
        to: emailList,
        subject: `Meeting Reminder: ${title || 'Meeting'}`,
        html: `
          <div style="font-family:'Inter',Arial,sans-serif;max-width:600px;margin:0 auto;padding:32px 24px;border:1px solid #e2e8f0;border-radius:16px;">
            <h2 style="margin:0 0 20px;color:#0f172a;">Meeting Reminder</h2>
            <div style="background:#f8fafc;border-radius:12px;padding:20px;margin-bottom:20px;">
              <h3 style="margin:0 0 16px;color:#1e293b;">${title || 'Meeting'}</h3>
              <table style="width:100%;border-collapse:collapse;">
                <tr><td style="padding:8px 0;color:#64748b;font-weight:500;">Date</td><td style="padding:8px 0;">${meeting_date || 'TBD'}</td></tr>
                <tr><td style="padding:8px 0;color:#64748b;font-weight:500;">Time</td><td style="padding:8px 0;">${meeting_time || 'TBD'}</td></tr>
                <tr><td style="padding:8px 0;color:#64748b;font-weight:500;">Platform</td><td style="padding:8px 0;">${platform || 'N/A'}</td></tr>${link ? `
                <tr><td style="padding:8px 0;color:#64748b;font-weight:500;">Link</td><td style="padding:8px 0;"><a href="${link}" style="color:#0ea5e9;text-decoration:underline;">${link}</a></td></tr>` : ''}${notes ? `
                <tr><td style="padding:8px 0;color:#64748b;font-weight:500;">Notes</td><td style="padding:8px 0;">${notes.replace(/\n/g, '<br>')}</td></tr>` : ''}
              </table>
            </div>
            <p style="color:#64748b;font-size:14px;margin:0;">This is an automated meeting reminder from The X Company.</p>
          </div>
        `,
      });

      if (emailErr) {
        console.error('Meeting email send failed', emailErr);
        // Check if it's a domain verification issue
        const errorMessage = emailErr.message || String(emailErr);
        if (errorMessage && errorMessage.includes('verify a domain')) {
          return res.status(500).json({
            ok: false,
            error: 'Email sending requires domain verification. Please verify a domain at resend.com/domains and update the from address.',
            details: errorMessage
          });
        }
        return res.status(500).json({ ok: false, error: 'Failed to send email notification.', details: errorMessage });
      }

      return res.json({ ok: true, message: 'Meeting email sent successfully' });
    } catch (emailErr) {
      console.error('Meeting email send failed', emailErr);
      // Check if it's a domain verification issue
      const errorMessage = emailErr.message || String(emailErr);
      if (errorMessage && errorMessage.includes('verify a domain')) {
        return res.status(500).json({
          ok: false,
          error: 'Email sending requires domain verification. Please verify a domain at resend.com/domains and update the from address.',
          details: errorMessage
        });
      }
      return res.status(500).json({ ok: false, error: 'Failed to send email notification.', details: errorMessage });
    }
  } catch (error) {
    console.error('Meeting email send failed', error);
    return res.status(500).json({ ok: false, error: 'Failed to send email notification.' });
  }
});

/* ================= ANONYMOUS MEETING SCORES ================= */

// Generate a random anonymous ID for the person submitting the score
function generateAnonymousId() {
  const rand = randomInt(0, 0xffffff).toString(16).padStart(6, '0');
  const ts = Date.now().toString(36).slice(-4);
  return `anon_${ts}${rand}`.toLowerCase();
}

// POST /api/meeting-scores - Submit an anonymous score for a meeting
// Completely private - no user identification stored
app.post('/api/meeting-scores', async (req, res) => {
  try {
    if (!supabase) {
      return res.status(500).json({ ok: false, error: 'Database not configured' });
    }

    const { meeting_id, score } = req.body || {};

    if (!meeting_id) {
      return res.status(400).json({ ok: false, error: 'Meeting ID is required' });
    }

    if (!score || typeof score !== 'string') {
      return res.status(400).json({ ok: false, error: 'Valid score is required' });
    }

    // Validate score is one of the allowed values
    const validScores = ['poor', 'bad', 'good', 'excellent'];
    if (!validScores.includes(score.toLowerCase())) {
      return res.status(400).json({ ok: false, error: 'Invalid score. Must be: poor, bad, good, or excellent' });
    }

    // Verify the meeting exists
    const { data: meeting, error: meetingErr } = await supabase
      .from('dce_meetings')
      .select('id')
      .eq('id', meeting_id)
      .single();

    if (meetingErr || !meeting) {
      return res.status(404).json({ ok: false, error: 'Meeting not found' });
    }

    // Generate anonymous ID and insert score
    const anonymousId = generateAnonymousId();
    const { error: insertErr } = await supabase
      .from('dce_meeting_scores')
      .insert([{
        meeting_id,
        anonymous_id: anonymousId,
        score: score.toLowerCase(),
        submitted_at: new Date().toISOString()
      }]);

    if (insertErr) {
      console.error('Failed to insert meeting score:', insertErr);
      return res.status(500).json({ ok: false, error: 'Failed to submit score' });
    }

    return res.json({
      ok: true,
      message: 'Score submitted anonymously',
      anonymous_id: anonymousId
    });
  } catch (e) {
    console.error('Meeting score submission error:', e);
    return res.status(500).json({ ok: false, error: 'Unexpected error submitting score' });
  }
});

// GET /api/meeting-scores/:meeting_id - Get anonymized score statistics
// Returns only aggregated counts, never individual scores
app.get('/api/meeting-scores/:meeting_id', async (req, res) => {
  try {
    if (!supabase) {
      return res.status(500).json({ ok: false, error: 'Database not configured' });
    }

    const { meeting_id } = req.params;

    if (!meeting_id) {
      return res.status(400).json({ ok: false, error: 'Meeting ID is required' });
    }

    // Get all scores for the meeting
    const { data: scores, error: scoresErr } = await supabase
      .from('dce_meeting_scores')
      .select('score')
      .eq('meeting_id', meeting_id);

    if (scoresErr) {
      console.error('Failed to fetch meeting scores:', scoresErr);
      return res.status(500).json({ ok: false, error: 'Failed to fetch scores' });
    }

    // Aggregate scores - no individual identifiers returned
    const scoreCounts = {
      poor: 0,
      bad: 0,
      good: 0,
      excellent: 0
    };

    (scores || []).forEach(scoreEntry => {
      const scoreValue = scoreEntry.score.toLowerCase();
      if (scoreCounts.hasOwnProperty(scoreValue)) {
        scoreCounts[scoreValue]++;
      }
    });

    const total = Object.values(scoreCounts).reduce((sum, count) => sum + count, 0);

    return res.json({
      ok: true,
      meeting_id,
      total_responses: total,
      scores: scoreCounts,
      percentages: total > 0 ? {
        poor: Math.round((scoreCounts.poor / total) * 100),
        bad: Math.round((scoreCounts.bad / total) * 100),
        good: Math.round((scoreCounts.good / total) * 100),
        excellent: Math.round((scoreCounts.excellent / total) * 100)
      } : {
        poor: 0,
        bad: 0,
        good: 0,
        excellent: 0
      }
    });
  } catch (e) {
    console.error('Meeting score fetch error:', e);
    return res.status(500).json({ ok: false, error: 'Unexpected error fetching scores' });
  }
});

app.listen(port, () => {
  console.log(`Backend running on port ${port}`);
});
