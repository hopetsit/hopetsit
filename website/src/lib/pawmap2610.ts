// 26/10/2026 (LEO) — ordre de Daniel via BOB : la PawMap du SITE prend la maquette de l'app.
// 10/11/2026 (LEO, build 639) — PASTILLES v2 (maquette « design_handoff_pawmap_pastilles_v2 », README
// = spécification visuelle ; contrats du build 639 §5 et §6) : pastille 32 px PLEINE à la couleur du
// rôle (plus d'anneau ni de bord blanc), filet + ombre courte, icône 17, halos PawBoost turquoise /
// PawFollow violet (onde) / Ami fuchsia (cœur), couronne Premium visible, point vert « disponible
// aujourd'hui », groupes 32 px, bulle de prix claire. Couleurs vives SUR LA CARTE SEULEMENT.
//
// Périmètre STRICT : dessin des ronds de profil, des groupes et de la bulle de prix. La logique
// (regroupement, éclatement, règle des prix, données, fiche au clic, confidentialité) ne change pas.
//
// Module PUR (aucun DOM, aucun Leaflet) : du HTML en chaînes que les cartes posent dans un
// L.divIcon. Testé par scripts/test-pawmap2610.mjs.

export type Role2610 = "owner" | "sitter" | "walker";

/** Couleurs de rôle de la CARTE (contrat 639 §6) : `color` pleine, `light` = départ du dégradé des
 *  pastilles d'icône de la bulle, `glow` = lueur des boutons du haut. Partout ailleurs sur le site,
 *  les couleurs de marque (pawmapLegend.ROLE_COLOR) ne changent pas. */
export const ROLE_2610: Record<Role2610, { color: string; light: string; glow: string }> = {
  owner: { color: "#ff3a0f", light: "#ff7a52", glow: "rgba(255,58,15,0.75)" },
  sitter: { color: "#0f62ff", light: "#5ea0ff", glow: "rgba(15,98,255,0.8)" },
  walker: { color: "#00c24a", light: "#3fd476", glow: "rgba(0,194,74,0.75)" },
};
export const GOLD_2610 = "#f6b400";
export const GOLD_ICON_2610 = "#6b3a00";
export const LIVE_2610 = "#e8452f";
/** Halos de la carte (contrat 639 §6). */
export const BOOST_2610 = "#12d8c9";
export const FOLLOW_2610 = "#8f5cff";
export const FRIEND_2610 = "#ff5ad2";
/** Point « disponible aujourd'hui » (contrat 639 §5). */
export const AVAILABLE_2610 = "#1fe074";
export const VERIFIED_2610 = "#2F6FE0";
export const ONLINE_2610 = "#16A34A";
export const OFFLINE_2610 = "#C2410C";

/** Surfaces de la bulle et du groupe (maquette §7) : clair / sombre. */
export function surface2610(dark?: boolean): { bg: string; ink: string; muted: string; line: string; sep: string } {
  return dark
    ? { bg: "#262123", ink: "#f6efec", muted: "#a99c9e", line: "rgba(255,255,255,.22)", sep: "rgba(255,255,255,.18)" }
    : { bg: "#ffffff", ink: "#1d1719", muted: "#7a6f71", line: "rgba(0,0,0,.07)", sep: "rgba(0,0,0,.14)" };
}

export function role2610(r: string | null | undefined): Role2610 {
  const k = (r || "").toLowerCase();
  return k === "sitter" ? "sitter" : k === "walker" ? "walker" : "owner";
}

