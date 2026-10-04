/**
 * 610 (ZOE, 04/10/2026) — règle B des signalements de la PawMap
 * (~/hopetsit-social/REGLES_610.md, décidée par BOB le 04/10 sur l'idée de
 * Daniel : « un peu mesquin de faire payer pour ça »).
 *
 * Classement des 27 types du catalogue (models/MapReport.REPORT_TYPES) :
 *   · DANGER (13) — gratuit et ILLIMITÉ pour tous, compte pour le « geste du
 *     bon Samaritain » : les 8 nommés par la règle + 5 types de sécurité du
 *     catalogue (produits chimiques, faune sauvage, arbre tombé, sol brûlant,
 *     zone à tiques).
 *   · INFOS UTILES gratuites (4) — déjà gratuites, restent illimitées.
 *   · CONFORT (8) — sans abonnement 1 par 7 jours glissants (par PERSONNE,
 *     ses 3 profils confondus), illimité avec un abonnement.
 *   · ANIMAL PERDU / TROUVÉ (2) — 611 (ZOE, 04/10, décision BOB,
 *     PROCHAIN_BUILD_611.md point 1) : GRATUIT pour tous.
 *       - found_pet : gratuit et ILLIMITÉ (celui qui aide ne paie jamais) ;
 *       - lost_pet  : gratuit ; sans abonnement 1 alerte ACTIVE à la fois par
 *         PERSONNE (ses 3 profils confondus), plusieurs avec un abonnement.
 *         « Active » = ni masquée ni expirée (un SOS en cours compte) ; elle se
 *         libère à la clôture (suppression), à l'expiration ou si la
 *         modération la masque.
 * DOIT rester synchronisé avec l'app (ReportTypes dans map_report_model.dart).
 */
const DANGER_TYPES = [
  'poison', 'trap', 'hazard', 'aggressive_dog', 'dead_animal',
  'fire_smoke', 'flood', 'busy_traffic',
  'chemical', 'wildlife', 'fallen_tree', 'heat_hot_ground', 'tick_zone',
];
const USEFUL_FREE_TYPES = ['water_active', 'food', 'trash', 'vet_open'];
const COMFORT_TYPES = [
  'poop', 'pee', 'water_broken', 'construction', 'stray_pet', 'other',
  'no_dogs_zone', 'leash_required',
];
const PET_ALERT_TYPES = ['lost_pet', 'found_pet'];
// 611 — plus aucun type réservé aux abonnés à la création (gardé, vide, pour
// les anciennes apps et /types).
const PREMIUM_CREATE_TYPES = [];

/** Types qu'on peut créer sans abonnement et sans limite. */
const FREE_UNLIMITED_TYPES = [...DANGER_TYPES, ...USEFUL_FREE_TYPES, 'found_pet'];

/** 611 — alertes « animal perdu » actives à la fois, sans abonnement. */
const LOST_PET_ACTIVE_LIMIT = 1;

const COMFORT_WEEKLY_LIMIT = 1;
const COMFORT_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

const isDanger = (t) => DANGER_TYPES.includes(t);
const isComfort = (t) => COMFORT_TYPES.includes(t);
const isFreeUnlimited = (t) => FREE_UNLIMITED_TYPES.includes(t);
const isPremiumCreate = (t) => PREMIUM_CREATE_TYPES.includes(t);
const isLostPet = (t) => t === 'lost_pet';

/**
 * Quota confort d'une personne : signalements de confort créés par l'un de ses
 * profils ([reporterIds]) depuis 7 jours glissants.
 * @returns {{limit, used, remaining, nextAvailableAt: Date|null}}
 */
