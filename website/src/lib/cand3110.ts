// 31/10/2026 (LEO) — logique PURE de la page unique « mes candidats → payer » (/application/<id>),
// testée par scripts/test-cand3110.mjs : tri « le plus proche de chez toi, puis le moins cher »,
// pays du paiement déduit de la devise, choix de la demande à afficher.
import { type ApplicationItem, applicationId, applicationProvider } from "@/lib/api";

export type LatLng = { lat: number; lng: number };

export function haversineKm3110(a: LatLng, b: LatLng): number {
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((a.lat * Math.PI) / 180) * Math.cos((b.lat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

export function point3110(o?: { lat?: number; lng?: number } | null): LatLng | null {
  if (!o || typeof o.lat !== "number" || typeof o.lng !== "number") return null;
  if (!Number.isFinite(o.lat) || !Number.isFinite(o.lng)) return null;
  return { lat: o.lat, lng: o.lng };
}

/** Distance arrondie (≥ 1 km, jamais l'adresse) entre la demande et le prestataire, sinon null. */
export function kmOf3110(a: ApplicationItem, postPoint: LatLng | null): number | null {
  const { who } = applicationProvider(a);
  const pp = point3110(who?.location);
  if (!postPoint || !pp) return null;
  return Math.max(1, Math.round(haversineKm3110(postPoint, pp)));
}

/** Prix total affichable (serveur), sinon null : jamais un total absent, nul ou < au tarif unitaire. */
export function totalOf3110(a: ApplicationItem): number | null {
  const p = a.pricing;
  if (!p || p.stale === true || p.indicative === true) return null;
  const total = p.totalPrice ?? null;
  if (total == null || !(total > 0)) return null;
  const rate = p.appliedRate ?? null;
  if (rate != null && rate > 0 && total + 0.001 < rate) return null;
  return total;
}

/**
 * Ordre de la page : 1) le candidat de l'e-mail (focus) ; 2) le plus proche de chez toi (distance
 * inconnue en dernier) ; 3) à distance égale, le moins cher (total inconnu en dernier) ; 4) ordre
 * du serveur (stable).
 */
export function sortCandidates3110(items: ApplicationItem[], postPoint: LatLng | null, focusId?: string): ApplicationItem[] {
  const idx = new Map(items.map((x, i) => [applicationId(x), i]));
  return [...items].sort((x, y) => {
    const fx = focusId && applicationId(x) === focusId ? 0 : 1;
    const fy = focusId && applicationId(y) === focusId ? 0 : 1;
    if (fx !== fy) return fx - fy;
    const kx = kmOf3110(x, postPoint);
    const ky = kmOf3110(y, postPoint);
    if (kx !== ky) {
      if (kx == null) return 1;
      if (ky == null) return -1;
      return kx - ky;
    }
    const tx = totalOf3110(x);
    const ty = totalOf3110(y);
    if (tx !== ty) {
      if (tx == null) return 1;
      if (ty == null) return -1;
      return tx - ty;
    }
    return (idx.get(applicationId(x)) ?? 0) - (idx.get(applicationId(y)) ?? 0);
  });
}

/** Pays à transmettre à Airwallex selon la devise du propriétaire (règle de l'app : EUR → FR). */
export function countryForCurrency3110(currency: string): string {
  switch (String(currency || "").toUpperCase()) {
    case "USD": return "US";
    case "GBP": return "GB";
    case "CHF": return "CH";
    case "PLN": return "PL";
    case "KRW": return "KR";
    case "JPY": return "JP";
    case "CAD": return "CA";
    case "AUD": return "AU";
    default: return "FR";
  }
}

/**
 * La demande à montrer : celle du candidat du lien, sinon celle qui a le plus de candidats en
 * attente, sinon la plus récente. Renvoie l'id de demande ou "".
 */
export function pickPostId3110(apps: ApplicationItem[], focusId?: string): string {
  if (focusId) {
    const f = apps.find((a) => applicationId(a) === focusId);
    if (f?.postId) return String(f.postId);
  }
  const count = new Map<string, number>();
  for (const a of apps) {
    if (!a.postId) continue;
    const w = a.status === "pending" ? 1 : a.status === "accepted" ? 0.5 : 0;
    count.set(String(a.postId), (count.get(String(a.postId)) || 0) + w);
  }
  let best = "";
  let bestN = -1;
  for (const [pid, n] of count) if (n > bestN) { best = pid; bestN = n; }
  return best;
}
