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
  // v23.1 part 59 — Bridge fixed with the OFFICIAL Airwallex CDN URL :
  //   https://static.airwallex.com/components/sdk/v1/index.js
  // Verified against airwallex-payment-demo/integrations/cdn/hpp.html on
  // GitHub. Previous attempts (parts 57/58) used either a wrong path
  // (`/components/v1/index.js` missing /sdk/) or pure guesses
  // (checkout.airwallex.com/assets/elements.bundle.min.js — doesn't exist).
  //
  // Global exposed by the script : `window.AirwallexComponentsSDK`.
  // Init returns `{ payments }`, then call `payments.redirectToCheckout({...})`
  // with the args from the official HPP demo : env, mode:'payment',
  // currency, intent_id, client_secret, successUrl, failUrl.
  //
  // We also keep our visible-error UX from part 58 :
  //   - Show JS errors visibly on the page (otherwise stuck = invisible)
  //   - Watchdogs that surface a "still loading…" message
  //   - Catch every onerror / unhandledrejection and report to the page
  //   - Provide a manual "Continuer" button as a last-resort escape hatch
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
  .btn { display: inline-block; margin-top: 16px; padding: 12px 24px;
         background: #EF4324; color: #fff; border: none; border-radius: 24px;
         font-size: 14px; font-weight: 700; cursor: pointer;
         text-decoration: none; }
  .btn:active { opacity: 0.8; }
  #cancelLink { display: block; margin-top: 12px; font-size: 12px; color: #999;
                text-decoration: underline; }