// Icônes Material (pets, home, directions_walk) en SVG 24 : dessinées sans attendre la police.
const ICON: Record<Role2610, string> = {
  owner:
    '<circle cx="4.5" cy="9.5" r="2.5"/><circle cx="9" cy="5.5" r="2.5"/><circle cx="15" cy="5.5" r="2.5"/><circle cx="19.5" cy="9.5" r="2.5"/><path d="M17.34 14.86c-.87-1.02-1.6-1.89-2.48-2.91-.46-.54-1.05-1.08-1.75-1.32-.11-.04-.22-.07-.33-.09-.25-.04-.52-.04-.78-.04s-.53 0-.79.05c-.11.02-.22.05-.33.09-.7.24-1.28.78-1.75 1.32-.87 1.02-1.6 1.89-2.48 2.91-1.31 1.31-2.92 2.76-2.62 4.79.29 1.02 1.02 2.03 2.33 2.32.73.15 3.06-.44 5.54-.44h.18c2.48 0 4.81.58 5.54.44 1.31-.29 2.04-1.31 2.33-2.32.31-2.04-1.3-3.49-2.61-4.8z"/>',
  sitter: '<path d="M10 19v-5h4v5c0 .55.45 1 1 1h3c.55 0 1-.45 1-1v-7h1.7c.46 0 .68-.57.33-.87L12.67 3.6c-.38-.34-.96-.34-1.34 0l-8.36 7.53c-.34.3-.13.87.33.87H5v7c0 .55.45 1 1 1h3c.55 0 1-.45 1-1z"/>',
  walker: '<path d="M13.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zM9.8 8.9 7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3C14.8 12 16.8 13 19 13v-2c-1.9 0-3.5-1-4.3-2.4l-1-1.6c-.4-.6-1-1-1.7-1-.3 0-.5.1-.8.1L6 8.3V13h2V9.6l1.8-.7"/>',
};
const ROCKET = '<path d="M14.5 2.5c3.3 0 6.4 1.6 7 4-3.2 6.4-6.7 9.6-9.7 11.2l-3.5-3.5C10 11.2 11.3 6 14.5 2.5zM8 14.7 4.4 13c1-2.2 2.4-3.9 4.1-5.1zM9.3 16 11 19.6c2.2-1 3.9-2.4 5.1-4.1zM4 20c1.1-2.6 2.2-3.5 3.6-3.6.2 1.4-.9 2.5-3.6 3.6zM15 7a1.6 1.6 0 1 0 0 3.2A1.6 1.6 0 0 0 15 7z"/>';
/** Couronne (Font Awesome « crown », viewBox 576×512). */
const CROWN = '<path d="M309 106c11.4-7 19-19.7 19-34c0-22.1-17.9-40-40-40s-40 17.9-40 40c0 14.4 7.6 27 19 34L209.7 220.6c-9.1 18.2-32.7 23.4-48.6 10.7L72 160c5-6.7 8-15 8-24c0-22.1-17.9-40-40-40S0 113.9 0 136s17.9 40 40 40c.2 0 .5 0 .7 0L86.4 427.4c5.5 30.4 32 52.6 63 52.6H426.6c30.9 0 57.4-22.1 63-52.6L535.3 176c.2 0 .5 0 .7 0c22.1 0 40-17.9 40-40s-17.9-40-40-40s-40 17.9-40 40c0 9 3 17.3 8 24l-89.1 71.3c-15.9 12.7-39.5 7.5-48.6-10.7L309 106z"/>';
/** Cœur (Material « favorite ») cadré au plus juste : viewBox 2 3 20 18.35. */
const HEART = '<path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>';
/** Étoile (Material « star »). */
const STAR = '<path d="M12 17.27 18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/>';

function icon(role: Role2610, size: number, color: string): string {
  return `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="${color}" aria-hidden="true" style="display:block;">${ICON[role]}</svg>`;
}
function esc(v: string): string {
  return String(v).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c] as string);
}

// ── Arcs SVG (mêmes formules que pawmap-markers.tsx) ─────────────────────────
export function arc2610(cx: number, cy: number, r: number, a0: number, a1: number): string {
  const p = (a: number) => [cx + r * Math.cos(((a - 90) * Math.PI) / 180), cy + r * Math.sin(((a - 90) * Math.PI) / 180)];
  const [x0, y0] = p(a0);
  const [x1, y1] = p(a1);
  const f = (n: number) => Math.round(n * 1000) / 1000;
  return `M ${f(x0)} ${f(y0)} A ${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${f(x1)} ${f(y1)}`;
}
const wedge = (c: number, r: number, a0: number, a1: number) => `M ${c} ${c} L ${arc2610(c, c, r, a0, a1).slice(2)} Z`;

/** Rôles uniques, dans l'ordre reçu (le rôle du point d'abord). */
export function uniqueRoles2610(roles: (string | null | undefined)[]): Role2610[] {
  const out: Role2610[] = [];
  for (const r of roles) { const k = role2610(r); if (!out.includes(k)) out.push(k); }
  return out.length ? out : ["owner"];
}

export type ProfilePin2610 = {
  roles: (string | null | undefined)[];
  premium?: boolean;
  live?: boolean;
  /** Halos : UN seul à la fois, priorité inchangée (PawBoost > PawFollow > ami). */
  boosted?: boolean;
  pawFollow?: boolean;
  /** 639 — ami : halo fuchsia + badge cœur (seulement si aucun halo PawBoost / PawFollow). */
  friend?: boolean;
  verified?: boolean;
  /** true = en ligne (point vert), false = hors ligne (point orange), null = rien. Le direct passe devant. */
  online?: boolean | null;
  /** 639 (contrat §5) — point vert « disponible aujourd'hui » en bas à gauche. À passer UNIQUEMENT quand
   *  le serveur a renvoyé `availableDot === true` ; ignoré pour un profil sans rôle gardien / promeneur. */
  availableDot?: boolean;
  /** Pins du classement (HTML déjà prêt, coin haut gauche). */
  pinsHtml?: string;
  selected?: boolean;
  /** 26/10 (bug « ça clignote ») — rebond SEULEMENT à la sélection ; une icône reconstruite plus tard
   *  (nouveau rendu de la carte) reste nette à 1,18 sans rejouer l'animation. Défaut : true. */
  pop?: boolean;
  /** Prix à montrer (rond SÉLECTIONNÉ seulement, règle visiblePrices appliquée par l'appelant). */
  prices?: Price2610[];
  /** 639 — note à poser sur la bulle de prix (« 4,9 »), seulement si la donnée existe déjà. */
  rating?: string | null;
  /** Prénom sous le rond (zoom rue, existant) — posé sous les mini-pastilles de rôles. */
  caption?: string | null;
  dark?: boolean;
};
export type Price2610 = { role: Role2610; amount: string; unit: string };

