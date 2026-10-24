// 24/10/2026 (620, LEO — CONTRAT_620_dates_visites.md §B, ordre de Daniel) :
// CATALOGUE des 4 services avec leur UNITÉ, MODES DE DATES et QUANTITÉS.
//
// Module PUR (aucun React, aucun fetch) : testé par scripts/test-services620.mjs.
//
// Contrat serveur (ZOE, §A) :
//   · GET /app-config/services (public, cache 60 s) → 4 services : house_sitting
//     (unité `day`), home_visit (unité `visit`, durée 30|60, visitsPerDay 1|2),
//     day_care (`day`), dog_walking (`walk`). Le site reconnaît le NOUVEAU
//     serveur à la présence de `home_visit` ; sans lui, il garde son
//     comportement d'avant (3 services, dates obligatoires, aucune estimation).
//   · Post : dateMode 'exact' | 'approx' | 'tbd' (défaut : 'exact' si début ET
//     fin, sinon 'tbd'), visitsPerDay 1 | 2 | null.
//   · Quantité (utils/pricingEngine620.js) : jours = fin − début + 1 ; nuits =
//     jours − 1 chez le gardien ; visites = jours × visitsPerDay ; balade = 1.
//     tbd → quantité null : on n'affiche QUE le tarif unitaire.
//
// Textes : lib/i18n/dates620.ts (9 langues).

export type ServiceKey620 = "house_sitting" | "home_visit" | "day_care" | "dog_walking";
export type PriceUnit620 = "day" | "night" | "visit" | "walk" | "hour" | "week" | "month";
export type DateMode620 = "exact" | "approx" | "tbd";

export type ServiceDef620 = {
  key: ServiceKey620;
  unit: PriceUnit620;
  /** Visite : durées proposées au gardien (minutes). */
  durations?: number[];
  /** Visite : nombre de passages par jour proposés au propriétaire. */
  visitsPerDay?: number[];
  /** Libellé fourni par le serveur dans la langue demandée (facultatif). */
  labels?: Record<string, string>;
};

export const SERVICE_KEYS_620: ServiceKey620[] = ["house_sitting", "home_visit", "day_care", "dog_walking"];

/** Ancien serveur (avant le 620) : les 3 services que le site connaissait. */
export const LEGACY_SERVICES_620: ServiceDef620[] = [
  { key: "house_sitting", unit: "day" },
  { key: "day_care", unit: "day" },
  { key: "dog_walking", unit: "walk" },
];

/** Catalogue 620 complet (repli quand le serveur renvoie `home_visit` sans détail). */
export const FULL_SERVICES_620: ServiceDef620[] = [
  { key: "house_sitting", unit: "day" },
  { key: "home_visit", unit: "visit", durations: [30, 60], visitsPerDay: [1, 2] },
  { key: "day_care", unit: "day" },
  { key: "dog_walking", unit: "walk" },
];

export function isServiceKey620(v: unknown): v is ServiceKey620 {
  return typeof v === "string" && (SERVICE_KEYS_620 as string[]).includes(v);
}

export function priceUnit620(v: unknown): PriceUnit620 | null {
  const s = String(v || "").trim().toLowerCase();
  if (s === "day" || s === "daily") return "day";
  if (s === "night" || s === "nightly") return "night";
  if (s === "visit" || s === "per_visit") return "visit";
  if (s === "walk" || s === "per_walk") return "walk";
  if (s === "hour" || s === "hourly") return "hour";
  if (s === "week" || s === "weekly") return "week";
  if (s === "month" || s === "monthly") return "month";
  return null;
}

export function unitOfService620(service: string | null | undefined, services?: ServiceDef620[] | null): PriceUnit620 {
  const found = (services || FULL_SERVICES_620).find((s) => s.key === service);
  if (found) return found.unit;
  if (service === "dog_walking") return "walk";
  if (service === "home_visit") return "visit";
  return "day";
}

/**
 * Lecture TOLÉRANTE de GET /app-config/services. Formes acceptées :
 *   { services: [ { key, unit, durations, visitsPerDay, label|labels } ] }
 *   { services: { home_visit: { unit, … }, … } }
 *   [ { key, … } ]
 * Retourne null quand `home_visit` n'y est pas (ancien serveur) → le site
 * garde son comportement d'avant.
 */
