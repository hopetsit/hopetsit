// 25/10/2026 (LEO, 622 — ordre de Daniel 01 h 25 via BOB : « il n'y a pas beaucoup les prix »).
// Prix de la PawMap du site, alignés sur l'app (PAM, build 622) et sur le serveur :
//   1. gardien / promeneur : son tarif quand il existe — `priceFrom`, sinon le plus petit tarif
//      de `prices` (cas réel mesuré le 25/10 : priceFrom 0 mais house_sitting 14,29 €/jour) ;
//      jamais de prix inventé ;
//   2. rond de groupe : « dès X » = le plus petit tarif RÉEL des gardiens du groupe (sinon des
//      promeneurs), une seule devise, rien sinon ;
//   3. demande d'un propriétaire : son budget ; sans budget, « dès X €/jour » lu sur
//      POST /pricing/estimate/public (route de ZOE, sans jeton, 30 appels/min/IP) — rien quand
//      basedOn vaut 0 ; la fiche ajoute « estimation ~Y € » quand la demande a ses dates.
// Module PUR (aucun React, aucun fetch) : testé par scripts/test-mapPrice622.mjs.

export type PriceUnit622 = "day" | "night" | "visit" | "walk" | "hour";
type PriceMap = Record<string, { amount?: unknown; unit?: unknown } | null | undefined>;
type Priced = { role?: string | null; priceFrom?: number | null; priceUnit?: string | null; currency?: string | null; prices?: unknown; priceAlt?: unknown };

const UNITS = new Set(["day", "night", "visit", "walk", "hour"]);

/** Plus petit tarif > 0 de `prices` ({ house_sitting: { amount, unit } … }), ou null. */
export function minFromPrices622(prices: unknown): { amount: number; unit: PriceUnit622 | null } | null {
  if (!prices || typeof prices !== "object") return null;
  let best: { amount: number; unit: PriceUnit622 | null } | null = null;
  for (const v of Object.values(prices as PriceMap)) {
    if (!v || typeof v !== "object") continue;
    const amount = Number(v.amount);
    if (!Number.isFinite(amount) || amount <= 0) continue;
    const u = String(v.unit || "").toLowerCase();
    if (!best || amount < best.amount) best = { amount: Math.round(amount * 100) / 100, unit: UNITS.has(u) ? (u as PriceUnit622) : null };
  }
  return best;
}

/** Copie d'un rôle dont `priceFrom` vaut 0 mais qui a des tarifs par service : le plus petit devient `priceFrom`. */
export function withEffectivePrice622<T extends Priced>(r: T): T {
  if (!r || (Number(r.priceFrom) || 0) > 0) return r;
  const m = minFromPrices622(r.prices);
  if (!m) return r;
  return { ...r, priceFrom: m.amount, priceUnit: m.unit || r.priceUnit || "" };
}

/** Un membre de la carte (et chacun de ses rôles) avec son tarif effectif. Même objet si rien ne change. */
export function normalizeMemberPrices622<T extends Priced & { roles?: Priced[] | null }>(m: T): T {
  const roles = Array.isArray(m.roles) ? m.roles.map((r) => withEffectivePrice622(r)) : m.roles;
  const top = withEffectivePrice622(m);
  const rolesChanged = Array.isArray(m.roles) && roles !== m.roles && (roles as Priced[]).some((r, i) => r !== (m.roles as Priced[])[i]);
  if (top === m && !rolesChanged) return m;
  return { ...top, roles: rolesChanged ? roles : m.roles };
}

/**
 * « dès X » d'un rond de groupe : rôle gardien d'abord (sinon promeneur), plus petit tarif réel.
 * `rolesOf` renvoie les rôles d'une personne ; `format` met en forme (null = pas montrable).
 * Une seule devise : si le groupe mélange les devises, rien (jamais d'addition entre devises).
 */
export function clusterFromPrice622<M>(
  items: M[],
  rolesOf: (m: M) => Priced[],
  format: (r: Priced) => string | null,
): { label: string; role: "sitter" | "walker" } | null {
  for (const want of ["sitter", "walker"]) {
    let best: Priced | null = null;
    const currencies = new Set<string>();
    for (const m of items) {
      for (const r0 of rolesOf(m)) {
        if (String(r0.role || "").toLowerCase() !== want) continue;
        const r = withEffectivePrice622(r0);
        const a = Number(r.priceFrom) || 0;
        if (a <= 0) continue;
        currencies.add(String(r.currency || "EUR").toUpperCase());
        if (!best || a < (Number(best.priceFrom) || 0)) best = r;
      }
    }
    if (best) {
      const label = currencies.size === 1 ? format(best) : null;
      return label ? { label, role: want as "sitter" | "walker" } : null;
    }
  }
  return null;
}

