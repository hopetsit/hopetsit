// 25/10/2026 (LEO, 622 — ordre de Daniel via BOB : « les bulles coupées »).
// Passe de mise en page FINALE de la PawMap du site, sur les rectangles RÉELS mesurés à l'écran
// (bulle, prénom, couronne et pastilles compris) :
//   1. rien de coupé au bord de la carte : une épingle dont la pointe est sur la carte est
//      ramenée entièrement dedans ; une épingle dont la pointe est hors de la carte est masquée
//      (avant : bulles et prénoms tranchés net au bord, « Hanene » coupé en haut) ;
//   2. rien sous les rails, la rangée du haut ni la languette (éléments [data-map-overlay]) ;
//   3. aucune bulle sur une autre ni sur une épingle : les couches principales (moi, amis,
//      membres, groupes, demandes) glissent vers la place libre la plus proche ; les couches
//      secondaires (lieux, PawSpots, signalements et leurs groupes) glissent d'au plus 40 px,
//      sinon elles s'effacent (on les retrouve en zoomant). Jamais un chevauchement toléré.
// Fonction PURE (aucun DOM) : testée par scripts/test-pawmapEdge622.mjs. Coordonnées = px écran.

import { LAYER_PRIORITY_607, DROPPABLE_607, type Layer607, type Rect607 } from "./pawmapLayout607";

export type EdgeItem622 = { id: string; layer: Layer607; rect: Rect607; anchor: { x: number; y: number }; /** 2610 — rond SÉLECTIONNÉ (sa bulle de prix) : posé en premier, jamais déplacé ni masqué. */ pinned?: boolean };
export type EdgeResult622 = { shifts: Map<string, { dx: number; dy: number }>; hidden: Set<string>; /** couches principales sans place libre (2e passage : bulle repliée, puis masquées). */ unplaced: Set<string> };
/** Jamais masqués, même sans place : moi et mes amis. */
const NEVER_HIDE_622 = new Set<Layer607>(["me", "friend"]);

/** Ordre de pose : celui de la passe 607, sauf les DEMANDES qui passent avant les membres et leurs
 *  groupes (une demande n'a pas de bulle à replier : sans place elle disparaissait, alors que c'est
 *  ce que les gardiens et les visiteurs viennent chercher ; les membres replient leur prix d'abord). */
export const PRIORITY_622: Record<Layer607, number> = { ...LAYER_PRIORITY_607, request: 82 };

/** Air minimal entre deux épingles et avec un bord (px). */
export const AIR_622 = 3;
/** Glissement maximal d'une couche principale / secondaire (px). */
export const MAX_SHIFT_MAIN_622 = 140;
export const MAX_SHIFT_SECONDARY_622 = 40;

function touch(a: Rect607, b: Rect607, air = AIR_622): boolean {
  return a.l < b.r + air && a.r > b.l - air && a.t < b.b + air && a.b > b.t - air;
}
function inside(r: Rect607, v: Rect607, m = AIR_622): boolean {
  return r.l >= v.l + m && r.r <= v.r - m && r.t >= v.t + m && r.b <= v.b - m;
}
const move = (r: Rect607, dx: number, dy: number): Rect607 => ({ l: r.l + dx, t: r.t + dy, r: r.r + dx, b: r.b + dy });

/**
 * `view` = rectangle de la carte, `overlays` = rails, boutons et languettes posés dessus.
 * Ordre : priorité de couche puis identifiant (déterministe, comme la passe 607).
 */