/** Taille de la pastille (maquette v2 §4 : 32 pt). */
export const PIN_2610 = 32;
/** Bas des mini-pastilles de rôles d'un profil multi-rôle (27 + 12). */
export const CHIPS_BOTTOM_2610 = 39;
/** Distance entre le BAS du conteneur 32 px et le bas de la boîte de la bulle : la pointe arrive à
 *  21 px au-dessus du CENTRE de la pastille (16 + 21 = 37, + 1 px : la pointe dépasse sa boîte d'1 px). */
export const BUBBLE_BOTTOM_2610 = 38;

const HALO_2610: Record<"boost" | "follow" | "friend", { color: string; rgb: string }> = {
  boost: { color: BOOST_2610, rgb: "18,216,201" },
  follow: { color: FOLLOW_2610, rgb: "143,92,255" },
  friend: { color: FRIEND_2610, rgb: "255,90,210" },
};
const WHITE_EDGE = "box-shadow:0 0 0 1.5px #fff;";

/**
 * Pastille de profil v2. Ancre = centre exact de la pastille (le conteneur fait 32 × 32).
 * Rond 32 PLEIN à la couleur du rôle, filet 0,5 px + ombre courte, icône blanche 17. Multi-rôle :
 * camembert en parts égales + `pets`, mini-pastilles 12 px sous le rond. Halo 43 px derrière (un
 * seul), couronne 14 px (haut-droite), fusée 13 px ou cœur 15 px (haut-gauche), point « disponible »
 * 8 px (bas-gauche), point « en direct » 7 px (bas-droite, pulsé). Sélectionné : 1,18 avec rebond
 * + pointe à la couleur du rôle (mono-rôle).
 */
