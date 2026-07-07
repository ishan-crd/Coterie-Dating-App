// Supabase "Send Email Hook" → renders a branded Circle email and sends it
// through the Resend API. OTP generation & verification stay in Supabase Auth;
// this function only owns delivery + design.
//
// Auth: called by Supabase Auth (no user JWT), authenticated via the
// Standard Webhooks signature using SEND_EMAIL_HOOK_SECRET. Deploy with
// verify_jwt = false.
//
// Required secrets (set with `supabase secrets set ...`):
//   RESEND_API_KEY          – your Resend API key
//   SEND_EMAIL_HOOK_SECRET  – the signing secret Supabase shows when you
//                             create the hook (format: v1,whsec_...)
//   AUTH_EMAIL_FROM         – verified sender, e.g. "Circle <hello@yourdomain.com>"

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import { Resend } from "https://esm.sh/resend@4.0.1";

const resend = new Resend(Deno.env.get("RESEND_API_KEY"));
const hookSecret = Deno.env.get("SEND_EMAIL_HOOK_SECRET") ?? "";
const fromAddress = Deno.env.get("AUTH_EMAIL_FROM") ?? "Circle <onboarding@resend.dev>";

interface EmailData {
  token: string;
  token_hash: string;
  redirect_to: string;
  email_action_type: string;
  site_url: string;
}

/** Copy tuned per auth action; all funnel to the same 6-digit-code layout. */
function copyFor(action: string): { subjectVerb: string; lead: string } {
  switch (action) {
    case "signup":
      return { subjectVerb: "Confirm your email", lead: "Welcome to Circle. Use this code to confirm your email and start finding your people." };
    case "recovery":
      return { subjectVerb: "Reset your access", lead: "Use this code to get back into your Circle account." };
    case "email_change":
      return { subjectVerb: "Confirm your new email", lead: "Use this code to confirm your new email address." };
    default: // magiclink / otp sign-in
      return { subjectVerb: "Your sign-in code", lead: "Use this code to sign in to Circle. It expires in a few minutes." };
  }
}

function renderEmail(token: string, lead: string): string {
  // Brand font stacks — the app pairs Cormorant Garamond (serif display) with
  // Hanken Grotesk (body). Loaded as webfonts below; graceful fallbacks for
  // clients that strip them (Gmail → Georgia / system sans).
  const serif = "'Cormorant Garamond', Georgia, 'Times New Roman', serif";
  const grotesk = "'Hanken Grotesk', -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif";
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light only">
  <meta name="supported-color-schemes" content="light">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@500;600&family=Hanken+Grotesk:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@500;600&family=Hanken+Grotesk:wght@400;500;600&display=swap');
    body { margin:0; padding:0; -webkit-font-smoothing:antialiased; }
  </style>
</head>
<body style="margin:0; padding:0; background-color:#FBFAF8;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#FBFAF8; padding:44px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:452px; background-color:#FFFFFF; border-radius:24px; overflow:hidden; border:1px solid rgba(11,11,11,0.08); box-shadow:0 12px 36px rgba(11,11,11,0.05);">
          <!-- Wordmark -->
          <tr>
            <td style="padding:42px 40px 0 40px;" align="center">
              <div style="font-family:${serif}; font-size:36px; font-weight:600; color:#0B0B0B; letter-spacing:0.4px; line-height:1;">Circle</div>
              <div style="height:2px; width:32px; background-color:#E0674A; margin:16px auto 0 auto; border-radius:2px;"></div>
            </td>
          </tr>
          <!-- Eyebrow -->
          <tr>
            <td style="padding:26px 44px 0 44px;" align="center">
              <div style="font-family:${grotesk}; font-size:11px; font-weight:600; letter-spacing:2.4px; text-transform:uppercase; color:#9A9792;">Verification Code</div>
            </td>
          </tr>
          <!-- Lead -->
          <tr>
            <td style="padding:14px 46px 0 46px;" align="center">
              <p style="margin:0; font-family:${grotesk}; font-size:15px; font-weight:400; line-height:1.6; color:#56534E;">${lead}</p>
            </td>
          </tr>
          <!-- Code -->
          <tr>
            <td style="padding:30px 40px 6px 40px;" align="center">
              <div style="background-color:#FBEDE9; border:1px solid #F3D5CD; border-radius:16px; padding:22px 30px;">
                <span style="font-family:${serif}; font-size:52px; font-weight:600; letter-spacing:12px; color:#C4553A; line-height:1; padding-left:12px; font-variant-numeric:lining-nums; font-feature-settings:'lnum' 1;">${token}</span>
              </div>
            </td>
          </tr>
          <!-- Fine print -->
          <tr>
            <td style="padding:22px 46px 0 46px;" align="center">
              <p style="margin:0; font-family:${grotesk}; font-size:12.5px; font-weight:400; line-height:1.55; color:#9A9792;">
                If you didn't request this, you can safely ignore this email — nothing will change.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="padding:28px 40px 36px 40px;" align="center">
              <div style="height:1px; background-color:rgba(11,11,11,0.06); margin-bottom:18px;"></div>
              <p style="margin:0; font-family:${serif}; font-style:italic; font-size:14px; color:#B6B3AE; letter-spacing:0.2px;">
                Find friends who share your world.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const payload = await req.text();
  const headers = Object.fromEntries(req.headers);

  let user: { email: string };
  let email_data: EmailData;
  try {
    // Standard Webhooks verification. Supabase stores the secret as
    // "v1,whsec_<base64>"; the library wants the base64 portion.
    const wh = new Webhook(hookSecret.replace(/^v1,whsec_/, ""));
    const verified = wh.verify(payload, headers) as {
      user: { email: string };
      email_data: EmailData;
    };
    user = verified.user;
    email_data = verified.email_data;
  } catch (err) {
    console.error("Webhook verification failed:", err);
    return new Response(JSON.stringify({ error: "Invalid signature" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { subjectVerb, lead } = copyFor(email_data.email_action_type);
  const subject = `${email_data.token} is your Circle code`;

  const { error } = await resend.emails.send({
    from: fromAddress,
    to: [user.email],
    subject,
    html: renderEmail(email_data.token, lead),
    text: `${subjectVerb}\n\nYour Circle code is ${email_data.token}.\nIt expires in a few minutes.\n\nIf you didn't request this, ignore this email.\n\nCircle · Find friends who share your world`,
  });

  if (error) {
    console.error("Resend error:", error);
    return new Response(JSON.stringify({ error: "Failed to send email" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
