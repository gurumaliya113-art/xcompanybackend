import "dotenv/config";

import { createClient } from "@supabase/supabase-js";

function getArg(name) {
  const prefix = `--${name}=`;
  const hit = process.argv.find((a) => a.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : null;
}

function hasFlag(name) {
  return process.argv.includes(`--${name}`);
}

function required(label, value) {
  if (!value) throw new Error(`Missing ${label}`);
  return value;
}

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

required("SUPABASE_URL", supabaseUrl);
required("SUPABASE_SERVICE_KEY", supabaseServiceKey);

const sb = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

const deleteOld = hasFlag("delete-old") || process.env.DELETE_OLD === "1";

const founderEmail = getArg("founder-email") || process.env.FOUNDER_EMAIL;
const founderPassword = getArg("founder-pass") || process.env.FOUNDER_PASSWORD;
const founderName = getArg("founder-name") || process.env.FOUNDER_NAME || "Founder";

const hrEmail = getArg("hr-email") || process.env.HR_EMAIL;
const hrPassword = getArg("hr-pass") || process.env.HR_PASSWORD;
const hrName = getArg("hr-name") || process.env.HR_NAME || "HR";

if (!founderEmail || !founderPassword || !hrEmail || !hrPassword) {
  console.log(
    [
      "Usage:",
      "  npm run seed:admins -- \\",
      "    --delete-old \\",
      "    --founder-email=founder@x.com --founder-pass=Password123! --founder-name=Founder \\",
      "    --hr-email=hr@x.com --hr-pass=Password123! --hr-name=HR",
      "",
      "Or use env vars: FOUNDER_EMAIL, FOUNDER_PASSWORD, HR_EMAIL, HR_PASSWORD (optional: DELETE_OLD=1)",
    ].join("\n")
  );
  process.exit(1);
}

async function findAuthUserByEmail(email) {
  let page = 1;
  const perPage = 1000;
  // Supabase Admin API does not provide a direct get-by-email in all setups.
  // Listing is acceptable here since we're seeding a small number of users.
  for (;;) {
    const { data, error } = await sb.auth.admin.listUsers({ page, perPage });
    if (error) throw error;
    const users = data?.users || [];
    const hit = users.find((u) => (u.email || "").toLowerCase() === email.toLowerCase());
    if (hit) return hit;
    if (users.length < perPage) return null;
    page += 1;
  }
}

async function deleteEmployeeRow({ userId, email }) {
  // Be resilient to schema differences.
  // Try delete-by-id first; then delete-by-email if the column exists.
  if (userId) {
    await sb.from("employees").delete().eq("id", userId);
  }
  if (email) {
    const res = await sb.from("employees").delete().eq("email", email);
    // Ignore missing-column errors here.
    if (res.error && !/column .*email/i.test(res.error.message || "")) {
      throw res.error;
    }
  }
}

async function ensureEmployeeRow({ userId, email, name, role }) {
  const candidates = [
    { id: userId, email, name, role, active: true },
    { id: userId, email, role, active: true },
    { id: userId, email, role },
    { id: userId, name, role },
    { id: userId, role },
  ];

  let lastError = null;
  for (const payload of candidates) {
    const { error } = await sb.from("employees").upsert([payload], { onConflict: "id" });
    if (!error) return;
    lastError = error;
    // Retry with a smaller payload if the schema doesn't match.
    if (/column .* does not exist|invalid input syntax|violates not-null constraint/i.test(error.message || "")) {
      continue;
    }
    // If it's something else (permissions, etc.), fail fast.
    throw error;
  }
  throw lastError || new Error("Failed to upsert employees row");
}

async function createOrReplaceUser({ email, password, name, role }) {
  if (deleteOld) {
    const existing = await findAuthUserByEmail(email);
    if (existing) {
      await deleteEmployeeRow({ userId: existing.id, email });
      const delRes = await sb.auth.admin.deleteUser(existing.id);
      if (delRes.error) throw delRes.error;
    } else {
      await deleteEmployeeRow({ userId: null, email });
    }
  }

  let user = await findAuthUserByEmail(email);

  if (!user) {
    const { data, error } = await sb.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name, role },
    });
    if (error) throw error;
    user = data.user;
  } else {
    // Ensure password is what you expect.
    const { data, error } = await sb.auth.admin.updateUserById(user.id, {
      password,
      user_metadata: { ...(user.user_metadata || {}), name, role },
    });
    if (error) throw error;
    user = data.user;
  }

  await ensureEmployeeRow({ userId: user.id, email, name, role });
  return user.id;
}

try {
  const founderId = await createOrReplaceUser({
    email: founderEmail,
    password: founderPassword,
    name: founderName,
    role: "FOUNDER",
  });

  const hrId = await createOrReplaceUser({
    email: hrEmail,
    password: hrPassword,
    name: hrName,
    role: "HR",
  });

  console.log("Seeded users:");
  console.log(`- Founder: ${founderEmail} (id: ${founderId})`);
  console.log(`- HR: ${hrEmail} (id: ${hrId})`);
  console.log("Now sign in via frontend/dashboard.html");
} catch (e) {
  console.error("Seeding failed:", e?.message || e);
  process.exit(1);
}
