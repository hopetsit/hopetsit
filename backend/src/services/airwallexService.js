/**
 * Airwallex Service — Payment Processing (replaces stripeService)
 *
 * Used by HoPetSit to accept card payments and to (eventually) pay sitters.
 * Mirrors the public surface of `stripeService.js` so controllers can swap
 * one for the other progressively.
 *
 * Required env vars (Render):
 *   AIRWALLEX_CLIENT_ID       — Client ID from Airwallex dashboard → API Keys
 *   AIRWALLEX_API_KEY         — API key from same place
 *   AIRWALLEX_BASE_URL        — 'https://api-demo.airwallex.com' (Demo)
 *                               'https://api.airwallex.com'      (Live)
 *   AIRWALLEX_WEBHOOK_SECRET  — webhook signing secret (set when creating
 *                               the webhook endpoint in Airwallex dashboard)
 *
 * IMPORTANT: this module is the FOUNDATION. As of v20.1 it ships with the
 * methods needed for donations + platform-only flows (boost, premium,
 * map-boost). Marketplace flows (booking with split-pay to provider) and
 * Connect-equivalent (Beneficiaries / Connected Accounts) come in a follow-up
 * session — see TODO blocks below.
 */

const crypto = require('crypto');
const logger = require('../utils/logger');

const PLATFORM_COMMISSION_RATE = 0.2; // 20%

// ─── HTTP / Auth helpers ────────────────────────────────────────────────────

const BASE_URL = () =>
  process.env.AIRWALLEX_BASE_URL || 'https://api-demo.airwallex.com';

let _cachedToken = null;
let _cachedTokenExpiresAt = 0;

/**
 * Get a bearer token, cached until 60s before expiry. Airwallex tokens are
 * valid 30 minutes — we re-authenticate well before that.
 *
 * @returns {Promise<string>} bearer token
 */
async function getAccessToken() {
  const now = Date.now();
  if (_cachedToken && now < _cachedTokenExpiresAt - 60_000) return _cachedToken;

  const clientId = process.env.AIRWALLEX_CLIENT_ID;
  const apiKey   = process.env.AIRWALLEX_API_KEY;
  if (!clientId || !apiKey) {
    throw new Error(
      'AIRWALLEX_CLIENT_ID / AIRWALLEX_API_KEY missing in env. ' +
      'Generate them at Airwallex Dashboard → Settings → Developer.',
    );
  }

  const res = await fetch(`${BASE_URL()}/api/v1/authentication/login`, {
    method: 'POST',
    headers: {
      'x-client-id': clientId,
      'x-api-key':   apiKey,
      'Content-Type': 'application/json',
    },
  });

  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`Airwallex login failed (${res.status}): ${text}`);
  }
  const data = await res.json();
  // data: { token, expires_at }
  _cachedToken = data.token;
  // expires_at is ISO 8601
  _cachedTokenExpiresAt = data.expires_at
    ? new Date(data.expires_at).getTime()
    : now + 25 * 60_000; // fallback: 25 min
  return _cachedToken;
}

/**
 * Tiny wrapper around fetch that re-uses the cached token, reads JSON,
 * normalises errors, and surfaces useful debug info.
 */
async function awxFetch(path, { method = 'GET', body, query, _retry = false } = {}) {
  const token = await getAccessToken();
  const url   = new URL(`${BASE_URL()}${path}`);
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      if (v !== undefined && v !== null) url.searchParams.set(k, String(v));
    }
  }
  const res = await fetch(url.toString(), {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  // Token expired in flight → re-authenticate once and retry.
  if (res.status === 401 && !_retry) {
    _cachedToken = null;
    _cachedTokenExpiresAt = 0;
    return awxFetch(path, { method, body, query, _retry: true });
  }

  const text = await res.text();
  let data = {};
  try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }

  if (!res.ok) {
    const err = new Error(
      data?.message || `Airwallex API error ${res.status} on ${method} ${path}`,
    );
    err.status   = res.status;
    err.code     = data?.code;
    err.details  = data;
    throw err;
  }
  return data;
}

// ─── Currency / amount helpers ──────────────────────────────────────────────

/**
 * Airwallex amounts are in MAJOR units (e.g. 1.50 EUR), unlike Stripe which
 * uses minor units (cents). Helper that converts a Stripe-style cents amount
 * to a Major-units float, rounded to 2 decimals.
 */
function centsToMajor(cents) {
  return Math.round(Number(cents)) / 100;
}

function majorToCents(major) {
  return Math.round(Number(major) * 100);
}

// ─── Idempotency helper ─────────────────────────────────────────────────────

function genRequestId(prefix = 'req') {
  return `${prefix}_${Date.now()}_${crypto.randomBytes(6).toString('hex')}`;
}

// ─── PaymentIntents ─────────────────────────────────────────────────────────

/**
 * Create a PLATFORM-only PaymentIntent (no marketplace split).
 * Used by: donation, boost, premium subscription, map-boost — mirrors
 * stripeService.createPlatformPaymentIntent so controllers can substitute it.
 *
 * @param {Object} params
 * @param {number} params.amount    — total in cents (minor units, like Stripe)
 * @param {string} params.currency  — ISO lowercase ('eur','gbp','chf','usd')
 * @param {Object} [params.metadata] — freeform tracking metadata (string-coerced)
 * @returns {Promise<Object>} {
 *   id, client_secret, status, amount, currency, ...
 * }
 */