export function parseCatalog620(raw: unknown): ServiceDef620[] | null {
  if (!raw || typeof raw !== "object") return null;
  const root = raw as Record<string, unknown>;
  let list: unknown = Array.isArray(raw) ? raw : root.services ?? root.catalog ?? root.items ?? null;
  if (list && typeof list === "object" && !Array.isArray(list)) {
    list = Object.entries(list as Record<string, unknown>).map(([key, v]) => ({ key, ...(v && typeof v === "object" ? (v as Record<string, unknown>) : {}) }));
  }
  if (!Array.isArray(list)) return null;
  const out: ServiceDef620[] = [];
  for (const it of list) {
    if (!it || typeof it !== "object") continue;
    const o = it as Record<string, unknown>;
    const key = o.key ?? o.id ?? o.type ?? o.serviceType;
    if (!isServiceKey620(key)) continue;
    if (o.active === false || o.enabled === false) continue;
    const base = FULL_SERVICES_620.find((s) => s.key === key)!;
    const unit = priceUnit620(o.unit ?? o.priceUnit) ?? base.unit;
    const nums = (v: unknown): number[] | undefined =>
      Array.isArray(v) ? v.map(Number).filter((n) => Number.isFinite(n) && n > 0) : undefined;
    const durations = nums(o.durations ?? o.durationMinutes ?? o.visitDurations) ?? base.durations;
    const visitsPerDay = nums(o.visitsPerDay ?? o.visitsPerDayOptions) ?? base.visitsPerDay;
    const labels = o.labels && typeof o.labels === "object" ? (o.labels as Record<string, string>) : o.label && typeof o.label === "object" ? (o.label as Record<string, string>) : undefined;
    if (!out.some((s) => s.key === key)) out.push({ key, unit, ...(durations?.length ? { durations } : {}), ...(visitsPerDay?.length ? { visitsPerDay } : {}), ...(labels ? { labels } : {}) });
  }
  if (!out.some((s) => s.key === "home_visit")) return null;
  // Ordre du contrat : garde, visite, garderie, promenade.
  out.sort((a, b) => SERVICE_KEYS_620.indexOf(a.key) - SERVICE_KEYS_620.indexOf(b.key));
  return out;
}

/** Jour civil AAAA-MM-JJ → ms UTC (null si vide ou illisible). */
function dayMs(v: string | null | undefined): number | null {
  if (!v) return null;
  const s = String(v).slice(0, 10);
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) {
    const t = new Date(String(v)).getTime();
    if (!Number.isFinite(t)) return null;
    const d = new Date(t);
    return Date.UTC(d.getFullYear(), d.getMonth(), d.getDate());
  }
  return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
}

/** Nombre de jours civils, début et fin COMPRIS (0 si incomplet ou inversé). */
export function daysBetween620(start: string | null | undefined, end: string | null | undefined): number {
  const a = dayMs(start), b = dayMs(end);
  if (a == null || b == null || b < a) return 0;
  return Math.round((b - a) / 86400000) + 1;
}

/** Mode de dates d'une demande (compatibilité : les anciennes demandes n'ont pas `dateMode`). */
export function dateModeOf620(post: { dateMode?: string | null; startDate?: string | null; endDate?: string | null } | null | undefined): DateMode620 {
  const m = String(post?.dateMode || "").toLowerCase();
  if (m === "exact" || m === "approx" || m === "tbd") return m;
  return post?.startDate && post?.endDate ? "exact" : "tbd";
}

/** Les dates sont-elles valables pour ce mode ? (exact / approx : début ≤ fin ; tbd : aucune) */
export function datesValid620(mode: DateMode620, start: string, end: string): boolean {
  if (mode === "tbd") return true;
  return daysBetween620(start, end) > 0;
}

export type Quantity620 = { quantity: number | null; unit: PriceUnit620 };

/**
 * Port de `quantityFor(post, serviceType)` (serveur) : jours (fin − début + 1),
 * nuits = jours − 1 quand l'animal dort chez le gardien, visites = jours ×
 * visitsPerDay, balade = 1. Mode `tbd` → null (indicatif : tarif unitaire seul).
 */
