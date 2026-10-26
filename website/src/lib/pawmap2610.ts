// 26/10/2026 (LEO) — ordre de Daniel via BOB : la PawMap du SITE prend la maquette de l'app
// (~/hopetsit-social/design_pawmap_2610/ : README.md fait foi, valeurs de
// code/pawmap-markers.tsx et de « PawMap - Bulles HD.dc.html », style retenu « A · Anneau »).
//
// Périmètre STRICT : ronds de profil, groupes, bulles de prix (au clic seulement), éclatement
// d'un groupe, couleur des 4 boutons du haut à droite. Rien d'autre.
//
// Module PUR (aucun DOM, aucun Leaflet) : du HTML en chaînes que les cartes posent dans un
// L.divIcon. Testé par scripts/test-pawmap2610.mjs.

export type Role2610 = "owner" | "sitter" | "walker";

/** Couleurs pleines, vives (README §Couleurs) — pas de dégradé ni reflet. */
export const ROLE_2610: Record<Role2610, { color: string; glow: string }> = {
  owner: { color: "#f23b16", glow: "rgba(242,59,22,0.5)" },
  sitter: { color: "#1a6cff", glow: "rgba(26,108,255,0.5)" },
  walker: { color: "#12b350", glow: "rgba(18,179,80,0.5)" },
};
export const GOLD_2610 = "#f6b400";
export const GOLD_ICON_2610 = "#7a4500";
export const LIVE_2610 = "#e8452f";
/** Signes existants gardés (Daniel, 26/10) — couleurs de la légende du site / de l'app 623. */
export const BOOST_2610 = "#06B6D4";
export const VERIFIED_2610 = "#2F6FE0";
export const ONLINE_2610 = "#16A34A";
export const OFFLINE_2610 = "#C2410C";

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
  /** 26/10 (Daniel : « pawboost pawspot etc faut laisser ») — signes existants, redessinés discrets. */
  boosted?: boolean;
  pawFollow?: boolean;
  verified?: boolean;
  /** true = en ligne (point vert), false = hors ligne (point orange), null = rien. Le direct passe devant. */
  online?: boolean | null;
  /** Pins du classement (HTML déjà prêt, coin haut gauche). */
  pinsHtml?: string;
  selected?: boolean;
  /** 26/10 (bug « ça clignote ») — rebond SEULEMENT à la sélection ; une icône reconstruite plus tard
   *  (nouveau rendu de la carte) reste nette à 1,18 sans rejouer l'animation. Défaut : true. */
  pop?: boolean;
  /** Prix à montrer (rond SÉLECTIONNÉ seulement, règle visiblePrices appliquée par l'appelant). */
  prices?: Price2610[];
  /** Prénom sous le rond (zoom rue, existant) — posé sous les pastilles de rôles. */
  caption?: string | null;
  dark?: boolean;
};
export type Price2610 = { role: Role2610; amount: string; unit: string };

/** Taille du rond (README §1 : 50 pt). */
export const PIN_2610 = 50;
/** Hauteur réservée sous le rond par les pastilles de rôles d'un profil multi-rôle (42 + 17). */
export const CHIPS_BOTTOM_2610 = 59;

/**
 * Marqueur profil — style A « Anneau ». Ancre = centre du rond (le conteneur fait 50 × 50).
 * Rond 50, fond blanc, liseré 1 px, ombre courte + halo du rôle ; anneau 5 px à 5,5 px du bord ;
 * centre 32 px plein + icône blanche 20. Multi-rôle : anneau découpé (écart 6°), centre en
 * camembert + `pets`, pastilles 17 px sous le rond. Couronne 17 px (haut-droite), point « en
 * direct » 10 px (bas-droite, pulsé). Sélectionné : 1,18 avec rebond.
 */
