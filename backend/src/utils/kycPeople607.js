'use strict';

/**
 * 607 (FLO, 02/10/2026) — Vérifications d'identité : qui est vérifié, par
 * quelle méthode, qui a payé 3 € sans être vérifié. Daniel : « je veux voir
 * la liste des personnes vérifiées » + les payés-non-vérifiés (cas réel du
 * 18/09 : 3 € payés, vérification jamais lancée, invisible pendant 14 jours).
 *
 * Fonctions PURES (aucun accès base) : la route admin
 * (routes/adminKycRoutes607.js) lit les documents Sitter / Walker et passe ici.
 */

const KYC_PRICE_EUR = 3;
// Au-delà d'une heure après le paiement sans session chez le prestataire de
// vérification, la vérification est considérée comme BLOQUÉE.
const STUCK_AFTER_MS = 60 * 60 * 1000;

const isVerifiedDoc = (d) => !!d && (
  d.kycStatus === 'verified'
  || !!(d.identityVerification && d.identityVerification.status === 'verified')
);

/**
 * Méthode de vérification :
 *  - 'admin_manual' : validée à la main dans l'admin
 *    (PATCH /admin/identity-verifications/:id pose identityVerification.reviewedAt) ;
 *  - 'didit' / 'persona' : résultat du prestataire (webhook ou relecture
 *    /kyc/status) — reconnu à l'identifiant de session stocké ;
 *  - 'inconnue' sinon.
 */
function methodOf(d) {
  const iv = d.identityVerification || {};
  if (iv.status === 'verified' && iv.reviewedAt) return 'admin_manual';
  const app = String(d.kycApplicantId || '');
  if (app.startsWith('inq_')) return 'persona';
  if (app) return 'didit';
  return 'inconnue';
}

function paymentChannelOf(d) {
  if (!d.kycPaidAt) return null;
  const ref = String(d.kycPaymentIntentId || '');
  if (ref.startsWith('wallet_')) return 'wallet';
  if (ref) return 'airwallex';
  return 'inconnu';
}

const cityOf = (d) => String(
  d.city || (d.location && d.location.city) || d.coverageCity || '',
).trim();

/**
 * Une ligne par profil (gardien / promeneur) qui est vérifié OU qui a payé.
 * @param {object} d   document lean Sitter/Walker
 * @param {string} role 'sitter' | 'walker'
 * @param {{now?: Date, isInternal?: (d)=>boolean}} opts
 */
function personRow(d, role, { now = new Date(), isInternal = () => false } = {}) {
  const verified = isVerifiedDoc(d);
  const paid = !!d.kycPaidAt;
  const iv = d.identityVerification || {};
  const verifiedAt = verified
    ? (d.kycVerifiedAt || iv.reviewedAt || null)
    : null;
  let blocked = null;
  if (paid && !verified) {
    const since = new Date(d.kycPaidAt).getTime();
    if (d.kycStatus === 'rejected') blocked = 'refusee';
    else if (!d.kycApplicantId && now.getTime() - since > STUCK_AFTER_MS) blocked = 'session_jamais_creee';
    else if (d.kycApplicantId && now.getTime() - since > 7 * 24 * 3600 * 1000) blocked = 'session_ouverte_sans_resultat';
    else blocked = 'en_cours';
  }
  return {
    id: String(d._id),
    role,
    name: d.name || '',
    city: cityOf(d),
    verified,
    verifiedAt,
    method: verified ? methodOf(d) : null,
    paid,
    paidAt: d.kycPaidAt || null,
    paidAmount: paid ? KYC_PRICE_EUR : 0,
    paymentChannel: paymentChannelOf(d),
    kycStatus: d.kycStatus || 'none',
    providerSessionStarted: !!d.kycApplicantId,
    blocked,
    daysSincePayment: paid
      ? Math.floor((now.getTime() - new Date(d.kycPaidAt).getTime()) / 86400000)
      : null,
    isTest: !!isInternal(d),
  };
}

