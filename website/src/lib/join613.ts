// 07/10/2026 — LEO (613) : « Rejoindre john · 355 m · 4 min à pied » pendant un suivi,
// comme l'app 613 (pawJoinLabel613 / pawJoinLine613 / pawKeepNumberWithUnit613 dans
// frontend/lib/views/map/widgets/pawmap_sheets.dart, _joinLine613 / _formatDuration dans
// paw_map_screen.dart). Textes : clés pm613_join, pm613_join_plain, pm613_walk_time,
// route_duration_min, route_duration_h — copiées de l'app (site613.ts, généré).
// Fichier pur (sans React) : testé par scripts/test-613.mjs.

type T = (k: string) => string;

/** Prénom seul (premier mot du nom). */
export function firstName613(fullName: string | null | undefined): string {
  return (fullName || "").trim().split(/\s+/)[0] || "";
}

/** « Rejoindre john » (prénom seul) ; « Le rejoindre » sans nom connu. */
export function joinLabel613(t: T, fullName: string | null | undefined): string {
  const first = firstName613(fullName);
  return first ? t("pm613_join").replace("@name", first) : t("pm613_join_plain");
}

/**
 * Toute espace qui TOUCHE un chiffre devient insécable (U+00A0) : « 355 m », « 4 min »,
 * « 1 h 05 min », « 1 Std. 5 Min. » ne se coupent jamais ; « min à pied » peut passer à la ligne.
 */
export function keepNumberWithUnit613(s: string): string {
  return s.replace(/(\d)[ \t]+/g, "$1 ").replace(/[ \t]+(\d)/g, " $1");
}

/** Distance comme l'app : « 355 m », « 1.2 km » (mètres entiers ; km à 1 décimale, point). */
export function formatJoinDistance613(meters: number | null | undefined): string {
  if (meters == null || !Number.isFinite(meters)) return "";
  const m = Math.round(meters);
  return m >= 1000 ? `${(m / 1000).toFixed(1)} km` : `${m} m`;
}

/** Durée comme l'app (`_formatDuration`) : « 4 min », « 1 h 05 min » selon la langue. */
export function formatJoinDuration613(t: T, seconds: number | null | undefined): string {
  if (seconds == null || !(seconds > 0)) return "";
  const min = Math.round(seconds / 60);
  if (min < 60) return t("route_duration_min").replace("{min}", String(min < 1 ? 1 : min));
  return t("route_duration_h").replace("{h}", String(Math.floor(min / 60))).replace("{min}", String(min % 60).padStart(2, "0"));
}

/** « Rejoindre john · 355 m · 4 min à pied » (morceaux vides omis ; « à pied » seulement en mode marche). */
export function joinLine613(
  t: T,
  o: { name: string | null | undefined; meters?: number | null; seconds?: number | null; walk?: boolean },
): string {
  const d = keepNumberWithUnit613(formatJoinDistance613(o.meters));
  const raw = formatJoinDuration613(t, o.seconds);
  const dur = keepNumberWithUnit613(raw === "" ? "" : o.walk === false ? raw : t("pm613_walk_time").replace("@t", raw));
  return [joinLabel613(t, o.name), d, dur].filter((x) => x !== "").join(" · ");
}

/** Recalcul de l'itinéraire quand la personne rejointe bouge (`PawRouteFollow611`) : ≥ 50 m, ou ≥ 10 m après 30 s. */
export function shouldRecomputeJoin613(movedMeters: number, sinceMs: number): boolean {
  if (movedMeters >= 50) return true;
  return sinceMs >= 30_000 && movedMeters >= 10;
}

/** Distance (m) entre deux points. */
export function meters613(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const r = 6371000, rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.asin(Math.min(1, Math.sqrt(x)));
}

/** Traits de liaison pleins (≥ 4 m, `kPawRouteLeadMinM613`) : de Moi au départ, de l'arrivée à la personne. */
export const JOIN_LEAD_MIN_M_613 = 4;
