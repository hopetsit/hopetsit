'use strict';
/**
 * 2711 (BOB, accord de Daniel du 27/11/2026 « oui fais les 5 points ») — « PUBLIE TA DEMANDE DEPUIS L'APP ».
 *
 * Mesure du 27/11 : 45 demandes en ligne, 42 publiées par des propriétaires SANS l'app (venus de la pub), dont 8 seulement
 * répondent à un gardien ; les 3 propriétaires qui ont l'app répondent tous. Et 93 propriétaires ont l'app (63 avec
 * e-mail vérifié) pour 3 demandes en ligne : les bons comptes existent, ils ne publient pas.
 *
 * Règle : UNE notification DANS L'APP (push + cloche, JAMAIS d'e-mail — règle « pas d'e-mail en plus »), gabarit
 * owner_publish_nudge_2711 (9 langues), qui ouvre l'accueil propriétaire sur « Mes annonces » (route /posts), envoyée
 * à la main depuis l'admin (jamais par une tâche de fond) aux propriétaires :
 *   · e-mail vérifié, compte actif, ni test (+test), ni équipe, ni interne (hopetsit@, dadaciao84@…) ;
 *   · dont la PERSONNE (ses profils propriétaire / gardien / promeneur de même e-mail) a au moins un jeton push ;
 *   · sans AUCUNE demande en ligne (ni masquée, ni close, ni dont les dates sont passées) sur ses profils propriétaire ;
 *   · une seule fois par personne (Owner.publishNudge2711At, posé AVANT l'envoi, sur tous ses profils propriétaire).
 * Interrupteur Render : OWNER_PUBLISH_NUDGE_2711=on pour autoriser l'envoi. ÉTEINT PAR DÉFAUT : rien ne part.
 * L'aperçu (preview) ne dépend pas de l'interrupteur et n'envoie jamais rien.
 */
const mongoose = require('mongoose');
const logger = require('../utils/logger');
const { TEST_EMAIL_RE } = require('../utils/testAccount2809');

const TEMPLATE = 'owner_publish_nudge_2711';
const MAX_PER_SEND = 200;
// ZOE 28/11 — avant le build 648, l'appui sur cette notification DANS LA CLOCHE rouvre la liste (aucun écran pour publier) :
// jamais d'envoi à une personne dont le dernier appareil connu est plus ancien ou inconnu. `minBuild` absent = ce plancher ;
// `minBuild` fourni plus bas = refus (bad_filter). Pour envoyer plus large, il faut changer cette ligne (décision de Daniel).
const MIN_BUILD_FLOOR = 648;
let running = false;

// ZOE 28/11 — entier écrit en clair (648 ou « 648 ») : `true`, [648], {} ou 648.5 ne sont PAS des nombres (Number(true) vaut 1).
const strictInt = (v) => {
  if (typeof v === 'number') return Number.isInteger(v) && v >= 1 ? v : null;
  if (typeof v === 'string' && /^\d{1,6}$/.test(v.trim()) && Number(v.trim()) >= 1) return Number(v.trim());
  return null;
};
const enabled = () => /^(on|1|true|yes)$/i.test(String(process.env.OWNER_PUBLISH_NUDGE_2711 || '').trim());
const dbReady = () => mongoose.connection && mongoose.connection.readyState === 1;
const plain = (stored) => {
  try { return String(require('../utils/encryption').decrypt(stored || '') || stored || '').trim().toLowerCase(); } catch (_) { return String(stored || '').trim().toLowerCase(); }
};
const internal = (o) => {
  const mail = plain(o.email);
  return o.isStaff === true || TEST_EMAIL_RE.test(mail) || TEST_EMAIL_RE.test(String(o.email || '')) || require('../utils/userCounts').isInternalEmail(mail);
};

/**
 * Liste des personnes à prévenir (une ligne par personne), plus le décompte de ce qui est écarté et pourquoi.
 * @returns {Promise<{targets:object[], skipped:object}>}
 */