/** Résumé + revenus KYC par période (seuls les comptes réels comptent). */
function summarize(rows, { now = new Date() } = {}) {
  const real = rows.filter((r) => !r.isTest);
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
  const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const paidSince = (t) => real.filter((r) => r.paid && new Date(r.paidAt).getTime() >= t);
  const money = (list) => ({ count: list.length, total: list.length * KYC_PRICE_EUR });
  return {
    verified: real.filter((r) => r.verified).length,
    verifiedByMethod: real.filter((r) => r.verified).reduce((acc, r) => {
      acc[r.method] = (acc[r.method] || 0) + 1; return acc;
    }, {}),
    paidUnverified: real.filter((r) => r.paid && !r.verified).length,
    blocked: real.filter((r) => r.blocked && r.blocked !== 'en_cours').length,
    revenue: {
      currency: 'EUR',
      allTime: money(real.filter((r) => r.paid)),
      thisMonth: money(paidSince(monthStart)),
      last30d: money(paidSince(now.getTime() - 30 * 86400000)),
      last7d: money(paidSince(now.getTime() - 7 * 86400000)),
      today: money(paidSince(dayStart)),
    },
    testAccounts: rows.length - real.length,
  };
}

/**
 * 3010 (ADA, demande de Daniel 30/10 15 h : « la vérification du profil doit être sur les 3 profils et
 * compter comme UNE par personne »). Regroupe les lignes de profils (personRow) par PERSONNE.
 * @param {object[]} rows   lignes personRow, chacune avec `personKey` (e-mail déchiffré normalisé, ou id)
 * @param {Map<string,string[]>} [rolesByKey]  personKey → rôles EXISTANTS de la personne (owner/sitter/walker)
 * Une ligne par personne : roles = profils existants (ordre sitter, walker, owner), rolesVerified = par rôle,
 * verifiedAt = la plus ancienne, method = celle du profil source (le plus ancien vérifié), paid/paidAt = le
 * paiement de 3 € une seule fois (le plus ancien), blocked = seulement si AUCUN profil n'est vérifié.
 */
const ROLE_ORDER = ['sitter', 'walker', 'owner'];
function groupByPerson(rows, rolesByKey = new Map()) {
  const groups = new Map();
  for (const r of rows) {
    const k = r.personKey || r.id;
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(r);
  }
  const ts = (x) => (x ? new Date(x).getTime() : Infinity);
  const out = [];
  for (const [k, list] of groups) {
    const verifiedRows = list.filter((r) => r.verified).sort((a, b) => ts(a.verifiedAt) - ts(b.verifiedAt));
    const paidRows = list.filter((r) => r.paid).sort((a, b) => ts(a.paidAt) - ts(b.paidAt));
    const source = verifiedRows[0] || paidRows[0] || list[0];
    const paidSrc = paidRows[0] || null;
    const roles = new Set([...(rolesByKey.get(k) || []), ...list.map((r) => r.role)]);
    const rolesVerified = {};
    for (const r of list) rolesVerified[r.role] = rolesVerified[r.role] || !!r.verified;
    const blockedSrc = verifiedRows.length ? null : (paidRows.find((r) => r.blocked) || null);
    out.push({
      ...source,
      personKey: undefined,
      roles: ROLE_ORDER.filter((x) => roles.has(x)),
      rolesVerified,
      profiles: list.length,
      verified: verifiedRows.length > 0,
      verifiedAt: verifiedRows.length ? verifiedRows[0].verifiedAt : null,
      method: verifiedRows.length ? verifiedRows[0].method : null,
      paid: paidRows.length > 0,
      paidAt: paidSrc ? paidSrc.paidAt : null,
      paidAmount: paidSrc ? KYC_PRICE_EUR : 0,
      paymentChannel: paidSrc ? paidSrc.paymentChannel : null,
      daysSincePayment: paidSrc ? paidSrc.daysSincePayment : null,
      blocked: blockedSrc ? blockedSrc.blocked : null,
      kycStatus: source.kycStatus,
      providerSessionStarted: list.some((r) => r.providerSessionStarted),
      isTest: list.some((r) => r.isTest),
    });
  }
  return out.map((r) => { delete r.personKey; return r; });
}

module.exports = {
  KYC_PRICE_EUR, STUCK_AFTER_MS, isVerifiedDoc, methodOf, paymentChannelOf, personRow, summarize, groupByPerson, ROLE_ORDER,
};
