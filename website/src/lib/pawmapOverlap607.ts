// 607 (LEO, 01/10/2026) — PawMap du site : plus rien ne se chevauche.
// Copie fidèle de `frontend/lib/views/map/widgets/pawmap_overlap607.dart`
// (PAM, captures iPhone de Daniel) — mêmes seuils, mêmes règles :
//   1. mergeCloseGroups : tout groupe de membres à moins de 50 px d'un autre
//      fusionne (avant : cases fixes → pastilles « 29 », « 3 », « 2 » collées) ;
//   2. repelShift : une pastille de groupe s'écarte (au plus 28 px, dessin
//      seulement) des ronds qui ne se regroupent jamais (Moi, amis) ;
//   3. pickLabelSide : « Vu il y a … » d'un ami dessous si la place est
//      libre, sinon dessus, sinon nulle part — jamais sur un rond ;
//   4. bubbleHasRoom : bulle de prix d'une épingle SEULE dès le zoom ville.
// Fonctions pures, en pixels d'écran Web Mercator (256 px au zoom 0, comme
// Leaflet et Google Maps).

/** Seuils de l'app (paw_map_screen.dart) — réversibles ici. */
export const PRICE_ZOOM_607 = 13; // `_priceZoom` : prénom + prix (zoom rue)
export const CITY_PRICE_ZOOM_607 = 9; // `_cityPriceZoom` : bulle d'une épingle seule
export const MEMBER_CELL_PX_607 = 44; // `_memberClusterCellPx`
/** Rond 46 px + anneau ami 2,5 + 4 px d'air (`kPawGroupMinPx`). */
export const GROUP_MIN_PX_607 = 50;

export type Px = { x: number; y: number };
export type Rect = { l: number; t: number; r: number; b: number };

export function mercatorPx(lat: number, lng: number, zoom: number): Px {
  const scale = 256 * Math.pow(2, zoom);
  const s = Math.min(0.9999, Math.max(-0.9999, Math.sin((lat * Math.PI) / 180)));
  return {
    x: ((lng + 180) / 360) * scale,
    y: (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * scale,
  };
}

/** Fusionne les groupes dont les centres (moyenne des px de leurs points)
 *  sont à moins de `minPx`, jusqu'à ce qu'aucune paire ne se touche. */
export function mergeCloseGroups<T>(groups: T[][], px: (t: T) => Px, minPx = GROUP_MIN_PX_607): T[][] {
  type G = { members: T[]; pts: Px[]; c: Px };
  const mean = (p: Px[]): Px => {
    let x = 0;
    let y = 0;
    for (const o of p) { x += o.x; y += o.y; }
    return { x: x / p.length, y: y / p.length };
  };
  let items: G[] = groups.filter((g) => g.length > 0).map((g) => {
    const pts = g.map(px);
    return { members: [...g], pts, c: mean(pts) };
  });
  if (items.length < 2) return items.map((g) => g.members);
  const min2 = minPx * minPx;
  let merged = true;
  let guard = 0;
  while (merged && guard++ < 64) {
    merged = false;
    const cells = new Map<string, number[]>();
    const keyOf = (cx: number, cy: number) => `${cx}_${cy}`;
    items.forEach((g, i) => {
      const k = keyOf(Math.floor(g.c.x / minPx), Math.floor(g.c.y / minPx));
      const arr = cells.get(k);
      if (arr) arr.push(i); else cells.set(k, [i]);
    });
    const dead = new Set<number>();
    for (let i = 0; i < items.length; i++) {
      if (dead.has(i)) continue;
      const a = items[i];
      const cx = Math.floor(a.c.x / minPx);
      const cy = Math.floor(a.c.y / minPx);
      for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
          const list = cells.get(keyOf(cx + dx, cy + dy));
          if (!list) continue;
          for (const j of list) {
            if (j <= i || dead.has(j)) continue;
            const b = items[j];
            const ddx = a.c.x - b.c.x;
            const ddy = a.c.y - b.c.y;
            if (ddx * ddx + ddy * ddy < min2) {
              a.members.push(...b.members);
              a.pts.push(...b.pts);
              a.c = mean(a.pts);
              dead.add(j);
              merged = true;
            }
          }
        }
      }
    }
    if (dead.size) items = items.filter((_, i) => !dead.has(i));
  }
  return items.map((g) => g.members);
}

