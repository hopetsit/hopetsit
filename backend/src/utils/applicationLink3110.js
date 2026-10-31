/**
 * 31/10/2026 (LEO, feu vert de BOB 13 h 15) — LIEN SIGNÉ « mes candidats → payer ».
 *
 * Mesure de BOB : 37 propriétaires sur 39 n'ont pas l'app ; ils reviennent par le lien de
 * l'e-mail ou du SMS et tombaient sur la page de connexion (mot de passe) dès qu'ils ouvraient
 * le lien sur un autre navigateur. Seuls les contacts de la pub (AdLead) arrivaient connectés.
 *
 * Règles (BOB) :
 *   · jeton à durée limitée (14 jours), lié AU PROPRIÉTAIRE et À LA CANDIDATURE (donc à la demande) ;
 *   · utilisable sur /application/<id> seulement : le site l'échange contre une session par
 *     POST /auth/application-link, et la cible du jeton doit être la candidature du chemin ;
 *   · invalidé si la demande est close, ou déjà réservée ET payée ;
 *   · jamais signé pour un compte +test dont la demande n'est pas en zone fictive (lat −35 / lng −30) ;
 *   · réutilisable tant qu'il est valable : un propriétaire rouvre le même e-mail plusieurs fois
 *     (Tremblay : 8 visites) — un jeton à usage unique l'aurait renvoyé au mot de passe dès la 2e fois.
 *
 * Format : base64url(JSON {v:1, o:ownerId, a:applicationId, p:postId, e:expMs}) + "." +
 *          base64url(HMAC-SHA256(payload, JWT_SECRET)). Rien n'est stocké en base.
 */
const crypto = require('crypto');

const TTL_MS = 14 * 24 * 3600 * 1000;
const PARAM = 'k';
const OID = /^[a-f0-9]{24}$/i;
// Zone fictive de test (règle d'équipe) : lat −35 / lng −30, à ±1°.
const FICTIVE = { lat: -35, lng: -30, tol: 1 };

const secret = () => process.env.JWT_SECRET || '';
const b64u = (buf) => Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const unb64u = (s) => Buffer.from(String(s).replace(/-/g, '+').replace(/_/g, '/'), 'base64');
const hmac = (payload) => b64u(crypto.createHmac('sha256', secret()).update(payload).digest());

/** Jeton signé, ou '' si une donnée manque (jamais d'exception : un e-mail sans jeton part quand même). */
const signApplicationLink = (ownerId, applicationId, { postId = '', now = Date.now(), ttlMs = TTL_MS } = {}) => {
  const o = String(ownerId || '');
  const a = String(applicationId || '');
  if (!secret() || !OID.test(o) || !OID.test(a)) return '';
  const payload = b64u(JSON.stringify({ v: 1, o, a, p: OID.test(String(postId || '')) ? String(postId) : '', e: now + ttlMs }));
  return `${payload}.${hmac(payload)}`;
};

/** { ok, reason, ownerId, applicationId, postId } — vérifie signature et date, rien d'autre. */
const verifyApplicationLink = (token, { now = Date.now() } = {}) => {
  try {
    if (!secret() || typeof token !== 'string' || token.length > 600) return { ok: false, reason: 'format' };
    const [payload, sig] = token.split('.');
    if (!payload || !sig) return { ok: false, reason: 'format' };
    const expected = hmac(payload);
    const A = Buffer.from(sig);
    const B = Buffer.from(expected);
    if (A.length !== B.length || !crypto.timingSafeEqual(A, B)) return { ok: false, reason: 'signature' };
    const data = JSON.parse(unb64u(payload).toString('utf8'));
    if (!data || data.v !== 1 || !OID.test(String(data.o || '')) || !OID.test(String(data.a || ''))) return { ok: false, reason: 'format' };
    if (!Number.isFinite(data.e) || data.e < now) return { ok: false, reason: 'expired' };
    return { ok: true, ownerId: String(data.o), applicationId: String(data.a), postId: String(data.p || ''), expiresAt: data.e };
  } catch (_) {
    return { ok: false, reason: 'format' };
  }
};

