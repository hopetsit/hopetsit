/**
 * Onfido KYC Service
 * v23.1 part 36 — wrapper API Onfido pour la vérification d'identité
 * payante (3 EUR) des sitters et walkers.
 *
 * Flow :
 *   1. createApplicant({ firstName, lastName, email }) → returns applicantId
 *   2. createSdkToken(applicantId) → returns sdkToken (frontend SDK)
 *   3. createCheck(applicantId) → triggers document + face check, returns checkId
 *   4. webhook /onfido/webhook reçoit check.completed → backend met
 *      User.kycStatus = 'verified' ou 'rejected'.
 *
 * Env vars requis :
 *   - ONFIDO_API_TOKEN (api_sandbox.* pour test, api_live.* pour prod)
 *   - ONFIDO_REGION (eu | us | ca, default eu)
 *   - ONFIDO_WEBHOOK_TOKEN (signature secret webhook)
 */
const logger = require('../utils/logger');

const REGION_HOSTS = {
  eu: 'https://api.eu.onfido.com',
  us: 'https://api.us.onfido.com',
  ca: 'https://api.ca.onfido.com',
};

function _baseUrl() {
  const region = (process.env.ONFIDO_REGION || 'eu').toLowerCase();
  return REGION_HOSTS[region] || REGION_HOSTS.eu;
}

function _authHeader() {
  const token = process.env.ONFIDO_API_TOKEN;
  if (!token) {
    throw new Error('ONFIDO_API_TOKEN env var is not configured.');
  }
  return `Token token=${token}`;
}

async function _fetch(path, options = {}) {
  const url = `${_baseUrl()}/v3.6${path}`;
  const headers = {
    'Authorization': _authHeader(),
    'Content-Type': 'application/json',
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
    const msg = data?.error?.message || data?.error?.type || res.statusText;
    const err = new Error(`Onfido ${res.status} ${msg}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

/**
 * POST /applicants
 * Creates an Onfido applicant for a user (one per HoPetSit user).
 * Returns the applicant object (id, first_name, last_name, ...).
 */
async function createApplicant({ firstName, lastName, email }) {
  if (!firstName || !lastName) {
    throw new Error('firstName and lastName are required for Onfido applicant.');
  }
  return _fetch('/applicants', {
    method: 'POST',
    body: {
      first_name: firstName,
      last_name: lastName,
      email: email || undefined,
    },
  });
}

/**
 * POST /sdk_token
 * Creates an SDK token for the Onfido Flutter SDK to authenticate the
 * client-side flow. Token is single-use (one verification flow) and
 * expires after 90min.
 *
 * @param {string} applicantId
 * @param {string} [referrer] — for web embedding (optional). Mobile apps
 *   pass applicationId via SDK config.
 */
async function createSdkToken(applicantId, referrer = null) {
  if (!applicantId) throw new Error('applicantId required.');
  const body = { applicant_id: applicantId };
  if (referrer) body.referrer = referrer;
  return _fetch('/sdk_token', {
    method: 'POST',
    body,
  });
}

/**
 * POST /workflow_runs
 * Triggers the verification workflow (document + face liveness + auto check).
 * Workflows are created in the Onfido Dashboard (one workflow id per setup).
 *
 * @param {string} applicantId
 * @param {string} workflowId — pre-configured in Onfido Dashboard
 */
async function createWorkflowRun(applicantId, workflowId) {
  if (!applicantId) throw new Error('applicantId required.');
  const wf = workflowId || process.env.ONFIDO_WORKFLOW_ID;
  if (!wf) throw new Error('ONFIDO_WORKFLOW_ID env var is not configured.');
  return _fetch('/workflow_runs', {
    method: 'POST',
    body: {
      workflow_id: wf,
      applicant_id: applicantId,
    },
  });
}

/**
 * GET /workflow_runs/:id — fetch the result of a workflow run.
 * Status values : awaiting_input | processing | approved | review | declined | abandoned
 */
async function getWorkflowRun(workflowRunId) {
  if (!workflowRunId) throw new Error('workflowRunId required.');
  return _fetch(`/workflow_runs/${workflowRunId}`);
}

/**
 * Verify Onfido webhook signature.
 * Onfido signs payloads with HMAC-SHA256 over the raw body using the
 * webhook token (set in dashboard). The signature is sent in the
 * X-SHA2-Signature header.
 *
 * @param {Buffer|string} rawBody — Express raw body (use express.raw() or middleware)
 * @param {string} signature — req.headers['x-sha2-signature']
 * @returns {boolean}
 */
function verifyWebhookSignature(rawBody, signature) {
  try {
    if (!signature || !rawBody) return false;
    const token = process.env.ONFIDO_WEBHOOK_TOKEN;
    if (!token) {
      logger.warn('[onfidoService] ONFIDO_WEBHOOK_TOKEN not set, skipping signature check (DEV ONLY).');
      return true;
    }
    const crypto = require('crypto');
    const expected = crypto
      .createHmac('sha256', token)
      .update(rawBody)
      .digest('hex');
    return crypto.timingSafeEqual(
      Buffer.from(expected),
      Buffer.from(signature),
    );
  } catch (e) {
    logger.error(`[onfidoService] verifyWebhookSignature error: ${e.message}`);
    return false;
  }
}

module.exports = {
  createApplicant,
  createSdkToken,
  createWorkflowRun,
  getWorkflowRun,
  verifyWebhookSignature,
};
