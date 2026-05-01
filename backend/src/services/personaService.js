/**
 * Persona KYC Service
 * v23.1 part 36 — wrapper API Persona pour la vérification d'identité
 * payante (3 EUR) des sitters et walkers HoPetSit.
 *
 * Flow :
 *   1. Daniel paie 3€ via Airwallex (createKycPaymentIntent)
 *   2. Backend crée une Inquiry Persona pour ce user (createInquiry)
 *   3. Frontend ouvre l'URL hosted Persona dans une WebView
 *   4. User scan ID + selfie → Persona traite
 *   5. Webhook /webhooks/persona reçoit inquiry.completed → backend
 *      met User.kycStatus = 'verified' / 'rejected'
 *
 * Env vars requis :
 *   - PERSONA_API_KEY (persona_sandbox_xxx ou persona_live_xxx)
 *   - PERSONA_TEMPLATE_ID (itmpl_xxx — template KYC GovID + Selfie)
 *   - PERSONA_WEBHOOK_SECRET (wbhsec_xxx — pour signature verify)
 */
const logger = require('../utils/logger');
const crypto = require('crypto');

const PERSONA_BASE_URL = 'https://api.withpersona.com/api/v1';

function _authHeader() {
  const key = process.env.PERSONA_API_KEY;
  if (!key) throw new Error('PERSONA_API_KEY env var is not configured.');
  return `Bearer ${key}`;
}

async function _fetch(path, options = {}) {
  const url = `${PERSONA_BASE_URL}${path}`;
  const headers = {
    'Authorization': _authHeader(),
    'Content-Type': 'application/json',
    'Persona-Version': '2023-01-05',
    'Key-Inflection': 'snake',
    ...(options.headers || {}),
  };
  const res = await fetch(url, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const text = await res.text();
  let data;
  try { data = text ? JSON.parse(text) : null; } catch (_) { data = text; }
  if (!res.ok) {
    const msg = data?.errors?.[0]?.title || data?.message || res.statusText;
    const err = new Error(`Persona ${res.status} ${msg}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

/**
 * POST /inquiries
 * Crée une nouvelle Inquiry Persona pour un user. L'inquiry contient
 * l'ID du template (config du flow KYC GovID + Selfie) et les données
 * pré-remplies de l'utilisateur (nom, email).
 *
 * Returns the inquiry object with id, status, and a hosted flow URL.
 */
async function createInquiry({ userId, firstName, lastName, email, role }) {
  const templateId = process.env.PERSONA_TEMPLATE_ID;
  if (!templateId) {
    throw new Error('PERSONA_TEMPLATE_ID env var is not configured.');
  }
  const body = {
    data: {
      attributes: {
        'inquiry-template-id': templateId,
        'reference-id': `${role}_${userId}`, // unique ref to map back to our user
        fields: {
          'name-first': firstName || '',
          'name-last': lastName || '',
          'email-address': email || '',
        },
      },
    },
  };
  return _fetch('/inquiries', { method: 'POST', body });
}

/**
 * POST /inquiries/:id/generate-one-time-link
 * Generates a one-time hosted URL where the user completes the verification
 * (open in a WebView). Each link is single-use and expires.
 */
async function generateOneTimeLink(inquiryId) {
  if (!inquiryId) throw new Error('inquiryId required.');
  return _fetch(`/inquiries/${inquiryId}/generate-one-time-link`, {
    method: 'POST',
  });
}

/**
 * GET /inquiries/:id — fetch the latest state of an inquiry.
 * status values: created | pending | completed | failed | expired | declined | approved
 */
async function getInquiry(inquiryId) {
  if (!inquiryId) throw new Error('inquiryId required.');
  return _fetch(`/inquiries/${inquiryId}`);
}

/**
 * Verify a Persona webhook signature. Persona signs every webhook with
 * HMAC-SHA256 using the webhook secret. Signature is sent as a header
 * `Persona-Signature: t=<timestamp>,v1=<signature>`.
 *
 * @param {Buffer|string} rawBody — raw HTTP body (use express.raw())
 * @param {string} signatureHeader — req.headers['persona-signature']
 * @returns {boolean}
 */
function verifyWebhookSignature(rawBody, signatureHeader) {
  try {
    if (!signatureHeader || !rawBody) return false;
    const secret = process.env.PERSONA_WEBHOOK_SECRET;
    if (!secret) {
      logger.warn('[personaService] PERSONA_WEBHOOK_SECRET not set, skipping signature check (DEV ONLY).');
      return true;
    }
    // Parse "t=...,v1=..." header
    const parts = signatureHeader.split(',').reduce((acc, p) => {
      const [k, v] = p.split('=');
      acc[k.trim()] = v ? v.trim() : '';
      return acc;
    }, {});
    const timestamp = parts.t;
    const signature = parts.v1;
    if (!timestamp || !signature) return false;
    // Persona signs `${timestamp}.${rawBody}`
    const payload = `${timestamp}.${typeof rawBody === 'string' ? rawBody : rawBody.toString('utf8')}`;
    const expected = crypto
      .createHmac('sha256', secret)
      .update(payload)
      .digest('hex');
    return crypto.timingSafeEqual(
      Buffer.from(expected, 'hex'),
      Buffer.from(signature, 'hex'),
    );
  } catch (e) {
    logger.error(`[personaService] verifyWebhookSignature error: ${e.message}`);
    return false;
  }
}

module.exports = {
  createInquiry,
  generateOneTimeLink,
  getInquiry,
  verifyWebhookSignature,
};
