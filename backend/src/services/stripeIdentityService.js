/**
 * Stripe Identity service — session v3.3 scaffolding.
 *
 * Wraps the Stripe Identity API so app endpoints can create verification
 * sessions and interpret webhook events. Requires STRIPE_SECRET_KEY in env
 * (same key used by stripeService.js for payments). Webhook secret should
 * be set separately as STRIPE_IDENTITY_WEBHOOK_SECRET — you get it from the
 * Stripe dashboard when adding the webhook endpoint.
 *
 * Docs: https://stripe.com/docs/identity
 */

const logger = require('../utils/logger');

let stripe = null;
function loadStripe() {
  if (stripe) return stripe;
  const secret = process.env.STRIPE_SECRET_KEY;
  if (!secret) {
    logger.warn('[stripeIdentity] STRIPE_SECRET_KEY is not set — identity verification is disabled.');
    return null;
  }
  try {
    stripe = require('stripe')(secret);
    return stripe;
  } catch (e) {
    logger.error('[stripeIdentity] failed to require stripe', e);
    return null;
  }
}

/**
 * Creates a Stripe Identity VerificationSession for the given user.
 * Returns { id, client_secret, url } so the client can open the Stripe
 * Identity flow (hosted page on web, SDK on mobile).
 *
 * @param {object} opts
 * @param {string} opts.userId      Our internal user id (saved in metadata).
 * @param {string} opts.userRole    'sitter' | 'walker' — saved in metadata.
 * @param {string} [opts.email]     Optional — prefilled in the Stripe flow.
 * @param {string} [opts.returnUrl] Optional — deep link Stripe redirects to.
 */
async function createVerificationSession({
  userId,
  userRole,
  email,
  returnUrl,
}) {
  const s = loadStripe();
  if (!s) {
    const err = new Error('Identity verification is not configured on this environment.');
    err.code = 'IDENTITY_NOT_CONFIGURED';
    throw err;
  }
  const session = await s.identity.verificationSessions.create({
    type: 'document',
    metadata: {
      userId: String(userId),
      role: String(userRole || ''),
      source: 'hopetsit',
    },
    options: {
      document: {
        require_matching_selfie: true,
        require_live_capture: true,
        require_id_number: false,
        allowed_types: ['driving_license', 'id_card', 'passport'],
      },
    },
    ...(returnUrl ? { return_url: returnUrl } : {}),
    ...(email ? { provided_details: { email } } : {}),
  });
  return {
    id: session.id,
    clientSecret: session.client_secret,
    url: session.url,
    status: session.status,
  };
}

/**
 * Retrieves a verification session by id — used after a webhook to fetch
 * the final verdict and persist details on the user doc.
 */
async function retrieveVerificationSession(sessionId) {
  const s = loadStripe();
  if (!s) return null;
  return s.identity.verificationSessions.retrieve(sessionId);
}

/**
 * Verifies a Stripe webhook signature and returns the parsed event. Use
 * this inside the webhook route handler BEFORE trusting the body.
 *
 * @param {Buffer|string} rawBody  The raw request body (Buffer ideal).
 * @param {string} signatureHdr    Value of the `Stripe-Signature` header.
 */
function parseWebhookEvent(rawBody, signatureHdr) {
  const s = loadStripe();
  if (!s) throw new Error('Stripe not configured.');
  const secret = process.env.STRIPE_IDENTITY_WEBHOOK_SECRET;
  if (!secret) {
    throw new Error('STRIPE_IDENTITY_WEBHOOK_SECRET is not set.');
  }
  return s.webhooks.constructEvent(rawBody, signatureHdr, secret);
}

module.exports = {
  createVerificationSession,
  retrieveVerificationSession,
  parseWebhookEvent,
  isConfigured: () => !!loadStripe() && !!process.env.STRIPE_IDENTITY_WEBHOOK_SECRET,
};