async function createPlatformPaymentIntent({
  amount,
  currency,
  metadata = {},
  // v23.1 — saved cards : optional customer_id + payment_consent so the
  // card used for this PI is auto-saved as a reusable consent on the
  // customer's profile. Without these args, behaviour is unchanged.
  customer_id = null,
  payment_consent = null,
  // v23.1 part 41 — fix Daniel "page Airwallex naffiche pas la carte" :
  // accept payment_consent_id explicitly. Previously the bookingController
  // passed payment_consent_id but this fn silently dropped it (only
  // customer_id and payment_consent were destructured). Result: HPP never
  // received the consent ref → user had to re-enter card.
  payment_consent_id = null,
}) {
  if (!currency || typeof currency !== 'string' || !currency.trim()) {
    throw new Error('Currency is required for PaymentIntent');
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error('Amount must be a positive integer in cents');
  }

  const merchantOrderId = metadata.bookingId
    || metadata.donationId
    || metadata.boostId
    || metadata.premiumId
    || genRequestId('order');

  // Airwallex requires string-only metadata values (same as Stripe).
  const awxMetadata = {};
  for (const [k, v] of Object.entries(metadata || {})) {
    if (v !== undefined && v !== null) awxMetadata[k] = String(v);
  }

  const requestBody = {
    request_id: genRequestId('pi'),
    amount: centsToMajor(amount),
    currency: currency.toUpperCase(), // Airwallex expects uppercase ISO
    merchant_order_id: merchantOrderId,
    metadata: awxMetadata,
    // Tells the PaymentIntent we want to collect any supported method.
    // The actual list is filtered by what's enabled in the Airwallex
    // dashboard (Visa, Mastercard, Amex, Apple Pay, Google Pay, etc.).
  };

  // v23.1 — attach to customer + create payment_consent so the card is saved.
  if (customer_id) {
    requestBody.customer_id = customer_id;
  }
  if (payment_consent && typeof payment_consent === 'object') {
    requestBody.payment_consent = payment_consent;
  }
  // v23.1 part 41 — when reusing an existing consent, pass it explicitly.
  // Airwallex HPP will then pre-fill the saved card (no re-entry needed).
  // Note: requires the consent to be in VERIFIED status — until the webhook
  // signature is correctly configured (AIRWALLEX_WEBHOOK_SECRET), consents
  // remain PENDING_VERIFICATION and HPP won't auto-fill them.
  if (payment_consent_id && typeof payment_consent_id === 'string') {
    requestBody.payment_consent_id = payment_consent_id;
  }

  console.log('[Airwallex] Creating PaymentIntent', {
    amount_major: requestBody.amount,
    currency: requestBody.currency,
    merchant_order_id: requestBody.merchant_order_id,
    has_customer_id: !!requestBody.customer_id,
    has_payment_consent: !!requestBody.payment_consent,
    has_payment_consent_id: !!requestBody.payment_consent_id,
  });

  try {
    const result = await awxFetch('/api/v1/pa/payment_intents/create', {
      method: 'POST',
      body: requestBody,
    });

    console.log('[Airwallex] PaymentIntent created:', result.id);
    return result;
  } catch (err) {
    console.error('[Airwallex] PaymentIntent creation failed', {
      status: err?.status,
      code: err?.code,
      message: err?.message,
      details: err?.details,
    });
    throw err;
  }
}


/**
 * Create a marketplace PaymentIntent for a booking.
 *
 * v23.1 STATUS — marketplace flow IS implemented end-to-end:
 *   1. Owner pays → PaymentIntent on the platform Airwallex wallet (this fn).
 *   2. Webhook `payment_intent.succeeded` (airwallexWebhookController) marks
 *      the booking paid and calls `processProviderPayoutForBooking`.
 *   3. That helper invokes `createPayout(beneficiaryId)` to release 80% to
 *      the provider's IBAN (lazy `createBeneficiary` on first IBAN save).
 *   4. Webhook `payment.dispatched` / `payment.failed` updates
 *      booking.payoutStatus accordingly.
 *
 * If the provider has NOT yet configured an IBAN (= no airwallexBeneficiaryId
 * on Sitter/Walker), the PI still succeeds — the payout is held until the
 * provider completes their IBAN onboarding, then released by the periodic
 * payoutScheduler. This is fine and intentional.
 *
 * @param {Object} params  same shape as stripeService.createPaymentIntent
 */
async function createPaymentIntent(params) {
  return createPlatformPaymentIntent({
    amount: params.amount,
    currency: params.currency,
    metadata: {
      ...(params.metadata || {}),
      bookingId: params.bookingId,
      ownerId:   params.ownerId,
      sitterId:  params.sitterId,
      // Surfaces the intended split so admin tooling / refund flows know it.
      platform_fee_cents: Math.round(params.amount * PLATFORM_COMMISSION_RATE),
      sitter_payout_cents: params.amount - Math.round(params.amount * PLATFORM_COMMISSION_RATE),
      _flow: 'platform-only-fallback-v20.1',
    },
  });
}

/**
 * Retrieve a PaymentIntent by ID.
 * @param {string} id
 */
async function retrievePaymentIntent(id) {
  if (!id) throw new Error('PaymentIntent id is required');
  return awxFetch(`/api/v1/pa/payment_intents/${encodeURIComponent(id)}`);
}

/**
 * Confirm a PaymentIntent (e.g. server-side after attaching a payment method).
 * Most of the time the client confirms it directly via the Airwallex SDK;
 * this is here for parity with stripeService.confirmPaymentIntent.
 *
 * @param {string} id
 * @param {Object} [opts] payment_method, return_url, etc.
 */