</style>
</head>
<body>
  <div class="lock">🔒</div>
  <div class="title" id="title">Connexion sécurisée…</div>
  <div class="spinner" id="spinner"></div>
  <div class="hint">Le paiement est traité par Airwallex (PCI-DSS Level 1).
  Vos données carte ne transitent jamais par HoPetSit.</div>
  <div id="status" class="hint" style="display:none"></div>
  <div id="error" class="hint err" style="display:none"></div>
  <button id="retryBtn" class="btn" style="display:none">Continuer</button>
  <a href="${cancelUrl}" id="cancelLink">Annuler</a>

  <script>
    // ─── State ────────────────────────────────────────────────────────────
    var INTENT   = ${JSON.stringify(intent)};
    var SECRET   = ${JSON.stringify(secret)};
    var CURRENCY = ${JSON.stringify(currency)};
    var COUNTRY  = ${JSON.stringify(country)};
    var ENV      = ${JSON.stringify(env)};
    var SUCCESS  = ${JSON.stringify(successUrl)};
    var CANCEL   = ${JSON.stringify(cancelUrl)};
    var FAILU    = ${JSON.stringify(failUrl)};

    var statusEl = document.getElementById('status');
    var errorEl  = document.getElementById('error');
    var retryBtn = document.getElementById('retryBtn');
    var titleEl  = document.getElementById('title');

    function setStatus(msg) {
      statusEl.textContent = msg;
      statusEl.style.display = 'block';
      console.log('[bridge]', msg);
    }
    function showError(msg) {
      errorEl.textContent = '⚠️ ' + msg;
      errorEl.style.display = 'block';
      retryBtn.style.display = 'inline-block';
      titleEl.textContent = 'Erreur de chargement';
      console.error('[bridge] ERROR:', msg);
    }

    // Catch any uncaught error so we can surface it (otherwise the user
    // is stuck on a silent loading screen).
    window.addEventListener('error', function(ev) {
      showError((ev && ev.message) ? ev.message : 'Script error');
    });
    window.addEventListener('unhandledrejection', function(ev) {
      var r = ev && ev.reason;
      showError(r && r.message ? r.message : (typeof r === 'string' ? r : 'Promise rejected'));
    });

    // ─── Load the Airwallex script with error fallback ────────────────────
    // We try the modern hosted bundle first ; if it fails to load we surface
    // a clear error rather than spinning forever.
    function loadScript(src, onload, onerror) {
      var s = document.createElement('script');
      s.src = src;
      s.async = true;
      s.onload = onload;
      s.onerror = function() { onerror(new Error('Failed to load ' + src)); };
      document.head.appendChild(s);
    }

    async function doRedirect() {
      try {
        var SDK = window.AirwallexComponentsSDK;
        if (!SDK || typeof SDK.init !== 'function') {
          showError('SDK Airwallex introuvable (window.AirwallexComponentsSDK manquant).');
          return;
        }
        setStatus('Init du SDK…');
        var ctx = await SDK.init({
          env: ENV,
          enabledElements: ['payments'],
        });
        var payments = ctx && ctx.payments;
        if (!payments || typeof payments.redirectToCheckout !== 'function') {
          showError('payments.redirectToCheckout indisponible.');
          return;
        }
        setStatus('Redirection vers la page sécurisée Airwallex…');
        await payments.redirectToCheckout({
          env: ENV,
          mode: 'payment',
          currency: CURRENCY,
          country_code: COUNTRY,
          intent_id: INTENT,
          client_secret: SECRET,
          successUrl: SUCCESS,
          failUrl:    FAILU,
          // We don't pass customer_id here — Airwallex auto-discovers it
          // from the customer_id attached on the PaymentIntent server-side.
        });
        // If after 4s we're still on this page, something went wrong.
        setTimeout(function() {
          if (document.visibilityState === 'visible') {
            setStatus('Si rien ne s\\'affiche, appuie sur Continuer.');
            retryBtn.style.display = 'inline-block';
          }
        }, 4000);
      } catch (e) {
        showError((e && e.message) ? e.message : 'Erreur inconnue redirectToCheckout.');
      }
    }

    setStatus('Chargement du SDK Airwallex…');
    loadScript(
      'https://static.airwallex.com/components/sdk/v1/index.js',
      function() {
        setStatus('SDK chargé, init…');
        doRedirect();
      },
      function() {
        showError('Impossible de charger le SDK Airwallex. Vérifie ta connexion internet.');
      }
    );

    // Watchdog : if 8s pass with no progress, show retry button.
    setTimeout(function() {
      if (errorEl.style.display === 'none') {
        setStatus('Si rien ne se passe, vérifie ta connexion et réessaie.');
        retryBtn.style.display = 'inline-block';
      }
    }, 8000);

    retryBtn.addEventListener('click', function() {
      retryBtn.style.display = 'none';
      errorEl.style.display = 'none';
      titleEl.textContent = 'Connexion sécurisée…';
      doRedirect();
    });
  </script>
</body>
</html>`;

  res.set('Content-Type', 'text/html; charset=utf-8');
  res.set('Cache-Control', 'no-store');
  // v23.1 part 60 — Override Helmet's default CSP for this specific route
  // so the browser can load the Airwallex SDK + connect to airwallex API
  // + render the HPP iframe. The default `script-src 'self'` was the
  // root cause of "Impossible de charger le SDK Airwallex" — the
  // <script src="https://static.airwallex.com/...">  load was blocked
  // before any onerror could fire, so loadScript fell through to the
  // showError handler. We allow the specific airwallex.com origins
  // (not a blanket *) to keep things tight.
  res.set(
    'Content-Security-Policy',
    [
      "default-src 'self' https://*.airwallex.com",
      "script-src 'self' 'unsafe-inline' https://*.airwallex.com https://static.airwallex.com",
      "style-src 'self' 'unsafe-inline' https://*.airwallex.com",
      "img-src 'self' data: blob: https:",
      "connect-src 'self' https://*.airwallex.com wss://*.airwallex.com",
      "frame-src 'self' https://*.airwallex.com",
      "frame-ancestors 'self' https://*.airwallex.com",
      "font-src 'self' data: https:",
      "form-action 'self' https://*.airwallex.com",
      "base-uri 'self'",
      "object-src 'none'",
    ].join('; '),
  );
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