export function profilePinHtml2610(o: ProfilePin2610): string {
  const roles = uniqueRoles2610(o.roles);
  const n = roles.length;
  const S = PIN_2610;
  const C = S / 2;
  const gap = n > 1 ? 6 : 0;
  const main = ROLE_2610[roles[0]];
  let svg = "";
  if (n === 1) {
    svg += `<circle cx="${C}" cy="${C}" r="${C - 5.5}" stroke="${main.color}" stroke-width="5" fill="none"/>`;
    svg += `<circle cx="${C}" cy="${C}" r="${C - 9}" fill="${main.color}"/>`;
  } else {
    roles.forEach((r, i) => {
      const a0 = (i / n) * 360 + gap;
      const a1 = ((i + 1) / n) * 360;
      svg += `<path d="${arc2610(C, C, C - 5.5, a0, a1)}" stroke="${ROLE_2610[r].color}" stroke-width="5" fill="none"/>`;
    });
    roles.forEach((r, i) => {
      svg += `<path d="${wedge(C, C - 9, (i / n) * 360, ((i + 1) / n) * 360 - 0.01)}" fill="${ROLE_2610[r].color}"/>`;
    });
  }
  const glyph = n > 1 ? icon("owner", 20, "#fff") : icon(roles[0], 20, "#fff");
  const crown = o.premium
    ? `<span style="position:absolute;z-index:2;right:-4px;top:-4px;width:17px;height:17px;border-radius:50%;background:${GOLD_2610};box-shadow:0 0 0 1.5px #fff,0 1px 3px rgba(0,0,0,.25);display:flex;align-items:center;justify-content:center;"><svg viewBox="0 0 576 512" width="9" height="8" fill="${GOLD_ICON_2610}" aria-hidden="true" style="display:block;">${CROWN}</svg></span>`
    : "";
  // Multi-rôle : les pastilles occupent le bas → le point remonte de 9 px (jamais sur une pastille).
  const live = o.live
    ? `<span data-live-2610="" style="position:absolute;z-index:2;right:0;bottom:${n > 1 ? 9 : 0}px;width:10px;height:10px;border-radius:50%;background:${LIVE_2610};box-shadow:0 0 0 1.5px #fff;animation:hps2610-pulse 1.8s ease-out infinite;"></span>`
    : o.online === true || o.online === false
      // Point « en ligne » : même place et même taille que le point direct, sans pulsation.
      ? `<span data-online-2610="" style="position:absolute;z-index:2;right:0;bottom:${n > 1 ? 9 : 0}px;width:10px;height:10px;border-radius:50%;background:${o.online ? ONLINE_2610 : OFFLINE_2610};box-shadow:0 0 0 1.5px #fff;"></span>`
      : "";
  // Coche « identité vérifiée » 15 px en bas à GAUCHE (même place que l'app 623 de PAM).
  const verified = o.verified
    // Multi-rôle : le bas gauche est pris par les pastilles de rôles → milieu du bord DROIT.
    ? `<span data-verified-2610="" style="position:absolute;z-index:2;${n > 1 ? "right:-6px;top:14px" : "left:-1px;bottom:-1px"};width:15px;height:15px;border-radius:50%;background:${VERIFIED_2610};box-shadow:0 0 0 1.5px #fff,0 1px 3px rgba(0,0,0,.25);display:flex;align-items:center;justify-content:center;"><svg viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="#fff" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></span>`
    : "";
  // Fusée PawBoost 15 px au milieu du bord gauche (le bas gauche est à la coche).
  const rocket = o.boosted
    ? `<span data-rocket-2610="" style="position:absolute;z-index:2;left:-6px;top:17.5px;width:15px;height:15px;border-radius:50%;background:${BOOST_2610};box-shadow:0 0 0 1.5px #fff,0 1px 3px rgba(0,0,0,.25);display:flex;align-items:center;justify-content:center;"><svg viewBox="0 0 24 24" width="9" height="9" fill="#fff" aria-hidden="true" style="display:block;">${ROCKET}</svg></span>`
    : "";
  // Halo discret sous le rond : PawBoost turquoise qui respire, sinon PawFollow violet fixe.
  const halo = o.boosted
    ? `<span data-boost-2610="" style="position:absolute;inset:0;border-radius:50%;animation:hps2610-boost 1.6s ease-in-out infinite;box-shadow:0 0 0 1.5px rgba(6,182,212,.75),0 0 8px 3px rgba(6,182,212,.4);"></span>`
    : o.pawFollow
      ? `<span data-follow-2610="" style="position:absolute;inset:0;border-radius:50%;box-shadow:0 0 0 1.5px rgba(124,58,237,.7),0 0 8px 3px rgba(124,58,237,.35);"></span>`
      : "";
  const chips = n > 1
    ? `<span data-chips-2610="" style="position:absolute;left:50%;top:42px;transform:translateX(-50%);display:flex;gap:4px;">${roles
        .map((r) => `<span style="width:17px;height:17px;border-radius:50%;background:${ROLE_2610[r].color};box-shadow:0 0 0 2px #fff,0 0 0 3px rgba(0,0,0,.12),0 2px 3px rgba(0,0,0,.3);display:flex;align-items:center;justify-content:center;">${icon(r, 10.5, "#fff")}</span>`)
        .join("")}</span>`
    : "";
  const capTop = n > 1 ? CHIPS_BOTTOM_2610 + 4 : S + 4;
  const caption = o.caption
    ? `<span data-pin-extra="" style="position:absolute;top:${capTop}px;left:50%;transform:translateX(-50%);height:20px;display:inline-flex;align-items:center;padding:0 8px;border-radius:10px;white-space:nowrap;max-width:160px;overflow:hidden;background:${o.dark ? "#262123" : "#fff"};color:${o.dark ? "#f6efec" : "#1d1719"};font:600 10.5px/1 Poppins,Inter,system-ui,sans-serif;box-shadow:0 2px 6px -1px rgba(0,0,0,.3);">${esc(o.caption)}</span>`
    : "";
  const bubble = o.selected && o.prices && o.prices.length ? priceBubbleHtml2610(o.prices, S + 5) : "";
  const anim = o.selected ? `transform:scale(1.18);${o.pop === false ? "" : "animation:hps2610-pop .35s cubic-bezier(.3,1.6,.5,1);"}` : "";
  return `<div data-pin-2610="" ${o.selected ? 'data-selected-2610=""' : ""} style="position:relative;width:${S}px;height:${S}px;transform-origin:50% 50%;${anim}">`
    + halo
    + `<div style="position:absolute;inset:0;border-radius:50%;background:#fff;box-shadow:0 0 0 1px rgba(0,0,0,.16),0 2px 3px rgba(0,0,0,.25),0 4px 10px -2px ${main.glow};">`
    + `<svg viewBox="0 0 ${S} ${S}" width="${S}" height="${S}" aria-hidden="true" style="position:absolute;inset:0;z-index:0;display:block;">${svg}</svg>`
    + `<span style="position:absolute;z-index:1;left:${C - 10}px;top:${C - 10}px;width:20px;height:20px;">${glyph}</span>`
    + `${crown}${live}${verified}${rocket}${o.pinsHtml || ""}</div>${chips}${caption}${bubble}</div>`;
}