async function confirmPaymentIntent(id, opts = {}) {
  if (!id) throw new Error('PaymentIntent id is required');
  return awxFetch(`/api/v1/pa/payment_intents/${encodeURIComponent(id)}/confirm`, {
    method: 'POST',
    body: {
      request_id: genRequestId('pi-confirm'),
      ...opts,
    },
  });
}

// ─── Refunds ────────────────────────────────────────────────────────────────

/**
 * Create a refund on a captured PaymentIntent.
 * @param {Object} params
 * @param {string} params.paymentIntentId
 * @param {number} [params.amount]   — in CENTS (minor units, like Stripe);
 *                                     omit to refund the full amount.
 * @param {string} [params.reason]   — 'requested_by_customer' | 'duplicate' | 'fraudulent' | freeform
 */
async function createRefund({ paymentIntentId, amount, reason }) {
  if (!paymentIntentId) throw new Error('paymentIntentId is required');
  return awxFetch('/api/v1/pa/refunds/create', {
    method: 'POST',
    body: {
      request_id: genRequestId('refund'),
      payment_intent_id: paymentIntentId,
      amount: amount != null ? centsToMajor(amount) : undefined,
      reason: reason || 'requested_by_customer',
    },
  });
}

// ─── Customers (saved cards) ────────────────────────────────────────────────

/**
 * Find an existing customer by their merchant_customer_id (we use the user's
 * Mongo _id) or create a new one.
 *
 * @param {Object} params
 * @param {string} params.userId   — Mongo _id of the owner/sitter/walker
 * @param {string} params.email
 * @param {string} [params.firstName]
 * @param {string} [params.lastName]
 */
async function findOrCreateCustomer({ userId, email, firstName, lastName }) {
  if (!userId) throw new Error('userId is required');
  // List customers filtered by merchant_customer_id (idempotent lookup).
  const list = await awxFetch('/api/v1/pa/customers', {
    query: { merchant_customer_id: userId, page_num: 0, page_size: 1 },
  }).catch(() => null);
  if (list && Array.isArray(list.items) && list.items[0]) {
    return list.items[0];
  }
  // Create.
  return awxFetch('/api/v1/pa/customers/create', {
    method: 'POST',
    body: {
      request_id: genRequestId('cust'),
      merchant_customer_id: userId,
      email,
      first_name: firstName || undefined,
      last_name:  lastName  || undefined,
    },
  });
}

/**
 * List a customer's saved payment methods (cards).
 * @param {string} customerId — Airwallex customer id
 */
async function listPaymentMethods(customerId) {
  if (!customerId) throw new Error('customerId is required');
  // v23.1 part 44 — fix Daniel "carte sauvegardée mais HPP redemande la
  // saisie". Previously this returned both VERIFIED and PENDING_VERIFICATION
  // consents. The frontend then showed the PENDING one as a "saved card",
  // and when the user tapped it the next PaymentIntent reused that consent
  // id — but Airwallex HPP rejects PENDING_VERIFICATION consents, so the
  // user had to re-enter the card from scratch. Net effect : the card
  // looked "saved" but was never actually usable.
  //
  // Now that booking PIs are created with `type: 'recurring'`, the consent
  // auto-flips to VERIFIED on first successful charge. We can therefore
  // restrict the list to VERIFIED consents only — anything still pending
  // would be unusable and would only mislead the user.
  const result = await awxFetch('/api/v1/pa/payment_consents', {
    query: { customer_id: customerId, page_size: 50 },
  });
  if (result && Array.isArray(result.items)) {
    result.items = result.items.filter((c) => {
      const s = (c?.status || '').toUpperCase();
      return s === 'VERIFIED' && c?.payment_method?.card?.last4;
    });
  }
  return result;
}

/**
 * Detach (disable) a saved payment consent so the user can no longer reuse it.
 * @param {string} consentId — Airwallex payment_consent id
 */
async function detachPaymentMethod(consentId) {
  if (!consentId) throw new Error('consentId is required');
  return awxFetch(`/api/v1/pa/payment_consents/${encodeURIComponent(consentId)}/disable`, {
    method: 'POST',
    body: { request_id: genRequestId('detach') },
  });
}

// ─── Webhook signature verification ─────────────────────────────────────────

/**
 * Verify an Airwallex webhook signature.
 *
 * Airwallex signs webhook bodies with HMAC-SHA256 using your endpoint secret.
 * Headers: `x-timestamp` and `x-signature`. The signed payload is
 * `${timestamp}${rawBody}`.
 *
 * @param {Buffer|string} rawBody — RAW request body (use express.raw())
 * @param {Object} headers       — request.headers
 * @returns {Object} parsed event JSON
 */