export function quantityFor620(input: {
  service: string | null | undefined;
  dateMode: DateMode620;
  startDate?: string | null;
  endDate?: string | null;
  visitsPerDay?: number | null;
  venue?: "owners_home" | "sitters_home" | string | null;
  services?: ServiceDef620[] | null;
}): Quantity620 {
  const unit0 = unitOfService620(input.service, input.services);
  if (input.dateMode === "tbd") return { quantity: null, unit: unit0 };
  const days = daysBetween620(input.startDate, input.endDate);
  if (days <= 0) return { quantity: null, unit: unit0 };
  if (input.service === "dog_walking") return { quantity: 1, unit: "walk" };
  if (input.service === "home_visit") {
    const v = Number(input.visitsPerDay);
    const per = v === 2 ? 2 : 1;
    return { quantity: days * per, unit: "visit" };
  }
  if (input.service === "house_sitting" && input.venue === "sitters_home") {
    return { quantity: Math.max(1, days - 1), unit: "night" };
  }
  return { quantity: days, unit: "day" };
}

export type Estimate620 = {
  quantity: number | null;
  unit: PriceUnit620;
  /** Tarif unitaire du prestataire (devise `currency`). */
  rate: number | null;
  currency: string;
  unitTotal: number | null;
  commission: number | null;
  ownerTotal: number | null;
  indicative: boolean;
  /** true = calcul du serveur (POST /pricing/estimate), false = calcul local de secours. */
  fromServer: boolean;
  /**
   * 620b (24/10, serveur de ZOE) — demande OUVERTE (aucun prestataire visé) : « à partir de »
   * = minimum des prestataires du rayon d'alerte. `basedOn` 0 → rien à afficher.
   */
  market?: boolean;
  fromRate?: number | null;
  ownerTotalFrom?: number | null;
  basedOn?: number;
};

/** Estimation LOCALE de secours (invité sans compte, serveur ancien ou injoignable). Même règle que le serveur : commission 20 %. */
export function estimateLocal620(q: Quantity620, rate: number | null, currency: string, commissionRate = 0.2): Estimate620 {
  const r = rate != null && Number.isFinite(rate) && rate > 0 ? rate : null;
  if (q.quantity == null || r == null) {
    return { quantity: q.quantity, unit: q.unit, rate: r, currency, unitTotal: null, commission: null, ownerTotal: null, indicative: q.quantity == null, fromServer: false };
  }
  const unitTotal = Math.round(r * q.quantity * 100) / 100;
  const commission = Math.round(unitTotal * commissionRate * 100) / 100;
  return { quantity: q.quantity, unit: q.unit, rate: r, currency, unitTotal, commission, ownerTotal: Math.round((unitTotal + commission) * 100) / 100, indicative: false, fromServer: false };
}

/** Lecture tolérante de la réponse de POST /pricing/estimate ({ estimate: {…} } ou à plat). */
export function parseEstimate620(raw: unknown, fallback: Quantity620, currency: string): Estimate620 | null {
  if (!raw || typeof raw !== "object") return null;
  const root = raw as Record<string, unknown>;
  const e = (root.estimate && typeof root.estimate === "object" ? root.estimate : root) as Record<string, unknown>;
  const num = (v: unknown): number | null => {
    const n = Number(v);
    return v == null || !Number.isFinite(n) ? null : n;
  };
  const quantity = num(e.quantity);
  const unit = priceUnit620(e.unit ?? e.priceUnit) ?? fallback.unit;
  const rate0 = num(e.rate ?? e.unitRate ?? e.appliedRate);
  // Serveur sans tarif pour ce prestataire (code NO_RATE, unitRate 0) → aucun tarif, jamais « 0 € ».
  const rate = rate0 != null && rate0 > 0 ? rate0 : null;
  const ownerTotal = num(e.ownerTotal ?? e.total ?? e.totalPrice);
  const unitTotal = num(e.unitTotal ?? e.basePrice);
  const commission = num(e.commission);
  const indicative = e.indicative === true || (quantity == null && ownerTotal == null);
  // Rien de reconnaissable (page d'erreur, autre route) → null ; une réponse du moteur
  // (même sans tarif : NO_RATE) est gardée telle quelle.
  const known = ["quantity", "ownerTotal", "unitTotal", "unitRate", "rate", "indicative", "fromRate"].some((k) => k in e);
  if (!known) return null;
  const cur = String(e.currency || currency || "EUR").toUpperCase();
  // 620b — réponse « market » (demande ouverte) : fromRate / ownerTotalFrom / basedOn ; le tarif
  // unitaire n'est pas celui d'un prestataire → `rate` reste null (jamais pris pour un prix ferme).
  if (e.rateSource === "market" || "fromRate" in e || "basedOn" in e) {
    const fromRate0 = num(e.fromRate);
    const basedOn = Math.max(0, Math.trunc(num(e.basedOn) ?? 0));
    const fromRate = fromRate0 != null && fromRate0 > 0 && basedOn > 0 ? fromRate0 : null;
    const ownerTotalFrom0 = num(e.ownerTotalFrom);
    return {
      quantity, unit, rate: null, currency: cur, unitTotal: null, commission: null, ownerTotal: null, indicative: true, fromServer: true,
      market: true, fromRate, ownerTotalFrom: fromRate != null && ownerTotalFrom0 != null && ownerTotalFrom0 > 0 ? ownerTotalFrom0 : null, basedOn: fromRate != null ? basedOn : 0,
    };
  }
  return { quantity, unit, rate, currency: cur, unitTotal, commission, ownerTotal, indicative, fromServer: true };
}

