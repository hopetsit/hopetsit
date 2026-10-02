// 02/10/2026 (607, PAM → LEO) — LA PASSE DE MISE EN PAGE UNIQUE de la PawMap
// (CONTRAT_607_bulles.md §2 ; app : frontend/lib/views/map/widgets/pawmap_layout607.dart).
// Après le rendu, pour TOUS les marqueurs : rectangle VISIBLE à l'écran (sur le
// site : mesuré dans le DOM, bulle et étiquette comprises), tri par priorité
// puis identifiant ; une couche SECONDAIRE (signalements, PawSpots, lieux et
// leurs groupes) qui recouvre de plus de 12 % un marqueur déjà posé n'est pas
// posée (on la retrouve en zoomant). Personnes et demandes jamais retirées.

export type Layer607 = "me" | "friend" | "plush" | "member" | "mgroup" | "request" | "report" | "spot" | "sgroup" | "place" | "pgroup" | "other";
export type Rect607 = { l: number; t: number; r: number; b: number };

export const LAYER_PRIORITY_607: Record<Layer607, number> = {
  me: 100, friend: 90, plush: 85, member: 80, mgroup: 75, request: 70, other: 60,
  report: 50, spot: 45, sgroup: 40, place: 35, pgroup: 30,
};
export const DROPPABLE_607 = new Set<Layer607>(["report", "spot", "sgroup", "place", "pgroup"]);
export const OVERLAP_TOLERANCE_607 = 0.12;

export function overlapRatio(a: Rect607, b: Rect607): number {
  const w = Math.min(a.r, b.r) - Math.max(a.l, b.l);
  const h = Math.min(a.b, b.b) - Math.max(a.t, b.t);
  if (w <= 0 || h <= 0) return 0;
  const aa = (a.r - a.l) * (a.b - a.t);
  const ab = (b.r - b.l) * (b.b - b.t);
  const small = Math.min(aa, ab);
  return small <= 0 ? 0 : (w * h) / small;
}

/** Identifiants à NE PAS poser. Déterministe : priorité, puis identifiant. */
export function resolveCollisions607(items: { id: string; layer: Layer607; rect: Rect607 }[], tolerance = OVERLAP_TOLERANCE_607): Set<string> {
  const list = [...items].sort((x, y) => (LAYER_PRIORITY_607[y.layer] - LAYER_PRIORITY_607[x.layer]) || (x.id < y.id ? -1 : x.id > y.id ? 1 : 0));
  const kept: Rect607[] = [];
  const hidden = new Set<string>();
  for (const it of list) {
    if (DROPPABLE_607.has(it.layer) && kept.some((k) => overlapRatio(it.rect, k) > tolerance)) {
      hidden.add(it.id);
      continue;
    }
    kept.push(it.rect);
  }
  return hidden;
}