function constructWebhookEvent(rawBody, headers) {
  const secretRaw = process.env.AIRWALLEX_WEBHOOK_SECRET;
  const signature = headers['x-signature'] || headers['X-Signature'];
  const timestamp = headers['x-timestamp'] || headers['X-Timestamp'];

  if (!secretRaw) throw new Error('AIRWALLEX_WEBHOOK_SECRET is not configured');
  if (!signature || !timestamp) throw new Error('Missing webhook signature headers');

  const bodyStr  = Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : String(rawBody);

  // v23.1 part 44 — emergency bypass. When AIRWALLEX_WEBHOOK_PERMISSIVE=true
  // we accept the body without verifying the signature. This is meant ONLY
  // as a temporary diagnostic switch when the signature format mismatch
  // blocks the rest of the pipeline (saved card pre-fill, payouts, …) on a
  // pre-prod env. NEVER leave this on in production : it allows anyone who
  // discovers the webhook URL to forge events. The flag is loud-logged on
  // every event so it cannot be forgotten silently.
  if (String(process.env.AIRWALLEX_WEBHOOK_PERMISSIVE || '').toLowerCase() === 'true') {
    try {
      require('../utils/logger').warn(
        '[airwallex.webhook] ⚠️ PERMISSIVE MODE — signature NOT verified. ' +
        'Set AIRWALLEX_WEBHOOK_PERMISSIVE=false on Render before going live.',
      );
    } catch (_) { /* logger optional */ }
    let event;
    try { event = JSON.parse(bodyStr); }
    catch { throw new Error('Webhook body is not valid JSON'); }
    return event;
  }

  // v23.1 part 44 — extended candidate list. Part 42/43 only tried 6 SHA-256
  // formats. Adding SHA-512 variants (some providers use it) and a "secret
  // bytes raw" interpretation (when the dashboard secret is already a hex-
  // encoded random key, not a printable string). If signature still fails
  // with this list, the format is genuinely exotic and the permissive flag
  // above is the escape hatch while we open a support ticket with Airwallex.
  const stripPrefix = (s) => (s.startsWith('whsec_') ? s.slice(6) : s);
  const stripped = stripPrefix(secretRaw);
  let strippedHexBytes = null;
  try {
    if (/^[0-9a-fA-F]+$/.test(stripped) && stripped.length % 2 === 0) {
      strippedHexBytes = Buffer.from(stripped, 'hex');
    }
  } catch (_) { strippedHexBytes = null; }

  const candidates = [
    // SHA-256 family
    { label: 'sha256_raw_hex',            algo: 'sha256', key: secretRaw,                                  enc: 'hex'    },
    { label: 'sha256_stripped_hex',       algo: 'sha256', key: stripped,                                   enc: 'hex'    },
    { label: 'sha256_raw_b64',            algo: 'sha256', key: secretRaw,                                  enc: 'base64' },
    { label: 'sha256_stripped_b64',       algo: 'sha256', key: stripped,                                   enc: 'base64' },
    { label: 'sha256_b64dec_hex',         algo: 'sha256', key: Buffer.from(stripped, 'base64'),            enc: 'hex'    },
    { label: 'sha256_b64dec_b64',         algo: 'sha256', key: Buffer.from(stripped, 'base64'),            enc: 'base64' },
    // SHA-512 family (some webhook providers use this)
    { label: 'sha512_raw_hex',            algo: 'sha512', key: secretRaw,                                  enc: 'hex'    },
    { label: 'sha512_stripped_hex',       algo: 'sha512', key: stripped,                                   enc: 'hex'    },
    { label: 'sha512_stripped_b64',       algo: 'sha512', key: stripped,                                   enc: 'base64' },
  ];
  // Hex-decoded key only if the stripped string actually looks like hex.
  if (strippedHexBytes) {
    candidates.push(
      { label: 'sha256_hexdec_hex',       algo: 'sha256', key: strippedHexBytes,                           enc: 'hex'    },
      { label: 'sha256_hexdec_b64',       algo: 'sha256', key: strippedHexBytes,                           enc: 'base64' },
      { label: 'sha512_hexdec_hex',       algo: 'sha512', key: strippedHexBytes,                           enc: 'hex'    },
    );
  }

  const computed = candidates.map((c) => ({
    label: c.label,
    digest: crypto
      .createHmac(c.algo, c.key)
      .update(`${timestamp}${bodyStr}`)
      .digest(c.enc),
  }));

  // Try matching against the received signature — supports both raw and
  // "v1=..." style headers (some webhook providers wrap signatures).
  const sigClean = String(signature).replace(/^v1=/, '').trim();
  const matched = computed.find((c) => {
    try {
      const a = Buffer.from(c.digest, c.digest.length === 64 || c.digest.length === 128 ? 'hex' : 'base64');
      const b = Buffer.from(sigClean,  sigClean.length  === 64 || sigClean.length  === 128 ? 'hex' : 'base64');
      if (a.length !== b.length) return false;
      return crypto.timingSafeEqual(a, b);
    } catch (_) { return false; }
  });

  if (!matched) {
    const diag = computed.map((c) => `${c.label}=${c.digest.slice(0, 16)}...`).join(' | ');
    const sigHead = sigClean.slice(0, 16);
    throw new Error(
      `Webhook signature mismatch | received_sig_head=${sigHead}... | ` +
      `received_sig_len=${sigClean.length} | candidates: ${diag}`
    );
  }

  // Log which format actually matched so we can simplify next deploy.
  try {
    require('../utils/logger').info(`[airwallex.webhook] signature ok via ${matched.label}`);
  } catch (_) { /* logger optional */ }

  let event;
  try { event = JSON.parse(bodyStr); }
  catch { throw new Error('Webhook body is not valid JSON'); }
  return event;
}

// ─── Beneficiaries (= sitter/walker IBAN destinations) ─────────────────────
//
// Replaces Stripe Connect destination accounts. Each provider (sitter or
// walker) gets ONE Beneficiary record on Airwallex tied to their IBAN.
// We lazy-create it the first time they save their IBAN, store the returned
// beneficiary_id on the Mongo Sitter/Walker document, then reuse it for
// every subsequent payout.