export function profilePinHtml2610(o: ProfilePin2610): string {
  const roles = uniqueRoles2610(o.roles);
  const n = roles.length;
  const S = PIN_2610;
  const C = S / 2;
  const main = ROLE_2610[roles[0]];
  const haloKind: "boost" | "follow" | "friend" | null = o.boosted ? "boost" : o.pawFollow ? "follow" : o.friend ? "friend" : null;
  const ring = "position:absolute;left:-5.5px;top:-5.5px;width:43px;height:43px;border-radius:50%;box-sizing:border-box;pointer-events:none;";
  const halo = haloKind
    ? `<span data-${haloKind}-2610="" style="${ring}border:2px solid ${HALO_2610[haloKind].color};background:rgba(${HALO_2610[haloKind].rgb},.22);box-shadow:0 0 9px 1px rgba(${HALO_2610[haloKind].rgb},.75);${haloKind === "boost" ? "animation:hps2610-boost 2.4s ease-in-out infinite;" : ""}"></span>`
      + (haloKind === "follow" ? `<span data-wave-2610="" style="${ring}border:2px solid ${FOLLOW_2610};animation:hps2610-wave 1.8s ease-out infinite;"></span>` : "")
    : "";
  const ground = `<span data-ground-2610="" style="position:absolute;left:7px;top:29px;width:18px;height:6px;border-radius:50%;background:radial-gradient(closest-side,rgba(0,0,0,.38),rgba(0,0,0,0));pointer-events:none;"></span>`;
  // Pointe de sélection : carré 9 px tourné à 45°, DERRIÈRE le rond, dépasse d'environ 4 px. Mono-rôle seulement.
  const selTail = o.selected && n === 1
    ? `<span data-seltail-2610="" style="position:absolute;left:11.5px;top:25.5px;width:9px;height:9px;border-radius:2px;background:${main.color};transform:rotate(45deg);box-shadow:0 1px 2px rgba(0,0,0,.3);"></span>`
    : "";
  const edge = "box-shadow:0 0 0 .5px rgba(0,0,0,.25),0 1px 3px rgba(0,0,0,.35);";
  const disc = n === 1
    ? `<span data-disc-2610="" style="position:absolute;inset:0;border-radius:50%;background:${main.color};${edge}"></span>`
    : `<span data-disc-2610="" style="position:absolute;inset:0;border-radius:50%;overflow:hidden;background:${main.color};${edge}"><svg viewBox="0 0 ${S} ${S}" width="${S}" height="${S}" aria-hidden="true" style="display:block;">${roles
        .map((r, i) => `<path d="${wedge(C, C, (i / n) * 360, ((i + 1) / n) * 360 - 0.01)}" fill="${ROLE_2610[r].color}"/>`)
        .join("")}</svg></span>`;
  const glyph = `<span style="position:absolute;left:${C - 8.5}px;top:${C - 8.5}px;width:17px;height:17px;">${icon(n > 1 ? "owner" : roles[0], 17, "#fff")}</span>`;
  const badge = "position:absolute;border-radius:50%;display:flex;align-items:center;justify-content:center;";
  const crown = o.premium
    ? `<span data-crown-2610="" style="${badge}right:-5px;top:-5px;width:14px;height:14px;background:${GOLD_2610};box-shadow:0 0 0 1.5px #fff,0 1px 3px rgba(0,0,0,.3);"><svg viewBox="0 0 576 512" width="8.4" height="7" fill="${GOLD_ICON_2610}" aria-hidden="true" style="display:block;">${CROWN}</svg></span>`
    : "";
  const rocket = haloKind === "boost"
    ? `<span data-rocket-2610="" style="${badge}left:-5px;top:-5px;width:13px;height:13px;background:${BOOST_2610};box-shadow:0 0 0 1.5px #fff,0 1px 3px rgba(0,0,0,.3);"><svg viewBox="0 0 24 24" width="9" height="9" fill="#003d38" aria-hidden="true" style="display:block;">${ROCKET}</svg></span>`
    : "";
  const heart = haloKind === "friend"
    ? `<span data-heart-2610="" style="${badge}left:-6px;top:-6px;width:15px;height:15px;background:linear-gradient(160deg,#f73cc0,#d9159f);box-shadow:0 0 0 1.5px #fff,0 1px 3px rgba(0,0,0,.3);"><svg viewBox="2 3 20 18.35" width="8" height="7.3" fill="#fff" aria-hidden="true" style="display:block;">${HEART}</svg></span>`
    : "";
  // Multi-rôle : les mini-pastilles occupent le bas → les points remontent sur les côtés (jamais sur une mini-pastille).
  const lowLeft = n > 1 ? "left:-3px;bottom:9px;" : "left:-1px;bottom:-1px;";
  const lowRight = n > 1 ? "right:-3px;bottom:9px;" : "right:-1px;bottom:-1px;";
  // Contrat 639 §5 : uniquement gardiens et promeneurs, uniquement quand l'appelant a lu `availableDot === true`.
  const available = o.availableDot === true && roles.some((r) => r !== "owner")
    ? `<span data-available-2610="" style="position:absolute;${lowLeft}width:8px;height:8px;border-radius:50%;background:${AVAILABLE_2610};${WHITE_EDGE}"></span>`
    : "";
  const live = o.live
    ? `<span data-live-2610="" style="position:absolute;${lowRight}width:7px;height:7px;border-radius:50%;background:${LIVE_2610};${WHITE_EDGE}animation:hps2610-pulse 1.8s ease-out infinite;"></span>`
    : o.online === true || o.online === false
      // Point « en ligne » : même place et même taille que le point direct, sans pulsation.
      ? `<span data-online-2610="" style="position:absolute;${lowRight}width:7px;height:7px;border-radius:50%;background:${o.online ? ONLINE_2610 : OFFLINE_2610};${WHITE_EDGE}"></span>`
      : "";
  // Coche « identité vérifiée » 10 px : le bas gauche revient au point « disponible » → milieu du bord
  // DROIT (mono-rôle) ; multi-rôle : haut, au centre (les côtés portent les points).
  const verified = o.verified
    ? `<span data-verified-2610="" style="${badge}${n > 1 ? "left:11px;top:-5px" : "right:-5px;top:11px"};width:10px;height:10px;background:${VERIFIED_2610};box-shadow:0 0 0 1.5px #fff,0 1px 3px rgba(0,0,0,.3);"><svg viewBox="0 0 24 24" width="7" height="7" fill="none" stroke="#fff" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></span>`
    : "";
  const chips = n > 1
    ? `<span data-chips-2610="" style="position:absolute;left:50%;top:27px;transform:translateX(-50%);display:flex;gap:3px;">${roles
        .map((r) => `<span style="width:12px;height:12px;border-radius:50%;background:${ROLE_2610[r].color};box-shadow:0 0 0 1.5px #fff,0 1px 2px rgba(0,0,0,.3);display:flex;align-items:center;justify-content:center;flex:none;">${icon(r, 8, "#fff")}</span>`)
        .join("")}</span>`
    : "";
  const sf = surface2610(o.dark);
  const capTop = n > 1 ? CHIPS_BOTTOM_2610 + 4 : S + 6;
  const caption = o.caption
    ? `<span data-pin-extra="" style="position:absolute;top:${capTop}px;left:50%;transform:translateX(-50%);height:20px;display:inline-flex;align-items:center;padding:0 8px;border-radius:10px;white-space:nowrap;max-width:160px;overflow:hidden;background:${sf.bg};color:${sf.ink};font:600 10.5px/1 Poppins,Inter,system-ui,sans-serif;box-shadow:0 2px 6px -1px rgba(0,0,0,.3);">${esc(o.caption)}</span>`
    : "";
  const bubble = o.selected && o.prices && o.prices.length
    ? priceBubbleHtml2610(o.prices, BUBBLE_BOTTOM_2610, { dark: o.dark, pop: o.pop !== false, rating: o.rating })
    : "";
  const anim = o.selected ? `transform:scale(1.18);${o.pop === false ? "" : "animation:hps2610-pop .35s cubic-bezier(.3,1.6,.5,1);"}` : "";
  return `<div data-pin-2610="" ${o.selected ? 'data-selected-2610=""' : ""} style="position:relative;width:${S}px;height:${S}px;transform-origin:50% 50%;${anim}">`
    + ground + halo + selTail + disc + glyph
    + `${crown}${rocket}${heart}${available}${live}${verified}${o.pinsHtml || ""}${chips}${caption}${bubble}</div>`;
}

