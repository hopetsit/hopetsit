/**
 * 620b (ZOE, 24/10/2026 — ordre de Daniel transmis par BOB « que ZOE fasse le job »,
 * point relevé par PAM au build 620) — TARIF « À PARTIR DE » d'une demande OUVERTE.
 *
 * Avant : `POST /pricing/estimate` sans `rate` ni `providerId` répondait 400 RATE_REQUIRED,
 * donc ni l'app ni le site ne pouvaient afficher « à partir de 12 €/visite · estimation
 * ~86 € » sur une demande qui ne vise personne.
 *
 * Maintenant : le tarif minimum (hors 0) des prestataires qui proposent ce service dans le
 * RAYON D'ALERTE de la demande (les mêmes personnes que celles qui seront prévenues :
 * services/requestAlert612.selectRecipients, 100 km autour de la position de la demande ou
 * du centre de sa ville), dans la devise du propriétaire.
 *   · exclus : comptes de test, staff, suspendus / bannis, personnes bloquées — règle 612 ;
 *     une demande d'un compte de test ne regarde QUE des comptes de test (essais sans bruit) ;
 *   · devise : seuls les prestataires facturant dans la devise du propriétaire comptent ;
 *   · sans prestataire → { fromRate: null, basedOn: 0 } (jamais une erreur) ;
 *   · cache 5 min par (service, zone, devise, test) — la zone est la position arrondie
 *     à ~5 km, ou le nom de ville plié.
 * Les appels AVEC `rate` ou `providerId` ne passent pas ici : inchangés.
 */
const logger = require('../utils/logger');
const engine = require('../utils/pricingEngine620');

const CACHE_TTL_MS = 5 * 60 * 1000;
const MAX_CACHE = 500;
const cache = new Map(); // key → { at, value }

const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : NaN);

/** Zone de cache : position arrondie à 0,05° (~5 km) ou nom de ville plié. */
const zoneKey = (center, city) => {
  if (center && Number.isFinite(center.lat) && Number.isFinite(center.lng)) {
    return `g:${(Math.round(center.lat * 20) / 20).toFixed(2)},${(Math.round(center.lng * 20) / 20).toFixed(2)}`;
  }
  let folded = String(city || '').trim().toLowerCase();
  try { folded = require('../utils/geocodeCity').baseCityName(folded) || folded; } catch (_) { /* nom brut */ }
  return `c:${folded.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ').trim()}`;
};

const cacheKeyOf = ({ serviceType, center, city, currency, ownerIsTest }) =>
  `${serviceType}|${zoneKey(center, city)}|${currency}|${ownerIsTest ? 'test' : 'real'}`;

const cacheGet = (key, now) => {
  const hit = cache.get(key);
  if (!hit) return null;
  if (now - hit.at > CACHE_TTL_MS) { cache.delete(key); return null; }
  return hit.value;
};
const cacheSet = (key, value, now) => {
  if (cache.size >= MAX_CACHE) {
    const oldest = cache.keys().next().value;
    if (oldest !== undefined) cache.delete(oldest);
  }
  cache.set(key, { at: now, value });
};

/** Position d'une demande : { lat, lng } ou null (0,0 = inconnue). */
const centerOf = (loc) => {
  if (!loc || typeof loc !== 'object') return null;
  const lat = num(loc.lat != null ? loc.lat : loc.latitude);
  const lng = num(loc.lng != null ? loc.lng : loc.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || (lat === 0 && lng === 0)) {
    const c = Array.isArray(loc.coordinates) ? loc.coordinates : null;
    if (c && c.length >= 2) {
      const la = num(c[1]); const ln = num(c[0]);
      if (Number.isFinite(la) && Number.isFinite(ln) && !(la === 0 && ln === 0)) return { lat: la, lng: ln };
    }
    return null;
  }
  return { lat, lng };
};

