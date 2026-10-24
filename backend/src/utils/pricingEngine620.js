/**
 * 620 (ZOE, 24/10/2026 — ordre de Daniel « dates à prévoir, prix par visite, grille de
 * tarifs ») — MOTEUR UNIQUE de quantité et d'estimation. Le site, l'app et le serveur
 * passent tous par ici (POST /pricing/estimate, candidatures, recalcul après dates) :
 * plus aucune copie du calcul côté client.
 *
 *   · dateMode d'une demande : 'exact' | 'approx' | 'tbd'. Une ancienne demande (sans
 *     champ) vaut 'exact' quand elle a ses deux dates, sinon 'tbd' — SAUF si elle est
 *     antérieure au 620 : voir `effectiveDateMode`, qui ne rend 'tbd' que pour les
 *     demandes qui le portent explicitement ou qui n'ont aucune date du tout.
 *   · quantityFor(post, serviceType) → { quantity, unit } :
 *       jours   = fin − début + 1 (calendrier, UTC)        unit 'day'
 *       nuits   = jours − 1 (garde chez le gardien)         unit 'night'
 *       visites = jours × visitsPerDay (1 par défaut)       unit 'visit'
 *       balades = 1 par défaut                              unit 'walk'
 *       'tbd' → quantity null (on ne connaît pas encore la période).
 *   · estimate({ serviceType, unit, rate, post, commissionRate }) →
 *       { quantity, unit, unitRate, unitTotal, commission, ownerTotal, indicative }
 *       indicative = true quand la demande est 'tbd' : on ne renvoie QUE le tarif unitaire.
 *
 * Commission : taux existant (20 %, 15 % Top) passé par l'appelant — jamais recalculé ici.
 * Lecture pure, aucune I/O.
 */
const DAY_MS = 24 * 60 * 60 * 1000;
const DATE_MODES = ['exact', 'approx', 'tbd'];
const VISITS_PER_DAY = [1, 2];
const VISIT_DURATIONS = [30, 60];

/** Unité de facturation par service (les clés inconnues sont traitées « au jour »). */
const SERVICE_UNITS = Object.freeze({
  house_sitting: 'day',
  pet_sitting: 'day',
  overnight_stay: 'day',
  long_stay: 'day',
  day_care: 'day',
  home_visit: 'visit',
  dog_walking: 'walk',
});

const VISIT_KEYS = new Set(['home_visit', 'drop_in', 'drop_in_visit', 'pet_visit', 'visit', 'visits']);
const WALK_KEYS = new Set(['dog_walking', 'walking', 'walk']);

const round2 = (n) => Math.round((Number(n) || 0) * 100) / 100;

const parseDate = (v) => {
  if (!v) return null;
  const d = v instanceof Date ? v : new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};

/** Clé de service normalisée : 'home_visit' | 'dog_walking' | 'house_sitting' | … */
const serviceKey = (raw) => {
  const s = String(raw == null ? '' : raw).trim().toLowerCase().replace(/[\s-]+/g, '_');
  if (!s) return '';
  if (VISIT_KEYS.has(s)) return 'home_visit';
  if (WALK_KEYS.has(s)) return 'dog_walking';
  if (s === 'house sitting' || s === 'housesitting') return 'house_sitting';
  return s;
};

/** Unité d'un service. */
const unitFor = (serviceType) => SERVICE_UNITS[serviceKey(serviceType)] || 'day';

/** Service principal d'une demande (1er de serviceTypes, ou chaîne). */
const mainService = (post) => {
  const list = Array.isArray(post && post.serviceTypes)
    ? post.serviceTypes
    : (post && post.serviceTypes != null ? [post.serviceTypes] : []);
  const first = list.map(serviceKey).find(Boolean);
  return first || '';
};

/** Normalise une valeur de dateMode ('' quand inconnue). */
const normalizeDateMode = (v) => {
  const s = String(v == null ? '' : v).trim().toLowerCase();
  return DATE_MODES.includes(s) ? s : '';
};

/**
 * Mode de dates réel d'une demande :
 *   · champ explicite → lui ;
 *   · sinon 'exact' si startDate ET endDate, 'exact' aussi si une seule date est posée
 *     (anciennes demandes : une balade n'a souvent que startDate) ;
 *   · sinon 'tbd'.
 */
const effectiveDateMode = (post) => {
  const explicit = normalizeDateMode(post && post.dateMode);
  if (explicit) return explicit;
  const start = parseDate(post && post.startDate);
  const end = parseDate(post && post.endDate);
  return (start || end) ? 'exact' : 'tbd';
};