/**
 * Bulle de prix v2 (maquette §7) : UNE pilule claire de 28 px (fond de surface, liseré intérieur 1 px,
 * padding horizontal 4). Par rôle : pastille d'icône 20 px en dégradé du rôle (160°) + icône blanche
 * 13, puis à 5 px le montant 13 px très gras (texte principal) et l'unité 9,5 px demi-gras (texte
 * secondaire), 8 px de marge à droite ; séparateur vertical 1 × 14 entre deux rôles. Pointe : carré
 * 11 px tourné à 45° (coin 3 px), même fond, qui dépasse d'environ 6 px. `bottom` = distance entre le
 * BAS du conteneur et le bas de la boîte de la bulle. La pilule porte `data-bubble-2610` : la passe
 * de mise en page la décale horizontalement pour la garder dans l'écran (elle ne doit donc porter ni
 * `translate` ni animation), la pointe (`data-tail-2610`) reste sur le marqueur. L'apparition
 * (280 ms) est jouée sur l'ENVELOPPE, seulement quand `pop` est vrai.
 */
export function priceBubbleHtml2610(prices: Price2610[], bottom: number, opts: { dark?: boolean; pop?: boolean; rating?: string | null } = {}): string {
  const sf = surface2610(opts.dark);
  const segs = prices
    .map((p, i) => {
      const c = ROLE_2610[p.role];
      return (i > 0 ? `<span data-bubble-sep-2610="" style="width:1px;height:14px;background:${sf.sep};margin-right:4px;flex:none;"></span>` : "")
        + `<span style="display:flex;align-items:center;margin-right:8px;white-space:nowrap;">`
        + `<span style="width:20px;height:20px;border-radius:50%;background:linear-gradient(160deg,${c.light},${c.color});display:flex;align-items:center;justify-content:center;flex:none;">${icon(p.role, 13, "#fff")}</span>`
        + `<span style="display:flex;align-items:baseline;gap:1px;margin-left:5px;line-height:1;font-family:Poppins,Inter,system-ui,sans-serif;">`
        + `<span style="font-size:13px;font-weight:800;color:${sf.ink};letter-spacing:-.01em;">${esc(p.amount)}</span>`
        + (p.unit ? `<span style="font-size:9.5px;font-weight:600;color:${sf.muted};">${esc(p.unit)}</span>` : "")
        + `</span></span>`;
    })
    .join("");
  // Étiquette de note : pilule dorée 16 px à cheval sur le bord supérieur, à 10 px du bord droit.
  const rating = opts.rating
    ? `<span data-bubble-rating-2610="" style="position:absolute;right:10px;top:-10px;height:16px;display:flex;align-items:center;gap:1px;padding:0 5px 0 3px;border-radius:999px;background:#ffc526;box-shadow:0 0 0 1.5px ${sf.bg};white-space:nowrap;"><svg viewBox="0 0 24 24" width="11" height="11" fill="#3d2600" aria-hidden="true" style="display:block;">${STAR}</svg><span style="font:800 10px/1 Poppins,Inter,system-ui,sans-serif;color:#3d2600;">${esc(opts.rating)}</span></span>`
    : "";
  const anim = opts.pop ? "transform-origin:50% 100%;animation:hps2610-bub .28s cubic-bezier(.3,1.5,.5,1) both;" : "";
  return `<span data-price-bubble-2610="" style="position:absolute;left:50%;bottom:${bottom}px;transform:translateX(-50%);display:flex;flex-direction:column;align-items:center;filter:drop-shadow(0 1px 1px rgba(0,0,0,.2)) drop-shadow(0 6px 9px rgba(0,0,0,.24));cursor:pointer;${anim}">`
    + `<span data-bubble-2610="" style="position:relative;z-index:1;display:flex;align-items:center;height:28px;padding:0 4px;border-radius:999px;background:${sf.bg};box-shadow:inset 0 0 0 1px ${sf.line};">${segs}${rating}</span>`
    + `<span data-tail-2610="" style="position:relative;z-index:0;display:block;width:11px;height:11px;border-radius:3px;background:${sf.bg};transform:rotate(45deg);margin-top:-5.5px;"></span></span>`;
}

