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

  return awxFetch('/api/v1/pa/payment_intents/create', {
    method: 'POST',
    body: {
      request_id: genRequestId('pi'),
      amount: centsToMajor(amount),
      currency: currency.toUpperCase(), // Airwallex expects uppercase ISO
      merchant_order_id: merchantOrderId,
      metadata: awxMetadata,
      // Tells the PaymentIntent we want to collect any supported method.
      // The actual list is filtered by what's enabled in the Airwallex
      // dashboard (Visa, Mastercard, Amex, Apple Pay, Google Pay, etc.).
    },
  });
}

/**
 * Create a marketplace PaymentIntent for a booking (owner pays, sitter
 * receives most of the funds, platform keeps 20%).
 *
 * v20.1 STATUS — temporarily falls back to a platform-only PI so the rest of
 * the pipeline keeps working while the Airwallex Beneficiaries / Connected
 * Accounts integration is built in the next session. Funds will accumulate
 * on the HoPetSit master wallet and be transferred manually until then.
 *
 * @param {Object} params  same shape as stripeService.createPaymentIntent
 */
async function createPaymentIntent(params) {
  // TODO(airwallex-marketplace): swap this for a real Connect-style flow.
  //   Plan:
  //   1. createBeneficiary(sitter) on first booking — store id on Sitter.
  //   2. Use Payouts API after PI capture to send (amount × 0.8) to the
  //      sitter's IBAN beneficiary, keep 20% on the platform wallet.
  //   3. Mirror stripeWebhookController to listen to payment_intent.succeeded
  //      and trigger the payout.
  logger.warn('[airwallex] createPaymentIntent: marketplace flow not yet ' +
    'implemented — falling back to platform-only PI. Funds will need a ' +
    'manual payout from the HoPetSit Airwallex wallet to the sitter IBAN.');
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

// ─── TODO: Marketplace / Connect equivalent (next session) ──────────────────
//
// To replace Stripe Connect with Airwallex Beneficiaries:
//   - createBeneficiary({ sitterId, name, iban, country, currency })
//   - getBeneficiary(beneficiaryId)
//   - createPayout({ beneficiaryId, amount, currency, reference })
//   - listPayouts({ beneficiaryId, fromDate, toDate })
//
// Endpoints:
//   POST /api/v1/beneficiaries/create
//   GET  /api/v1/beneficiaries/{id}
//   POST /api/v1/payouts/create
//   GET  /api/v1/payouts
//
// Flow:
//   1. On booking.payment_intent.succeeded webhook:
//      → fetch sitter's beneficiaryId (lazy-create if missing)
//      → call createPayout for (amount × 0.8)
//      → mark booking as paid & sitter as paid_out
//   2. Daily reconciliation cron checks pending payouts.

module.exports = {
  // Auth (exposed for debugging)
  getAccessToken,
  // PaymentIntents
  createPlatformPaymentIntent,
  createPaymentIntent,
  retrievePaymentIntent,
  confirmPaymentIntent,
  // Refunds
  createRefund,
  // Customers / saved cards
  findOrCreateCustomer,
  listPaymentMethods,
  detachPaymentMethod,
  // Webhooks
  constructWebhookEvent,
  // Constants
  PLATFORM_COMMISSION_RATE,
};