const select = async ({ now = Date.now() } = {}) => {
  const Owner = require('../models/Owner');
  const Post = require('../models/Post');
  const { personGroups } = require('../utils/person3110');
  const { isDateOpen } = require('../utils/openRequest1111');
  const skipped = {};
  const skip = (why) => { skipped[why] = (skipped[why] || 0) + 1; };

  const owners = await Owner.find({ verified: true, status: { $in: ['active', null] } })
    .select('email name firstName isStaff country appLocale language publishNudge2711At createdAt marketingOptOut').lean();
  const real = [];
  // BOB 28/11 — message d'incitation : jamais aux personnes désabonnées des messages marketing.
  for (const o of owners) { if (internal(o)) skip('test_ou_equipe'); else if (o.marketingOptOut === true) skip('desabonne_marketing'); else real.push(o); }
  const groups = await personGroups(real.map((o) => ({ role: 'owner', id: String(o._id) })));

  // Demandes en ligne : ni masquées, ni closes, ni réservées, et dont la fin (ou le début) n'est pas passée.
  const allOwnerIds = new Set();
  for (const g of groups.values()) for (const id of g.ids.owner) allOwnerIds.add(id);
  for (const o of real) allOwnerIds.add(String(o._id));
  const oid = (s) => new mongoose.Types.ObjectId(String(s));
  const posts = await Post.find({ ownerId: { $in: [...allOwnerIds].map(oid) }, postType: 'request' })
    .select('ownerId hidden bannedAt status closedAt startDate endDate').lean();
  const online = new Set();
  for (const p of posts) {
    if (p.hidden === true || p.bannedAt || p.status === 'closed' || p.closedAt) continue;
    const end = p.endDate || p.startDate;
    // ZOE 27/11 — une demande « pour aujourd'hui » (dates à minuit) reste proposée aux gardiens toute la journée
    // (règle produit utils/openRequest1111) : tant que le produit la montre, elle compte comme en ligne.
    if (end && new Date(end).getTime() < now && !isDateOpen(p, new Date(now))) continue;
    online.add(String(p.ownerId));
  }
  // Marqueur « déjà prévenu » : sur n'importe lequel des profils propriétaire de la personne.
  const nudged = new Set((await Owner.find({ _id: { $in: [...allOwnerIds].map(oid) }, publishNudge2711At: { $ne: null } }).select('_id').lean()).map((d) => String(d._id)));

  // ZOE 27/11 — règle des 3 profils : équipe ou compte bloqué sur le profil gardien / promeneur de la personne = jamais.
  const blockedSibling = new Set();
  const optOutSibling = new Set();
  for (const role of ['sitter', 'walker']) {
    const ids = new Set();
    for (const g of groups.values()) for (const x of g.ids[role] || []) ids.add(x);
    if (!ids.size) continue;
    // eslint-disable-next-line no-await-in-loop, global-require
    const M = role === 'sitter' ? require('../models/Sitter') : require('../models/Walker');
    // eslint-disable-next-line no-await-in-loop
    const bad = await M.find({ _id: { $in: [...ids].map(oid) }, $or: [{ isStaff: true }, { status: { $in: ['suspended', 'banned'] } }] }).select('_id').lean();
    for (const d of bad) blockedSibling.add(String(d._id));
    // ZOE 28/11 — le désabonnement vaut pour la PERSONNE : le lien d'un e-mail le pose sur UN profil (routes/lifecycleRoutes),
    // souvent le gardien / promeneur (même règle que services/requestAlert612).
    // eslint-disable-next-line no-await-in-loop
    const out = await M.find({ _id: { $in: [...ids].map(oid) }, marketingOptOut: true }).select('_id').lean();
    for (const d of out) optOutSibling.add(String(d._id));
  }
  for (const d of await Owner.find({ _id: { $in: [...allOwnerIds].map(oid) }, marketingOptOut: true }).select('_id').lean()) optOutSibling.add(String(d._id));

  // ZOE 28/11 — sous QUEL profil le dernier appareil de la personne s'est enregistré (l'app enregistre son jeton sous le
  // profil ouvert). Ouverte en gardien / promeneur, l'app répond à cette notification « concerne ton profil propriétaire »
  // sans ouvrir le formulaire : l'aperçu le compte, et l'envoi peut s'en tenir aux profils propriétaire (ownerProfileOnly).
  const lastSeen = new Map(); // 'role:id' → date du dernier appareil enregistré sous ce profil
  for (const role of ['owner', 'sitter', 'walker']) {
    const ids = new Set();
    for (const g of groups.values()) for (const x of g.ids[role] || []) ids.add(x);
    if (!ids.size) continue;
    // eslint-disable-next-line no-await-in-loop, global-require
    const M = role === 'owner' ? Owner : (role === 'sitter' ? require('../models/Sitter') : require('../models/Walker'));
    // eslint-disable-next-line no-await-in-loop
    for (const d of await M.find({ _id: { $in: [...ids].map(oid) } }).select('fcmDevices').lean()) {
      let at = 0;
      for (const dev of (Array.isArray(d.fcmDevices) ? d.fcmDevices : [])) if (dev && dev.token) at = Math.max(at, new Date(dev.at || 0).getTime() || 0);
      if (at) lastSeen.set(`${role}:${d._id}`, at);
    }
  }
  const lastRoleOf = (g) => {
    let best = '?'; let at = 0;
    for (const role of ['owner', 'sitter', 'walker']) for (const x of g.ids[role] || []) { const t = lastSeen.get(`${role}:${x}`) || 0; if (t > at) { at = t; best = role; } }
    return best;
  };

  const seen = new Set();
  const targets = [];
  for (const o of real) {
    const id = String(o._id);
    const g = groups.get(`owner:${id}`) || { key: `owner:${id}`, ids: { owner: [id] }, device: { has: false } };
    const ownerIds = g.ids.owner.length ? g.ids.owner : [id];
    const personKey = [...ownerIds].sort()[0];
    if (seen.has(personKey)) { skip('meme_personne'); continue; }
    seen.add(personKey);
    if ([...(g.ids.sitter || []), ...(g.ids.walker || [])].some((x) => blockedSibling.has(x))) { skip('profil_frere_equipe_ou_bloque'); continue; }
    if ([...ownerIds, ...(g.ids.sitter || []), ...(g.ids.walker || [])].some((x) => optOutSibling.has(x))) { skip('desabonne_marketing'); continue; }
    if (!(g.device && g.device.has)) { skip('sans_app'); continue; }
    if (ownerIds.some((x) => online.has(x))) { skip('demande_en_ligne'); continue; }
    if (ownerIds.some((x) => nudged.has(x))) { skip('deja_envoye'); continue; }
    targets.push({
      ownerId: id, ownerIds, country: String(o.country || '').toUpperCase() || '?',
      lang: String(o.appLocale || o.language || '').slice(0, 2).toLowerCase() || '?',
      platform: String((g.device && g.device.platform) || '').toLowerCase() || '?',
      appBuild: (g.device && g.device.appBuild) || null, createdAt: o.createdAt || null,
      lastDeviceRole: lastRoleOf(g),
    });
  }
  return { targets, skipped };
};