export function resolveEdges622(items: EdgeItem622[], view: Rect607, overlays: Rect607[], opts: { hideUnplaced?: boolean } = {}): EdgeResult622 {
  const shifts = new Map<string, { dx: number; dy: number }>();
  const hidden = new Set<string>();
  const unplaced = new Set<string>();
  const list = [...items].sort((x, y) => (Number(!!y.pinned) - Number(!!x.pinned)) || (PRIORITY_622[y.layer] - PRIORITY_622[x.layer]) || (x.id < y.id ? -1 : x.id > y.id ? 1 : 0));
  const kept: Rect607[] = [];
  for (const it of list) {
    if (it.pinned) {
      const pa = it.anchor;
      if (pa.x < view.l || pa.x > view.r || pa.y < view.t || pa.y > view.b) { hidden.add(it.id); continue; }
      kept.push(it.rect);
      continue;
    }
    const a = it.anchor;
    // Pointe hors de la carte : on ne dessine pas un morceau d'épingle tranché au bord.
    if (a.x < view.l || a.x > view.r || a.y < view.t || a.y > view.b) { hidden.add(it.id); continue; }
    const secondary = DROPPABLE_607.has(it.layer);
    const w = it.rect.r - it.rect.l;
    const h = it.rect.b - it.rect.t;
    // Plus grande que la carte (très petite fenêtre) : on la laisse telle quelle.
    if (w > view.r - view.l - 2 * AIR_622 || h > view.b - view.t - 2 * AIR_622) { kept.push(it.rect); continue; }
    const near = kept.filter((k) => k.r > it.rect.l - 220 && k.l < it.rect.r + 220 && k.b > it.rect.t - 220 && k.t < it.rect.b + 220);
    const freeOf = (r: Rect607, withKept: boolean) =>
      inside(r, view) && !overlays.some((o) => touch(r, o)) && (!withKept || !near.some((k) => touch(r, k)));
    if (freeOf(it.rect, true)) { kept.push(it.rect); continue; }
    const max = secondary ? MAX_SHIFT_SECONDARY_622 : MAX_SHIFT_MAIN_622;
    let found: { dx: number; dy: number } | null = null;
    // 1er essai : la poussée minimale qui ramène la boîte dans la carte (bords seulement).
    const ex = it.rect.l < view.l + AIR_622 ? view.l + AIR_622 - it.rect.l : it.rect.r > view.r - AIR_622 ? view.r - AIR_622 - it.rect.r : 0;
    const ey = it.rect.t < view.t + AIR_622 ? view.t + AIR_622 - it.rect.t : it.rect.b > view.b - AIR_622 ? view.b - AIR_622 - it.rect.b : 0;
    if ((ex || ey) && Math.hypot(ex, ey) <= max && freeOf(move(it.rect, ex, ey), true)) found = { dx: ex, dy: ey };
    // Sinon : anneaux de 4 px, tous les 15°, à partir de la poussée vers l'intérieur.
    if (!found) {
      const a0 = ex || ey ? Math.atan2(ey, ex) : Math.atan2((view.t + view.b) / 2 - a.y, (view.l + view.r) / 2 - a.x);
      outer: for (let d = 4; d <= max; d += 4) {
        for (let k = 0; k <= 12; k++) {
          for (const s of k === 0 ? [1] : [1, -1]) {
            const ang = a0 + (s * k * 15 * Math.PI) / 180;
            const dx = Math.round(Math.cos(ang) * d);
            const dy = Math.round(Math.sin(ang) * d);
            if (freeOf(move(it.rect, dx, dy), true)) { found = { dx, dy }; break outer; }
          }
        }
      }
    }
    if (!found && secondary) { hidden.add(it.id); continue; }
    if (!found) unplaced.add(it.id);
    // 2e passage (bulle déjà repliée) : toujours pas de place → masqué, on le retrouve en zoomant.
    if (!found && opts.hideUnplaced && !NEVER_HIDE_622.has(it.layer)) { hidden.add(it.id); continue; }
    if (!found) {
      // Couche principale sans place libre (très dense) : au moins hors des bords et des rails.
      if ((ex || ey) && freeOf(move(it.rect, ex, ey), false)) found = { dx: ex, dy: ey };
      else {
        for (let d = 4; d <= MAX_SHIFT_MAIN_622 && !found; d += 4) {
          for (let k = 0; k < 24 && !found; k++) {
            const ang = (k * 15 * Math.PI) / 180;
            const dx = Math.round(Math.cos(ang) * d);
            const dy = Math.round(Math.sin(ang) * d);
            if (freeOf(move(it.rect, dx, dy), false)) found = { dx, dy };
          }
        }
      }
    }
    if (found && (found.dx || found.dy)) shifts.set(it.id, found);
    kept.push(found ? move(it.rect, found.dx, found.dy) : it.rect);
  }
  return { shifts, hidden, unplaced };
}
