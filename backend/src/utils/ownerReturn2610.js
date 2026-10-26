/**
 * 26/10/2026 (ADA, décision de Daniel — proposition C de SAM) — MESURE FIABLE
 * des propriétaires qui reviennent vraiment voir leurs candidats.
 *
 * Le piège mesuré par SAM : nos propres scripts (replacement au code postal du
 * 23/10, rattrapage des dates du 24/10…) se connectent avec la session d'un
 * propriétaire (jeton rendu par POST /ad-leads/:id/confirm) et faisaient
 * bouger « dernière activité » : « Claire revenue le 24/10 à 18 h 06 » était
 * un script.
 *
 * Méthode retenue : l'ORIGINE de chaque requête connectée est classée côté
 * serveur, à partir de ce que seuls nos vrais clients envoient :
 *   · app    : l'app Flutter envoie X-App-Version « 23.1.x+NNN » (chiffres)
 *              et un User-Agent « Dart/… » ;
 *   · web    : le site envoie un vrai User-Agent de navigateur (« Mozilla/… »),
 *              hors navigateur sans tête (« HeadlessChrome » = nos bancs) ;
 *   · script : tout le reste — Python-urllib, curl, node, sans User-Agent,
 *              navigateur sans tête — ET toute requête qui porte l'en-tête
 *              explicite `X-HPS-Script` (nos scripts peuvent s'annoncer, ça
 *              l'emporte sur tout).
 * Une session « script » est quand même notée (avec origin = 'script', pour
 * la transparence) mais ne compte JAMAIS comme un retour : elle ne touche plus
 * `lastSeenAt`, ne lance pas les PawPoints, et le tableau des demandes
 * l'écarte. Les sessions d'avant ce changement n'ont pas d'origine : on les
 * juge comme SAM l'a fait à la main (une version d'app ou « web » = réelle,
 * rien = script).
 *
 * Aucune donnée personnelle nouvelle : on garde déjà plateforme + version.
 */

const SCRIPT_UA_RE = /headless|python|curl|wget|\bnode\b|node-fetch|undici|axios|go-http|java\/|okhttp|postman|insomnia|httpie|libwww|scrapy|bot\b|spider|crawl|lighthouse|puppeteer|playwright/i;

function _h(req, name) {
  const v = req && req.headers ? req.headers[name] : '';
  return String(v || '').slice(0, 300);
}

/**
 * Origine d'une requête connectée : 'app' | 'web' | 'script'. Pur, testable.
 */