const tally = (rows, key) => rows.reduce((m, r) => { m[r[key]] = (m[r[key]] || 0) + 1; return m; }, {});

/** Aperçu : qui recevrait la notification. N'envoie rien, ne marque rien, ne dépend pas de l'interrupteur. */
const preview = async ({ now = Date.now() } = {}) => {
  if (!dbReady()) return { enabled: enabled(), count: 0, reason: 'db' };
  const { targets, skipped } = await select({ now });
  return {
    enabled: enabled(), template: TEMPLATE, route: '/posts', count: targets.length,
    // ZOE 28/11 — ce que l'envoi atteindrait vraiment (dernier appareil connu au build plancher ou plus).
    minBuildFloor: MIN_BUILD_FLOOR, sendable: (narrow(targets, { minBuild: MIN_BUILD_FLOOR }) || []).length,
    byCountry: tally(targets, 'country'), byLang: tally(targets, 'lang'), byPlatform: tally(targets, 'platform'),
    byLastDeviceRole: tally(targets, 'lastDeviceRole'),
    skipped,
    items: targets.map((t) => ({ ownerId: t.ownerId, country: t.country, lang: t.lang, platform: t.platform, appBuild: t.appBuild, lastDeviceRole: t.lastDeviceRole, createdAt: t.createdAt })),
  };
};

/**
 * Envoi : une notification par personne, push + cloche, sans e-mail. Refuse si l'interrupteur est éteint.
 * @returns {Promise<{sent:number, noToken:number, prefsOff:number, alreadySent:number, failed:number, remaining:number, reason?:string}>}
 */