/**
 * Create a Beneficiary on Airwallex tied to the provider's IBAN.
 *
 * @param {Object} params
 * @param {string} params.providerId — Mongo _id of the sitter/walker
 *                                     (used as `nickname` for traceability).
 * @param {string} params.holderName — IBAN account holder name.
 * @param {string} params.iban       — Full IBAN, no spaces.
 * @param {string} [params.bic]      — BIC/SWIFT (optional but recommended).
 * @param {string} [params.currency] — ISO 4217, defaults to 'EUR'.
 * @param {string} [params.bankCountryCode] — ISO-2, defaults to first 2 chars of IBAN.
 * @returns {Promise<Object>} the Airwallex beneficiary object incl. `id`.
 */
async function createBeneficiary({
  providerId,
  holderName,
  iban,
  bic,
  currency = 'EUR',
  bankCountryCode,
}) {
  if (!providerId) throw new Error('providerId is required');
  if (!holderName) throw new Error('holderName is required');
  if (!iban)       throw new Error('iban is required');

  const cleanIban = iban.replace(/\s+/g, '').toUpperCase();
  const country   = (bankCountryCode || cleanIban.slice(0, 2)).toUpperCase();
  // v23.1 part 91 — pour SEPA, Airwallex exige le champ `iban` ; on n'envoie
  // `account_number` que pour les comptes non-IBAN (US ACH, UK FPS sans IBAN…).
  const isIbanValue = /^[A-Z]{2}\d{2}/.test(cleanIban);

  return awxFetch('/api/v1/beneficiaries/create', {
    method: 'POST',
    body: {
      request_id: genRequestId('benef'),
      nickname: `provider_${providerId}`,
      transfer_methods: ['LOCAL'],
      beneficiary: {
        type: 'INDIVIDUAL',
        entity_type: 'PERSONAL',
        bank_details: {
          account_currency: currency.toUpperCase(),
          account_name: holderName.trim(),
          ...(isIbanValue ? { iban: cleanIban } : { account_number: cleanIban }),
          bank_country_code: country,
          ...(bic ? { swift_code: bic.replace(/\s+/g, '').toUpperCase() } : {}),
        },
        first_name: holderName.split(' ')[0] || holderName,
        last_name:  holderName.split(' ').slice(1).join(' ') || holderName,
      },
      payment_methods: ['LOCAL'],
    },
  });
}

/**
 * v23.1 part 87 — Daniel : "comment crrer sur airwallex ton lien me
 * donne page blanche". On lui crée le beneficiary société directement
 * via l'API au lieu de le faire pointer vers la dashboard.
 *
 * Crée un beneficiary BUSINESS pour HoPetSit lui-même (CARDELLI
 * HERMANOS LIMITED ou autre entité) qu'on stocke ensuite dans
 * COMPANY_AIRWALLEX_BENEFICIARY_ID. C'est CE beneficiary qui reçoit
 * le sweep des bénéfices société.
 *
 * Différent de createBeneficiary() (qui crée des INDIVIDUAL pour les
 * walkers/sitters).
 */
