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

const SOURCES = ['email', 'push', 'notification', 'direct', 'link', 'sms'];
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
  const owners = await Owner.find({ _id: { $in: ownerIds } }).select('email isStaff').lean();
  // 3110 (ADA, règle de Daniel « toujours regarder les 3 profils ») — une PERSONNE = même e-mail sur les profils
  // propriétaire + gardien + promeneur (utils/person3110, fonction partagée) : sessions, appareils et « a l'app »
  // se lisent sur les 3 profils.
  const groups = await require('./person3110').personGroups(ownerIds.map((id) => ({ role: 'owner', id })));
  const keyOfOwner = (id) => `owner:${id}`;
  // 3110 (ADA, demande de Daniel) — compte de test / équipe : ses sessions ne comptent pas comme un vrai retour.
  const plain = (e) => { try { return require('./encryption').decrypt(e || '') || String(e || ''); } catch (_) { return String(e || ''); } };
  const internalOwner = new Set(owners.filter((o) => o.isStaff === true || require('./userCounts').isInternalEmail(plain(o.email))).map((o) => String(o._id)));
  const allIds = [...new Set([...groups.values()].flatMap((g) => g.allIds))];
  const idToKey = new Map();
  for (const g of groups.values()) for (const i of g.allIds) idToKey.set(i, g.key);

  // 0111 (ADA) — ouvertures des candidats de la PERSONNE (toutes ses demandes, ses profils propriétaire), pas seulement
  // celles des demandes affichées : un retour sur une autre demande est un retour de la personne (returnVerdict).
  const ownerIdsAll = [...new Set([...groups.values()].flatMap((g) => g.ids.owner))];
  const [events, views] = await Promise.all([
    allIds.length ? ActivityEvent.find({ userId: { $in: allIds } }).select('userId at platform appVersion origin').sort({ at: -1 }).limit(20000).lean() : [],
    CandidatesView.find({ $or: [{ postId: { $in: items.map((it) => String(it.postId)) } }, { ownerId: { $in: ownerIdsAll } }] }).select('postId ownerId at channel source origin').lean(),
  ]);
  const evByKey = new Map();
  for (const ev of events) {
    const k = idToKey.get(String(ev.userId)); if (!k) continue;
    if (!evByKey.has(k)) evByKey.set(k, []);
    evByKey.get(k).push(ev);
  }
  const viewsByPost = new Map();
  const viewsByPerson = new Map();
  const ownerToKey = new Map();
  for (const g of groups.values()) for (const i of g.ids.owner) ownerToKey.set(i, g.key);
  for (const v of views) {
    if (!isRealOrigin(v.origin)) continue;
    const k = String(v.postId);
    if (!viewsByPost.has(k)) viewsByPost.set(k, []);
    viewsByPost.get(k).push(v);
    const pk = ownerToKey.get(String(v.ownerId));
    if (pk) { if (!viewsByPerson.has(pk)) viewsByPerson.set(pk, []); viewsByPerson.get(pk).push(v); }
  }
  for (const it of items) {
    const key = keyOfOwner(String(it.owner && it.owner.id || ''));
    const evs = evByKey.get(key) || [];
    const pub = it.stages && it.stages.published && it.stages.published.at ? new Date(it.stages.published.at).getTime() : 0;
    const real = evs.filter(isRealSession);
    const script = evs.filter((e) => !isRealSession(e));
    const lastReal = real[0] || null;
    // 3110d — l'admin compte aussi comme retour une ouverture des candidats après la publication (candidatesView).
    // 3110 (ADA, demande de Daniel : « le propriétaire est revenu ? par canal ») — sessions RÉELLES (nos scripts et
    // l'admin exclus) depuis la publication, séparées site / app ; 0 pour un compte de test ou de l'équipe.
    const internal = internalOwner.has(String(it.owner && it.owner.id || ''));
    const since = internal ? [] : real.filter((e) => new Date(e.at).getTime() >= pub);
    const chanOf = (e) => e.origin || (String(e.appVersion) === 'web' ? 'web' : 'app');
    const sessionsByChannel = { web: since.filter((e) => chanOf(e) === 'web').length, app: since.filter((e) => chanOf(e) === 'app').length };
    const vs = (viewsByPost.get(String(it.postId)) || []).sort((a, b) => new Date(a.at) - new Date(b.at));
    out.set(String(it.postId), {
      lastRealReturnAt: lastReal ? lastReal.at : null,
      lastRealReturnChannel: lastReal ? (lastReal.origin || (String(lastReal.appVersion) === 'web' ? 'web' : 'app')) : null,
      realSessionsSincePublish: real.filter((e) => new Date(e.at).getTime() >= pub).length,
      lastScriptAt: script[0] ? script[0].at : null,
      sessionsByChannel,
      lastReturnSincePublishAt: since[0] ? since[0].at : null,
      lastReturnSincePublishChannel: since[0] ? chanOf(since[0]) : null,
      internalOwner: internal,
      candidatesView: {
        count: vs.length,
        firstAt: vs[0] ? vs[0].at : null,
        lastAt: vs.length ? vs[vs.length - 1].at : null,
        fromEmail: vs.filter((v) => v.source === 'email').length,
        // 2910 (BOB, Daniel : « savoir d'où le proprio répond : web, app, mail ou tél ») — par source et dernier retour.
        fromSms: vs.filter((v) => v.source === 'sms').length,
        fromPush: vs.filter((v) => v.source === 'push' || v.source === 'notification').length,
        fromDirect: vs.filter((v) => !v.source || v.source === 'direct' || v.source === 'link').length,
        lastSource: vs.length ? (vs[vs.length - 1].source || 'direct') : null,
        lastChannel: vs.length ? (vs[vs.length - 1].channel || null) : null,
        channels: { web: vs.filter((v) => v.channel === 'web').length, app: vs.filter((v) => v.channel === 'app').length },
      },
      // 3110 (ADA) — « a l'app » = la PERSONNE a un appareil enregistré (3 profils) OU un retour mesuré par l'app
      // (session ou ouverture des candidats) ; plateforme et build du dernier appareil connu.
      hasApp: !!((groups.get(key) && groups.get(key).device.has) || real.some((e) => chanOf(e) === 'app') || vs.some((x) => x.channel === 'app')),
      appDevice: (() => {
        const d = groups.get(key) && groups.get(key).device;
        if (d && (d.platform || d.appBuild)) return { platform: d.platform, build: d.appBuild || null };
        const ev = real.find((e) => chanOf(e) === 'app');
        if (!ev) return null;
        const m = String(ev.appVersion || '').match(/\+(\d+)$/);
        return { platform: String(ev.platform || ''), build: m ? Number(m[1]) : null };
      })(),
      // retours par l'app SANS nouvelle connexion (session déjà ouverte) : ouvertures des candidats dans l'app après la publication
      appViewsSincePublish: internal ? 0 : vs.filter((x) => x.channel === 'app' && new Date(x.at).getTime() >= pub).length,
    });
    const sig = out.get(String(it.postId));
    const g = groups.get(key);
    sig.back = returnVerdict({
      publishedAt: pub, internal, sessions: real, postViews: vs, personViews: viewsByPerson.get(key) || [], hasApp: sig.hasApp, appDevice: sig.appDevice,
    });
    sig.back.personKey = g ? require('crypto').createHash('sha1').update([...g.allIds].sort().join(',')).digest('hex').slice(0, 10) : null;
  }
  markPrimary(items, out);
  return out;
}

