// 25/09/2026 (PawMap 585, lot 2 — bug 16) — PRIX ESTIMÉ d'une réservation,
// port fidèle du calcul serveur (backend/src/utils/tierPricing.js et
// controllers/bookingController.js, tarif promenade exact par durée). Pur,
// testé par scripts/test-bookingEstimate.mjs.
//
// Types de service envoyés (valeurs canoniques acceptées par le serveur) :
//   gardien  : house_sitting (+ lieu owners_home | sitters_home), home_visit,
//              day_care, long_stay ;
//   promeneur : dog_walking (+ duration 30 / 60 / 120).

export type SitterService = "house_sitting" | "home_visit" | "day_care" | "long_stay";
export type WalkerService = "dog_walking";
export type BookService = SitterService | WalkerService;

export const SITTER_SERVICES: SitterService[] = ["house_sitting", "home_visit", "day_care", "long_stay"];
export const WALK_DURATIONS = [30, 60, 120] as const;
export const VISIT_DURATIONS = [30, 60] as const;

export type RateSource = {
  hourlyRate?: number | null;
  dailyRate?: number | null;
  weeklyRate?: number | null;
  monthlyRate?: number | null;
  extraPetRate?: number | null;
  walkRates?: { durationMinutes?: number; basePrice?: number; enabled?: boolean }[] | null;
};

const num = (v: unknown) => {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : 0;
};
const round2 = (n: number) => Math.round(n * 100) / 100;

/** Même règle que calculateTierBasePrice (serveur). null = pas de tarif. */
export function tierPrice(rates: RateSource, startMs: number, endMs: number, durationMinutes?: number | null): number | null {
  const h = num(rates.hourlyRate);
  const d = num(rates.dailyRate);
  const w = num(rates.weeklyRate);
  const m = num(rates.monthlyRate);
  let hEff = h > 0 ? h : d > 0 ? d / 8 : 0;
  // Repli serveur : ni heure ni jour → dérivé de la semaine / du mois.
  if (!h && !d) {
    if (w) hEff = w / 56;
    else if (m) hEff = m / 240;
  }
  if (hEff <= 0) return null;
  if (!Number.isFinite(startMs)) return null;
  let end = endMs;
  if (!Number.isFinite(end) || end <= startMs) {
    const dm = Number(durationMinutes);
    end = startMs + (Number.isFinite(dm) && dm > 0 ? dm : 60) * 60000;
  }
  const dm = Number(durationMinutes);
  const explicit = Number.isFinite(dm) && dm > 0 && dm < 60;
  const rawHours = (end - startMs) / 3600000;
  const hoursRaw = explicit ? rawHours : Math.max(rawHours, 1);
  const totalHours = round2(hoursRaw);
  const totalDays = Math.max(1, Math.ceil(hoursRaw / 24));
  let price = totalHours * hEff;
  if (totalDays >= 30 && m > 0) price = Math.floor(totalDays / 30) * m + (totalDays % 30) * (m / 30);
  else if (totalDays >= 7 && w > 0) price = Math.floor(totalDays / 7) * w + (totalDays % 7) * (w / 7);
  else if (totalDays >= 1 && d > 0 && hoursRaw >= 8) {
    const fullDays = Math.floor(hoursRaw / 24);
    const rem = hoursRaw - fullDays * 24;
    price = fullDays === 0 ? d : fullDays * d + (rem > 0 ? rem * hEff : 0);
  }
  return round2(price);
}

/** Tarif horaire d'un promeneur pour une durée (palier exact, sinon 60, sinon le plus proche). */
export function walkHourly(rates: RateSource, minutes: number): number | null {
  const list = (rates.walkRates || []).filter((r) => r && r.enabled !== false && num(r.basePrice) > 0 && num(r.durationMinutes) > 0);
  const exact = list.find((r) => Number(r.durationMinutes) === minutes);
  if (exact) return (num(exact.basePrice) * 60) / minutes;
  const sixty = list.find((r) => Number(r.durationMinutes) === 60);
  if (sixty) return num(sixty.basePrice);
  if (list.length) {
    const near = [...list].sort((a, b) => Math.abs(Number(a.durationMinutes) - minutes) - Math.abs(Number(b.durationMinutes) - minutes))[0];
    return (num(near.basePrice) * 60) / num(near.durationMinutes);
  }
  return num(rates.hourlyRate) || null;
}

export type EstimateInput = {
  role: "sitter" | "walker";
  service: BookService;
  /** Début : date AAAA-MM-JJ + heure HH:MM. */
  startDate: string;
  startTime: string;
  /** Fin (garde à domicile, long séjour) : date AAAA-MM-JJ + heure HH:MM. */
  endDate?: string;
  endTime?: string;
  durationMinutes?: number;
  pets: number;
};

/** Début et fin EFFECTIFS envoyés au serveur (null si incomplet). */
export function bookingWindow(i: EstimateInput): { start: Date; end: Date } | null {
  if (!i.startDate) return null;
  const start = new Date(`${i.startDate}T${i.startTime || "09:00"}:00`);
  if (Number.isNaN(start.getTime())) return null;
  let end: Date;
  if (i.service === "house_sitting" || i.service === "long_stay") {
    if (!i.endDate) return null;
    end = new Date(`${i.endDate}T${i.endTime || i.startTime || "09:00"}:00`);
  } else if (i.service === "day_care") {
    end = new Date(start.getTime() + 8 * 3600000); // même filet que le serveur
  } else {
    end = new Date(start.getTime() + (i.durationMinutes || 60) * 60000);
  }
  if (Number.isNaN(end.getTime()) || end <= start) return null;
  return { start, end };
}

/** Prix estimé (devise du prestataire). Le serveur ne facture pas l'animal en
 *  plus à la création (seul tierPricing compte) : on ne l'ajoute pas ici. */
export function estimateBooking(rates: RateSource, i: EstimateInput): number | null {
  const win = bookingWindow(i);
  if (!win) return null;
  let base: number | null;
  if (i.role === "walker") {
    const minutes = i.durationMinutes || 60;
    const hourly = walkHourly(rates, minutes);
    if (!hourly) return null;
    base = tierPrice({ hourlyRate: hourly }, win.start.getTime(), win.end.getTime(), minutes);
  } else {
    base = tierPrice(rates, win.start.getTime(), win.end.getTime(), i.service === "home_visit" ? i.durationMinutes : null);
  }
  return base == null ? null : round2(base);
}

/** Nombre de nuits/jours entre deux dates AAAA-MM-JJ (≥ 0). */
export function daysBetween(a: string, b: string): number {
  const s = new Date(`${a}T00:00:00`).getTime();
  const e = new Date(`${b}T00:00:00`).getTime();
  if (!Number.isFinite(s) || !Number.isFinite(e)) return 0;
  return Math.max(0, Math.round((e - s) / 86400000));
}