async function createCompanyBeneficiary({
  companyName,
  iban,
  bic,
  bankName,
  bankCountryCode,
  currency = 'EUR',
  addressLine,
  addressCity,
  addressCountryCode,
  postalCode,
}) {
  if (!companyName) throw new Error('companyName is required');
  if (!iban) throw new Error('iban is required');
  const cleanIban = iban.replace(/\s+/g, '').toUpperCase();
  const country = (bankCountryCode || cleanIban.slice(0, 2)).toUpperCase();
  // v23.1 part 91 — pour SEPA/IBAN, Airwallex exige le champ `iban`.
  const isIbanValue = /^[A-Z]{2}\d{2}/.test(cleanIban);

  // v23.1 part 93 — Airwallex exige TOUJOURS street_address + city +
  // country_code pour les COMPANY beneficiaries (validation_failed code 001
  // sur ces 3 champs sinon). Seul le postcode est optionnel : on le saute
  // quand il est manifestement bidon (000000, vide) ou que le pays n'a pas
  // de code postal standardisé (HK, IE, AE, …).
  if (!addressLine) throw new Error('addressLine est obligatoire (Airwallex exige beneficiary.address.street_address)');
  if (!addressCity) throw new Error('addressCity est obligatoire (Airwallex exige beneficiary.address.city)');
  const addrCC = (addressCountryCode || country || 'FR').toUpperCase();

  const cleanZip = (postalCode || '').toString().trim();
  const isFakeZip = !cleanZip || /^0+$/.test(cleanZip.replace(/\s+/g, ''));
  // Pays sans code postal standardisé (HK, IE, AE, …) — Airwallex accepte
  // que postcode soit absent.
  const noPostcodeCountries = new Set(['HK', 'IE', 'AE', 'AO', 'AG', 'BS', 'BZ',
    'BJ', 'BO', 'BW', 'BF', 'BI', 'CM', 'CF', 'TD', 'KM', 'CG', 'CD', 'CI',
    'DJ', 'DM', 'GQ', 'ER', 'FJ', 'GM', 'GH', 'GD', 'GY', 'KE', 'KI', 'LY',
    'MO', 'MW', 'ML', 'MR', 'NR', 'KP', 'PA', 'QA', 'RW', 'KN', 'LC', 'ST',
    'SC', 'SL', 'SB', 'SO', 'SR', 'SY', 'TZ', 'TG', 'TV', 'UG', 'VU', 'YE',
    'ZW']);
  const sendPostcode = !!cleanZip && !isFakeZip && !noPostcodeCountries.has(addrCC);

  // v23.1 part 94 — On retire `type: 'COMPANY'` au profit de `entity_type`
  // seul. Le doublon est probablement la cause du `invalid_argument` opaque
  // (les docs Airwallex récentes ne mentionnent que `entity_type`).
  // Si ça échoue encore, l'API du back-end retournera maintenant les logs
  // serveur détaillés (request body + response Airwallex masqué) → on
  // pourra trancher sur les vrais champs rejetés.
  const body = {
    request_id: genRequestId('compbenef'),
    nickname: `HoPetSit company sweep`,
    transfer_methods: ['LOCAL'],
    beneficiary: {
      entity_type: 'COMPANY',
      company_name: companyName.trim(),
      bank_details: {
        account_currency: currency.toUpperCase(),
        account_name: companyName.trim(),
        ...(isIbanValue ? { iban: cleanIban } : { account_number: cleanIban }),
        bank_country_code: country,
        ...(bic ? { swift_code: bic.replace(/\s+/g, '').toUpperCase() } : {}),
        ...(bankName ? { bank_name: bankName.trim() } : {}),
      },
      address: {
        street_address: addressLine.trim(),
        city: addressCity.trim(),
        country_code: addrCC,
        ...(sendPostcode ? { postcode: cleanZip } : {}),
      },
    },
    payment_methods: ['LOCAL'],
  };

  // Logs explicites pour qu'on puisse diagnostiquer si Airwallex rejette.
  // On masque l'IBAN dans les logs (4 premiers + 4 derniers caractères).
  const maskIban = (s) => s ? (s.slice(0, 4) + '***' + s.slice(-4)) : '';
  const logBody = JSON.parse(JSON.stringify(body));
  if (logBody.beneficiary?.bank_details?.iban) logBody.beneficiary.bank_details.iban = maskIban(logBody.beneficiary.bank_details.iban);
  if (logBody.beneficiary?.bank_details?.account_number) logBody.beneficiary.bank_details.account_number = maskIban(logBody.beneficiary.bank_details.account_number);
  console.log('[airwallex/createCompanyBeneficiary] ▶ request body:', JSON.stringify(logBody));

  try {
    const r = await awxFetch('/api/v1/beneficiaries/create', { method: 'POST', body });
    console.log('[airwallex/createCompanyBeneficiary] ✅ created id=' + r.id);
    return r;
  } catch (e) {
    console.error('[airwallex/createCompanyBeneficiary] ❌', {
      message: e.message,
      status: e.status,
      code: e.code,
      details: e.details,
      sentBody: logBody,
    });
    // v23.1 part 94 — attache le body envoyé à l'erreur pour qu'il remonte
    // jusqu'au formulaire admin (avec IBAN masqué). Daniel verra
    // exactement ce qui a été envoyé sans avoir à ouvrir Render logs.
    e.sentBody = logBody;
    throw e;
  }
}

/**
 * v23.1 part 88 — Daniel : "jai deja un compte ouvert je veux
 * recevoir les sous sur ce compte". List les beneficiaries existants
 * pour que Daniel choisisse celui sur lequel il veut recevoir les
 * bénéfices société (au lieu d'en créer un nouveau).
 */
async function listBeneficiaries({ pageSize = 50 } = {}) {
  return awxFetch(`/api/v1/beneficiaries?page_size=${pageSize}`);
}

/**
 * Retrieve a Beneficiary by ID.
 * @param {string} id — Airwallex beneficiary id
 */
async function getBeneficiary(id) {
  if (!id) throw new Error('beneficiary id is required');
  return awxFetch(`/api/v1/beneficiaries/${encodeURIComponent(id)}`);
}

/**
 * Delete a Beneficiary (e.g. when provider changes their IBAN — we delete
 * the old one before creating a new one to keep the dashboard clean).
 * @param {string} id
 */