/** Décalage du DESSIN d'une pastille posée en `at` pour ne recouvrir aucun
 *  rond fixe (Moi, amis) ; borné à `maxShift`. {0,0} si rien ne la touche. */
export function repelShift(at: Px, obstacles: Px[], minPx = GROUP_MIN_PX_607, maxShift = 28): Px {
  let sx = 0;
  let sy = 0;
  for (const o of obstacles) {
    let dx = at.x - o.x;
    let dy = at.y - o.y;
    let dist = Math.hypot(dx, dy);
    if (dist >= minPx) continue;
    if (dist < 0.5) {
      dx = 0.7071;
      dy = 0.7071;
      dist = 1;
    }
    const push = minPx - dist;
    sx += (dx / dist) * push;
    sy += (dy / dist) * push;
  }
  const len = Math.hypot(sx, sy);
  if (len === 0) return { x: 0, y: 0 };
  if (len <= maxShift) return { x: sx, y: sy };
  return { x: (sx / len) * maxShift, y: (sy / len) * maxShift };
}

export type LabelSide = "below" | "above" | "none";

/** Étiquette de largeur `width` sous / au-dessus d'un rond de rayon `r`
 *  (3 px d'écart, hauteur 19,3 px — mêmes cotes que l'app). */
export function labelRect(c: Px, r: number, width: number, side: LabelSide, height = 19.3): Rect {
  const t = side === "above" ? c.y - r - 3 - height : c.y + r + 3;
  return { l: c.x - width / 2, t, r: c.x + width / 2, b: t + height };
}
export function circleRect(c: Px, r: number): Rect {
  return { l: c.x - r, t: c.y - r, r: c.x + r, b: c.y + r };
}
function inflate(a: Rect, d: number): Rect {
  return { l: a.l - d, t: a.t - d, r: a.r + d, b: a.b + d };
}
/** Même test que `Rect.overlaps` de Flutter (bords qui se touchent = non). */
export function overlaps(a: Rect, b: Rect): boolean {
  return a.r > b.l && b.r > a.l && a.b > b.t && b.b > a.t;
}

export function pickLabelSide(o: { center: Px; radius: number; width: number; obstacles: Rect[]; allowAbove?: boolean }): LabelSide {
  const free = (s: LabelSide) => {
    const r = inflate(labelRect(o.center, o.radius, o.width, s), 1);
    return !o.obstacles.some((x) => overlaps(r, x));
  };
  if (free("below")) return "below";
  if ((o.allowAbove ?? true) && free("above")) return "above";
  return "none";
}

/** La bulle de prix (≈ bubbleW × 30 px) au-dessus d'un rond seul ne touche rien. */
export function bubbleHasRoom(c: Px, r: number, bubbleW: number, others: Rect[]): boolean {
  const bubble: Rect = { l: c.x - bubbleW / 2, t: c.y - r - 32, r: c.x + bubbleW / 2, b: c.y - r - 2 };
  return !others.some((o) => overlaps(bubble, o));
}

// Largeur de texte réelle (canvas), repli à ~0,6 em par caractère.
let ctx2d: CanvasRenderingContext2D | null | undefined;
export function textWidth(text: string, font: string, sizePx: number): number {
  if (ctx2d === undefined) {
    try { ctx2d = typeof document !== "undefined" ? document.createElement("canvas").getContext("2d") : null; } catch { ctx2d = null; }
  }
  if (ctx2d) {
    ctx2d.font = font;
    return ctx2d.measureText(text).width;
  }
  return text.length * sizePx * 0.6;
}