/** Coupe « 20 €/jour » en montant « 20 € » + unité « /jour » (rien à couper = tout en montant). */
export function splitPrice2610(label: string): { amount: string; unit: string } {
  const i = label.indexOf("/");
  if (i <= 0) return { amount: label.trim(), unit: "" };
  return { amount: label.slice(0, i).trim(), unit: label.slice(i).trim() };
}

/**
 * Règle des prix (README §2, `visiblePrices`) : propriétaire → gardiens + promeneurs ;
 * gardien / promeneur → uniquement les propriétaires (budgets). Jamais son propre rôle.
 * Visiteur non connecté (site) = vue PROPRIÉTAIRE (le public visé par le site).
 */
export function visibleRoles2610(viewer: string | null | undefined): Role2610[] {
  const v = (viewer || "").toLowerCase();
  return v === "sitter" || v === "walker" ? ["owner"] : ["sitter", "walker"];
}
export function visiblePrices2610(viewer: string | null | undefined, profileRoles: (string | null | undefined)[], prices: Price2610[]): Price2610[] {
  const allowed = visibleRoles2610(viewer);
  const has = uniqueRoles2610(profileRoles);
  return prices.filter((p) => allowed.includes(p.role) && has.includes(p.role));
}

/**
 * Groupe v2 (maquette §6) : rond 32, fond blanc (sombre #262123), PAS de contour blanc, même filet
 * et même ombre que les pastilles, anneau 3,3 px partagé proportionnellement aux rôles (petit écart),
 * nombre 13 px très gras. « dès X » masqué, montré seulement quand le groupe est touché (`fromLabel`) :
 * pilule 24 px, point 7 px à la couleur du rôle, « dès » 10 px secondaire, prix 12 px très gras.
 */
export function clusterHtml2610(o: { counts: Partial<Record<Role2610, number>>; total: number; dark?: boolean; fromLabel?: { from: string; amount: string; role: Role2610 } | null }): string {
  const S = PIN_2610;
  const C = S / 2;
  const R = C - 2.2;
  const order: Role2610[] = ["walker", "owner", "sitter"];
  const parts = order.map((r) => [r, Math.max(0, o.counts[r] || 0)] as const).filter(([, v]) => v > 0);
  const tot = parts.reduce((s, [, v]) => s + v, 0);
  let acc = 0;
  let svg = "";
  if (parts.length === 1) {
    svg = `<circle cx="${C}" cy="${C}" r="${R}" stroke="${ROLE_2610[parts[0][0]].color}" stroke-width="3.3" fill="none"/>`;
  } else {
    for (const [r, v] of parts) {
      const a0 = (acc / tot) * 360 + 8;
      acc += v;
      const a1 = (acc / tot) * 360;
      svg += `<path d="${arc2610(C, C, R, a0, Math.max(a0 + 1, a1))}" stroke="${ROLE_2610[r].color}" stroke-width="3.3" fill="none"/>`;
    }
  }
  const label = o.total > 99 ? "99+" : String(o.total);
  const sf = surface2610(o.dark);
  const from = o.fromLabel
    ? `<span data-cluster-from-2610="" style="position:absolute;left:50%;top:${S + 5}px;transform:translateX(-50%);display:flex;align-items:center;gap:4px;height:24px;padding:0 10px 0 8px;border-radius:999px;background:${sf.bg};box-shadow:inset 0 0 0 1px ${sf.line},0 1px 1px rgba(0,0,0,.2),0 6px 9px -2px rgba(0,0,0,.24);white-space:nowrap;font-family:Poppins,Inter,system-ui,sans-serif;">`
      + `<span style="width:7px;height:7px;border-radius:50%;background:${ROLE_2610[o.fromLabel.role].color};flex:none;"></span>`
      + (o.fromLabel.from ? `<span style="font-size:10px;font-weight:600;color:${sf.muted};">${esc(o.fromLabel.from)}</span>` : "")
      + `<span style="font-size:12px;font-weight:800;color:${sf.ink};">${esc(o.fromLabel.amount)}</span></span>`
    : "";
  return `<div data-cluster-2610="" ${o.fromLabel ? 'data-cluster-open-2610=""' : ""} style="position:relative;width:${S}px;height:${S}px;">`
    + `<div style="position:absolute;inset:0;border-radius:50%;background:${sf.bg};box-shadow:0 0 0 .5px rgba(0,0,0,.25),0 1px 3px rgba(0,0,0,.35);">`
    + `<svg viewBox="0 0 ${S} ${S}" width="${S}" height="${S}" aria-hidden="true" style="position:absolute;inset:0;z-index:0;display:block;">${svg}</svg>`
    + `<span style="position:absolute;z-index:1;inset:0;display:flex;align-items:center;justify-content:center;font:800 ${label.length > 2 ? 10.5 : 13}px/1 Poppins,Inter,system-ui,sans-serif;letter-spacing:-.04em;color:${sf.ink};">${label}</span>`
    + `</div>${from}</div>`;
}