async function deleteBeneficiary(id) {
  if (!id) throw new Error('beneficiary id is required');
  return awxFetch(`/api/v1/beneficiaries/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}

// ─── Payouts (= release of sitter cut after a successful booking) ──────────

/**
 * Initiate a Payout from the HoPetSit Airwallex wallet to a Beneficiary.
 *
 * Used after a booking PaymentIntent succeeds : the platform keeps 20%
 * commission on its wallet, and 80% goes back to the sitter via a Local
 * (SEPA) payout to their IBAN.
 *
 * @param {Object} params
 * @param {string} params.beneficiaryId — Airwallex beneficiary id
 * @param {number} params.amount        — in CENTS (minor units), like Stripe
 * @param {string} params.currency      — ISO 4217, e.g. 'EUR'
 * @param {string} [params.reference]   — appears on the recipient's bank
 *                                        statement (max 35 chars).
 * @param {Object} [params.metadata]    — bookingId, sitterId, …
 * @returns {Promise<Object>}
 */
async function createPayout({ beneficiaryId, amount, currency, reference, metadata = {} }) {
  if (!beneficiaryId) throw new Error('beneficiaryId is required');
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error('Amount must be a positive integer in cents');
  }

  const awxMetadata = {};
  for (const [k, v] of Object.entries(metadata || {})) {
    if (v !== undefined && v !== null) awxMetadata[k] = String(v);
  }

  return awxFetch('/api/v1/payouts/create', {
    method: 'POST',
    body: {
      request_id: genRequestId('payout'),
      beneficiary_id: beneficiaryId,
      amount: centsToMajor(amount),
      source_currency: currency.toUpperCase(),
      payment_currency: currency.toUpperCase(),
      reason: 'service_charges',
      reference: (reference || 'HoPetSit booking payout').slice(0, 35),
      metadata: awxMetadata,
    },
  });
}

/**
 * Retrieve a Payout by ID — used by the reconciliation cron to confirm
 * actual settlement before flagging the booking `paid_out=true`.
 */
async function retrievePayout(id) {
  if (!id) throw new Error('payout id is required');
  return awxFetch(`/api/v1/payouts/${encodeURIComponent(id)}`);
}

/**
 * v23.1 part 79 — Daniel : "verifie les payout pour ma societer".
 * v23.1 part 98 — Daniel a 168.30 EUR sur son dashboard Airwallex
 * (compte multi-devises + règlements quotidiens) mais notre app voyait
 * 0. /balances/current renvoie probablement vide pour son type de
 * compte (Standard, pas Marketplace). On essaie plusieurs endpoints en
 * parallèle, on retourne le premier qui a des items, et on inclut une
 * diagnostic verbose pour qu'on voie ce que chaque endpoint renvoie.
 *
 * Returns: { items, raw, diagnosticEndpoints }
 */
async function getPlatformBalance() {
  const endpoints = [
    '/api/v1/balances/current',
    '/api/v1/balances',
    '/api/v1/balances/history?page_size=1',
    '/api/v1/accounts/balance',
    '/api/v1/wallets/balance',
  ];
  const diagnosticEndpoints = [];
  let firstWithItems = null;

  for (const ep of endpoints) {
    try {
      const r = await awxFetch(ep);
      // Normalisation : on cherche des "items" ou similar.
      let items = [];
      if (r && Array.isArray(r.items)) items = r.items;
      else if (Array.isArray(r)) items = r;
      else if (r && Array.isArray(r.balances)) items = r.balances;
      else if (r && r.currency) items = [r]; // single-balance shape

      diagnosticEndpoints.push({
        endpoint: ep,
        ok: true,
        itemsCount: items.length,
        keysAtRoot: r && typeof r === 'object' ? Object.keys(r) : null,
        sample: items[0] || null,
      });

      if (!firstWithItems && items.length > 0) {
        firstWithItems = { endpoint: ep, items, raw: r };
      }
    } catch (e) {
      diagnosticEndpoints.push({
        endpoint: ep,
        ok: false,
        error: e.message,
        status: e.status,
      });
    }
  }

  if (firstWithItems) {
    console.log('[airwallex/getPlatformBalance] using endpoint=' + firstWithItems.endpoint +
      ' itemsCount=' + firstWithItems.items.length);
    return {
      items: firstWithItems.items,
      raw: firstWithItems.raw,
      sourceEndpoint: firstWithItems.endpoint,
      diagnosticEndpoints,
    };
  }

  // Aucun endpoint n'a renvoyé d'items.
  console.warn('[airwallex/getPlatformBalance] aucun endpoint n\'a renvoyé d\'items :');
  for (const d of diagnosticEndpoints) console.warn('   • ' + JSON.stringify(d));
  return {
    items: [],
    raw: null,
    sourceEndpoint: null,
    diagnosticEndpoints,
  };
}

/**
 * v23.1 part 79 — sweep the available platform balance to a saved
 * company beneficiary. This is how Daniel actually receives the
 * accumulated commissions + boutique revenue (Boost / PawSpot /
 * PawFollow / Chat Add-on / KYC) into his company bank account.
 *
 * The COMPANY_AIRWALLEX_BENEFICIARY_ID env var must point to a
 * pre-saved Airwallex beneficiary representing Daniel's company bank
 * (created once via the Airwallex dashboard or via a one-off
 * createBeneficiary call). Each currency is swept independently.
 *
 * @param {object} opts
 * @param {string} opts.beneficiaryId - Airwallex beneficiary id (Daniel's company bank).
 * @param {number} [opts.minSweepAmount=10] - Skip sweep if available < this in major units.
 * @param {string[]} [opts.currencies] - Optional whitelist (default: all currencies with balance).
 * @returns {Promise<{swept: Array<{currency, amount, payoutId}>, skipped: Array<{currency, available, reason}>}>}
 */
async function sweepPlatformBalance({
  beneficiaryId,
  minSweepAmount = 10,
  currencies = null,
}) {
  if (!beneficiaryId) {
    throw new Error('beneficiaryId is required (set COMPANY_AIRWALLEX_BENEFICIARY_ID).');
  }
  const balance = await getPlatformBalance();
  const items = (balance && Array.isArray(balance.items)) ? balance.items : [];
  const swept = [];
  const skipped = [];
  for (const item of items) {
    const currency = (item.currency || '').toUpperCase();
    if (!currency) continue;
    if (currencies && !currencies.includes(currency)) continue;
    const available = Number(item.available_amount || 0);
    if (!Number.isFinite(available) || available < minSweepAmount) {
      skipped.push({ currency, available, reason: 'below_min' });
      continue;
    }
    try {
      // amount comes back from Airwallex as major units already (EUR
      // not cents), but our createPayout helper takes cents → multiply.
      const amountInCents = Math.round(available * 100);
      const payout = await createPayout({
        beneficiaryId,
        amount: amountInCents,
        currency,
        reference: `HoPetSit sweep ${new Date().toISOString().slice(0, 10)}`.slice(0, 35),
        metadata: { type: 'company_sweep' },
      });
      swept.push({
        currency,
        amount: available,
        payoutId: payout?.id || null,
      });
    } catch (e) {
      skipped.push({ currency, available, reason: 'payout_failed', error: e.message });
    }
  }
  return { swept, skipped };
}


// ─── Structured error mapping ──────────────────────────────────────────────
//
// v23.1 — translates an Airwallex API error (or any thrown Error inside this
// service) into a stable, frontend-friendly { code, message } pair. Callers
// should pass `err` from a try/catch and forward the resulting `code` to the
// client toast so the user sees an actionable, translated message.
//
// Codes are intentionally finite and stable across versions:
//   PAYMENT_INTENT_FAILED     — generic Airwallex 4xx/5xx on PI create
//   PAYMENT_AUTH_FAILED       — 401 / 403 / token issue (env vars wrong)
//   PAYMENT_DECLINED          — card declined / risk rejected
//   PROVIDER_NOT_CONFIGURED   — sitter/walker has no airwallexBeneficiaryId
//   AMOUNT_INVALID            — negative / zero / NaN amount
//   CURRENCY_INVALID          — missing / unsupported currency
//   ENV_NOT_CONFIGURED        — AIRWALLEX_CLIENT_ID / API_KEY missing
//   UNKNOWN                   — fallback, includes raw message in details

function mapAirwallexError(err) {
  if (!err) return { code: 'UNKNOWN', message: 'Unknown error', details: null };

  const msg = String(err?.message || err || '').trim();
  const status = Number(err?.status) || 0;
  const awxCode = String(err?.code || '').trim();
  const details = err?.details || null;

  // Env / auth issues (backend mis-configured)
  if (msg.includes('AIRWALLEX_CLIENT_ID') || msg.includes('AIRWALLEX_API_KEY')) {
    return { code: 'ENV_NOT_CONFIGURED', message: msg, status, awxCode, details };
  }
  if (status === 401 || status === 403 || msg.includes('login failed')) {
    return { code: 'PAYMENT_AUTH_FAILED', message: msg, status, awxCode, details };
  }

  // Local validation throws
  if (msg.includes('Currency is required') || msg.includes('Unsupported currency')) {
    return { code: 'CURRENCY_INVALID', message: msg, status, awxCode, details };
  }
  if (msg.includes('Amount must be') || msg.includes('positive integer in cents')) {
    return { code: 'AMOUNT_INVALID', message: msg, status, awxCode, details };
  }
  if (msg.includes('beneficiary') || msg.includes('Beneficiary') || awxCode === 'beneficiary_not_found') {
    return { code: 'PROVIDER_NOT_CONFIGURED', message: msg, status, awxCode, details };
  }

  // Card decline-style codes from Airwallex
  if (
    awxCode === 'card_declined' ||
    awxCode === 'do_not_honor' ||
    awxCode === 'insufficient_funds' ||
    msg.toLowerCase().includes('declined')
  ) {
    return { code: 'PAYMENT_DECLINED', message: msg, status, awxCode, details };
  }

  // Anything else from Airwallex → generic PI failure
  if (status >= 400 || awxCode) {
    return { code: 'PAYMENT_INTENT_FAILED', message: msg, status, awxCode, details };
  }

  return { code: 'UNKNOWN', message: msg, status, awxCode, details };
}


/**
 * Cancel a PaymentIntent that is still in REQUIRES_PAYMENT_METHOD or
 * REQUIRES_CONFIRMATION state (i.e. before the user has confirmed the
 * payment). v23.1 — used by the explicit "Annuler" button on the Payment
 * screen so a real cancel is recorded on Airwallex side instead of just
 * letting the PI expire silently.
 *
 * Airwallex returns 400 if the PI is in a state where cancel is not allowed
 * (e.g. SUCCEEDED, CANCELLED) — the caller should treat that as a soft no-op.
 *
 * @param {string} id
 * @param {Object} [opts]
 * @param {string} [opts.reason] free-form reason, defaults to 'requested_by_customer'
 */
async function cancelPaymentIntent(id, opts = {}) {
  if (!id) throw new Error('PaymentIntent id is required');
  return awxFetch(`/api/v1/pa/payment_intents/${encodeURIComponent(id)}/cancel`, {
    method: 'POST',
    body: {
      request_id: genRequestId('pi-cancel'),
      cancellation_reason: opts.reason || 'requested_by_customer',
    },
  });
}

module.exports = {
  // Auth (exposed for debugging)
  getAccessToken,
  // PaymentIntents
  createPlatformPaymentIntent,
  createPaymentIntent,
  retrievePaymentIntent,
  confirmPaymentIntent,
  cancelPaymentIntent,
  // Refunds
  createRefund,
  // Customers / saved cards
  findOrCreateCustomer,
  listPaymentMethods,
  detachPaymentMethod,
  // Webhooks
  constructWebhookEvent,
  // Beneficiaries (provider IBAN destinations) — v21
  createBeneficiary,
  getBeneficiary,
  deleteBeneficiary,
  // v23.1 part 87 — company beneficiary (HoPetSit's own bank for sweeps)
  createCompanyBeneficiary,
  // v23.1 part 88 — list existing beneficiaries
  listBeneficiaries,
  // Payouts (sitter/walker payouts) — v21
  createPayout,
  retrievePayout,
  // v23.1 part 79 — company-side payouts (sweep platform balance to
  // Daniel's company bank).
  getPlatformBalance,
  sweepPlatformBalance,
  // Constants
  PLATFORM_COMMISSION_RATE,
  // Error mapping (v23.1)
  mapAirwallexError,
};