const inFictiveZone = (loc) => {
  if (!loc) return false;
  let lat = typeof loc.lat === 'number' ? loc.lat : null;
  let lng = typeof loc.lng === 'number' ? loc.lng : null;
  if (lat == null && Array.isArray(loc.coordinates) && loc.coordinates.length >= 2) { lng = Number(loc.coordinates[0]); lat = Number(loc.coordinates[1]); }
  if (lat == null || lng == null || !Number.isFinite(lat) || !Number.isFinite(lng)) return false;
  return Math.abs(lat - FICTIVE.lat) <= FICTIVE.tol && Math.abs(lng - FICTIVE.lng) <= FICTIVE.tol;
};

const isTestEmail = (raw) => {
  let plain = String(raw || '');
  try { plain = String(require('./encryption').decrypt(plain) || plain); } catch (_) { /* déjà en clair */ }
  return /\+test/i.test(plain) || /^probe-/i.test(plain) || /@invalid\.example$/i.test(plain);
};

/**
 * Ajoute `&k=<jeton>` à un lien du site qui vise /application/<id> (chemin exact), pour un
 * PROPRIÉTAIRE. Tout autre lien, rôle ou cas douteux revient inchangé. Jamais d'exception.
 * Un compte +test n'a un jeton que si la demande de la candidature est en zone fictive.
 */
const withSignedApplicationLink = async (role, userId, link) => {
  try {
    if (String(role || '').toLowerCase() !== 'owner' || !userId || typeof link !== 'string') return link;
    const m = link.match(/^(https?:\/\/[^/]+)?\/application\/([a-f0-9]{24})(\?[^#]*)?$/i);
    if (!m) return link;
    if (/[?&]k=/.test(m[3] || '')) return link;
    const applicationId = m[2];
    let postId = '';
    let appDoc = null;
    try {
      const Application = require('../models/Application');
      if (Application.db && Application.db.readyState === 1) {
        appDoc = await Application.findById(applicationId).select('ownerId postId').lean();
      }
    } catch (_) { appDoc = null; }
    // La candidature doit appartenir à ce propriétaire (sinon pas de jeton : le lien reste normal).
    if (appDoc && String(appDoc.ownerId || '') !== String(userId)) return link;
    if (appDoc && appDoc.postId) postId = String(appDoc.postId);
    try {
      const Owner = require('../models/Owner');
      if (Owner.db && Owner.db.readyState === 1) {
        const o = await Owner.findById(userId).select('email').lean();
        if (o && isTestEmail(o.email)) {
          let loc = null;
          if (postId) {
            const Post = require('../models/Post');
            const p = await Post.findById(postId).select('location').lean();
            loc = p && p.location;
          }
          if (!inFictiveZone(loc)) return link;
        }
      }
    } catch (_) { return link; }
    const token = signApplicationLink(userId, applicationId, { postId });
    if (!token) return link;
    const sep = m[3] ? '&' : '?';
    return `${link}${sep}${PARAM}=${token}`;
  } catch (_) {
    return link;
  }
};

/**
 * Contrôle complet pour l'échange (route /auth/application-link) :
 * signature + date, candidature existante et à ce propriétaire, demande ni close ni payée.
 * Renvoie { ok, status, error, ownerId, application } ; ne signe PAS la session (l'appelant le fait).
 */
const checkApplicationLink = async (token, { now = Date.now() } = {}) => {
  const v = verifyApplicationLink(token, { now });
  if (!v.ok) return { ok: false, status: v.reason === 'expired' ? 410 : 401, error: v.reason === 'expired' ? 'LINK_EXPIRED' : 'LINK_INVALID' };
  const Application = require('../models/Application');
  const app = await Application.findById(v.applicationId).select('ownerId postId status bookingId').lean();
  if (!app || String(app.ownerId || '') !== v.ownerId) return { ok: false, status: 401, error: 'LINK_INVALID' };
  if (app.postId) {
    const Post = require('../models/Post');
    const post = await Post.findById(app.postId).select('status').lean();
    if (!post || String(post.status || 'open') === 'closed') return { ok: false, status: 410, error: 'REQUEST_CLOSED' };
  }
  if (app.bookingId) {
    const Booking = require('../models/Booking');
    const bk = await Booking.findById(app.bookingId).select('paymentStatus status').lean();
    if (bk && (String(bk.paymentStatus || '') === 'paid' || String(bk.status || '') === 'paid')) return { ok: false, status: 410, error: 'REQUEST_BOOKED' };
  }
  return { ok: true, ownerId: v.ownerId, application: app };
};

module.exports = { signApplicationLink, verifyApplicationLink, withSignedApplicationLink, checkApplicationLink, inFictiveZone, isTestEmail, TTL_MS, PARAM };
