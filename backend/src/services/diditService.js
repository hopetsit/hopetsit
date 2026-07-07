/**
 * Didit KYC Service — v510
 * Daniel : « il faut remplacer Persona par Didit, sans rebuild l'app ».
 *
 * Remplace personaService pour la vérification d'identité des sitters /
 * walkers. Le flux app est INCHANGÉ (aucun rebuild) : l'app appelle
 * POST /kyc/start qui renvoie { inquiryId, oneTimeLink, kycStatus } — on
 * met simplement l'URL de session Didit dans oneTimeLink et l'app l'ouvre
 * dans sa WebView comme avant.
 *
 * ⚠️ Contrainte WebView app (kyc_verification_screen.dart) : la WebView se
 * ferme quand une navigation contient « complete », « cancelled » ou
 * « failed ». On passe donc à Didit un callback contenant « complete »
 * (https://hopetsit.com/kyc-complete) → à la fin du parcours Didit
 * redirige dessus → la WebView se ferme, puis l'app poll /kyc/status.
 *
 * API Didit v3 (docs.didit.me) :
 *   POST https://verification.didit.me/v3/session/            (x-api-key)
 *     body { workflow_id, vendor_data, callback, contact_details }
 *     → { session_id, url, status: 'Not Started', ... }
 *   GET  https://verification.didit.me/v3/session/{id}/decision/
 *     → { session_id, status, session_url, ... }
 *   Webhook : HMAC-SHA256 des bytes bruts avec la Webhook Secret Key,
 *     headers X-Signature + X-Timestamp (fenêtre 5 min).
 *
 * Env vars (Render) :
 *   - DIDIT_API_KEY        (console Didit → Settings → API Key)
 *   - DIDIT_WORKFLOW_ID    (console Didit → Workflows → UUID du workflow KYC)
 *   - DIDIT_WEBHOOK_SECRET (console Didit → Webhooks → Secret Key)
 *   - DIDIT_CALLBACK_URL   (optionnel, défaut https://hopetsit.com/kyc-complete)
 *
 * Bascule de fournisseur : dès que DIDIT_API_KEY + DIDIT_WORKFLOW_ID sont
 * présents, kycController utilise Didit ; sinon Persona continue → zéro
 * coupure pendant la transition.
 */
const crypto = require('crypto');
const logger = require('../utils/logger');

const DIDIT_BASE_URL = 'https://verification.didit.me/v3';
const DEFAULT_CALLBACK = 'https://hopetsit.com/kyc-complete';

function isConfigured() {
  return !!(process.env.DIDIT_API_KEY && process.env.DIDIT_WORKFLOW_ID);
}

async function _fetch(path, options = {}) {
  const key = process.env.DIDIT_API_KEY;
  if (!key) throw new Error('DIDIT_API_KEY env var is not configured.');
  const url = `${DIDIT_BASE_URL}${path}`;
  const res = await fetch(url, {
    method: options.method || 'GET',
    headers: {
      'x-api-key': key,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const text = await res.text();
  let data;
  try { data = text ? JSON.parse(text) : null; } catch (_) { data = text; }
  if (!res.ok) {
    const msg = data?.detail || data?.message || res.statusText;
    const err = new Error(`Didit ${res.status} ${msg}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

/**
 * POST /v3/session/ — crée une session de vérification pour un user.
 * vendor_data = `${role}_${userId}` (même convention que le reference-id
 * Persona → le webhook retrouve le user pareil).
 * Returns { session_id, url, status }.
 */
async function createSession({ userId, role, email, language }) {
  const workflowId = process.env.DIDIT_WORKFLOW_ID;
  if (!workflowId) throw new Error('DIDIT_WORKFLOW_ID env var is not configured.');
  const body = {
    workflow_id: workflowId,
    vendor_data: `${role}_${userId}`,
    callback: process.env.DIDIT_CALLBACK_URL || DEFAULT_CALLBACK,
  };
  if (language) body.language = language;
  if (email) {
    body.contact_details = { email, send_notification_emails: false };
  }
  const session = await _fetch('/session/', { method: 'POST', body });
  logger.info(
    `[didit] session created ${session?.session_id} for ${role}_${userId} status=${session?.status}`,
  );
  return session;
}

/**
 * GET /v3/session/{id}/decision/ — statut + décision d'une session.
 */
async function getSessionDecision(sessionId) {
  return _fetch(`/session/${encodeURIComponent(sessionId)}/decision/`);
}

/**
 * Mappe le statut Didit → kycStatus HoPetSit.
 * Retourne { newStatus: 'verified'|'rejected'|null, rejectionReason } ;
 * null = pas de changement (toujours en cours / en review / abandonné —
 * l'user peut relancer, ça recrée une session).
 * Statuts Didit : Not Started, In Progress, Awaiting User, Resubmitted,
 * In Review, Approved, Declined, Abandoned, Expired, Kyc Expired.
 */
function mapStatus(diditStatus) {
  const s = String(diditStatus || '').toLowerCase();
  if (s === 'approved') return { newStatus: 'verified', rejectionReason: null };
  if (s === 'declined') {
    return { newStatus: 'rejected', rejectionReason: 'Verification declined by Didit.' };
  }
  if (s === 'expired' || s === 'kyc expired') {
    return { newStatus: 'rejected', rejectionReason: 'Verification link expired.' };
  }
  // In Review / In Progress / Not Started / Awaiting User / Resubmitted /
  // Abandoned → on ne touche pas kycStatus (reste pending_verification).
  return { newStatus: null, rejectionReason: null };
}

/** Statuts pour lesquels une session existante est encore réutilisable. */
const REUSABLE_STATUSES = new Set([
  'not started', 'in progress', 'awaiting user', 'resubmitted',
]);
function isSessionReusable(diditStatus) {
  return REUSABLE_STATUSES.has(String(diditStatus || '').toLowerCase());
}

/**
 * Vérifie la signature HMAC du webhook Didit.
 * X-Signature = HMAC-SHA256 hex des bytes BRUTS du body, clé = Webhook
 * Secret Key. X-Timestamp doit être frais (± 5 min).
 */
function verifyWebhookSignature(rawBody, signature, timestamp) {
  const secret = process.env.DIDIT_WEBHOOK_SECRET;
  if (!secret) {
    logger.error('[didit.webhook] DIDIT_WEBHOOK_SECRET not configured — rejecting webhook.');
    return false;
  }
  if (!signature || !rawBody) return false;
  const ts = Number(timestamp);
  if (!Number.isFinite(ts) || Math.abs(Date.now() / 1000 - ts) > 300) {
    logger.warn(`[didit.webhook] stale or invalid timestamp: ${timestamp}`);
    return false;
  }
  const expected = crypto
    .createHmac('sha256', secret)
    .update(rawBody, 'utf8')
    .digest('hex');
  try {
    return crypto.timingSafeEqual(
      Buffer.from(expected, 'utf8'),
      Buffer.from(String(signature), 'utf8'),
    );
  } catch (_) {
    return false;
  }
}

module.exports = {
  isConfigured,
  createSession,
  getSessionDecision,
  mapStatus,
  isSessionReusable,
  verifyWebhookSignature,
};