export type ProviderRates620 = {
  currency: string;
  hourlyRate: number | null;
  dailyRate: number | null;
  weeklyRate: number | null;
  monthlyRate: number | null;
  visitRate: number | null;
  visitDurationMinutes: number | null;
  walkRates: { durationMinutes: number; basePrice: number }[];
};

const pos = (v: unknown): number | null => {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : null;
};

/** Tarifs d'un profil gardien / promeneur (GET /sitters/:id, /walkers/:id, /users/me/profile). */
export function readProviderRates620(raw: unknown): ProviderRates620 {
  const p = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const walkRaw = Array.isArray(p.walkRates) ? (p.walkRates as Record<string, unknown>[]) : [];
  const walkRates = walkRaw
    .filter((w) => w && w.enabled !== false && pos(w.basePrice) != null && pos(w.durationMinutes) != null)
    .map((w) => ({ durationMinutes: Number(w.durationMinutes), basePrice: Number(w.basePrice) }));
  const wc = walkRaw.find((w) => w && w.currency)?.currency;
  const vd = Number(p.visitDurationMinutes);
  return {
    currency: String(p.currency || wc || "EUR").toUpperCase(),
    hourlyRate: pos(p.hourlyRate),
    dailyRate: pos(p.dailyRate),
    weeklyRate: pos(p.weeklyRate),
    monthlyRate: pos(p.monthlyRate),
    visitRate: pos(p.visitRate),
    visitDurationMinutes: vd === 60 ? 60 : vd === 30 ? 30 : null,
    walkRates,
  };
}

/**
 * Tarif unitaire d'un prestataire POUR un service (même règle que `priceFrom` +
 * `priceUnit` du serveur) : garde / garderie = jour (sinon heure × 8), visite =
 * visitRate, promenade = la balade la moins chère. null = non proposé.
 */
export function rateForService620(rates: ProviderRates620, service: string | null | undefined, walkDurationMinutes?: number | null): { rate: number; unit: PriceUnit620 } | null {
  if (service === "dog_walking") {
    if (!rates.walkRates.length) return rates.hourlyRate ? { rate: rates.hourlyRate, unit: "walk" } : null;
    const exact = walkDurationMinutes ? rates.walkRates.find((w) => w.durationMinutes === walkDurationMinutes) : null;
    const pick = exact ?? [...rates.walkRates].sort((a, b) => a.basePrice - b.basePrice)[0];
    return { rate: pick.basePrice, unit: "walk" };
  }
  if (service === "home_visit") return rates.visitRate ? { rate: rates.visitRate, unit: "visit" } : null;
  if (rates.dailyRate) return { rate: rates.dailyRate, unit: "day" };
  if (rates.hourlyRate) return { rate: Math.round(rates.hourlyRate * 8 * 100) / 100, unit: "day" };
  if (rates.weeklyRate) return { rate: rates.weeklyRate, unit: "week" };
  if (rates.monthlyRate) return { rate: rates.monthlyRate, unit: "month" };
  return null;
}

/** Services qu'un prestataire propose vraiment (tarif > 0), dans l'ordre du catalogue. */
export function offeredServices620(role: "sitter" | "walker", rates: ProviderRates620, services?: ServiceDef620[] | null): ServiceKey620[] {
  const cat = services || FULL_SERVICES_620;
  return cat
    .map((s) => s.key)
    .filter((k) => (role === "walker" ? k === "dog_walking" : k !== "dog_walking"))
    .filter((k) => rateForService620(rates, k) != null);
}
