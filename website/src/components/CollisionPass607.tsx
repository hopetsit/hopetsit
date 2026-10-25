"use client";

// 02/10/2026 (607, PAM → LEO) — passe de mise en page unique sur une carte
// Leaflet (CONTRAT_607_bulles.md §2). Chaque icône porte sa couche dans sa
// classe (`hps-l-<couche>`) ; après chaque rendu / déplacement, on mesure le
// rectangle VISIBLE de chaque marqueur (bulle et étiquette comprises).
//
// 25/10/2026 (LEO, 622 — ordre de Daniel : « les bulles coupées ») : la passe
// ne se contente plus de masquer les lieux qui chevauchent ; elle applique
// `resolveEdges622` (lib/pawmapEdge622.ts) :
//   - rien de coupé au bord de la carte (épingle ramenée dedans, ou masquée si
//     sa pointe est hors de la carte) ;
//   - rien sous les rails / la rangée du haut / les languettes ([data-map-overlay])
//     ni sous les contrôles Leaflet (attribution) ;
//   - aucune bulle sur une autre : glissement vers la place libre la plus proche
//     (CSS `translate`, qui s'ajoute au `transform` de Leaflet sans le toucher),
//     les couches secondaires s'effacent seulement faute de place.
// Rien n'est retiré du DOM : un marqueur masqué revient dès qu'il a de nouveau la place.

import { useEffect } from "react";
import { useMap } from "react-leaflet";
import type { Layer607, Rect607 } from "@/lib/pawmapLayout607";
import { resolveEdges622, type EdgeItem622 } from "@/lib/pawmapEdge622";

const LAYERS: Layer607[] = ["me", "friend", "plush", "member", "mgroup", "request", "report", "spot", "sgroup", "place", "pgroup"];

function layerOf(el: Element): Layer607 | null {
  for (const l of LAYERS) if (el.classList.contains(`hps-l-${l}`)) return l;
  if (el.classList.contains("hps-l-request-public")) return "request";
  return null;
}
function visibleRect(el: HTMLElement): Rect607 | null {
  let l = Infinity, t = Infinity, r = -Infinity, b = -Infinity;
  const parts = el.querySelectorAll<HTMLElement>("*");
  const list: Element[] = parts.length ? Array.from(parts) : [el];
  for (const p of list) {
    const q = p.getBoundingClientRect();
    if (q.width < 2 || q.height < 2) continue;
    l = Math.min(l, q.left); t = Math.min(t, q.top); r = Math.max(r, q.right); b = Math.max(b, q.bottom);
  }
  return Number.isFinite(l) ? { l, t, r, b } : null;
}

/** Rails, rangée du haut, languettes, attribution : tout ce qui est posé SUR la carte. */
function overlayRects(container: HTMLElement, view: Rect607): Rect607[] {
  const out: Rect607[] = [];
  const els = [
    ...Array.from(document.querySelectorAll<HTMLElement>("[data-map-overlay]")),
    ...Array.from(container.querySelectorAll<HTMLElement>(".leaflet-control")),
  ];
  for (const el of els) {
    const q = el.getBoundingClientRect();
    if (q.width < 4 || q.height < 4) continue;
    const cs = getComputedStyle(el);
    if (cs.visibility === "hidden" || cs.display === "none" || Number(cs.opacity) < 0.05) continue;
    if (q.right <= view.l || q.left >= view.r || q.bottom <= view.t || q.top >= view.b) continue;
    out.push({ l: q.left, t: q.top, r: q.right, b: q.bottom });
  }
  return out;
}

