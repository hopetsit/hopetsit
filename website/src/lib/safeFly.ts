// 25/09/2026 (PawMap 584) — vol de caméra SÛR pour Leaflet.
// Reproduit sur /pawmap : dézoomer vite puis chercher « paris » lançait un
// flyTo pendant l'animation de zoom → « Invalid LatLng object: (NaN, NaN) »,
// page plantée. On arrête d'abord toute animation en cours, on vérifie la
// taille de la carte, et en dernier recours on pose la vue sans animation.
import type { Map as LeafletMap, LatLngExpression } from "leaflet";

export function safeFly(map: LeafletMap, center: [number, number], zoom: number, duration = 0.9): void {
  if (!Number.isFinite(center[0]) || !Number.isFinite(center[1]) || !Number.isFinite(zoom)) return;
  const target: LatLngExpression = center;
  try {
    map.stop();
    map.invalidateSize({ animate: false });
    const size = map.getSize();
    if (!size.x || !size.y) {
      map.setView(target, zoom, { animate: false });
      return;
    }
    map.flyTo(target, zoom, { duration });
  } catch {
    try { map.setView(target, zoom, { animate: false }); } catch { /* carte démontée */ }
  }
}
