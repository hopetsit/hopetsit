/**
 * Airwallex Bridge + Debug Routes — v23.1 part 57.
 *
 * Replaces the opaque external bridge `hopetsit.com/pay` with an HTML page
 * we serve ourselves from Render. This lets us :
 *   1. Control 100% of the Airwallex.js call site (so saved-card display,
 *      country, env, payment_consent flags etc. are exactly what we want).
 *   2. Iterate without redeploying the public website (Wix/Vercel etc.).
 *   3. Verify in Render logs which params the page received.
 *
 * Also exposes a `/airwallex/customer-debug` endpoint that returns the
 * authenticated user's Airwallex customer state — useful when diagnosing
 * "why doesn't HPP show my saved card" without guessing.
 *
 * Mounted at `/api/v1/airwallex` in app.js.
 */
const express = require('express');
const { requireAuth } = require('../middleware/auth');
const airwallex = require('../services/airwallexService');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('../utils/logger');

const router = express.Router();

const _roleModel = (role) =>
  role === 'sitter' ? Sitter :
  role === 'owner' ? Owner :
  role === 'walker' ? Walker :
  null;

// ─── Self-hosted bridge HTML page ────────────────────────────────────────────
//
// The Flutter WebView opens this URL with query params :
//   ?intent=...&secret=...&currency=EUR&country=FR&env=prod
// The page loads Airwallex.js, awaits SDK ready, then calls
// `payments.redirectToCheckout(...)`. Airwallex's HPP then auto-displays the
// saved cards belonging to the customer attached on the PaymentIntent.
//
// On payment outcome Airwallex redirects to :
//   /api/v1/airwallex/checkout/done?status=success|cancel|fail
// — the WebView's NavigationDelegate detects this URL and resolves.
//
// This route is PUBLIC (no auth) because Airwallex.js needs to be served
// to a browser context that won't carry the user's JWT in headers ; the
// security comes from the unguessable `client_secret` query param, exactly
// like the previous external bridge.
router.get('/checkout', (req, res) => {
  const intent = String(req.query.intent || '').trim();
  const secret = String(req.query.secret || '').trim();
  const currency = String(req.query.currency || 'EUR').toUpperCase();
  const country = String(req.query.country || 'FR').toUpperCase();
  const env = String(req.query.env || 'prod').toLowerCase() === 'demo' ? 'demo' : 'prod';

  if (!intent || !secret) {
    return res.status(400).type('html').send(
      '<!doctype html><meta charset=utf-8><title>HoPetSit</title>' +
      '<body style="font-family:sans-serif;text-align:center;padding:40px">' +
      '<h2>⚠️ Paiement invalide</h2>' +
      '<p>Les paramètres requis sont manquants. Reviens à l\'app.</p>' +
      '</body>',
    );
  }

  logger.info(
    `[airwallex.bridge] checkout requested intent=${intent} env=${env} ` +
    `currency=${currency} country=${country}`,
  );

  const successUrl = `${req.protocol}://${req.get('host')}/api/v1/airwallex/checkout/done?status=success`;
  const cancelUrl = `${req.protocol}://${req.get('host')}/api/v1/airwallex/checkout/done?status=cancel`;
  const failUrl = `${req.protocol}://${req.get('host')}/api/v1/airwallex/checkout/done?status=fail`;

  // The components-sdk auto-discovers the customer and saved cards from the
  // PaymentIntent's `customer_id` server-side. We just call redirectToCheckout
  // with the standard params — Airwallex does the rest.
  const html = `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>HoPetSit · Paiement sécurisé</title>
<style>
  body { font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif;
         margin: 0; padding: 0; background: #fff; color: #1f1f1f;
         min-height: 100vh; display: flex; align-items: center;
         justify-content: center; flex-direction: column; }
  .lock { width: 80px; height: 80px; border-radius: 50%;
          background: #FEEEEA; display: flex; align-items: center;
          justify-content: center; margin-bottom: 24px; font-size: 36px; }
  .spinner { width: 28px; height: 28px; border: 3px solid #f3f3f3;
             border-top: 3px solid #EF4324; border-radius: 50%;
             animation: spin 1s linear infinite; margin: 16px 0; }
  @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
  .title { font-size: 18px; font-weight: 700; }
  .amount { font-size: 22px; font-weight: 700; color: #EF4324; margin-top: 4px; }
  .hint { font-size: 12px; color: #777; margin-top: 16px; max-width: 320px;
          padding: 0 16px; text-align: center; line-height: 1.4; }
  .err { color: #C62828; font-weight: 700; }
</style>
</head>
<body>
  <div class="lock">🔒</div>
  <div class="title">Connexion sécurisée…</div>
  <div class="spinner"></div>
  <div class="hint">Le paiement est traité par Airwallex (PCI-DSS Level 1).
  Vos données carte ne transitent jamais par HoPetSit.</div>
  <div id="error" class="hint err" style="display:none"></div>

  <script type="module">
    import { init } from 'https://static.airwallex.com/components/v1/index.js';

    const errorEl = document.getElementById('error');
    function fail(msg) {
      console.error('[bridge] error:', msg);
      errorEl.textContent = '⚠️ ' + msg;
      errorEl.style.display = 'block';
      // Redirect to fail URL after 1.5s so the WebView resolves.
      setTimeout(() => { window.location.href = ${JSON.stringify(failUrl)}; }, 1500);
    }

    try {
      const { payments } = await init({
        env: ${JSON.stringify(env)},
        enabledElements: ['payments'],
      });
      console.log('[bridge] sdk init ok, redirecting to checkout');
      payments.redirectToCheckout({
        intent_id: ${JSON.stringify(intent)},
        client_secret: ${JSON.stringify(secret)},
        currency: ${JSON.stringify(currency)},
        country_code: ${JSON.stringify(country)},
        successUrl: ${JSON.stringify(successUrl)},
        cancelUrl: ${JSON.stringify(cancelUrl)},
        failUrl: ${JSON.stringify(failUrl)},
        // No customer_id here — Airwallex picks it up from the PaymentIntent
        // and auto-displays the customer's saved cards on the HPP.
      });
    } catch (e) {
      fail((e && e.message) ? e.message : 'Impossible d\\'initialiser le paiement.');
    }
  </script>
</body>
</html>`;

  res.set('Content-Type', 'text/html; charset=utf-8');
  res.set('Cache-Control', 'no-store');
  res.send(html);
});