/** Éclatement d'un groupe (README §3) : 6 profils sur un cercle de 72, le reste sur 132. Aucun trait. */
export function spiderfy2610(n: number): { x: number; y: number }[] {
  const inner = Math.min(n, 6);
  return Array.from({ length: n }, (_, j) => {
    const ring = j < inner ? 0 : 1;
    const cnt = ring ? n - inner : inner;
    const idx = ring ? j - inner : j;
    const rad = ring ? 132 : 72;
    const a = (idx / cnt) * Math.PI * 2 - Math.PI / 2 + (ring ? Math.PI / cnt : 0);
    return { x: Math.round(Math.cos(a) * rad * 10) / 10, y: Math.round(Math.sin(a) * rad * (ring ? 0.95 : 1) * 10) / 10 };
  });
}
/**
 * Au-delà de 6 + 15 profils (mesuré par le test : à 22, deux ronds sont à 49 px), le second cercle (132 px) ne loge plus des ronds de 50 px sans
 * qu'ils se touchent (2π·132 / 16 ≈ 52 px) : on garde alors le comportement d'avant (zoom ou
 * liste) — règle « 0 chevauchement ».
 */
export const SPIDER_MAX_2610 = 21;

/**
 * 26/10 (bug « ça clignote ») — même HTML = même objet L.DivIcon : react-leaflet ne rappelle
 * `setIcon` (qui réécrit l'icône et relance son animation) que si l'objet change. Cache borné.
 */
export function cachedIcon2610<T>(key: string, make: () => T): T {
  const hit = ICON_CACHE_2610.get(key) as T | undefined;
  if (hit) return hit;
  if (ICON_CACHE_2610.size > 3000) ICON_CACHE_2610.clear();
  const ic = make();
  ICON_CACHE_2610.set(key, ic);
  return ic;
}
const ICON_CACHE_2610 = new Map<string, unknown>();
/** Rebond une seule fois par sélection : vrai la 1re fois qu'on dessine le rond sélectionné `id`. */
let popKey2610 = "";
let popAt2610 = 0;
export function popOnce2610(id: string, selected: boolean, now = Date.now()): boolean {
  if (!selected) { if (popKey2610 === id) popKey2610 = ""; return false; }
  if (popKey2610 !== id) { popKey2610 = id; popAt2610 = now; return true; }
  // Même sélection : l'animation (0,35 s) n'est rejouée que si l'icône est redessinée pendant le rebond.
  return now - popAt2610 < 350;
}

/** Images clés (rebond de la sélection, apparition de la bulle, onde PawFollow, point « en direct » pulsé). */
export const PAWMAP_2610_CSS = `
@keyframes hps2610-boost { 0%,100% { box-shadow:0 0 9px 1px rgba(18,216,201,.75); } 50% { box-shadow:0 0 15px 4px rgba(18,216,201,.95); } }
@keyframes hps2610-wave { 0% { transform:scale(1); opacity:.75; } 100% { transform:scale(1.6); opacity:0; } }
@keyframes hps2610-pop { 0% { transform:scale(1); } 100% { transform:scale(1.18); } }
@keyframes hps2610-bub { 0% { opacity:0; transform:translateX(-50%) translateY(6px) scale(.7); } 100% { opacity:1; transform:translateX(-50%) translateY(0) scale(1); } }
@keyframes hps2610-pulse { 0% { box-shadow:0 0 0 1.5px #fff,0 0 0 0 rgba(232,69,47,.55); } 70% { box-shadow:0 0 0 1.5px #fff,0 0 0 7px rgba(232,69,47,0); } 100% { box-shadow:0 0 0 1.5px #fff,0 0 0 0 rgba(232,69,47,0); } }
.hps2610-dim { opacity:.85; }
.hps2610-btn { transition: transform .15s; }
.hps2610-btn:hover > span { transform: translateY(-1px); }
.hps2610-btn:active > span { transform: scale(.94); }
@media (prefers-reduced-motion: reduce) { [data-pin-2610], [data-price-bubble-2610], [data-live-2610], [data-boost-2610] { animation:none !important; } [data-wave-2610] { display:none !important; } }
`;