/** Nombre de jours calendaires couverts (fin − début + 1), ≥ 1 ; null sans dates. */
const dayCount = (post) => {
  const start = parseDate(post && post.startDate);
  const end = parseDate(post && post.endDate) || start;
  if (!start) return null;
  const s = Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate());
  const e = Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), end.getUTCDate());
  if (e < s) return 1;
  return Math.floor((e - s) / DAY_MS) + 1;
};

/** Visites par jour (1 par défaut, 2 au plus). */
const visitsPerDayOf = (post) => {
  const n = Number(post && post.visitsPerDay);
  return VISITS_PER_DAY.includes(n) ? n : 1;
};

/**
 * Quantité facturée pour un service sur une demande.
 * @returns {{quantity:number|null, unit:string, days:number|null}}
 */
const quantityFor = (post, serviceType) => {
  const key = serviceKey(serviceType) || mainService(post);
  const unit = unitFor(key);
  const mode = effectiveDateMode(post);
  if (mode === 'tbd') return { quantity: null, unit: unit === 'day' && isSittersHome(post, key) ? 'night' : unit, days: null };
  const days = dayCount(post) || 1;
  if (unit === 'visit') return { quantity: days * visitsPerDayOf(post), unit: 'visit', days };
  if (unit === 'walk') return { quantity: 1, unit: 'walk', days };
  if (isSittersHome(post, key)) return { quantity: Math.max(1, days - 1), unit: 'night', days };
  return { quantity: days, unit: 'day', days };
};

const isSittersHome = (post, key) =>
  (key === 'house_sitting' || key === 'pet_sitting') && post
  && (post.houseSittingVenue === 'sitters_home' || post.serviceLocation === 'at_sitter');

/**
 * Estimation complète.
 * @param {{serviceType?:string, unit?:string, rate:number, post:object, commissionRate?:number, currency?:string}} p
 */
const estimate = ({ serviceType, unit, rate, post, commissionRate = 0.2, currency = 'EUR' } = {}) => {
  const q = quantityFor(post || {}, serviceType);
  const unitRate = round2(rate);
  const mode = effectiveDateMode(post || {});
  const indicative = mode === 'tbd';
  const outUnit = unit || q.unit;
  if (indicative || q.quantity == null || !(unitRate > 0)) {
    return {
      dateMode: mode,
      indicative: true,
      quantity: null,
      unit: outUnit,
      unitRate,
      unitTotal: null,
      commission: null,
      ownerTotal: null,
      commissionRate,
      currency,
    };
  }
  const unitTotal = round2(unitRate * q.quantity);
  const commission = round2(unitTotal * commissionRate);
  return {
    dateMode: mode,
    indicative: false,
    quantity: q.quantity,
    unit: outUnit,
    unitRate,
    unitTotal,
    commission,
    ownerTotal: round2(unitTotal + commission),
    commissionRate,
    currency,
  };
};

/**
 * Tarif unitaire d'un prestataire pour un service : { rate, unit, durationMinutes, source }
 * ou null quand il ne propose pas ce service à ce tarif.
 *   · visite   → visitRate (gardien)                       unit 'visit'
 *   · balade   → walkRates (promeneur) : durée demandée, sinon la moins chère   unit 'walk'
 *   · jour     → dailyRate, sinon weeklyRate/7, sinon monthlyRate/30, sinon hourlyRate × 8   unit 'day'
 *   · nuit     → même tarif que le jour                    unit 'night'
 */
const rateFor = (provider, serviceType, { durationMinutes, unit } = {}) => {
  const d = provider || {};
  const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);
  const key = serviceKey(serviceType);
  const u = unit || unitFor(key);
  if (u === 'visit') {
    const r = num(d.visitRate);
    return r > 0 ? { rate: round2(r), unit: 'visit', durationMinutes: VISIT_DURATIONS.includes(Number(d.visitDurationMinutes)) ? Number(d.visitDurationMinutes) : 30, source: 'visitRate' } : null;
  }
  if (u === 'walk') {
    const rates = (Array.isArray(d.walkRates) ? d.walkRates : [])
      .filter((w) => w && w.enabled !== false && num(w.basePrice) > 0);
    if (!rates.length) return null;
    const exact = durationMinutes ? rates.find((w) => Number(w.durationMinutes) === Number(durationMinutes)) : null;
    const pick = exact || rates.slice().sort((a, b) => num(a.basePrice) - num(b.basePrice))[0];
    return { rate: round2(pick.basePrice), unit: 'walk', durationMinutes: num(pick.durationMinutes) || null, source: 'walkRates' };
  }
  const outUnit = u === 'night' ? 'night' : 'day';
  if (num(d.dailyRate) > 0) return { rate: round2(d.dailyRate), unit: outUnit, durationMinutes: null, source: 'dailyRate' };
  if (num(d.weeklyRate) > 0) return { rate: round2(num(d.weeklyRate) / 7), unit: outUnit, durationMinutes: null, source: 'weeklyRate' };
  if (num(d.monthlyRate) > 0) return { rate: round2(num(d.monthlyRate) / 30), unit: outUnit, durationMinutes: null, source: 'monthlyRate' };
  if (num(d.hourlyRate) > 0) return { rate: round2(num(d.hourlyRate) * 8), unit: outUnit, durationMinutes: null, source: 'hourlyRate' };
  return null;
};

