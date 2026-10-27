// 27/10/2026 (LEO, ordre de Daniel « l'expérience app mobile et web doit être la meilleure ») — regroupement
// STABLE et toucher d'un groupe, partagés par /map (PoiMap) et /pawmap (PublicPawMap). Module pur (aucun DOM,
// aucun Leaflet) : testé par scripts/test-pawmap2710.mjs. Règle = règle 626 de PAM (même comportement que l'app).
//
// Bugs filmés par Daniel (captures_daniel_2710) et MESURÉS sur le site avant correctif :
//   1. toucher un groupe de ≤ 21 membres l'« éclatait » en anneaux de 72 / 132 px autour de LUI : dézoomé, ses
//      membres se posaient jusqu'à 54 km de leur vraie place, dont un dans l'Atlantique, et le groupe restait ;
//   2. les groupes changeaient pendant un chargement (couche « proches » d'une autre ville encore affichée
//      puis remplacée, liste publique remplacée d'un coup) : 2 changements de groupes en ~1,5 s par arrivée.

import { GROUP_MIN_PX_2610 } from "./pawmap2610";

export type Px2710 = { x: number; y: number };

export function mercatorPx2710(lat: number, lng: number, zoom: number): Px2710 {
  const scale = 256 * Math.pow(2, zoom);
  const s = Math.min(0.9999, Math.max(-0.9999, Math.sin((lat * Math.PI) / 180)));
  return { x: ((lng + 180) / 360) * scale, y: (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * scale };
}

export type Group2710<T> = { items: T[]; anchor: T; key: string };

// ── Règle 626 de PAM (PAM_rapport.md, code de référence frontend/lib/views/map/widgets/pawmap_cluster626.dart),
// portée À L'IDENTIQUE pour que l'app et le site se comportent pareil :
//   1. niveau de regroupement = partie entière du zoom (0 à 20) : entre deux niveaux entiers, rien ne bouge ;
//   2. hiérarchie : au niveau 21 chacun est seul ; pour Z = 20 → 0, on regroupe les groupes de Z+1 (plus gros
//      d'abord, puis plus petit identifiant ; chaque groupe libre absorbe les groupes libres à < 56 px au zoom Z,
//      puis toute paire d'ancres à < 56 px fusionne, la plus proche d'abord) ;
//   3. ancre = membre le plus proche de la moyenne (médoïde), identifiant du rond = plus petit id ;
//   4. entrée triée par identifiant ; mêmes règles pour lieux et PawSpots (18 px dès le zoom 13 pour les spots).
export const CLUSTER_MAX_ZOOM_2710 = 20;
export function clusterLevel2710(zoom: number): number {
  if (!Number.isFinite(zoom)) return 0;
  return Math.max(0, Math.min(CLUSTER_MAX_ZOOM_2710 + 1, Math.floor(zoom)));
}
type C2710<T> = { items: T[]; pts: Px2710[]; ids: string[]; anchor: Px2710; minId: string };
function medoid2710(pts: Px2710[]): number {
  if (pts.length < 2) return 0;
  let mx = 0, my = 0;
  for (const p of pts) { mx += p.x; my += p.y; }
  mx /= pts.length; my /= pts.length;
  let best = 0, bd = Infinity;
  for (let i = 0; i < pts.length; i++) { const dx = pts[i].x - mx, dy = pts[i].y - my; const d = dx * dx + dy * dy; if (d < bd) { bd = d; best = i; } }
  return best;
}
const cmpStr = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);
const order2710 = <T>(a: C2710<T>, b: C2710<T>) => (b.items.length - a.items.length) || cmpStr(a.minId, b.minId);
const copy2710 = <T>(c: C2710<T>): C2710<T> => ({ items: [...c.items], pts: [...c.pts], ids: [...c.ids], anchor: c.anchor, minId: c.minId });
function absorb2710<T>(c: C2710<T>, o: C2710<T>) {
  c.items.push(...o.items); c.pts.push(...o.pts); c.ids.push(...o.ids);
  c.anchor = c.pts[medoid2710(c.pts)];
  if (cmpStr(o.minId, c.minId) < 0) c.minId = o.minId;
}
function mergeClose2710<T>(cs: C2710<T>[], r: number): C2710<T>[] {
  const r2 = r * r;
  let cur = cs.sort(order2710);
  for (let guard = 0; guard < 10000; guard++) {
    const grid = new Map<string, number[]>();
    for (let i = 0; i < cur.length; i++) { const a = cur[i].anchor; const k = `${Math.floor(a.x / r)}:${Math.floor(a.y / r)}`; (grid.get(k) || grid.set(k, []).get(k)!).push(i); }
    let bi = -1, bj = -1, bd = Infinity;
    for (let i = 0; i < cur.length; i++) {
      const a = cur[i].anchor; const cx = Math.floor(a.x / r), cy = Math.floor(a.y / r);
      for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) {
        for (const j of grid.get(`${cx + dx}:${cy + dy}`) || []) {
          if (j <= i) continue;
          const d = (cur[j].anchor.x - a.x) ** 2 + (cur[j].anchor.y - a.y) ** 2;
          if (d < r2 && d < bd) { bd = d; bi = i; bj = j; }
        }
      }
    }
    if (bi < 0) break;
    absorb2710(cur[bi], cur[bj]);
    cur.splice(bj, 1);
    cur = cur.sort(order2710);
  }
  return cur;
}
function clusterLevelOnce2710<T>(prev: C2710<T>[], r: number): C2710<T>[] {
  const src = [...prev].sort(order2710);
  const key = (p: Px2710) => `${Math.floor(p.x / r)}:${Math.floor(p.y / r)}`;
  const grid = new Map<string, number[]>();
  for (let i = 0; i < src.length; i++) { const k = key(src[i].anchor); (grid.get(k) || grid.set(k, []).get(k)!).push(i); }
  const taken = new Array<boolean>(src.length).fill(false);
  const out: C2710<T>[] = [];
  const r2 = r * r;
  for (let i = 0; i < src.length; i++) {
    if (taken[i]) continue;
    taken[i] = true;
    const seed = src[i];
    const c = copy2710(seed);
    const cx = Math.floor(seed.anchor.x / r), cy = Math.floor(seed.anchor.y / r);
    const near: number[] = [];
    for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) {
      for (const j of grid.get(`${cx + dx}:${cy + dy}`) || []) {
        if (!taken[j] && (src[j].anchor.x - seed.anchor.x) ** 2 + (src[j].anchor.y - seed.anchor.y) ** 2 < r2) near.push(j);
      }
    }
    near.sort((a, b) => a - b);
    for (const j of near) { taken[j] = true; absorb2710(c, src[j]); }
    out.push(c);
  }
  return mergeClose2710(out, r);
}

