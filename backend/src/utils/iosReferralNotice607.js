'use strict';

/**
 * 607b (ZOE, 01/10/2026) — décision de BOB : la récompense de parrainage
 * (-10 % sur PawFollow / PawFamily) ne peut pas s'utiliser via Apple (refus
 * 3.1.1, codes maison interdits sur iOS). Un parrain dont l'app ACTIVE est
 * l'app iOS ≥ 607 ne reçoit donc plus la notification REFERRAL_CREDITED
 * (ni push, ni cloche, ni l'e-mail qui annonce la réduction).
 *
 * « App active » = la DERNIÈRE plateforme connue du serveur pour la personne
 * (ses 3 profils), d'après les deux traces qu'il garde déjà :
 *   · `fcmDevices` (jeton push : plateforme + build + date d'enregistrement) ;
 *   · `ActivityEvent` (début de session : plateforme + X-App-Version + date).
 * La trace la plus récente qui porte une plateforme gagne.
 *
 * Plateforme inconnue (aucune trace), ou iOS sans numéro de build lisible :
 * le serveur NE SAIT PAS → comportement inchangé (la notification part).
 * Android, site, iOS ≤ 606 : inchangés.
 */

const IOS_NO_REFERRAL_NOTICE_MIN_BUILD = 607;

function buildFrom(value) {
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) return value;
  const m = String(value || '').trim().match(/(?:\+|^)(\d{1,6})$/);
  return m ? Number(m[1]) : null;
}

const _t = (d) => {
  const n = d ? new Date(d).getTime() : NaN;
  return Number.isFinite(n) ? n : 0;
};

/**
 * Trace la plus récente parmi des candidats { platform, build, at }.
 * Fonction PURE. Ignore les traces sans plateforme.
 */
function latestKnownClient(candidates) {
  let best = null;
  for (const c of candidates || []) {
    const platform = String((c && c.platform) || '').trim().toLowerCase();
    if (!platform) continue;
    const at = _t(c.at);
    if (!best || at > best.atMs) best = { platform, build: buildFrom(c.build), at: c.at || null, atMs: at, source: c.source || '' };
  }
  if (!best) return null;
  const { atMs, ...rest } = best;
  return rest;
}

/** Vrai seulement si la dernière app connue est iOS ≥ 607 (build lisible). */
function isIosNoReferralClient(client) {
  return !!client && client.platform === 'ios'
    && client.build !== null && client.build >= IOS_NO_REFERRAL_NOTICE_MIN_BUILD;
}

/** Lit les traces de la personne (3 profils) puis rend la dernière connue. */
async function lastKnownClientOf(userId) {
  const { identityGroup } = require('./identityGroup');
  const group = await identityGroup(userId);
  const models = {
    Owner: require('../models/Owner'),
    Sitter: require('../models/Sitter'),
    Walker: require('../models/Walker'),
  };
  const candidates = [];
  const docs = group.docs && group.docs.length ? group.docs : [];
  await Promise.all(docs.map(async ({ id, model }) => {
    const M = models[model];
    if (!M) return;
    const d = await M.findById(id).select('fcmDevices').lean().catch(() => null);
    for (const dev of (d && Array.isArray(d.fcmDevices) ? d.fcmDevices : [])) {
      candidates.push({ platform: dev.platform, build: dev.appBuild, at: dev.at, source: 'fcm' });
    }
  }));
  try {
    const ActivityEvent = require('../models/ActivityEvent');
    const ev = await ActivityEvent.findOne({ userId: { $in: group.ids }, platform: { $nin: ['', null] } })
      .sort({ at: -1 }).select('platform appVersion at').lean();
    if (ev) candidates.push({ platform: ev.platform, build: ev.appVersion, at: ev.at, source: 'activity' });
  } catch (_) { /* trace absente = inconnue */ }
  return latestKnownClient(candidates);
}

/**
 * Faut-il taire l'annonce -10 % pour ce parrain ? Ne lève jamais :
 * en cas d'erreur de lecture → false (comportement actuel conservé).
 */
async function shouldSkipReferralNotice(userId) {
  try {
    return isIosNoReferralClient(await lastKnownClientOf(userId));
  } catch (_) {
    return false;
  }
}

module.exports = {
  IOS_NO_REFERRAL_NOTICE_MIN_BUILD,
  latestKnownClient,
  isIosNoReferralClient,
  lastKnownClientOf,
  shouldSkipReferralNotice,
};