// BOB 28/11 — `countries` (codes pays, ex. ['FR']) : envoi pays par pays, en journée chez eux ; `minBuild` :
// seulement les personnes dont le dernier appareil connu est à ce build ou plus (cloche corrigée dans le 648).
// Un filtre fourni mais vide ou illisible n'envoie RIEN.
const narrow = (targets, { countries, minBuild, ownerProfileOnly } = {}) => {
  let list = targets;
  // ZOE 28/11 — `ownerProfileOnly: true` : seulement les personnes dont le dernier appareil s'est enregistré sous le profil
  // propriétaire (les autres ne sont pas marquées : elles restent atteignables plus tard). Toute autre valeur que true / false = refus.
  if (ownerProfileOnly !== undefined && ownerProfileOnly !== null) {
    if (typeof ownerProfileOnly !== 'boolean') return null;
    if (ownerProfileOnly) list = list.filter((t) => t.lastDeviceRole === 'owner');
  }
  if (countries !== undefined && countries !== null) {
    // ZOE 28/11 — UN seul code illisible dans la liste (« Etats-Unis », « ? ») = rien ne part : pas d'envoi partiel sur une faute de frappe.
    const codes = (Array.isArray(countries) ? countries : []).map((c) => (typeof c === 'string' ? c.trim().toUpperCase() : ''));
    if (!codes.length || codes.some((c) => !/^[A-Z]{2}$/.test(c))) return null;
    const set = new Set(codes);
    list = list.filter((t) => set.has(t.country));
  }
  if (minBuild !== undefined && minBuild !== null) {
    const n = strictInt(minBuild);
    if (n === null) return null;
    list = list.filter((t) => Number(t.appBuild) >= n);
  }
  return list;
};

const sendAll = async ({ now = Date.now(), limit = MAX_PER_SEND, send, countries, minBuild, ownerProfileOnly } = {}) => {
  const out = { sent: 0, noToken: 0, prefsOff: 0, alreadySent: 0, failed: 0, remaining: 0 };
  if (!enabled()) return { ...out, reason: 'off' };
  // ZOE 27/11 — une limite fournie mais nulle, négative ou illisible n'envoie RIEN (avant : limit 0 = 200 envois).
  if (limit !== undefined && limit !== null && strictInt(limit) === null) return { ...out, reason: 'bad_limit' };
  if (!dbReady()) return { ...out, reason: 'db' };
  if (running) return { ...out, reason: 'busy' };
  running = true;
  try {
    const Owner = require('../models/Owner');
    const notify = typeof send === 'function' ? send : require('./notificationSender').sendNotification;
    const max = Math.max(1, Math.min(MAX_PER_SEND, Number(limit) || MAX_PER_SEND));
    const sel = await select({ now });
    const skipped = sel.skipped;
    const floor = minBuild === undefined || minBuild === null ? MIN_BUILD_FLOOR : strictInt(minBuild);
    if (floor === null || floor < MIN_BUILD_FLOOR) return { ...out, reason: 'bad_filter' };
    const targets = narrow(sel.targets, { countries, minBuild: floor, ownerProfileOnly });
    if (!targets) return { ...out, reason: 'bad_filter' };
    out.alreadySent = skipped.deja_envoye || 0;
    out.remaining = Math.max(0, targets.length - max);
    for (const t of targets.slice(0, max)) {
      // Réservation AVANT l'envoi : deux appels simultanés ne préviennent jamais deux fois la même personne.
      // eslint-disable-next-line no-await-in-loop
      const claim = await Owner.updateOne({ _id: t.ownerId, publishNudge2711At: null }, { $set: { publishNudge2711At: new Date(now) } });
      if (!claim || !claim.modifiedCount) { out.alreadySent += 1; continue; }
      if (t.ownerIds.length > 1) {
        // eslint-disable-next-line no-await-in-loop
        await Owner.updateMany({ _id: { $in: t.ownerIds }, publishNudge2711At: null }, { $set: { publishNudge2711At: new Date(now) } }).catch(() => {});
      }
      try {
        // eslint-disable-next-line no-await-in-loop
        const r = await notify({ userId: t.ownerId, role: 'owner', type: TEMPLATE, channels: { email: false }, data: {} });
        const push = r && r.push;
        if (push === 'sent') out.sent += 1;
        else if (push === 'no_token') out.noToken += 1;
        else if (push === 'prefs_off') out.prefsOff += 1; // notifications coupées dans l'app : cloche seule, pas un échec
        else out.failed += 1;
      } catch (e) {
        out.failed += 1;
        logger.warn(`[publishNudge2711] envoi raté pour ${t.ownerId} : ${e && e.message ? e.message : e}`);
      }
    }
    logger.info(`[publishNudge2711] envoi : ${JSON.stringify(out)}`);
  } catch (e) {
    out.reason = 'error';
    logger.warn(`[publishNudge2711] passage interrompu : ${e && e.message ? e.message : e}`);
  } finally { running = false; }
  return out;
};

module.exports = { preview, sendAll, select, narrow, strictInt, enabled, TEMPLATE, MAX_PER_SEND, MIN_BUILD_FLOOR };