/**
 * 26/10 (ordre de Daniel : « les marqueurs ne sont pas à leur place », groupes posés en mer) — regroupement
 * ANCRÉ : chaque rond / groupe est posé sur une VRAIE position (un groupe = celle de son membre le plus
 * proche du centre de ses membres : jamais en mer quand ses membres sont à terre). Deux positions
 * affichées à moins de `minPx` (rond 50 + air 6) sont FUSIONNÉES (le chiffre augmente) au lieu d'être
 * écartées l'une de l'autre. Pur (aucun DOM) : testé par scripts/test-pawmap2610.mjs.
 */
export const GROUP_MIN_PX_2610 = 56;
export function mergeAnchored2610<T>(groups: T[][], px: (t: T) => { x: number; y: number }, minPx = GROUP_MIN_PX_2610): { items: T[]; anchor: T }[] {
  type G = { items: T[]; pts: { x: number; y: number }[]; a: number };
  const medoid = (pts: { x: number; y: number }[]): number => {
    let mx = 0, my = 0;
    for (const p of pts) { mx += p.x; my += p.y; }
    mx /= pts.length; my /= pts.length;
    let best = 0, bd = Infinity;
    pts.forEach((p, i) => { const d = (p.x - mx) ** 2 + (p.y - my) ** 2; if (d < bd) { bd = d; best = i; } });
    return best;
  };
  // 27/10 (fluidité, mesurée : 1,5 s pour 3 000 membres au zoom pays avec la double boucle) — MÊME règle
  // qu'avant : la paire la plus proche d'abord, à égalité la première dans l'ordre de la liste (un groupe
  // fusionné passe en fin de liste). Mise en œuvre : file de priorité des paires voisines (grille de
  // `minPx` : deux ancres à moins de `minPx` sont forcément dans des cases voisines) ; l'ordre de la liste
  // est porté par un numéro croissant (`o`). Résultat identique, vérifié par scripts/test-pawmap2710.mjs.
  type N = G & { o: number; dead: boolean; cx: number; cy: number };
  const min2 = minPx * minPx;
  let order = 0;
  const live = new Map<number, N>();
  const grid = new Map<string, Set<number>>();
  const heap: [number, number, number][] = []; // [d², o petit, o grand]
  const less = (a: [number, number, number], b: [number, number, number]) => a[0] < b[0] || (a[0] === b[0] && (a[1] < b[1] || (a[1] === b[1] && a[2] < b[2])));
  const push = (e: [number, number, number]) => { heap.push(e); let k = heap.length - 1; while (k > 0) { const up = (k - 1) >> 1; if (!less(heap[k], heap[up])) break; [heap[k], heap[up]] = [heap[up], heap[k]]; k = up; } };
  const pop = (): [number, number, number] | undefined => { const top = heap[0]; const last = heap.pop(); if (heap.length && last) { heap[0] = last; let k = 0; for (;;) { const l = 2 * k + 1, r = l + 1; let m = k; if (l < heap.length && less(heap[l], heap[m])) m = l; if (r < heap.length && less(heap[r], heap[m])) m = r; if (m === k) break; [heap[k], heap[m]] = [heap[m], heap[k]]; k = m; } } return top; };
  const add = (g: G): N => {
    const p = g.pts[g.a];
    const n: N = { ...g, o: order++, dead: false, cx: Math.floor(p.x / minPx), cy: Math.floor(p.y / minPx) };
    for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) {
      const set = grid.get(`${n.cx + dx}_${n.cy + dy}`);
      if (!set) continue;
      for (const o of set) {
        const q = live.get(o)!;
        const pq = q.pts[q.a];
        const d = (p.x - pq.x) ** 2 + (p.y - pq.y) ** 2;
        if (d < min2) push([d, Math.min(o, n.o), Math.max(o, n.o)]);
      }
    }
    live.set(n.o, n);
    const key = `${n.cx}_${n.cy}`;
    (grid.get(key) || grid.set(key, new Set()).get(key)!).add(n.o);
    return n;
  };
  const kill = (n: N) => { n.dead = true; live.delete(n.o); grid.get(`${n.cx}_${n.cy}`)?.delete(n.o); };
  for (const g of groups) if (g.length > 0) { const pts = g.map(px); add({ items: [...g], pts, a: medoid(pts) }); }
  for (let e = pop(); e; e = pop()) {
    const A = live.get(e[1]), B = live.get(e[2]);
    if (!A || !B) continue;
    kill(A); kill(B);
    const pts = [...A.pts, ...B.pts];
    add({ items: [...A.items, ...B.items], pts, a: medoid(pts) });
  }
  const gs = [...live.values()].sort((x, y) => x.o - y.o);
  return gs.map((g) => ({ items: g.items, anchor: g.items[g.a] }));
}
