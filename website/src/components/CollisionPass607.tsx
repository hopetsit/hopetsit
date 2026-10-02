"use client";

// 02/10/2026 (607, PAM → LEO) — passe de mise en page unique sur une carte
// Leaflet (CONTRAT_607_bulles.md §2). Chaque icône porte sa couche dans sa
// classe (`hps-l-<couche>`) ; après chaque rendu / déplacement, on mesure le
// rectangle VISIBLE de chaque marqueur (bulle et étiquette comprises) et on
// masque les marqueurs SECONDAIRES qui en recouvrent un plus prioritaire de
// plus de 12 % (lieux, PawSpots, signalements et leurs groupes). Personnes,
// peluches et demandes ne sont jamais masquées. Rien n'est retiré du DOM :
// un marqueur masqué revient dès qu'il a de nouveau la place.

import { useEffect } from "react";
import { useMap } from "react-leaflet";
import { resolveCollisions607, type Layer607, type Rect607 } from "@/lib/pawmapLayout607";

const LAYERS: Layer607[] = ["me", "friend", "plush", "member", "mgroup", "request", "report", "spot", "sgroup", "place", "pgroup"];

function layerOf(el: Element): Layer607 | null {
  for (const l of LAYERS) if (el.classList.contains(`hps-l-${l}`)) return l;
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

export function runCollisionPass607(pane: HTMLElement): { hidden: number; total: number } {
  const icons = Array.from(pane.querySelectorAll<HTMLElement>(".leaflet-marker-icon"));
  const items: { id: string; layer: Layer607; rect: Rect607; el: HTMLElement }[] = [];
  for (const el of icons) {
    const layer = layerOf(el);
    if (!layer) continue;
    // Mesure sans tenir compte d'un masquage précédent (visibility ne change pas la géométrie).
    const rect = visibleRect(el);
    if (!rect) continue;
    items.push({ id: `${layer}:${Math.round(rect.l)}:${Math.round(rect.t)}:${items.length}`, layer, rect, el });
  }
  const hidden = resolveCollisions607(items);
  for (const it of items) {
    const hide = hidden.has(it.id);
    if (hide) { it.el.style.visibility = "hidden"; it.el.style.pointerEvents = "none"; it.el.dataset.hps607Hidden = "1"; }
    else if (it.el.dataset.hps607Hidden) { it.el.style.visibility = ""; it.el.style.pointerEvents = ""; delete it.el.dataset.hps607Hidden; }
  }
  return { hidden: hidden.size, total: items.length };
}

export function CollisionPass607() {
  const map = useMap();
  useEffect(() => {
    const pane = map.getPane("markerPane");
    if (!pane) return;
    let raf = 0;
    const schedule = () => {
      if (raf) cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => { raf = 0; try { runCollisionPass607(pane); } catch { /* jamais bloquant */ } });
    };
    const mo = new MutationObserver(schedule);
    mo.observe(pane, { childList: true, subtree: true });
    map.on("zoomend moveend", schedule);
    schedule();
    return () => { mo.disconnect(); map.off("zoomend moveend", schedule); if (raf) cancelAnimationFrame(raf); };
  }, [map]);
  return null;
}

export default CollisionPass607;
