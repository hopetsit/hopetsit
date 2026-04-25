// POST /api/contact — receives the website's contact-form payload and forwards
// it to contact@hopetsit.com via Resend (https://resend.com).
//
// Required env vars on Vercel:
//   RESEND_API_KEY        — server-side, NOT public. Get one at https://resend.com.
//   CONTACT_TO            — recipient (default: contact@hopetsit.com)
//   CONTACT_FROM          — sender. Until the domain is verified at Resend, use
//                           "HoPetSit <onboarding@resend.dev>". After verifying
//                           hopetsit.com on Resend, switch to a real address like
//                           "HoPetSit <noreply@hopetsit.com>".
//
// This route runs on the Edge runtime to keep cold starts low.

export const runtime = "edge";

type Body = {
  name?: string;
  email?: string;
  message?: string;
};

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

export async function POST(req: Request) {
  let body: Body;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const name    = (body.name    ?? "").toString().trim();
  const email   = (body.email   ?? "").toString().trim();
  const message = (body.message ?? "").toString().trim();

  if (!name || !email || !message) {
    return Response.json({ error: "Missing required fields" }, { status: 400 });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return Response.json({ error: "Invalid email" }, { status: 400 });
  }
  if (message.length > 5000) {
    return Response.json({ error: "Message too long" }, { status: 400 });
  }

  const RESEND_API_KEY = process.env.RESEND_API_KEY;
  const TO   = process.env.CONTACT_TO   || "contact@hopetsit.com";
  const FROM = process.env.CONTACT_FROM || "HoPetSit Contact <onboarding@resend.dev>";

  if (!RESEND_API_KEY) {
    // Don't leak config errors to the user — but log so the operator notices.
    console.error("[contact] RESEND_API_KEY env var is missing — email not sent.");
    return Response.json(
      { error: "Email service is temporarily unavailable. Please email contact@hopetsit.com directly." },
      { status: 503 },
    );
  }

  const subject = `New contact form message from ${name}`;
  const html = `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width:560px; margin:0 auto; padding:24px;">
      <h2 style="color:#EF4324; margin:0 0 16px 0;">New message from hopetsit.com</h2>
      <table style="border-collapse:collapse; width:100%; font-size:14px; color:#1F2937;">
        <tr><td style="padding:8px 0; font-weight:600; width:90px;">From:</td><td>${escapeHtml(name)}</td></tr>
        <tr><td style="padding:8px 0; font-weight:600;">Email:</td><td><a href="mailto:${escapeHtml(email)}" style="color:#1A73E8;">${escapeHtml(email)}</a></td></tr>
      </table>
      <h3 style="margin:24px 0 8px 0; color:#1F2937;">Message</h3>
      <div style="padding:16px; background:#F9FAFB; border-radius:12px; white-space:pre-wrap; color:#1F2937;">${escapeHtml(message)}</div>
      <p style="margin-top:24px; font-size:12px; color:#6B7280;">
        Reply directly to this email to answer ${escapeHtml(name)}.
      </p>
    </div>
  `.trim();

  const text = `New contact form message from ${name}

From: ${name}
Email: ${email}

Message:
${message}

---
Reply to ${email} to answer.
`;

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type":  "application/json",
      },
      body: JSON.stringify({
        from:     FROM,
        to:       [TO],
        reply_to: email,
        subject,
        html,
        text,
      }),
    });

    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      console.error("[contact] Resend error", res.status, errText);
      return Response.json(
        { error: "Failed to send the message. Please try again or email contact@hopetsit.com directly." },
        { status: 502 },
      );
    }
    return Response.json({ ok: true });
  } catch (e) {
    console.error("[contact] Network error", e);
    return Response.json(
      { error: "Failed to send the message. Please try again." },
      { status: 502 },
    );
  }
}