/**
 * Bulle de prix (README §2) : pilule blanche (padding 2), un segment plein par rôle, icône 12 dans
 * un rond blanc 18, montant 12,5 gras + unité 9,5 medium blanc 88 %, pointe blanche 12 × 7, ombre
 * fine. `bottom` = distance entre le BAS du conteneur 50 px et la pointe (maquette : pointe à 30 px
 * au-dessus du CENTRE du rond = 25 + 30 = 55 px depuis le bas). La pilule porte
 * `data-bubble-2610` : la passe de mise en page la décale horizontalement pour la garder dans
 * l'écran, la pointe (`data-tail-2610`) reste sur le marqueur.
 */
export function priceBubbleHtml2610(prices: Price2610[], bottom: number): string {
  const segs = prices
    .map((p) => {
      const c = ROLE_2610[p.role].color;
      return `<span style="display:flex;align-items:center;gap:6px;height:24px;padding:0 10px 0 3px;border-radius:999px;background:${c};white-space:nowrap;">`
        + `<span style="width:18px;height:18px;border-radius:50%;background:#fff;display:flex;align-items:center;justify-content:center;">${icon(p.role, 12, c)}</span>`
        + `<span style="display:flex;align-items:baseline;gap:1px;line-height:1;font-family:Poppins,Inter,system-ui,sans-serif;">`
        + `<span style="font-size:12.5px;font-weight:700;color:#fff;letter-spacing:-.01em;">${esc(p.amount)}</span>`
        + (p.unit ? `<span style="font-size:9.5px;font-weight:500;color:rgba(255,255,255,.88);">${esc(p.unit)}</span>` : "")
        + `</span></span>`;
    })
    .join("");
  return `<span data-price-bubble-2610="" style="position:absolute;left:50%;bottom:${bottom}px;transform:translateX(-50%);display:flex;flex-direction:column;align-items:center;filter:drop-shadow(0 0 .6px rgba(0,0,0,.4)) drop-shadow(0 2px 2px rgba(0,0,0,.22));cursor:pointer;">`
    + `<span data-bubble-2610="" style="display:flex;gap:2px;padding:2px;border-radius:999px;background:#fff;box-shadow:0 0 0 .5px rgba(0,0,0,.08);">${segs}</span>`
    + `<span data-tail-2610="" style="display:block;width:0;height:0;border-left:6px solid transparent;border-right:6px solid transparent;border-top:7px solid #fff;margin-top:-1px;"></span></span>`;
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
 * Groupe (README §3) : rond 48, fond blanc (sombre #262123), contour blanc 2,5, anneau 7
 * segmenté proportionnellement aux rôles (écart 5°), nombre 15,5 extra-gras. « dès X » masqué,
 * montré seulement quand le groupe est touché (`fromLabel`).
 */
export function clusterHtml2610(o: { counts: Partial<Record<Role2610, number>>; total: number; dark?: boolean; fromLabel?: { from: string; amount: string; role: Role2610 } | null }): string {
  const S = 48;
  const C = S / 2;
  const order: Role2610[] = ["walker", "owner", "sitter"];
  const parts = order.map((r) => [r, Math.max(0, o.counts[r] || 0)] as const).filter(([, v]) => v > 0);
  const tot = parts.reduce((s, [, v]) => s + v, 0);
  let acc = 0;
  let svg = "";
  if (parts.length === 1) {
    svg = `<circle cx="${C}" cy="${C}" r="${C - 5}" stroke="${ROLE_2610[parts[0][0]].color}" stroke-width="7" fill="none"/>`;
  } else {
    for (const [r, v] of parts) {
      const a0 = (acc / tot) * 360 + 5;
      acc += v;
      const a1 = (acc / tot) * 360;
      svg += `<path d="${arc2610(C, C, C - 5, a0, a1)}" stroke="${ROLE_2610[r].color}" stroke-width="7" fill="none"/>`;
    }
  }
  const label = o.total > 99 ? "99+" : String(o.total);
  const bg = o.dark ? "#262123" : "#fff";
  const ink = o.dark ? "#f6efec" : "#1d1719";
  const muted = o.dark ? "#a99c9e" : "#7a6f71";
  const from = o.fromLabel
    ? `<span data-cluster-from-2610="" style="position:absolute;left:50%;top:${C + 27}px;transform:translateX(-50%);display:flex;align-items:center;gap:3px;height:22px;padding:0 10px;border-radius:999px;background:${bg};box-shadow:0 4px 10px -4px rgba(0,0,0,.3),inset 0 0 0 1.5px ${ROLE_2610[o.fromLabel.role].color}55;white-space:nowrap;font-family:Poppins,Inter,system-ui,sans-serif;">`
      + (o.fromLabel.from ? `<span style="font-size:10px;font-weight:600;color:${muted};">${esc(o.fromLabel.from)}</span>` : "")
      + `<span style="font-size:12px;font-weight:800;color:${ROLE_2610[o.fromLabel.role].color};">${esc(o.fromLabel.amount)}</span></span>`
    : "";
  return `<div data-cluster-2610="" ${o.fromLabel ? 'data-cluster-open-2610=""' : ""} style="position:relative;width:${S}px;height:${S}px;">`
    + `<div style="position:absolute;inset:0;border-radius:50%;background:${bg};box-shadow:0 0 0 2.5px #fff,0 0 0 3.5px rgba(0,0,0,.18),0 3px 3px rgba(0,0,0,.25);">`
    + `<svg viewBox="0 0 ${S} ${S}" width="${S}" height="${S}" aria-hidden="true" style="position:absolute;inset:0;z-index:0;display:block;">${svg}</svg>`
    + `<span style="position:absolute;z-index:1;inset:0;display:flex;align-items:center;justify-content:center;font:800 15.5px/1 Poppins,Inter,system-ui,sans-serif;letter-spacing:-.04em;color:${ink};">${label}</span>`
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

/** Images clés (rebond de la sélection, point « en direct » pulsé) — mêmes courbes que la maquette. */
export const PAWMAP_2610_CSS = `
@keyframes hps2610-boost { 0%,100% { box-shadow:0 0 0 1.5px rgba(6,182,212,.75),0 0 6px 2px rgba(6,182,212,.35); } 50% { box-shadow:0 0 0 2px rgba(6,182,212,.85),0 0 10px 4px rgba(6,182,212,.5); } }
@keyframes hps2610-pop { 0% { transform:scale(1); } 100% { transform:scale(1.18); } }
@keyframes hps2610-pulse { 0% { box-shadow:0 0 0 1.5px #fff,0 0 0 0 rgba(232,69,47,.55); } 70% { box-shadow:0 0 0 1.5px #fff,0 0 0 7px rgba(232,69,47,0); } 100% { box-shadow:0 0 0 1.5px #fff,0 0 0 0 rgba(232,69,47,0); } }
.hps2610-dim { opacity:.85; }
.hps2610-btn { transition: transform .15s; }
.hps2610-btn:hover > span { transform: translateY(-1px); }
.hps2610-btn:active > span { transform: scale(.94); }
@media (prefers-reduced-motion: reduce) { [data-pin-2610] { animation:none !important; } [data-live-2610] { animation:none !important; } [data-boost-2610] { animation:none !important; } }
`;