export type ClusterIndex2710<T> = {
  /** Groupes au zoom `zoom` (niveau = partie entière). */
  at: (zoom: number) => Group2710<T>[];
  /** Plus petit niveau (au-dessus du zoom courant) où ces membres ne forment plus UN groupe ; null = encore
   *  ensemble au niveau 20 (même endroit) → on ouvre la liste au lieu de zoomer. */
  expansionLevel: (ids: string[], fromZoom: number) => number | null;
};
export function clusterIndex2710<T>(items: T[], idOf: (t: T) => string, posOf: (t: T) => [number, number] | null, radiusAt: (level: number) => number = () => GROUP_MIN_PX_2610): ClusterIndex2710<T> {
  const sorted = items.filter((t) => !!posOf(t)).sort((a, b) => cmpStr(idOf(a), idOf(b)));
  let cur: C2710<T>[] = sorted.map((it) => { const [la, ln] = posOf(it)!; const p = mercatorPx2710(la, ln, 0); return { items: [it], pts: [p], ids: [idOf(it)], anchor: p, minId: idOf(it) }; });
  const levels: C2710<T>[][] = new Array(CLUSTER_MAX_ZOOM_2710 + 2);
  levels[CLUSTER_MAX_ZOOM_2710 + 1] = cur;
  for (let z = CLUSTER_MAX_ZOOM_2710; z >= 0; z--) {
    cur = clusterLevelOnce2710(cur, radiusAt(z) / Math.pow(2, z));
    levels[z] = cur;
  }
  const cache = new Map<number, Group2710<T>[]>();
  return {
    at: (zoom) => {
      const lv = clusterLevel2710(zoom);
      const hit = cache.get(lv);
      if (hit) return hit;
      const out = levels[lv].map((c) => ({ items: c.items, anchor: c.items[medoid2710(c.pts)], key: c.minId }));
      cache.set(lv, out);
      return out;
    },
    expansionLevel: (ids, fromZoom) => {
      const want = new Set(ids);
      if (want.size < 2) return null;
      for (let z = clusterLevel2710(fromZoom) + 1; z <= CLUSTER_MAX_ZOOM_2710; z++) {
        const holders = new Set<number>();
        const lv = levels[z];
        for (let i = 0; i < lv.length && holders.size < 2; i++) for (const id of lv[i].ids) if (want.has(id)) { holders.add(i); break; }
        if (holders.size >= 2) return z;
      }
      return null;
    },
  };
}

