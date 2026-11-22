// 31/10/2026 (LEO) — logique PURE de la page unique « mes candidats → payer » (/application/<id>),
// testée par scripts/test-cand3110.mjs : tri « photo, identité vérifiée, puis le plus proche de chez toi et le moins cher »,
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

/** 17/11 — le gardien ou le promeneur de cette candidature a-t-il le badge « Identité vérifiée » ? */
export function verified1711(a: ApplicationItem): boolean {
  return a.walker?.identityVerified === true || a.sitter?.identityVerified === true;
}

/** 22/11 — le candidat a-t-il une photo de profil ? (seul champ lu : `avatar` du gardien / promeneur de la carte). */
export function hasPhoto2211(a: ApplicationItem): boolean {
  const { who } = applicationProvider(a);
  return typeof who?.avatar === "string" && who.avatar.trim().length > 0;
}

/** 22/11 — au-delà de cette distance, un candidat à une promenade ou à une visite passe « Plus loin de chez toi ». */
export const FAR_KM_2211 = 10;
const NEAR_SERVICES_2211 = new Set(["dog_walking", "home_visit"]);

/**
 * 22/11 — « Plus loin de chez toi » : seulement pour une promenade ou une visite à domicile (service de la
 * candidature, sinon ceux de la demande : tous doivent être de ce type), à PLUS de 10 km. Distance inconnue =
 * traité comme proche. Personne n'est masqué : ces candidats sont seulement rangés après les autres.
 */
export function isFar2211(a: ApplicationItem, postPoint: LatLng | null, postServices?: string[] | null): boolean {
  const services = a.serviceType ? [String(a.serviceType)] : (postServices || []).map(String);
  if (!services.length || !services.every((x) => NEAR_SERVICES_2211.has(x))) return false;
  const km = kmOf3110(a, postPoint);
  return km != null && km > FAR_KM_2211;
}

/**
 * Ordre de la page (22/11, « confiance d'abord ») : 1) le candidat de l'e-mail (focus) ; 2) promenade / visite :
 * les candidats à plus de 10 km après tous les autres ; 3) les profils AVEC PHOTO ; 4) les profils « Identité
 * vérifiée » ; 5) le plus proche de chez toi (distance inconnue en dernier) ; 6) à distance égale, le moins cher
 * (total inconnu en dernier) ; 7) ordre du serveur (stable).
 */
export function sortCandidates3110(items: ApplicationItem[], postPoint: LatLng | null, focusId?: string, postServices?: string[] | null): ApplicationItem[] {
  const idx = new Map(items.map((x, i) => [applicationId(x), i]));
  return [...items].sort((x, y) => {
    const fx = focusId && applicationId(x) === focusId ? 0 : 1;
    const fy = focusId && applicationId(y) === focusId ? 0 : 1;
    if (fx !== fy) return fx - fy;
    // 22/11 — promenade / visite : au-delà de 10 km, après tous les autres (jamais masqué).
    const dx = isFar2211(x, postPoint, postServices) ? 1 : 0;
    const dy = isFar2211(y, postPoint, postServices) ? 1 : 0;
    if (dx !== dy) return dx - dy;
    // 22/11 (mesure : 42 % des gardiens ont une photo, 5 % une identité vérifiée) — la photo d'abord, puis
    // l'identité vérifiée (17/11) ; entre profils de même niveau, l'ordre d'avant ne change pas.
    const px = hasPhoto2211(x) ? 0 : 1;
    const py = hasPhoto2211(y) ? 0 : 1;
    if (px !== py) return px - py;
    const vx = verified1711(x) ? 0 : 1;
    const vy = verified1711(y) ? 0 : 1;
    if (vx !== vy) return vx - vy;
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