// Bridge "done" page — the WebView's NavigationDelegate looks for the
// `/checkout/done` substring in the URL and resolves the payment result.
// We render a tiny HTML so users who somehow land here directly see something.
router.get('/checkout/done', (req, res) => {
  const status = String(req.query.status || 'unknown');
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.send(
    `<!doctype html><meta charset=utf-8>` +
    `<title>HoPetSit</title>` +
    `<body style="font-family:sans-serif;text-align:center;padding:40px">` +
    `<h2>Statut : ${status}</h2>` +
    `<p>Reviens à l\'application HoPetSit pour voir le résultat.</p>` +
    `</body>`,
  );
});

// ─── Diagnostic : returns the user's Airwallex state ─────────────────────────
//
// Hit this from the authenticated app (or curl with the user's JWT) to see :
//   - the Airwallex customer linked to the user
//   - all payment_consents (any status) belonging to that customer
//   - the most recent PaymentIntents
//
// Useful for diagnosing "why doesn't HPP show my saved card" — we can verify
// in seconds whether the customer has a VERIFIED consent.
router.get('/customer-debug', requireAuth, async (req, res) => {
  try {
    const userId = req.user?.id;
    const role = req.user?.role;
    const Model = _roleModel(role);
    if (!Model) return res.status(403).json({ error: 'Unsupported role.' });

    const user = await Model.findById(userId).lean();
    if (!user) return res.status(404).json({ error: 'User not found.' });

    // Resolve the customer by merchant_customer_id (idempotent).
    let customer = null;
    try {
      const list = await airwallex
        .findOrCreateCustomer({
          userId: user._id.toString(),
          email: user.email,
          firstName: (user.name || '').split(' ')[0] || user.name || '',
          lastName: (user.name || '').split(' ').slice(1).join(' ') || '',
        });
      customer = list;
    } catch (e) {
      return res.status(502).json({
        error: 'Unable to resolve Airwallex customer.',
        details: e?.message || String(e),
      });
    }

    // List ALL consents (any status) so we can see what's happening — note this
    // bypasses the VERIFIED filter that listPaymentMethods() applies.
    let allConsents = null;
    try {
      const r = await airwallex
        .__rawAwxFetch?.(
          `/api/v1/pa/payment_consents?customer_id=${encodeURIComponent(customer.id)}&page_size=50`,
        );
      allConsents = r;
    } catch (_) { /* fall through */ }

    // Fallback: use the public listPaymentMethods (which filters to VERIFIED).
    let verifiedConsents = null;
    try {
      verifiedConsents = await airwallex.listPaymentMethods(customer.id);
    } catch (e) {
      verifiedConsents = { error: e?.message || String(e) };
    }

    return res.json({
      user: {
        _id: user._id.toString(),
        email: user.email,
        role,
      },
      airwallexCustomer: {
        id: customer.id,
        merchant_customer_id: customer.merchant_customer_id,
        email: customer.email,
        request_id: customer.request_id,
      },
      verifiedConsents: {
        count: (verifiedConsents?.items || []).length,
        items: (verifiedConsents?.items || []).map((c) => ({
          id: c.id,
          status: c.status,
          last4: c?.payment_method?.card?.last4,
          brand: c?.payment_method?.card?.brand,
          type: c?.next_triggered_by ? `next_by=${c.next_triggered_by}` : null,
          created_at: c.created_at,
        })),
        error: verifiedConsents?.error || null,
      },
      hint:
        'If verifiedConsents.count is 0 but you have a saved card visible in the app, ' +
        'the consent is in PENDING_VERIFICATION or DISABLED state — Airwallex HPP ' +
        'will NOT show it as a saved card. Make a NEW payment with "Save my card" ' +
        'checked at the very FIRST checkout to create a fresh VERIFIED consent.',
    });
  } catch (e) {
    logger.error(`[airwallex.customer-debug] ${e?.message || e}`);
    return res.status(500).json({ error: e?.message || String(e) });
  }
});

module.exports = router;