const _t = (d) => (d ? new Date(d).getTime() : 0);
const _chan = (e) => e.origin || (String(e.appVersion) === 'web' ? 'web' : 'app');

/**
 * 0111 (ADA, bug signalé par Daniel : « Caroline est revenue et quand je mets détails c'est jamais revenu ») —
 * LA SEULE règle « le propriétaire est revenu ? » de l'admin. La tuile du tableau de bord, la carte de « Demandes
 * publiées » et « Voir le détail » affichent toutes ce verdict (ownerSignals.back), jamais un calcul à elles.
 * Par PERSONNE (3 profils, même e-mail) : un retour = une vraie session site/app d'un des 3 profils, ou une
 * ouverture de la page des candidats de l'une de ses demandes (nos scripts et l'admin exclus). Pur, testable.
 *   state 'since'    : revenu après la publication de CETTE demande (lastAt = dernier retour)
 *   state 'before'   : revenu, mais seulement avant cette demande (lastAt = dernier retour, antérieur)
 *   state 'never'    : jamais revenu du tout
 *   state 'internal' : compte de test / équipe, non compté
 */
function returnVerdict({ publishedAt, internal, sessions, postViews, personViews, hasApp, appDevice }) {
  const pub = _t(publishedAt);
  const seenList = (postViews || []).filter((v) => isRealOrigin(v.origin));
  const seen = {
    count: seenList.length,
    web: seenList.filter((v) => v.channel === 'web').length,
    app: seenList.filter((v) => v.channel === 'app').length,
    lastAt: seenList.length ? new Date(Math.max(...seenList.map((v) => _t(v.at)))).toISOString() : null,
  };
  const base = { hasApp: !!hasApp, appDevice: appDevice || null, seen, primary: false };
  if (internal) return { ...base, state: 'internal', lastAt: null, channel: null, via: null, sessions: { web: 0, app: 0 }, appViews: 0 };
  const real = (sessions || []).filter(isRealSession);
  const vmap = new Map();
  for (const v of [...(personViews || []), ...(postViews || [])]) if (isRealOrigin(v.origin)) vmap.set(v._id ? String(v._id) : `${v.postId}|${_t(v.at)}`, v);
  const views = [...vmap.values()];
  const ret = [
    ...real.map((e) => ({ at: _t(e.at), channel: _chan(e), kind: 'session' })),
    ...views.map((v) => ({ at: _t(v.at), channel: v.channel === 'app' ? 'app' : v.channel === 'web' ? 'web' : null, kind: 'view', source: v.source || 'direct', postId: String(v.postId) })),
  ].filter((r) => r.at).sort((a, b) => b.at - a.at);
  const since = ret.filter((r) => r.at >= pub);
  const sess = real.filter((e) => _t(e.at) >= pub);
  const sessions2 = { web: sess.filter((e) => _chan(e) === 'web').length, app: sess.filter((e) => _chan(e) === 'app').length };
  const appViews = views.filter((v) => v.channel === 'app' && _t(v.at) >= pub).length;
  const last = since[0] || ret[0] || null;
  if (!last) return { ...base, state: 'never', lastAt: null, channel: null, via: null, sessions: sessions2, appViews };
  // « via » : provenance d'une ouverture des candidats dans la même demi-heure que le dernier retour, sinon inconnue.
  const pool = since.length ? since : ret;
  const v = pool.find((r) => r.kind === 'view' && Math.abs(r.at - last.at) <= 30 * 60000);
  return {
    ...base,
    state: since.length ? 'since' : 'before',
    lastAt: new Date(last.at).toISOString(),
    channel: last.channel,
    via: v ? v.source : null,
    viewPostId: v ? v.postId : null,
    sessions: sessions2,
    appViews,
  };
}

/** Une personne, plusieurs demandes : une seule ligne « revenu » = la demande concernée par le retour. */
function markPrimary(items, out) {
  const byPerson = new Map();
  for (const it of items) {
    const b = (out.get(String(it.postId)) || {}).back;
    if (!b || b.state !== 'since' || !b.personKey) continue;
    if (!byPerson.has(b.personKey)) byPerson.set(b.personKey, []);
    byPerson.get(b.personKey).push({ it, b });
  }
  for (const list of byPerson.values()) {
    const lastAt = Math.max(...list.map((x) => _t(x.b.lastAt)));
    const viewed = list.find((x) => x.b.viewPostId && x.b.viewPostId === String(x.it.postId));
    const pick = viewed || list
      .filter((x) => _t(x.it.stages && x.it.stages.published && x.it.stages.published.at) <= lastAt)
      .sort((a, b) => _t(b.it.stages.published.at) - _t(a.it.stages.published.at))[0] || list[0];
    pick.b.primary = true;
  }
}

module.exports = { classifyOrigin, isRealOrigin, isRealSession, REAL_SESSION_FILTER, boardSignals, returnVerdict, markPrimary, SOURCES, CHANNELS };