export function runCollisionPass607(pane: HTMLElement, container: HTMLElement): { hidden: number; moved: number; total: number; compact: number } {
  const icons = Array.from(pane.querySelectorAll<HTMLElement>(".leaflet-marker-icon"));
  // Mesure sans le glissement ni le repli d'un passage précédent (visibility ne change pas la géométrie).
  for (const el of icons) {
    if (el.dataset.hps622Shift) { el.style.translate = ""; delete el.dataset.hps622Shift; }
    if (el.dataset.hps622Compact) { el.querySelectorAll<HTMLElement>("[data-pin-extra]").forEach((x) => { x.style.display = ""; }); delete el.dataset.hps622Compact; }
  }
  const c = container.getBoundingClientRect();
  const view: Rect607 = { l: c.left, t: c.top, r: c.right, b: c.bottom };
  const items: (EdgeItem622 & { el: HTMLElement })[] = [];
  for (const el of icons) {
    const layer = layerOf(el);
    if (!layer) continue;
    const rect = visibleRect(el);
    if (!rect) continue;
    const box = el.getBoundingClientRect();
    const ml = parseFloat(el.style.marginLeft || "0") || 0;
    const mt = parseFloat(el.style.marginTop || "0") || 0;
    items.push({ id: `${layer}:${Math.round(rect.l)}:${Math.round(rect.t)}:${items.length}`, layer, rect, anchor: { x: box.left - ml, y: box.top - mt }, el });
  }
  const overlays = overlayRects(container, view);
  let { shifts, hidden, unplaced } = resolveEdges622(items, view, overlays);
  // 2e passage : une épingle principale sans place libre replie sa bulle de prix / son prénom
  // (le rond reste), puis, toujours sans place, s'efface (moi et mes amis jamais).
  if (unplaced.size) {
    for (const it of items) {
      if (!unplaced.has(it.id)) continue;
      const extras = it.el.querySelectorAll<HTMLElement>("[data-pin-extra]");
      if (!extras.length) continue;
      extras.forEach((x) => { x.style.display = "none"; });
      it.el.dataset.hps622Compact = "1";
      const r = visibleRect(it.el);
      if (r) it.rect = r;
    }
    ({ shifts, hidden, unplaced } = resolveEdges622(items, view, overlays, { hideUnplaced: true }));
  }
  for (const it of items) {
    if (hidden.has(it.id)) { it.el.style.visibility = "hidden"; it.el.style.pointerEvents = "none"; it.el.dataset.hps607Hidden = "1"; continue; }
    if (it.el.dataset.hps607Hidden) { it.el.style.visibility = ""; it.el.style.pointerEvents = ""; delete it.el.dataset.hps607Hidden; }
    const s = shifts.get(it.id);
    if (s) { it.el.style.translate = `${s.dx}px ${s.dy}px`; it.el.dataset.hps622Shift = "1"; }
  }
  return { hidden: hidden.size, moved: shifts.size, total: items.length, compact: unplaced.size };
}

export function CollisionPass607() {
  const map = useMap();
  useEffect(() => {
    const pane = map.getPane("markerPane");
    const container = map.getContainer();
    if (!pane || !container) return;
    let raf = 0;
    let late = 0;
    const run = () => { try { runCollisionPass607(pane, container); } catch { /* jamais bloquant */ } };
    const schedule = () => {
      if (raf) cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => { raf = 0; run(); });
      // Les rails et la rangée du haut s'animent (repli, mise à l'échelle) : 2e passage après la transition.
      window.clearTimeout(late);
      late = window.setTimeout(run, 380);
    };
    const mo = new MutationObserver(schedule);
    mo.observe(pane, { childList: true, subtree: true });
    // Rails repliés / dépliés : leurs attributs changent (classe, style, aria).
    const wrap = container.closest("[data-map-shell]") || container.parentElement?.parentElement || null;
    // Jamais les mutations DE LA CARTE elle-même (nos propres glissements, le transform de Leaflet) :
    // sinon la passe se relancerait elle-même en boucle.
    const mo2 = new MutationObserver((recs) => { if (recs.some((r) => !container.contains(r.target))) schedule(); });
    if (wrap) mo2.observe(wrap, { attributes: true, subtree: true, attributeFilter: ["class", "style", "aria-expanded", "data-collapsed"] });
    map.on("zoomend moveend resize", schedule);
    window.addEventListener("resize", schedule);
    schedule();
    return () => {
      mo.disconnect(); mo2.disconnect();
      map.off("zoomend moveend resize", schedule);
      window.removeEventListener("resize", schedule);
      if (raf) cancelAnimationFrame(raf);
      window.clearTimeout(late);
    };
  }, [map]);
  return null;
}

export default CollisionPass607;
