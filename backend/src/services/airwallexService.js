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
async function createPlatformPaymentIntent({ amount, currency, metadata = {} }) {
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

  console.log('[Airwallex] Creating PaymentIntent', {
    amount_major: requestBody.amount,
    currency: requestBody.currency,
    merchant_order_id: requestBody.merchant_order_id,
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
  return awxFetch('/api/v1/pa/payment_consents', {
    query: { customer_id: customerId, status: 'VERIFIED', page_size: 20 },
  });
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
  const secret    = process.env.AIRWALLEX_WEBHOOK_SECRET;
  const signature = headers['x-signature'] || headers['X-Signature'];
  const timestamp = headers['x-timestamp'] || headers['X-Timestamp'];

  if (!secret) throw new Error('AIRWALLEX_WEBHOOK_SECRET is not configured');
  if (!signature || !timestamp) throw new Error('Missing webhook signature headers');

  const bodyStr  = Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : String(rawBody);
  const expected = crypto
    .createHmac('sha256', secret)
    .update(`${timestamp}${bodyStr}`)
    .digest('hex');

  if (!crypto.timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(signature, 'hex'))) {
    throw new Error('Webhook signature mismatch');
  }

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
          account_number: cleanIban,
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
  // Payouts (sitter/walker payouts) — v21
  createPayout,
  retrievePayout,
  // Constants
  PLATFORM_COMMISSION_RATE,
  // Error mapping (v23.1)
  mapAirwallexError,
};
