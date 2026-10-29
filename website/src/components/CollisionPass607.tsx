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
    // 30/10 (LEO, fluidité mesurée à CPU ×4) — l'intérieur d'un <svg> (cercles, arcs, chemins) ne déborde
    // jamais de sa boîte (overflow hidden) : on mesure le <svg>, pas ses enfants (≈ 40 % de rectangles en moins).
    if (p instanceof SVGElement && p.tagName.toLowerCase() !== "svg") continue;
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

/** 26/10 (2610) — bulle de prix du rond sélectionné : toujours DANS la carte. La pilule glisse
 *  horizontalement (marge 12 px, comme la maquette), la pointe reste sur le marqueur. Appelée par la
 *  passe ET à chaque image d'un déplacement de carte (glisser, inertie). */
function clampBubbles2610(icons: HTMLElement[], view: Rect607): void {
  for (const el of icons) {
    if (!el.querySelector("[data-selected-2610]")) continue;
    const pill = el.querySelector<HTMLElement>("[data-selected-2610] [data-bubble-2610]");
    if (!pill) continue;
    pill.style.translate = "";
    // Rond hors de la carte : la bulle part avec lui (jamais une bulle seule collée au bord).
    const tail = el.querySelector<HTMLElement>("[data-selected-2610] [data-tail-2610]")?.getBoundingClientRect();
    if (!tail || tail.right < view.l || tail.left > view.r || tail.bottom < view.t || tail.top > view.b) continue;
    const q = pill.getBoundingClientRect();
    const lo = view.l + 12;
    const hi = view.r - 12;
    let dx = 0;
    if (q.right - q.left > hi - lo) dx = (lo + hi) / 2 - (q.left + q.right) / 2;
    else if (q.left < lo) dx = lo - q.left;
    else if (q.right > hi) dx = hi - q.right;
    // Le rond sélectionné est agrandi (1,18) : le décalage se donne en px non agrandis (échelle mesurée).
    const k = pill.offsetWidth > 0 ? (q.right - q.left) / pill.offsetWidth : 1;
    if (dx) pill.style.translate = `${Math.round((dx / (k || 1)) * 10) / 10}px 0`;
  }
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
  clampBubbles2610(icons, view);
  const items: (EdgeItem622 & { el: HTMLElement })[] = [];
  let offMap = 0;
  for (const el of icons) {
    const layer = layerOf(el);
    if (!layer) continue;
    const box = el.getBoundingClientRect();
    const ml = parseFloat(el.style.marginLeft || "0") || 0;
    const mt = parseFloat(el.style.marginTop || "0") || 0;
    const anchor = { x: box.left - ml, y: box.top - mt };
    // 30/10 (LEO) — ancre hors de la carte : resolveEdges622 la masquerait de toute façon (« pointe hors de la
    // carte ») ; on le fait ici, sans mesurer son contenu. Sur 240 épingles chargées, ~220 sont hors de l'écran
    // au zoom rue : la passe passait de ~70 ms à ~15 ms sur un téléphone (CPU ×4).
    if (anchor.x < view.l || anchor.x > view.r || anchor.y < view.t || anchor.y > view.b) {
      offMap += 1;
      if (!el.dataset.hps607Hidden) { el.style.visibility = "hidden"; el.style.pointerEvents = "none"; el.dataset.hps607Hidden = "1"; }
      continue;
    }
    const rect = visibleRect(el);
    if (!rect) continue;
    items.push({ id: `${layer}:${Math.round(rect.l)}:${Math.round(rect.t)}:${items.length}`, layer, rect, anchor, el, pinned: el.classList.contains("hps-fan-2710") || !!el.querySelector("[data-selected-2610], [data-cluster-open-2610]") });
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
    if (hidden.has(it.id)) { if (!it.el.dataset.hps607Hidden) { it.el.style.visibility = "hidden"; it.el.style.pointerEvents = "none"; it.el.dataset.hps607Hidden = "1"; } continue; }
    if (it.el.dataset.hps607Hidden) { it.el.style.visibility = ""; it.el.style.pointerEvents = ""; delete it.el.dataset.hps607Hidden; }
    const s = shifts.get(it.id);
    if (s) { it.el.style.translate = `${s.dx}px ${s.dy}px`; it.el.dataset.hps622Shift = "1"; }
  }
  return { hidden: hidden.size + offMap, moved: shifts.size, total: items.length + offMap, compact: unplaced.size };
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
    // 30/10 (LEO) — `withLate` : la 2e passe à 380 ms sert aux rails qui s'animent (repli, mise à l'échelle) ;
    // une mutation du calque des marqueurs (icône réécrite) n'en a pas besoin — elle doublait chaque passe.
    const schedule = (withLate = true) => {
      if (raf) cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => { raf = 0; run(); });
      if (!withLate) return;
      window.clearTimeout(late);
      late = window.setTimeout(run, 380);
    };
    // 26/10 (bug « ça clignote ») — une icône réécrite garde sa bulle à la bonne place DÈS l'image
    // suivante (rattrapage avant l'affichage), la passe complète suit au prochain rafraîchissement.
    const mo = new MutationObserver(() => {
      try {
        const c = container.getBoundingClientRect();
        clampBubbles2610(Array.from(pane.querySelectorAll<HTMLElement>(".leaflet-marker-icon")), { l: c.left, t: c.top, r: c.right, b: c.bottom });
      } catch { /* jamais bloquant */ }
      schedule(false);
    });
    mo.observe(pane, { childList: true, subtree: true });
    // Rails repliés / dépliés : leurs attributs changent (classe, style, aria).
    const wrap = container.closest("[data-map-shell]") || container.parentElement?.parentElement || null;
    // Jamais les mutations DE LA CARTE elle-même (nos propres glissements, le transform de Leaflet) :
    // sinon la passe se relancerait elle-même en boucle.
    const mo2 = new MutationObserver((recs) => { if (recs.some((r) => !container.contains(r.target))) schedule(); });
    if (wrap) mo2.observe(wrap, { attributes: true, subtree: true, attributeFilter: ["class", "style", "aria-expanded", "data-collapsed"] });
    const scheduleLate = () => schedule(true);
    map.on("zoomend moveend resize", scheduleLate);
    let rafMove = 0;
    const onMove = () => {
      if (rafMove) return;
      rafMove = requestAnimationFrame(() => {
        rafMove = 0;
        try {
          const c = container.getBoundingClientRect();
          clampBubbles2610(Array.from(pane.querySelectorAll<HTMLElement>(".leaflet-marker-icon")), { l: c.left, t: c.top, r: c.right, b: c.bottom });
        } catch { /* jamais bloquant */ }
      });
    };
    map.on("move", onMove);
    // 2610 — le rond sélectionné grandit (1 → 1,18 en 0,35 s) : nouvelle passe à la fin du rebond,
    // sinon les voisins sont placés contre un rond encore petit.
    const onAnim = (e: AnimationEvent) => { if (e.animationName === "hps2610-pop") schedule(false); };
    pane.addEventListener("animationend", onAnim);
    window.addEventListener("resize", scheduleLate);
    schedule();
    return () => {
      mo.disconnect(); mo2.disconnect();
      map.off("zoomend moveend resize", scheduleLate);
      map.off("move", onMove);
      pane.removeEventListener("animationend", onAnim);
      if (rafMove) cancelAnimationFrame(rafMove);
      window.removeEventListener("resize", scheduleLate);
      if (raf) cancelAnimationFrame(raf);
      window.clearTimeout(late);
    };
  }, [map]);
  return null;
}

export default CollisionPass607;