/** Compatibilité : regroupement d'une liste au zoom donné (index construit à la volée). */
export function stableGroups2710<T>(items: T[], zoom: number, posOf: (t: T) => [number, number] | null, idOf: (t: T) => string, radiusAt?: (level: number) => number): Group2710<T>[] {
  return clusterIndex2710(items, idOf, posOf, radiusAt).at(zoom);
}

/**
 * Toucher un groupe (règle 626, point 5) : vol vers le centre de l'emprise de ses membres, au zoom qui les
 * montre tous dans la zone utile `w × h` px, au moins `niveau où il se divise + 0,05`, au plus `maxZoom`.
 * null = le groupe ne se divise pas avant le zoom maximal (même endroit) ou on y est : on ouvre la LISTE.
 * Plus aucun anneau.
 */
export function clusterTapTarget2710(o: { pts: [number, number][]; w: number; h: number; currentZoom: number; expansionLevel: number | null; maxZoom: number }): { zoom: number; center: [number, number] } | null {
  if (o.pts.length < 2 || o.expansionLevel == null) return null;
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const [la, ln] of o.pts) { const p = mercatorPx2710(la, ln, 0); minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x); minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y); }
  const dx = Math.max(maxX - minX, 1e-9), dy = Math.max(maxY - minY, 1e-9);
  let z = Math.log2(Math.min(o.w / dx, o.h / dy));
  if (z < o.expansionLevel) z = o.expansionLevel + 0.05;
  if (z > o.maxZoom) {
    if (o.expansionLevel > o.maxZoom) return null;
    z = o.maxZoom;
  }
  if (z <= o.currentZoom + 0.05) z = Math.min(o.maxZoom, o.currentZoom + 1);
  const cxp = (minX + maxX) / 2, cyp = (minY + maxY) / 2;
  const lng = (cxp / 256) * 360 - 180;
  const n = Math.PI - (2 * Math.PI * cyp) / 256;
  const lat = (180 / Math.PI) * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)));
  return { zoom: z, center: [lat, lng] };
}

/**
 * Données gardées entre deux chargements (« on garde l'affichage précédent tant que le nouveau n'est pas
 * prêt ») : chaque nouvelle liste COMPLÈTE le cache (même identifiant = fiche remplacée par la plus
 * récente), rien n'est retiré pendant la session. Sortie triée par identifiant.
 */
export function mergeCache2710<T>(cache: Map<string, T>, fresh: T[], idOf: (t: T) => string): T[] {
  for (const it of fresh) cache.set(idOf(it), it);
  return [...cache.entries()].sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0)).map(([, v]) => v);
}

/** Rayon (km) à demander au serveur pour couvrir la carte visible : demi-diagonale, 30 km à 500 km. */
export function viewRadiusKm2710(s: number, w: number, n: number, e: number): number {
  const R = 6371;
  const lat1 = (s * Math.PI) / 180, lat2 = (n * Math.PI) / 180;
  const dLat = lat2 - lat1, dLng = ((e - w) * Math.PI) / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  const diag = 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
  // Paliers fixes : un même cadrage demande toujours le même rayon (réponse identique du serveur).
  const half = diag / 2;
  for (const step of [30, 60, 120, 250, 500]) if (half <= step) return step;
  return 500;
}
