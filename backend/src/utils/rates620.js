/**
 * 620 (ZOE, 24/10/2026) — GRILLE DE TARIFS d'un prestataire, lue depuis un corps de
 * requête (PUT /users/me/profile, PUT /sitters/me/profile, PUT /sitters/me/pricing).
 *
 *   applyRateFields(body, role) → { ok: true, update: { … } } | { ok: false, error }
 *     gardien   : hourlyRate, dailyRate, weeklyRate, monthlyRate, extraPetRate (≥ 0),
 *                 visitRate (≥ 0, 0 = visite non proposée), visitDurationMinutes (30 | 60),
 *                 defaultRateType (hour | day | week | month | visit)
 *     promeneur : walkRates ([{ durationMinutes, basePrice, currency?, enabled? }], mêmes
 *                 règles que PUT /walkers/me/rates), extraPetRate
 *   Un champ absent n'est pas touché. Lecture pure.
 */
const { VISIT_DURATIONS } = require('./pricingEngine620');

const RATE_TYPES = ['hour', 'day', 'week', 'month', 'visit'];
const SITTER_AMOUNTS = ['hourlyRate', 'dailyRate', 'weeklyRate', 'monthlyRate', 'extraPetRate', 'visitRate'];

const amount = (v) => {
  if (v === '' || v === null) return 0;
  const n = typeof v === 'number' ? v : parseFloat(v);
  return Number.isFinite(n) && n >= 0 ? Math.round(n * 100) / 100 : null;
};

function applyRateFields(body = {}, role = 'sitter') {
  const b = body && typeof body === 'object' ? body : {};
  const has = (k) => Object.prototype.hasOwnProperty.call(b, k) && b[k] !== undefined;
  const update = {};
  if (role === 'sitter') {
    for (const k of SITTER_AMOUNTS) {
      if (!has(k)) continue;
      const n = amount(b[k]);
      if (n === null) return { ok: false, error: `${k} must be a non-negative number.` };
      update[k] = n;
    }
    if (has('visitDurationMinutes')) {
      const n = Number(b.visitDurationMinutes);
      if (!VISIT_DURATIONS.includes(n)) return { ok: false, error: 'visitDurationMinutes must be 30 or 60.' };
      update.visitDurationMinutes = n;
    }
    if (has('defaultRateType')) {
      const t = String(b.defaultRateType || '').trim().toLowerCase();
      if (!RATE_TYPES.includes(t)) return { ok: false, error: `defaultRateType must be one of ${RATE_TYPES.join(', ')}.` };
      update.defaultRateType = t;
    }
  } else if (role === 'walker') {
    if (has('extraPetRate')) {
      const n = amount(b.extraPetRate);
      if (n === null) return { ok: false, error: 'extraPetRate must be a non-negative number.' };
      update.extraPetRate = n;
    }
    if (has('walkRates')) {
      if (!Array.isArray(b.walkRates)) return { ok: false, error: '`walkRates` must be an array.' };
      const seen = new Set();
      const out = [];
      for (const e of b.walkRates) {
        const dur = Number(e && e.durationMinutes);
        const price = amount(e && e.basePrice);
        if (!Number.isInteger(dur) || dur < 15 || dur > 300 || dur % 15 !== 0) {
          return { ok: false, error: 'walkRates: durationMinutes must be a multiple of 15 between 15 and 300.' };
        }
        if (price === null) return { ok: false, error: 'walkRates: basePrice must be a non-negative number.' };
        if (seen.has(dur)) return { ok: false, error: `walkRates: duplicate duration ${dur}.` };
        seen.add(dur);
        out.push({
          durationMinutes: dur,
          basePrice: price,
          ...(e && e.currency ? { currency: String(e.currency).toUpperCase() } : {}),
          enabled: !(e && (e.enabled === false || e.enabled === 'false')),
        });
      }
      update.walkRates = out.sort((a, b2) => a.durationMinutes - b2.durationMinutes);
    }
  }
  return { ok: true, update };
}

module.exports = { applyRateFields, RATE_TYPES, SITTER_AMOUNTS };
