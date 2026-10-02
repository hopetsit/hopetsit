'use strict';

/**
 * 607 (NEO, 02/10/2026) — décision écrite de Daniel : « Jesse T. et Lela T. :
 * oui, corrige ». Ces DEUX gardiens (et seulement eux) ont une adresse e-mail
 * dans le champ « ville ». Exécuté UNE fois au démarrage du serveur (marqueur
 * `fix_city_email_607` dans la collection `migrations`, comme la migration
 * v555 : l'URI Mongo de production n'existe que sur Render).
 *
 * Règle : la vraie ville est déduite des coordonnées de PROFIL par géocodage
 * inverse (Nominatim, niveau ville). Coordonnées absentes ou non fiables
 * (positions par défaut des simulateurs, Zone test, 0/0) → ville VIDÉE, jamais
 * inventée. Propagé aux profils frères (même personne) qui portent la même
 * valeur fautive. Journal avant/après sans jamais écrire l'e-mail.
 */
const logger = require('../utils/logger');
const { isUnsafeCity } = require('../utils/publicCity607');

const KEY = 'fix_city_email_607';
const TARGETS = [
  { id: '6aacae41b4d70237d89c8def', model: 'Sitter', label: 'Jesse T.' },
  { id: '6ab09f325f2c7ca4acd8c315', model: 'Sitter', label: 'Lela T.' },
];

// Positions qui ne disent rien de l'endroit où vit la personne.
const UNRELIABLE = [
  [37.4220, -122.0841], // émulateur Android (Googleplex)
  [37.3317, -122.0307], // simulateur iOS « Apple » (Infinite Loop)
  [37.3349, -122.0090], // Apple Park
  [37.785834, -122.406417], // simulateur Xcode (position personnalisée par défaut)
  [-49.35, 70.22], // Zone test (Kerguelen)
  [-35, -30], // ancienne Zone test
];
function kmBetween([la1, lo1], [la2, lo2]) {
  const r = (x) => (x * Math.PI) / 180;
  const a = Math.sin(r(la2 - la1) / 2) ** 2 + Math.cos(r(la1)) * Math.cos(r(la2)) * Math.sin(r(lo2 - lo1) / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(a));
}
function reliableLatLng(doc) {
  const { homeOf } = require('../utils/personMapPosition');
  const h = homeOf(doc);
  if (!h) return null;
  const [lng, lat] = h.coordinates;
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || (Math.abs(lat) < 0.01 && Math.abs(lng) < 0.01)) return null;
  if (UNRELIABLE.some((p) => kmBetween([lat, lng], p) < 3)) return null;
  return { lat, lng };
}

async function reverseCity({ lat, lng }, fetchImpl = fetch) {
  const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=10&addressdetails=1&lat=${lat}&lon=${lng}`;
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 8000);
  try {
    const r = await fetchImpl(url, { signal: ctrl.signal, headers: { 'User-Agent': 'HoPetSit/607 (contact@hopetsit.com)', 'Accept-Language': 'fr' } });
    if (!r.ok) return '';
    const j = await r.json();
    const a = (j && j.address) || {};
    const c = String(a.city || a.town || a.village || a.municipality || '').trim();
    return c && !isUnsafeCity(c) ? c : '';
  } catch (_) {
    return '';
  } finally {
    clearTimeout(t);
  }
}

const CITY_PATHS = ['city', 'location.city', 'homeLocation.city', 'coverageCity'];
const getPath = (d, p) => p.split('.').reduce((o, k) => (o == null ? undefined : o[k]), d);

async function fixOne(target, { fetchImpl } = {}) {
  const M = { Owner: require('../models/Owner'), Sitter: require('../models/Sitter'), Walker: require('../models/Walker') };
  const doc = await M[target.model].findById(target.id).select('+homeLocation').lean();
  if (!doc) return { id: target.id, label: target.label, result: 'introuvable' };
  const bad = CITY_PATHS.map((p) => getPath(doc, p)).filter((v) => typeof v === 'string' && isUnsafeCity(v));
  if (!bad.length) return { id: target.id, label: target.label, result: 'déjà propre' };
  const pos = reliableLatLng(doc);
  const newCity = pos ? await reverseCity(pos, fetchImpl) : '';
  const badSet = new Set(bad.map((v) => v.trim().toLowerCase()));

  const { identityGroup } = require('../utils/identityGroup');
  const g = await identityGroup(target.id);
  const changed = [];
  for (const d of g.docs) {
    const Model = M[d.model];
    if (!Model) continue;
    // eslint-disable-next-line no-await-in-loop
    const sib = await Model.findById(d.id).select('+homeLocation').lean();
    if (!sib) continue;
    const $set = {};
    for (const p of CITY_PATHS) {
      const v = getPath(sib, p);
      if (typeof v === 'string' && badSet.has(v.trim().toLowerCase()) && (p !== 'homeLocation.city' || sib.homeLocation)) $set[p] = newCity;
    }
    if (Object.keys($set).length) {
      // eslint-disable-next-line no-await-in-loop
      await Model.updateOne({ _id: sib._id }, { $set });
      changed.push({ model: d.model, id: String(sib._id), champs: Object.keys($set) });
    }
  }
  return {
    id: target.id,
    label: target.label,
    avant: '<adresse e-mail masquée>',
    apres: newCity || '(vide)',
    source: pos ? `géocodage inverse de la position de profil (${pos.lat.toFixed(1)}, ${pos.lng.toFixed(1)})` : 'aucune position fiable : ville vidée',
    profils: changed,
  };
}

/** Une seule fois par base. Ne lève jamais. */
async function runFixCityEmail607(db, opts = {}) {
  try {
    const mig = db.collection('migrations');
    if (await mig.findOne({ _id: KEY })) return null;
    const results = [];
    for (const t of (opts.targets || TARGETS)) {
      // eslint-disable-next-line no-await-in-loop
      results.push(await fixOne(t, opts));
    }
    await mig.insertOne({ _id: KEY, at: new Date(), results });
    for (const r of results) logger.info(`[boot] ${KEY} ${r.label} (${r.id}) : ${r.avant || ''} → ${r.apres || r.result} — ${r.source || ''} — ${JSON.stringify(r.profils || [])}`);
    return results;
  } catch (e) {
    logger.error(`[boot] ${KEY} échec (non bloquant) : ${e && e.message}`);
    return null;
  }
}

module.exports = { runFixCityEmail607, reliableLatLng, reverseCity, TARGETS, KEY };