function classifyOrigin(req) {
  if (_h(req, 'x-hps-script')) return 'script';
  const ua = _h(req, 'user-agent');
  const ver = _h(req, 'x-app-version').trim();
  if (ua && SCRIPT_UA_RE.test(ua) && !/dart/i.test(ua)) return 'script';
  if (/^\d/.test(ver) || /\bdart\//i.test(ua)) return 'app';
  if (/mozilla\//i.test(ua)) return 'web';
  return 'script';
}

const isRealOrigin = (o) => o === 'app' || o === 'web';

/** Une session enregistrée (ActivityEvent) est-elle un VRAI retour ? */
function isRealSession(ev) {
  if (!ev) return false;
  if (ev.origin) return isRealOrigin(ev.origin);
  // Sessions d'avant le 26/10 : pas d'origine → règle de SAM.
  return !!String(ev.appVersion || '').trim();
}

/** Filtre Mongo équivalent à isRealSession. */
const REAL_SESSION_FILTER = {
  $or: [
    { origin: { $in: ['app', 'web'] } },
    { origin: { $exists: false }, appVersion: { $nin: ['', null] } },
  ],
};

const SOURCES = ['email', 'push', 'notification', 'direct', 'link'];
const CHANNELS = ['web', 'app'];

/**
 * Pour le tableau des demandes : signaux par propriétaire (lecture seule).
 * items : éléments du board ({ postId, owner: { id }, stages.published.at }).
 * Renvoie Map postId → {
 *   lastRealReturnAt, lastRealReturnChannel, realSessionsSincePublish,
 *   lastScriptAt,                                   // transparence : nos scripts
 *   candidatesView: { count, firstAt, lastAt, fromEmail, channels: { web, app } },
 *   hasApp,                                          // jeton push présent (oui/non)
 * }
 */
async function boardSignals(items) {
  const out = new Map();
  if (!Array.isArray(items) || !items.length) return out;
  const Owner = require('../models/Owner');
  const Sitter = require('../models/Sitter');
  const Walker = require('../models/Walker');
  const ActivityEvent = require('../models/ActivityEvent');
  const CandidatesView = require('../models/CandidatesView2610');

  const ownerIds = [...new Set(items.map((it) => String(it.owner && it.owner.id || '')).filter((s) => /^[a-f0-9]{24}$/i.test(s)))];
  const owners = await Owner.find({ _id: { $in: ownerIds } }).select('email fcmTokens').lean();
  const emailOf = new Map(owners.map((o) => [String(o._id), String(o.email || '').toLowerCase()]));
  const emails = [...new Set([...emailOf.values()].filter(Boolean))];
  // Toute la personne (ses 3 profils, reliés par l'e-mail) : l'app peut être ouverte sur un autre rôle.
  const groupIds = new Map(); // email → [ids]
  const pushByEmail = new Map(); // email → bool
  const add = (d) => {
    const e = String(d.email || '').toLowerCase(); if (!e) return;
    if (!groupIds.has(e)) groupIds.set(e, []);
    groupIds.get(e).push(String(d._id));
    if (Array.isArray(d.fcmTokens) && d.fcmTokens.length) pushByEmail.set(e, true);
  };
  if (emails.length) {
    const [o2, s2, w2] = await Promise.all([Owner, Sitter, Walker].map((M) => M.find({ email: { $in: emails } }).select('email fcmTokens').lean()));
    [...o2, ...s2, ...w2].forEach(add);
  }
  for (const o of owners) {
    if (!emailOf.get(String(o._id))) { groupIds.set(`id:${o._id}`, [String(o._id)]); if (Array.isArray(o.fcmTokens) && o.fcmTokens.length) pushByEmail.set(`id:${o._id}`, true); }
  }
  const keyOfOwner = (id) => emailOf.get(id) || `id:${id}`;
  const allIds = [...new Set([...groupIds.values()].flat())];
  const idToKey = new Map();
  for (const [k, ids] of groupIds) for (const i of ids) idToKey.set(i, k);

  const [events, views] = await Promise.all([
    allIds.length ? ActivityEvent.find({ userId: { $in: allIds } }).select('userId at platform appVersion origin').sort({ at: -1 }).limit(20000).lean() : [],
    CandidatesView.find({ postId: { $in: items.map((it) => String(it.postId)) } }).select('postId at channel source origin').lean(),
  ]);
  const evByKey = new Map();
  for (const ev of events) {
    const k = idToKey.get(String(ev.userId)); if (!k) continue;
    if (!evByKey.has(k)) evByKey.set(k, []);
    evByKey.get(k).push(ev);
  }
  const viewsByPost = new Map();
  for (const v of views) {
    if (!isRealOrigin(v.origin)) continue;
    const k = String(v.postId);
    if (!viewsByPost.has(k)) viewsByPost.set(k, []);
    viewsByPost.get(k).push(v);
  }
  for (const it of items) {
    const key = keyOfOwner(String(it.owner && it.owner.id || ''));
    const evs = evByKey.get(key) || [];
    const pub = it.stages && it.stages.published && it.stages.published.at ? new Date(it.stages.published.at).getTime() : 0;
    const real = evs.filter(isRealSession);
    const script = evs.filter((e) => !isRealSession(e));
    const lastReal = real[0] || null;
    const vs = (viewsByPost.get(String(it.postId)) || []).sort((a, b) => new Date(a.at) - new Date(b.at));
    out.set(String(it.postId), {
      lastRealReturnAt: lastReal ? lastReal.at : null,
      lastRealReturnChannel: lastReal ? (lastReal.origin || (String(lastReal.appVersion) === 'web' ? 'web' : 'app')) : null,
      realSessionsSincePublish: real.filter((e) => new Date(e.at).getTime() >= pub).length,
      lastScriptAt: script[0] ? script[0].at : null,
      candidatesView: {
        count: vs.length,
        firstAt: vs[0] ? vs[0].at : null,
        lastAt: vs.length ? vs[vs.length - 1].at : null,
        fromEmail: vs.filter((v) => v.source === 'email').length,
        channels: { web: vs.filter((v) => v.channel === 'web').length, app: vs.filter((v) => v.channel === 'app').length },
      },
      hasApp: pushByEmail.get(key) === true,
    });
  }
  return out;
}

module.exports = { classifyOrigin, isRealOrigin, isRealSession, REAL_SESSION_FILTER, boardSignals, SOURCES, CHANNELS };