// ─── Demandes des propriétaires ────────────────────────────────────────────────

export type MapRequestPricing622 = {
  serviceType?: string | null;
  lat: number;
  lng: number;
  currency?: string | null;
  country?: string | null;
  dateMode?: string | null;
  startDate?: string | null;
  endDate?: string | null;
  visitsPerDay?: number | null;
};

export type RequestEstimateBody622 = {
  serviceType: string;
  lat: number;
  lng: number;
  currency?: string;
  country?: string;
  startDate?: string;
  endDate?: string;
  visitsPerDay?: number;
};

const day = (v: unknown): string => {
  const s = String(v || "");
  const m = /^(\d{4}-\d{2}-\d{2})/.exec(s);
  return m ? m[1] : "";
};

/** Service de l'estimation : le 1er service de la demande, sinon la garde (« sitting ») ou la promenade. */
export function requestServiceType622(types: string[] | null | undefined, service: "sitting" | "walk"): string {
  const first = (types || []).map((s) => String(s || "").trim()).find(Boolean);
  if (first) return first;
  return service === "walk" ? "dog_walking" : "house_sitting";
}

/**
 * Corps de POST /pricing/estimate/public pour une demande : position FLOUTÉE (~1 km, celle de
 * la carte), devise de la demande (sinon pays), dates seulement si les deux sont là et dans le
 * bon ordre (mode « à prévoir » = tarif unitaire seul). Aucune donnée personnelle.
 * `withDates` false = tarif unitaire seul (bulle de la carte).
 */
export function requestEstimateBody622(r: MapRequestPricing622, withDates = true): RequestEstimateBody622 | null {
  const serviceType = String(r.serviceType || "").trim();
  if (!serviceType || !Number.isFinite(r.lat) || !Number.isFinite(r.lng) || (r.lat === 0 && r.lng === 0)) return null;
  const body: RequestEstimateBody622 = { serviceType, lat: Math.round(r.lat * 100) / 100, lng: Math.round(r.lng * 100) / 100 };
  const cur = String(r.currency || "").trim().toUpperCase();
  if (/^[A-Z]{3}$/.test(cur)) body.currency = cur;
  const cc = String(r.country || "").trim().toUpperCase();
  if (/^[A-Z]{2}$/.test(cc)) body.country = cc;
  // Demande sans devise ni pays (mesuré le 25/10 : aucune des 22 demandes ouvertes n'en porte) : le
  // serveur prendrait l'euro et ne trouverait aucun gardien new-yorkais (tarifs en dollars, filtrés par
  // devise → basedOn 0, rien d'affiché). Dans le rectangle des États-Unis continentaux → pays US.
  // Hors de ce rectangle : rien d'ajouté (euro par défaut côté serveur ; une autre devise = basedOn 0,
  // donc jamais un faux prix).
  if (!body.currency && !body.country && inContinentalUS622(r.lat, r.lng)) body.country = "US";
  if (withDates && String(r.dateMode || "").toLowerCase() !== "tbd") {
    const s = day(r.startDate);
    const e = day(r.endDate);
    if (s && e && e >= s) { body.startDate = s; body.endDate = e; }
  }
  const v = Number(r.visitsPerDay);
  if (/home_visit|visit/i.test(serviceType) && (v === 1 || v === 2)) body.visitsPerDay = v;
  return body;
}

/** États-Unis continentaux (rectangle large, aucune ville européenne dedans). */
export function inContinentalUS622(lat: number, lng: number): boolean {
  return lat >= 24.4 && lat <= 49.4 && lng >= -125 && lng <= -66.8;
}

/** Clé d'une estimation de BULLE : même service, même devise, même zone d'~50 km = un seul appel. */
export function requestBubbleKey622(b: RequestEstimateBody622 | null): string {
  if (!b) return "";
  return [b.serviceType, b.currency || "", b.country || "", Math.round(b.lat * 2) / 2, Math.round(b.lng * 2) / 2].join("|");
}

/** Clé d'une estimation de FICHE (dates comprises). */
export function requestFicheKey622(b: RequestEstimateBody622 | null): string {
  if (!b) return "";
  return [b.serviceType, b.currency || "", b.country || "", b.lat, b.lng, b.startDate || "", b.endDate || "", b.visitsPerDay ?? ""].join("|");
}

/** Plafond d'appels de bulles par chargement de carte (la route publique accepte 30/min/IP). */
export const BUBBLE_ESTIMATE_MAX_622 = 10;

/** Estimation utilisable : marché réel, tarif > 0, au moins 1 prestataire. */
export function usableEstimate622(e: { market?: boolean; fromRate?: number | null; basedOn?: number | null } | null | undefined): boolean {
  return !!e && !!e.market && (Number(e.fromRate) || 0) > 0 && (Number(e.basedOn) || 0) > 0;
}
