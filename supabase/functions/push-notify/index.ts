// Push fan-out for Circle. Invoked by Supabase Database Webhooks on INSERT into
// public.messages and public.matches. Resolves the recipient(s), looks up their
// APNs device tokens, and sends an alert push signed with an ES256 APNs token.
//
// Auth: verify_jwt = false; authenticated by a shared secret header
// (x-webhook-secret == PUSH_WEBHOOK_SECRET) set on the webhook.
//
// Required secrets:
//   PUSH_WEBHOOK_SECRET  – shared secret you also put on the DB webhook header
//   APNS_KEY_P8          – contents of your APNs .p8 auth key (PEM)
//   APNS_KEY_ID          – the key's Key ID
//   APNS_TEAM_ID         – your Apple Developer Team ID
//   APNS_BUNDLE_ID       – com.circlein.app
//   APNS_ENV             – "sandbox" (dev/TestFlight builds) or "production"
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected automatically.

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const webhookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
const keyId = Deno.env.get("APNS_KEY_ID") ?? "";
const teamId = Deno.env.get("APNS_TEAM_ID") ?? "";
const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "";
const apnsHost = (Deno.env.get("APNS_ENV") ?? "sandbox") === "production"
  ? "https://api.push.apple.com"
  : "https://api.sandbox.push.apple.com";

// ---- APNs auth token (ES256 JWT) -------------------------------------------

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

let cachedToken: { jwt: string; at: number } | null = null;

async function apnsToken(): Promise<string> {
  // APNs allows reusing a token; refresh at most every ~50 min.
  if (cachedToken && Date.now() - cachedToken.at < 50 * 60 * 1000) return cachedToken.jwt;

  const pem = (Deno.env.get("APNS_KEY_P8") ?? "")
    .replaceAll("-----BEGIN PRIVATE KEY-----", "")
    .replaceAll("-----END PRIVATE KEY-----", "")
    .replace(/[^A-Za-z0-9+/=]/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );

  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const claims = b64url(new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) })));
  const signingInput = `${header}.${claims}`;
  const sig = new Uint8Array(await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput),
  ));
  const jwt = `${signingInput}.${b64url(sig)}`;
  cachedToken = { jwt, at: Date.now() };
  return jwt;
}

async function sendAPNs(token: string, title: string, body: string, extra: Record<string, unknown> = {}) {
  const jwt = await apnsToken();
  const res = await fetch(`${apnsHost}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: JSON.stringify({
      aps: { alert: { title, body }, sound: "default", badge: 1 },
      ...extra,
    }),
  });
  if (res.status === 410 || res.status === 400) {
    // Unregistered / bad token — clean it up so we stop trying.
    await supabase.from("device_tokens").delete().eq("token", token);
  }
}

async function notifyUser(userId: string, title: string, body: string, extra: Record<string, unknown> = {}) {
  const { data: tokens } = await supabase.from("device_tokens").select("token").eq("user_id", userId);
  if (!tokens?.length) return;
  await Promise.all(tokens.map((t) => sendAPNs(t.token, title, body, extra).catch(() => {})));
}

async function displayName(userId: string): Promise<string> {
  const { data } = await supabase.from("profiles").select("name").eq("id", userId).single();
  const n = (data?.name ?? "").trim();
  return n.length ? n : "Someone";
}

// ---- Webhook entrypoint -----------------------------------------------------

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== webhookSecret) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }

  const payload = await req.json();
  const table = payload.table as string;
  const record = payload.record ?? {};

  try {
    if (table === "messages") {
      const { data: match } = await supabase.from("matches")
        .select("user_a, user_b").eq("id", record.match_id).single();
      if (match) {
        const recipient = match.user_a === record.sender_id ? match.user_b : match.user_a;
        const name = await displayName(record.sender_id);
        const preview = String(record.body ?? "").slice(0, 140);
        await notifyUser(recipient, name, preview, { matchId: record.match_id });
      }
    } else if (table === "matches") {
      const [nameA, nameB] = await Promise.all([displayName(record.user_a), displayName(record.user_b)]);
      await Promise.all([
        notifyUser(record.user_a, "You have a new friend on Circle", `You and ${nameB} matched — say hello!`, { matchId: record.id }),
        notifyUser(record.user_b, "You have a new friend on Circle", `You and ${nameA} matched — say hello!`, { matchId: record.id }),
      ]);
    }
  } catch (err) {
    console.error("push-notify error:", err);
    return new Response(JSON.stringify({ error: "failed" }), { status: 500 });
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
});