/**
 * Lit et valide les champs « dates » d'un corps de requête (createPost / updatePost).
 * @param {object} body            corps reçu (dateMode, startDate, endDate, visitsPerDay)
 * @param {object} [current]       demande existante (updatePost) — les champs absents gardent sa valeur
 * @returns {{ok:true, dateMode:string, startDate:Date|null, endDate:Date|null, visitsPerDay:number|null}|{ok:false, error:string, code:string}}
 */
const resolveDates = (body = {}, current = null) => {
  const has = (k) => body && Object.prototype.hasOwnProperty.call(body, k) && body[k] !== undefined;
  const cur = current || {};
  const start = has('startDate') ? parseDate(body.startDate) : parseDate(cur.startDate);
  const end = has('endDate') ? parseDate(body.endDate) : parseDate(cur.endDate);
  let mode = has('dateMode') ? normalizeDateMode(body.dateMode) : '';
  if (has('dateMode') && body.dateMode != null && String(body.dateMode).trim() !== '' && !mode) {
    return { ok: false, error: 'dateMode must be exact, approx or tbd.', code: 'INVALID_DATE_MODE' };
  }
  // Une date illisible n'est refusée qu'avec un dateMode explicite (client ≥ 620) ;
  // sans dateMode elle est ignorée, comme avant le 620 (apps ≤ 619).
  if (mode) {
    if (has('startDate') && body.startDate && !start) return { ok: false, error: 'startDate is invalid.', code: 'INVALID_DATES' };
    if (has('endDate') && body.endDate && !end) return { ok: false, error: 'endDate is invalid.', code: 'INVALID_DATES' };
  }
  if (!mode) {
    // Sans dateMode (apps ≤ 619, site actuel) : 'exact' dès qu'une date est posée, sinon 'tbd'.
    // Une modification qui ne touche ni au mode ni aux dates garde le mode enregistré.
    const kept = normalizeDateMode(cur.dateMode);
    if (kept && !has('startDate') && !has('endDate')) mode = kept;
    else mode = (start || end) ? 'exact' : 'tbd';
  }
  let visits = null;
  if (has('visitsPerDay') && body.visitsPerDay !== null && String(body.visitsPerDay).trim() !== '') {
    const n = Number(body.visitsPerDay);
    if (!VISITS_PER_DAY.includes(n)) return { ok: false, error: 'visitsPerDay must be 1 or 2.', code: 'INVALID_VISITS_PER_DAY' };
    visits = n;
  } else if (!has('visitsPerDay') && VISITS_PER_DAY.includes(Number(cur.visitsPerDay))) {
    visits = Number(cur.visitsPerDay);
  }
  if (mode === 'tbd') {
    if (has('dateMode') && (has('startDate') ? body.startDate : false)) {
      return { ok: false, error: 'dateMode tbd forbids startDate / endDate.', code: 'DATES_FORBIDDEN' };
    }
    return { ok: true, dateMode: 'tbd', startDate: null, endDate: null, visitsPerDay: visits };
  }
  // exact / approx : les deux dates, début ≤ fin (une seule date = ce jour-là).
  const s = start || end;
  const e = end || start;
  if (!s) return { ok: false, error: `dateMode ${mode} requires startDate and endDate.`, code: 'DATES_REQUIRED' };
  if (e < s) return { ok: false, error: 'startDate must be before endDate.', code: 'INVALID_DATES' };
  return { ok: true, dateMode: mode, startDate: s, endDate: e, visitsPerDay: visits };
};

module.exports = {
  DAY_MS,
  DATE_MODES,
  VISITS_PER_DAY,
  VISIT_DURATIONS,
  SERVICE_UNITS,
  serviceKey,
  unitFor,
  mainService,
  normalizeDateMode,
  effectiveDateMode,
  dayCount,
  visitsPerDayOf,
  quantityFor,
  estimate,
  rateFor,
  resolveDates,
  round2,
};
