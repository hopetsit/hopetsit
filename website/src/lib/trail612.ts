// 05/10/2026 (612, LEO) — tracé PROPRE d'une balade suivie en direct.
// Même règle que l'app (frontend/lib/views/map/widgets/pawmap_follow612.dart,
// `pawCleanTrail612`), mêmes seuils :
//   1. retire les « pics » : B loin de A et de C alors que A et C sont proches
//      (aller-retour en étoile d'un GPS qui saute dans un magasin) ;
//   2. retire un point isolé à plus de `maxJumpM` de ses deux voisins ;
//   3. lisse (Chaikin, 2 passes) en gardant le 1er et le dernier point.
// Le serveur nettoie déjà le tracé qu'il renvoie (`trailOf`) ; les points
// reçus ensuite par la socket passent par ici. Fonctions pures, sans Leaflet.

export type TrailPoint = [number, number];

export function meters612(a: TrailPoint, b: TrailPoint): number {
  const r = 6371000;
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b[0] - a[0]);
  const dLng = rad(b[1] - a[1]);
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a[0])) * Math.cos(rad(b[0])) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.asin(Math.min(1, Math.sqrt(x)));
}

export function cleanTrail612(
  raw: readonly TrailPoint[],
  { spikeM = 20, maxJumpM = 60, smoothPasses = 2 }: { spikeM?: number; maxJumpM?: number; smoothPasses?: number } = {},
): TrailPoint[] {
  let pts: TrailPoint[] = raw
    .filter((p) => Array.isArray(p) && Number.isFinite(p[0]) && Number.isFinite(p[1]))
    .map((p) => [p[0], p[1]] as TrailPoint);
  if (pts.length < 3) return pts;
  // 1 + 2 — on recommence tant qu'un pic tombe (étoiles à plusieurs branches).
  let changed = true;
  let guard = 0;
  while (changed && pts.length >= 3 && guard++ < 8) {
    changed = false;
    const out: TrailPoint[] = [pts[0]];
    for (let i = 1; i < pts.length - 1; i++) {
      const a = out[out.length - 1];
      const b = pts[i];
      const c = pts[i + 1];
      const ab = meters612(a, b);
      const bc = meters612(b, c);
      const ac = meters612(a, c);
      const spike = ab > spikeM && bc > spikeM && ac < 0.5 * Math.min(ab, bc);
      const jump = ab > maxJumpM && bc > maxJumpM && ac < Math.max(ab, bc);
      if (spike || jump) {
        changed = true;
        continue;
      }
      out.push(b);
    }
    out.push(pts[pts.length - 1]);
    pts = out;
  }
  // 3 — Chaikin : chaque segment donne deux points, à 1/4 et à 3/4.
  for (let p = 0; p < smoothPasses && pts.length >= 3; p++) {
    const s: TrailPoint[] = [pts[0]];
    for (let i = 0; i < pts.length - 1; i++) {
      const a = pts[i];
      const b = pts[i + 1];
      s.push([0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]]);
      s.push([0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]]);
    }
    s.push(pts[pts.length - 1]);
    pts = s;
  }
  return pts;
}

/** Ajoute un point au tracé brut (sans doublon), plafonné à `max` points. */
export function appendTrail612(prev: readonly TrailPoint[], lat: number, lng: number, max = 600): TrailPoint[] {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return prev as TrailPoint[];
  const last = prev[prev.length - 1];
  if (last && Math.abs(last[0] - lat) < 1e-6 && Math.abs(last[1] - lng) < 1e-6) return prev as TrailPoint[];
  const next = [...prev, [lat, lng] as TrailPoint];
  return next.length > max ? next.slice(-max) : next;
}

// ── 612 §7 (Daniel, 05/10 23 h 19) — pendant le direct : une COURTE TRAÎNE ──
// Mêmes valeurs que l'app (pawmap_follow612.dart : kPawTrailMeters612,
// pawShortTrail612, pawFadedTrail612, _walkPolylines) : les 200 derniers
// mètres, épaisseur 3, violet #7C3AED, 5 morceaux d'opacité 0,12 → 1 du plus
// ancien au plus récent. Nettoyage + lissage AVANT la coupe ; le dernier point
// est la position de la photo. Le serveur garde le trajet entier.
export const TRAIL_METERS_612 = 200;
export const TRAIL_COLOR_612 = "#7C3AED";
export const TRAIL_WEIGHT_612 = 3;
export const TRAIL_PARTS_612 = 5;

/** La fin du tracé, sur `maxMeters` au plus ; le 1er point est coupé pile à la bonne longueur. */
export function shortTrail612(pts: readonly TrailPoint[], maxMeters = TRAIL_METERS_612): TrailPoint[] {
  if (pts.length < 2) return pts.map((p) => [p[0], p[1]] as TrailPoint);
  const out: TrailPoint[] = [pts[pts.length - 1]];
  let left = maxMeters;
  for (let i = pts.length - 1; i > 0 && left > 0; i--) {
    const a = pts[i];
    const b = pts[i - 1];
    const d = meters612(a, b);
    if (d <= left) {
      out.push(b);
      left -= d;
    } else {
      const t = left / d;
      out.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]);
      left = 0;
    }
  }
  return out.reverse();
}

export type TrailPart612 = { pts: TrailPoint[]; alpha: number };

/** Traîne qui s'estompe vers l'arrière : `parts` morceaux, chacun reprend le dernier point du précédent (aucun trou). */
export function fadedTrail612(pts: readonly TrailPoint[], parts = TRAIL_PARTS_612): TrailPart612[] {
  if (pts.length < 2) return [];
  const n = pts.length - 1; // segments
  const k = Math.min(parts, n);
  const out: TrailPart612[] = [];
  for (let p = 0; p < k; p++) {
    const from = Math.floor((n * p) / k);
    const to = Math.floor((n * (p + 1)) / k);
    if (to <= from) continue;
    const alpha = k === 1 ? 1 : 0.12 + 0.88 * (p / (k - 1));
    out.push({ pts: pts.slice(from, to + 1) as TrailPoint[], alpha });
  }
  return out;
}

/** Du tracé brut à la traîne dessinée : nettoyage → lissage Chaikin 2 passes → coupe à 200 m → fondu. */
export function liveTail612(raw: readonly TrailPoint[]): TrailPart612[] {
  return fadedTrail612(shortTrail612(cleanTrail612(raw)));
}
