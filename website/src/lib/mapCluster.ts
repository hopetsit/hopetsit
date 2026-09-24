// v551 — regroupement maison des points qui se chevauchent (aucune dépendance) :
// projection Web Mercator au zoom courant, cellules de 76 px = ce que l'œil
// perçoit comme « collé ». 24/09/2026 (LOT B) : sorti de PoiMap.tsx pour être
// partagé avec la carte sans compte (PublicPawMap) sans charger Leaflet.

const CLUSTER_CELL_PX = 76;
function mercX(lng: number) {
  return ((lng + 180) / 360) * 256;
}
function mercY(lat: number) {
  const s = Math.min(0.9999, Math.max(-0.9999, Math.sin((lat * Math.PI) / 180)));
  return (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * 256;
}
export function clusterize<T>(
  items: T[],
  zoom: number,
  posOf: (t: T) => [number, number] | null,
): { items: T[]; center: [number, number] }[] {
  const scale = Math.pow(2, zoom);
  const cells = new Map<string, T[]>();
  for (const it of items) {
    const p = posOf(it);
    if (!p) continue;
    const x = Math.floor((mercX(p[1]) * scale) / CLUSTER_CELL_PX);
    const y = Math.floor((mercY(p[0]) * scale) / CLUSTER_CELL_PX);
    const key = `${x}_${y}`;
    const arr = cells.get(key);
    if (arr) arr.push(it);
    else cells.set(key, [it]);
  }
  return [...cells.values()].map((group) => {
    let la = 0;
    let ln = 0;
    let n = 0;
    for (const g of group) {
      const p = posOf(g);
      if (!p) continue;
      la += p[0];
      ln += p[1];
      n += 1;
    }
    return { items: group, center: [la / n, ln / n] as [number, number] };
  });
}

/** Distance à vol d'oiseau (km), même formule que le backend. */
export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}