/**
 * Tarif « à partir de » pour un service autour d'une position / ville.
 * @param {Object} p
 * @param {string} p.serviceType       clé de service (home_visit, house_sitting, day_care, dog_walking…)
 * @param {{lat:number,lng:number}|null} [p.center]
 * @param {string} [p.city]
 * @param {string} [p.currency='EUR']  devise du propriétaire
 * @param {boolean} [p.ownerIsTest]    demande d'un compte de test → seuls des comptes de test comptent
 * @param {Set<string>} [p.selfIds]    profils de l'auteur (jamais lui-même)
 * @param {number} [p.durationMinutes] durée de balade demandée
 * @param {number} [p.now]
 * @returns {Promise<{fromRate:number|null, unit:string, durationMinutes:number|null, basedOn:number, currency:string, radiusKm:number, cached:boolean}>}
 */
const fromRateFor = async ({
  serviceType, center = null, city = '', currency = 'EUR', ownerIsTest = false, selfIds = null,
  durationMinutes, now = Date.now(),
} = {}) => {
  const key = engine.serviceKey(serviceType);
  const unit = engine.unitFor(key);
  const cur = String(currency || 'EUR').toUpperCase();
  const ck = cacheKeyOf({ serviceType: key, center, city, currency: cur, ownerIsTest });
  const hit = cacheGet(ck, now);
  if (hit) return { ...hit, cached: true };

  const alert612 = require('../services/requestAlert612');
  const empty = { fromRate: null, unit, durationMinutes: null, basedOn: 0, currency: cur, radiusKm: alert612.ALERT_RADIUS_KM };
  const hasCenter = !!(center && Number.isFinite(center.lat) && Number.isFinite(center.lng));
  if (!hasCenter && !String(city || '').trim()) return { ...empty, cached: false };

  let geocode = null;
  try { ({ geocodeCity: geocode } = require('../utils/geocodeCity')); } catch (_) { geocode = null; }

  let picked;
  try {
    picked = await alert612.selectRecipients({
      center: hasCenter ? center : null,
      city: String(city || ''),
      services: [key],
      selfIds: selfIds instanceof Set ? selfIds : new Set(),
      ownerIsTest,
      geocode,
    });
  } catch (e) {
    logger.warn(`[fromRate620] sélection impossible : ${e && e.message ? e.message : e}`);
    return { ...empty, cached: false };
  }

  const ids = { sitter: [], walker: [] };
  for (const r of picked.recipients || []) {
    if (r && (r.role === 'sitter' || r.role === 'walker')) ids[r.role].push(r.id);
  }
  const SELECT = 'hourlyRate dailyRate weeklyRate monthlyRate visitRate visitDurationMinutes walkRates currency';
  const rates = [];
  for (const role of ['sitter', 'walker']) {
    if (!ids[role].length) continue;
    const Model = role === 'walker' ? require('../models/Walker') : require('../models/Sitter');
    let docs = [];
    try {
      docs = await Model.find({ _id: { $in: ids[role] } }).select(SELECT).lean(); // eslint-disable-line no-await-in-loop
    } catch (e) {
      logger.warn(`[fromRate620] lecture des tarifs ${role} : ${e && e.message ? e.message : e}`);
      continue;
    }
    for (const d of docs) {
      const providerCurrency = String(d.currency || 'EUR').toUpperCase();
      if (providerCurrency !== cur) continue;
      const r = engine.rateFor(d, key, { durationMinutes });
      if (r && r.rate > 0) rates.push(r);
    }
  }
  rates.sort((a, b) => a.rate - b.rate);
  const best = rates[0] || null;
  const value = {
    fromRate: best ? best.rate : null,
    unit: best ? best.unit : unit,
    durationMinutes: best ? (best.durationMinutes || null) : null,
    basedOn: rates.length,
    currency: cur,
    radiusKm: picked.radiusKm || alert612.ALERT_RADIUS_KM,
  };
  cacheSet(ck, value, now);
  return { ...value, cached: false };
};

const _resetForTest = () => cache.clear();

module.exports = { fromRateFor, centerOf, zoneKey, cacheKeyOf, CACHE_TTL_MS, _resetForTest };
