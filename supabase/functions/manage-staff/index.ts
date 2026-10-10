// manage-staff: the only way accounts are created or changed.
//
// There is no email signup. A senior creates logins for people below them:
//   - admins can manage anyone in their hospital
//   - everyone else can only manage roles ranked below their own
//   - viewers manage no one
//
// Each person logs in with a username and PIN. Supabase needs an email, so we
// use a made-up one: <username>@wardmap.local. Nobody ever sees it.
//
// Actions (POST JSON body):
//   { "action": "create", "username", "full_name", "role", "pin" }
//   { "action": "reset_pin", "staff_id", "pin" }
//   { "action": "set_active", "staff_id", "active": true|false }
//   { "action": "add_hospital", "setup_key", "hospital_name", "username", "full_name", "pin" }
//       Creates a hospital and its first admin. Needs the SETUP_KEY secret,
//       which only whoever runs the Supabase project knows. Used for the
//       first hospital and for every hospital added later. ("setup" is the
//       older name for the same action.)
//
// See docs/roles-and-access.md.

import { createClient } from "npm:@supabase/supabase-js@2";

const RANK: Record<string, number> = {
  admin: 100, consultant: 90,
  r6: 60, r5: 50, r4: 40, r3: 30, r2: 20, r1: 10,
  rotator: 5, viewer: 0,
};

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

const emailFor = (username: string) => `${username}@wardmap.local`;
const validUsername = (u: string) => /^[a-z0-9._-]{3,32}$/.test(u ?? "");
const validPin = (p: string) => /^\d{6,12}$/.test(p ?? "");

// The service-role client bypasses the database access rules, so every
// permission check happens here before it is used. Because it is not the
// caller, logAction() adds a history entry naming who actually did it.
const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return reply(200, {});
  const body = await req.json().catch(() => ({}));

  if (body.action === "add_hospital" || body.action === "setup") return addHospital(body);

  // Who is calling?
  const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  const { data: auth } = await admin.auth.getUser(token);
  if (!auth?.user) return reply(401, { error: "Please log in" });

  const { data: me } = await admin.from("staff").select("*")
    .eq("id", auth.user.id).eq("is_active", true).single();
  if (!me) return reply(403, { error: "Account not active" });

  const canManage = (role: string) =>
    role in RANK && (me.role === "admin" || RANK[role] < RANK[me.role]);

  if (body.action === "create") {
    const { username, full_name, role, pin } = body;
    if (!validUsername(username)) return reply(400, { error: "Username: 3-32 lowercase letters, numbers, . _ -" });
    if (!full_name) return reply(400, { error: "Full name is required" });
    if (!validPin(pin)) return reply(400, { error: "PIN must be 6-12 digits" });
    if (!canManage(role)) return reply(403, { error: "You can only create accounts junior to you" });

    const { data: created, error } = await admin.auth.admin.createUser({
      email: emailFor(username), password: pin, email_confirm: true,
    });
    if (error) return reply(400, { error: "That username is taken" });

    const { error: insertError } = await admin.from("staff").insert({
      id: created.user.id, hospital_id: me.hospital_id,
      username, full_name, role, created_by: me.id,
    });
    if (insertError) {
      await admin.auth.admin.deleteUser(created.user.id);
      return reply(400, { error: insertError.message });
    }
    await logAction(me, "create_account", created.user.id, { username, role });
    return reply(200, { id: created.user.id });
  }

  if (body.action === "reset_pin" || body.action === "set_active") {
    const { data: target } = await admin.from("staff").select("*")
      .eq("id", body.staff_id).eq("hospital_id", me.hospital_id).single();
    if (!target || !canManage(target.role)) {
      return reply(403, { error: "You can only manage accounts junior to you" });
    }

    if (body.action === "reset_pin") {
      if (!validPin(body.pin)) return reply(400, { error: "PIN must be 6-12 digits" });
      await admin.auth.admin.updateUserById(target.id, { password: body.pin });
      await logAction(me, "reset_pin", target.id, {});
    } else {
      const active = body.active === true;
      await admin.from("staff").update({ is_active: active }).eq("id", target.id);
      // A deactivated account is also signed out and blocked from logging in.
      await admin.auth.admin.updateUserById(target.id, { ban_duration: active ? "none" : "876000h" });
      await logAction(me, active ? "activate_account" : "deactivate_account", target.id, {});
    }
    return reply(200, { ok: true });
  }

  return reply(400, { error: "Unknown action" });
});

// PIN resets and account creation are recorded in the change history too.
// The PIN itself is never stored in the history.
async function logAction(me: { id: string; hospital_id: string }, what: string, staffId: string, details: object) {
  await admin.from("audit_log").insert({
    actor_id: me.id, hospital_id: me.hospital_id, table_name: "accounts",
    row_id: staffId, action: "update", new_data: { event: what, ...details },
  });
}

async function addHospital(body: Record<string, string>) {
  const key = Deno.env.get("SETUP_KEY");
  if (!key || body.setup_key !== key) return reply(403, { error: "Wrong setup key" });

  const { hospital_name, username, full_name, pin } = body;
  if (!hospital_name || !full_name || !validUsername(username) || !validPin(pin)) {
    return reply(400, { error: "hospital_name, username, full_name and a 6-12 digit pin are required" });
  }

  // Create the login first, so a taken username doesn't leave an empty hospital.
  const { data: created, error } = await admin.auth.admin.createUser({
    email: emailFor(username), password: pin, email_confirm: true,
  });
  if (error) return reply(400, { error: "That username is taken" });

  const { data: hospital } = await admin.from("hospitals").insert({ name: hospital_name }).select().single();
  const { error: staffError } = hospital
    ? await admin.from("staff").insert({
      id: created.user.id, hospital_id: hospital.id, username, full_name, role: "admin",
    })
    : { error: true };
  if (staffError) {
    await admin.auth.admin.deleteUser(created.user.id);
    if (hospital) await admin.from("hospitals").delete().eq("id", hospital.id);
    return reply(400, { error: "Could not create the hospital" });
  }
  return reply(200, { hospital_id: hospital!.id, admin_id: created.user.id });
}
