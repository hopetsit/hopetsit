'use strict';

/**
 * 2910 (BOB) — Daniel : « les abonnements et achats doivent suivre les 3 profils ».
 * Les abonnements (UserSubscription) suivaient déjà les 3 profils (syncAllRolesByEmail) ;
 * les BOOSTS, eux, vivent sur le document du profil (boostExpiry / mapBoostExpiry) et
 * restaient sur le profil qui les avait achetés (cas réel : PawBoost d'Agnès acheté en
 * promeneuse, elle candidate en gardienne).
 *
 * Ici : pour une personne (même e-mail sur Owner / Sitter / Walker), le boost profil et le
 * boost carte les plus longs encore actifs sont recopiés sur ses autres profils. Jamais de
 * ligne boostPurchases (rien ne s'ajoute aux revenus), jamais un boost raccourci.
 * Appelé à chaque lecture de /users/me/benefits et toutes les 10 minutes pour tous les
 * boosts actifs (couvre TOUS les chemins d'achat : Apple, carte, points, promo, cadeaux).
 * BOOST_SYNC=off pour couper.
 */
const logger = require('../utils/logger');

const TICK_MS = 10 * 60 * 1000;
const enabled = () => String(process.env.BOOST_SYNC || 'on').toLowerCase() !== 'off';

function models() {
  return {
    Owner: require('../models/Owner'),
    Sitter: require('../models/Sitter'),
    Walker: require('../models/Walker'),
  };
}

const SEL = 'email boostExpiry boostTier mapBoostExpiry mapBoostTier mapBoostLocation';
const ms = (d) => (d ? new Date(d).getTime() : 0);

/** Aligne les boosts des profils d'une même personne. @returns {Promise<number>} profils mis à jour */
async function syncBoostsForEmail(email, now = new Date()) {
  const mail = String(email || '').trim();
  if (!mail) return 0;
  const M = models();
  const docs = [];
  for (const [name, Model] of Object.entries(M)) {
    const d = await Model.findOne({ email: mail }).select(SEL).lean();
    if (d) docs.push({ name, Model, d });
  }
  if (docs.length < 2) return 0;
  const t = now.getTime();
  const best = (field) => docs.reduce((b, x) => (ms(x.d[field]) > t && ms(x.d[field]) > ms(b && b.d[field]) ? x : b), null);
  const prof = best('boostExpiry');
  const map = best('mapBoostExpiry');
  if (!prof && !map) return 0;
  let changed = 0;
  for (const x of docs) {
    const set = {};
    if (prof && x !== prof && ms(x.d.boostExpiry) < ms(prof.d.boostExpiry)) {
      set.boostExpiry = prof.d.boostExpiry;
      set.boostTier = prof.d.boostTier || null;
    }
    if (map && x !== map && ms(x.d.mapBoostExpiry) < ms(map.d.mapBoostExpiry)) {
      set.mapBoostExpiry = map.d.mapBoostExpiry;
      set.mapBoostTier = map.d.mapBoostTier || null;
      const loc = map.d.mapBoostLocation;
      const hasOwn = x.d.mapBoostLocation && Array.isArray(x.d.mapBoostLocation.coordinates) && x.d.mapBoostLocation.coordinates.length === 2;
      if (!hasOwn && loc && Array.isArray(loc.coordinates) && loc.coordinates.length === 2) set.mapBoostLocation = loc;
    }
    if (Object.keys(set).length) {
      await x.Model.updateOne({ _id: x.d._id }, { $set: set });
      changed += 1;
      logger.info(`[boostSync] ${x.name} ${x.d._id} aligné (${Object.keys(set).join(', ')})`);
    }
  }
  return changed;
}

/** À partir d'un profil (id + modèle) : aligne la personne. Jamais bloquant. */
async function syncBoostsForUser(userId, modelName) {
  if (!enabled()) return 0;
  try {
    const Model = models()[modelName];
    if (!Model) return 0;
    const me = await Model.findById(userId).select('email').lean();
    return me ? await syncBoostsForEmail(me.email) : 0;
  } catch (e) {
    logger.warn(`[boostSync] échec non bloquant : ${e && e.message}`);
    return 0;
  }
}

/** Passe complète : toutes les personnes qui ont un boost actif. */
async function syncAllActiveBoosts(now = new Date()) {
  if (!enabled()) return { emails: 0, changed: 0 };
  const emails = new Set();
  for (const Model of Object.values(models())) {
    const rows = await Model.find({ $or: [{ boostExpiry: { $gt: now } }, { mapBoostExpiry: { $gt: now } }] }).select('email').lean();
    for (const r of rows) if (r.email) emails.add(r.email);
  }
  let changed = 0;
  for (const e of emails) {
    // eslint-disable-next-line no-await-in-loop
    changed += await syncBoostsForEmail(e, now);
  }
  return { emails: emails.size, changed };
}

let timer = null;
function startBoostSyncScheduler() {
  if (timer || process.env.NODE_ENV === 'test' || !enabled()) return;
  const run = () => syncAllActiveBoosts()
    .then((r) => { if (r.changed) logger.info(`[boostSync] passe : ${r.changed} profil(s) alignés sur ${r.emails} personne(s)`); })
    .catch((e) => logger.warn(`[boostSync] passe en échec : ${e && e.message}`));
  setTimeout(run, 30 * 1000);
  timer = setInterval(run, TICK_MS);
}

module.exports = { syncBoostsForEmail, syncBoostsForUser, syncAllActiveBoosts, startBoostSyncScheduler };
