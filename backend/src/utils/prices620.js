/**
 * 620 (ZOE, 24/10/2026 — complément de Daniel « que ça marche aussi dans la PawMap ») —
 * PRIX PAR SERVICE d'un prestataire, pour les listes, les fiches et les bulles de la
 * carte : « à partir de 12 €/visite », « 18 €/jour », « 10 €/balade ».
 *
 *   pricesFor(doc, role) → {
 *     house_sitting: { amount, unit: 'day' },   (gardien : dailyRate, sinon semaine/7, mois/30, heure×8)
 *     day_care:      { amount, unit: 'day' },   (même tarif au jour)
 *     home_visit:    { amount, unit: 'visit', durationMinutes },   (gardien : visitRate > 0)
 *     dog_walking:   { amount, unit: 'walk', durationMinutes },    (promeneur : balade la moins chère)
 *   }  — seuls les services réellement tarifés sont présents.
 *
 *   priceFromFor(doc, role, service) → { priceFrom, priceUnit }
 *     · avec `service` : le prix de CE service (0 si non proposé) ;
 *     · sans : l'ancien `priceFrom` (le plus bas de heure / jour / balade), INCHANGÉ
 *       pour les apps ≤ 619, plus son unité.
 * Lecture pure.
 */
const { rateFor, round2 } = require('./pricingEngine620');

const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);

function pricesFor(doc, role) {
  const d = doc || {};
  const out = {};
  if (role === 'walker') {
    const w = rateFor(d, 'dog_walking');
    if (w) out.dog_walking = { amount: w.rate, unit: 'walk', durationMinutes: w.durationMinutes };
    return out;
  }
  if (role === 'sitter') {
    const day = rateFor(d, 'house_sitting');
    if (day) {
      out.house_sitting = { amount: day.rate, unit: 'day' };
      out.day_care = { amount: day.rate, unit: 'day' };
    }
    const visit = rateFor(d, 'home_visit');
    if (visit) out.home_visit = { amount: visit.rate, unit: 'visit', durationMinutes: visit.durationMinutes };
  }
  return out;
}

/** Ancien « tarif le plus bas » (v604), avec son unité. */
function legacyPriceFrom(d, role) {
  const cands = [];
  if (role === 'walker' && Array.isArray(d.walkRates)) {
    for (const w of d.walkRates) {
      if (w && w.enabled !== false && num(w.basePrice) > 0) cands.push({ amount: num(w.basePrice), unit: 'walk' });
    }
  }
  if (num(d.hourlyRate) > 0) cands.push({ amount: num(d.hourlyRate), unit: 'hour' });
  if (num(d.dailyRate) > 0) cands.push({ amount: num(d.dailyRate), unit: 'day' });
  if (!cands.length) return { priceFrom: 0, priceUnit: '' };
  const best = cands.sort((a, b) => a.amount - b.amount)[0];
  return { priceFrom: round2(best.amount), priceUnit: best.unit };
}

function priceFromFor(doc, role, service) {
  const d = doc || {};
  if (role === 'owner') return { priceFrom: 0, priceUnit: '' };
  const key = String(service || '').trim().toLowerCase();
  if (key) {
    const p = pricesFor(d, role)[key];
    return p ? { priceFrom: p.amount, priceUnit: p.unit } : { priceFrom: 0, priceUnit: '' };
  }
  return legacyPriceFrom(d, role);
}

/** Champs à projeter dans une réponse de liste / carte : { prices, priceUnit }. */
function priceFields(doc, role, service) {
  const { priceUnit } = priceFromFor(doc, role, service);
  return { prices: pricesFor(doc, role), priceUnit };
}

module.exports = { pricesFor, priceFromFor, priceFields, legacyPriceFrom };
