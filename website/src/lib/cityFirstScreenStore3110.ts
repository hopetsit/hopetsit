// 31/10/2026 (LEO, décision BOB point 2) — même source des deux côtés : le premier écran d'une page ville
// (CityFirstScreen3110) publie son mode (« form » / « recruit »), et le bloc de preuve « N gardiens déjà
// inscrits à moins de 100 km » (CitySupplyProof, rayon 100 km sans photo) s'efface quand le premier écran
// dit « Devenir gardien » (0 gardien avec photo dans la ville) : plus de contradiction sur le même écran.
// Petit magasin partagé, sans dépendance, lisible par useSyncExternalStore.

type Mode = "loading" | "form" | "recruit";
let mode: Mode = "loading";
const listeners = new Set<() => void>();

export function setCityFirstScreenMode(m: Mode): void {
  if (mode === m) return;
  mode = m;
  listeners.forEach((l) => l());
}
export function subscribeCityFirstScreen(l: () => void): () => void {
  listeners.add(l);
  return () => { listeners.delete(l); };
}
export function getCityFirstScreenMode(): Mode { return mode; }
export function getCityFirstScreenModeServer(): Mode { return "loading"; }