async function comfortQuota(MapReport, reporterIds, now = new Date()) {
  const since = new Date(now.getTime() - COMFORT_WINDOW_MS);
  const ids = (reporterIds || []).filter((id) => /^[a-f0-9]{24}$/i.test(String(id)));
  // Signalements encore en base + registre des créations (un signalement
  // supprimé reste compté) ; dédoublonnés par id de signalement.
  const ComfortReportLog = require('../models/ComfortReportLog');
  const [live, logged] = await Promise.all([
    MapReport.find({
      reporterId: { $in: ids },
      type: { $in: COMFORT_TYPES },
      createdAt: { $gt: since },
    }).select('_id createdAt').lean(),
    ComfortReportLog.find({
      reporterId: { $in: ids },
      createdAt: { $gt: since },
    }).select('reportId createdAt').lean(),
  ]);
  const byId = new Map();
  for (const r of live) byId.set(String(r._id), new Date(r.createdAt));
  for (const l of logged) {
    const k = String(l.reportId);
    if (!byId.has(k)) byId.set(k, new Date(l.createdAt));
  }
  const dates = [...byId.values()].sort((a, b) => a - b);
  const used = dates.length;
  const remaining = Math.max(0, COMFORT_WEEKLY_LIMIT - used);
  let nextAvailableAt = null;
  if (remaining === 0 && used > 0) {
    // La place se libère quand le plus ancien signalement « en trop » sort
    // de la fenêtre de 7 jours.
    nextAvailableAt = new Date(dates[used - COMFORT_WEEKLY_LIMIT].getTime() + COMFORT_WINDOW_MS);
  }
  return { limit: COMFORT_WEEKLY_LIMIT, used, remaining, nextAvailableAt };
}

/**
 * 611 — alertes « animal perdu » ACTIVES d'une personne ([reporterIds] = ses
 * 3 profils) : ni masquées ni expirées. La plus récente d'abord.
 * @returns {{limit, active, remaining, activeReportId, activeExpiresAt}}
 */
async function lostPetQuota(MapReport, reporterIds, now = new Date()) {
  const ids = (reporterIds || []).filter((id) => /^[a-f0-9]{24}$/i.test(String(id)));
  const active = await MapReport.find({
    reporterId: { $in: ids },
    type: 'lost_pet',
    hidden: { $ne: true },
    expiresAt: { $gt: now },
  })
    .sort({ createdAt: -1 })
    .select('_id expiresAt createdAt isSos')
    .lean();
  const first = active[0] || null;
  return {
    limit: LOST_PET_ACTIVE_LIMIT,
    active: active.length,
    remaining: Math.max(0, LOST_PET_ACTIVE_LIMIT - active.length),
    activeReportId: first ? String(first._id) : null,
    activeExpiresAt: first ? first.expiresAt : null,
  };
}

/**
 * 611 — verrou en mémoire par personne : deux envois simultanés ne peuvent pas
 * passer tous les deux le contrôle « 1 alerte active » (le serveur tourne sur
 * une seule instance Render).
 */
const personLocks = new Map();
async function withPersonLock(key, fn) {
  const prev = personLocks.get(key) || Promise.resolve();
  let release;
  const mine = new Promise((r) => { release = r; });
  const chain = prev.then(() => mine);
  personLocks.set(key, chain);
  await prev;
  try {
    return await fn();
  } finally {
    release();
    if (personLocks.get(key) === chain) personLocks.delete(key);
  }
}

/** 610 — inscrit une création de confort au registre (après save). */
async function logComfortCreation(report) {
  if (!report || !isComfort(report.type)) return;
  const ComfortReportLog = require('../models/ComfortReportLog');
  await ComfortReportLog.create({
    reporterId: report.reporterId,
    reportId: report._id,
    type: report.type,
    createdAt: report.createdAt || new Date(),
  });
}

module.exports = {
  DANGER_TYPES,
  USEFUL_FREE_TYPES,
  COMFORT_TYPES,
  PREMIUM_CREATE_TYPES,
  PET_ALERT_TYPES,
  FREE_UNLIMITED_TYPES,
  LOST_PET_ACTIVE_LIMIT,
  COMFORT_WEEKLY_LIMIT,
  COMFORT_WINDOW_MS,
  isDanger,
  isComfort,
  isFreeUnlimited,
  isPremiumCreate,
  isLostPet,
  comfortQuota,
  lostPetQuota,
  withPersonLock,
  logComfortCreation,
};
