// 24/09/2026 — LOT B (site) : LA LÉGENDE DE LA NOUVELLE PAWMAP, source unique
// pour la carte connectée (/map) et la carte sans compte (/pawmap et accueil).
// Norme : ~/hopetsit-social/LEGENDE_PAWMAP.md (validée par Daniel le 23/09).
//
// Règle : une FORME par famille, la couleur ne fait que préciser.
//   rond = personne (icône du rôle) · goutte = lieu · carré = groupe de lieux
//   noir et or = PawSpot · rose = ami · couronne or = Paw Premium
//   PawBoost = lueur TURQUOISE qui respire + fusée (jamais l'or).
//
// Ce module ne dépend pas de Leaflet : il produit du HTML (chaînes) que les
// composants carte enveloppent dans un L.divIcon. Il est aussi utilisé par la
// fenêtre « ? » (légende en images) — les mêmes dessins, pas des copies.

export const ROLE_COLOR = {
  owner: "#C92A12",
  sitter: "#2563EB",
  walker: "#16A34A",
} as const;
export type RoleKey = keyof typeof ROLE_COLOR;

export const PAWFOLLOW_VIOLET = "#7C3AED";
export const PAWBOOST_TURQUOISE = "#06B6D4";
export const PREMIUM_GOLD = "#F4C04A";
export const INK = "#17141F";
export const FRIEND_PINK = "#F06AA0";
export const REPORT_RED = "#D32F2F";

export function roleKey(role: string | undefined | null): RoleKey {
  const r = (role || "").toLowerCase();
  if (r === "sitter") return "sitter";
  if (r === "walker") return "walker";
  return "owner";
}

// ── 26/09/2026 (PawMap 590, handoff « boutons et profil PawMap ») ───────────
// Mêmes valeurs que l'app (frontend/lib/views/map/widgets/pawmap_pins.dart,
// pawmap_jewel.dart, pawmap_discreet.dart).

/** Anneau des photos : dégradé clair → foncé de la couleur du rôle (§4). */
export const RING_GRAD: Record<RoleKey | "friend", [string, string]> = {
  sitter: ["#4A86F0", "#2458C9"],
  walker: ["#43B862", "#1F7A37"],
  owner: ["#FFA94D", "#D63D1F"],
  friend: ["#F47BB2", "#D6377F"],
};
export function ringGradient(k: RoleKey | "friend"): string {
  const [a, b] = RING_GRAD[k];
  return `linear-gradient(170deg,${a},${b})`;
}
/** Couleur « solide » du rôle (§9) : tracé de balade, libellés, chevrons. */
export const ROLE_SOLID: Record<RoleKey, string> = { owner: "#D8352A", sitter: "#2F6FE0", walker: "#2A9A48" };

/**
 * Règle des prix (§1) : chacun ne voit que les prix de L'AUTRE côté du
 * marché. Propriétaire (ou visiteur) → tarifs des gardiens / promeneurs ;
 * gardien / promeneur → budgets des demandes des propriétaires. Même règle
 * que `pawMapShowsPriceBubble` de l'app.
 */
export function showsPriceBubble(viewerRole: string | null | undefined, targetRole: string | null | undefined): boolean {
  const v = (viewerRole || "").toLowerCase();
  const t = (targetRole || "").toLowerCase();
  const viewerProvider = v === "sitter" || v === "walker";
  if (t === "owner") return viewerProvider;
  if (t === "sitter" || t === "walker") return !viewerProvider;
  return false;
}

// Icônes Material (maison, marcheur) en SVG : dessinées dans les épingles
// sans attendre la police d'icônes.
const MS_HOME = '<path d="M10 19v-5h4v5c0 .55.45 1 1 1h3c.55 0 1-.45 1-1v-7h1.7c.46 0 .68-.57.33-.87L12.67 3.6c-.38-.34-.96-.34-1.34 0l-8.36 7.53c-.34.3-.13.87.33.87H5v7c0 .55.45 1 1 1h3c.55 0 1-.45 1-1z"/>';
const MS_WALK = '<path d="M13.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zM9.8 8.9 7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3C14.8 12 16.8 13 19 13v-2c-1.9 0-3.5-1-4.3-2.4l-1-1.6c-.4-.6-1-1-1.7-1-.3 0-.5.1-.8.1L6 8.3V13h2V9.6l1.8-.7"/>';
export const POPPINS = "Poppins,Inter,system-ui,sans-serif";

/**
 * Bulle de prix (§1) posée AU-DESSUS d'un rond de `discSize` px : couleur du
 * service (gardien bleu + maison, promeneur vert + marcheur, demande orange +
 * maison), 22 px de haut, contour blanc 2 px, pointe 10 × 6 foncée.
 */
export function priceBubbleHtml(text: string, service: string, discSize: number): string {
  const k = roleKey(service);
  const [a, b] = RING_GRAD[k];
  const icon = k === "walker" ? MS_WALK : MS_HOME;
  return `<span style="position:absolute;bottom:${discSize + 3}px;left:50%;transform:translateX(-50%);display:flex;flex-direction:column;align-items:center;">`
    + `<span style="height:22px;padding:0 8px;border-radius:8px;background:linear-gradient(170deg,${a},${b});color:#fff;display:inline-flex;align-items:center;gap:4px;font:700 11.5px/1 ${POPPINS};white-space:nowrap;box-shadow:0 0 0 2px #fff,0 5px 10px -4px rgba(23,20,31,.45);">`
    + `<svg viewBox="0 0 24 24" width="11" height="11" fill="#fff" aria-hidden="true">${icon}</svg>${escapeHtml(text)}</span>`
    + `<svg viewBox="0 0 10 6" width="10" height="6" style="display:block;margin-top:1px;" aria-hidden="true"><path d="M0 0h10L5 6z" fill="${b}"/></svg></span>`;
}

/** Étiquette du prénom sous un rond (§4) : 20 px, fond blanc (sombre : encre chaude). */
function nameTagHtml(text: string, top: number, dark?: boolean): string {
  return `<span style="position:absolute;top:${top}px;left:50%;transform:translateX(-50%);height:20px;display:inline-flex;align-items:center;padding:0 8px;border-radius:10px;white-space:nowrap;max-width:160px;overflow:hidden;background:${dark ? "rgba(32,29,35,.95)" : "#fff"};color:${dark ? "#F6F1EE" : "#1B1616"};font:600 10.5px/1 ${POPPINS};box-shadow:0 2px 6px -1px rgba(23,20,31,.35);">${escapeHtml(text)}</span>`;
}

/** Coche bleue « identité vérifiée » (15 px, en bas à gauche). */
function verifiedBadge(): string {
  return `<span style="position:absolute;bottom:-1px;left:-2px;width:15px;height:15px;border-radius:50%;background:#2F6FE0;border:1.5px solid #fff;display:flex;align-items:center;justify-content:center;box-sizing:border-box;"><svg viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="#fff" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></span>`;
}

// ── Icônes blanches des rôles (mêmes sens que l'accueil de l'app) ──────────
// propriétaire = patte · gardien = maison · promeneur = personnage qui marche.
// Trait/formes sur grille 24, remplies en blanc (lisibles à 34 px).
export const ROLE_GLYPH: Record<RoleKey, string> = {
  owner:
    '<svg viewBox="0 0 24 24" fill="#fff" aria-hidden="true"><ellipse cx="12" cy="15.6" rx="4.6" ry="3.7"/><ellipse cx="5.3" cy="10.9" rx="2" ry="2.6"/><ellipse cx="9.4" cy="7.4" rx="2" ry="2.7"/><ellipse cx="14.6" cy="7.4" rx="2" ry="2.7"/><ellipse cx="18.7" cy="10.9" rx="2" ry="2.6"/></svg>',
  sitter:
    '<svg viewBox="0 0 24 24" fill="#fff" aria-hidden="true"><path d="M12 3.2 3 10.6V20a1.4 1.4 0 0 0 1.4 1.4h5V15h5.2v6.4h5A1.4 1.4 0 0 0 21 20v-9.4z"/></svg>',
  walker:
    '<svg viewBox="0 0 24 24" fill="#fff" aria-hidden="true"><circle cx="13.2" cy="4.3" r="2.2"/><path d="M9.6 21.5l1.6-6.6 2.1 2v4.6h2.2v-6.1l-2.3-2.2.7-3.3c1.1 1.4 2.7 2.3 4.6 2.3V10c-1.6 0-2.9-.8-3.6-2.1l-1-1.6c-.4-.6-1-1-1.7-1-.3 0-.6.1-.8.2L7 7.6v4.6h2.2V9l1.7-.7-1.6 8.1-3.9-.8-.4 2.1z"/></svg>',
};

// Lieux (POI OpenStreetMap + HoPetSit) : une couleur PAR TYPE, jamais une
// couleur réservée de la carte (rôles, PawFollow, PawBoost, or, rose). Eau,
// parc et plage prennent un bleu-vert PLUS SOMBRE et plein (légende).
export const PLACE_COLOR: Record<string, string> = {
  vet: "#B42318",
  shop: "#A16207",
  groomer: "#DB2777",
  park: "#0F766E",
  beach: "#0E7490",
  water: "#155E75",
  trainer: "#4D7C0F",
  hotel: "#3730A3",
  restaurant: "#C2410C",
  other: "#6E4F48",
};

// Icône blanche par type de lieu (trait 2, grille 24).
export const PLACE_GLYPH: Record<string, string> = {
  vet: '<path d="M10 3h4v7h7v4h-7v7h-4v-7H3v-4h7z"/>',
  shop: '<path d="M4 7h16l-1 13H5zM8 7V5a4 4 0 0 1 8 0v2h-2V5a2 2 0 0 0-4 0v2z"/>',
  groomer:
    '<path d="M8.5 3a3.5 3.5 0 1 1-2.4 6l3.6 3.6 3.6-3.6a3.5 3.5 0 1 1 1.4 1.4L11.4 14l4.8 4.8-1.4 1.4-4.8-4.8-4.8 4.8-1.4-1.4L8.6 14 4.9 10.3A3.5 3.5 0 0 1 8.5 3z"/>',
  park: '<path d="M12 2 5.5 11h3L4 17h6.5v5h3v-5H20l-4.5-6h3z"/>',
  beach:
    '<path d="M3 17c2 0 2 1.5 4 1.5s2-1.5 4-1.5 2 1.5 4 1.5 2-1.5 4-1.5 2 1.5 4 1.5v2c-2 0-2-1.5-4-1.5s-2 1.5-4 1.5-2-1.5-4-1.5-2 1.5-4 1.5-2-1.5-4-1.5zM12 3a6 6 0 0 1 6 6h-2l-3-3v9h-2V6L8 9H6a6 6 0 0 1 6-6z"/>',
  water:
    '<path d="M12 2.5c3.5 4.5 6 7.9 6 11.3A6 6 0 0 1 6 13.8c0-3.4 2.5-6.8 6-11.3z"/>',
  trainer:
    '<path d="M4 6h3v12H4zm13 0h3v12h-3zM8 10h8v4H8zm-6 1h2v2H2zm18 0h2v2h-2z"/>',
  hotel:
    '<path d="M3 5h2v10h6V9h8a2 2 0 0 1 2 2v9h-2v-3H5v3H3zM7 9a2 2 0 1 1 0 4 2 2 0 0 1 0-4z"/>',
  restaurant:
    '<path d="M7 2h2v6a2 2 0 0 0 2-2V2h2v4a4 4 0 0 1-3 3.9V22H8V9.9A4 4 0 0 1 5 6V2h2zm10 0c1.7 0 3 2.2 3 5s-1.3 5-3 5v10h-2V2z"/>',
  other: '<circle cx="12" cy="12" r="4"/>',
};

// Types de PawSpot : liseré à la couleur du type sur la goutte noire.
export const SPOT_COLOR: Record<string, string> = {
  path_walk: "#0F766E",
  chill: "#3730A3",
  playground: "#B42318",
  swimming: "#0E7490",
  food_cafe: "#A16207",
  other: "#DB2777",
};

const SPOT_GLYPH: Record<string, string> = {
  path_walk: PLACE_GLYPH.park,
  chill: '<path d="M4 12h16v2H4zm2 3h12l-1 5H7zM8 4h8l1 7H7z"/>',
  playground: '<circle cx="12" cy="12" r="6"/>',
  swimming: PLACE_GLYPH.water,
  food_cafe: '<path d="M4 6h12v6a5 5 0 0 1-10 0V6h-2zm12 2h2a2 2 0 0 1 0 4h-2zM3 19h16v2H3z"/>',
  other: '<circle cx="12" cy="12" r="4"/>',
};

// ── Floutage ~1 km : PORT EXACT de backend/src/utils/coarseLocation.js ──────
// Pour la carte sans compte : les routes publiques renvoient la position du
// prestataire ; on l'arrondit AVANT tout affichage, avec la même grille et le
// même décalage déterministe que le serveur (erreur max ≈ 0,7 km).
export const WORLD_APPROX_KM = 1;
const KM_PER_DEG_LAT = 111.32;
function jitterKm(idStr: string): [number, number] {
  let h = 0;
  for (let i = 0; i < idStr.length; i += 1) h = (h * 31 + idStr.charCodeAt(i)) | 0;
  const a = ((h & 0xffff) / 0xffff - 0.5) * 0.4;
  const b = (((h >> 16) & 0xffff) / 0xffff - 0.5) * 0.4;
  return [a, b];
}
/** Renvoie [lat, lng] flouté (grille ~1 km + décalage stable ±0,2 km). */
export function blurLatLng(lat: number, lng: number, idStr: string): [number, number] {
  const cosLat = Math.max(0.05, Math.cos((lat * Math.PI) / 180));
  const stepLat = WORLD_APPROX_KM / KM_PER_DEG_LAT;
  const stepLng = WORLD_APPROX_KM / (KM_PER_DEG_LAT * cosLat);
  const [kLng, kLat] = jitterKm(String(idStr || ""));
  const outLat = Math.round(lat / stepLat) * stepLat + kLat / KM_PER_DEG_LAT;
  const outLng = Math.round(lng / stepLng) * stepLng + kLng / (KM_PER_DEG_LAT * cosLat);
  return [Math.round(outLat * 1e5) / 1e5, Math.round(outLng * 1e5) / 1e5];
}

// ── Petits morceaux réutilisés ───────────────────────────────────────────────
/** Couronne Paw Premium : or, contour noir, en haut à droite du rond. */
export function crownBadge(size: number): string {
  const r = Math.round(size / 2);
  return `<span style="position:absolute;top:-${Math.round(size * 0.35)}px;right:-${Math.round(size * 0.3)}px;width:${size}px;height:${size}px;border-radius:50%;background:${PREMIUM_GOLD};border:1.5px solid ${INK};display:flex;align-items:center;justify-content:center;box-shadow:0 1px 3px rgba(23,20,31,.35);"><svg viewBox="0 0 24 24" width="${r + 2}" height="${r + 2}" fill="${INK}" aria-hidden="true"><path d="M3 8l4.5 4L12 5l4.5 7L21 8l-1.6 10H4.6z"/></svg></span>`;
}
/** Fusée PawBoost : blanche sur pastille turquoise, en bas à gauche. */
export function rocketBadge(size: number): string {
  return `<span style="position:absolute;bottom:-${Math.round(size * 0.25)}px;left:-${Math.round(size * 0.3)}px;width:${size}px;height:${size}px;border-radius:50%;background:${PAWBOOST_TURQUOISE};border:1.5px solid #fff;display:flex;align-items:center;justify-content:center;box-shadow:0 1px 3px rgba(23,20,31,.3);"><svg viewBox="0 0 24 24" width="${Math.round(size * 0.62)}" height="${Math.round(size * 0.62)}" fill="#fff" aria-hidden="true"><path d="M14.5 2.5c3.3 0 6.4 1.6 7 4-3.2 6.4-6.7 9.6-9.7 11.2l-3.5-3.5C10 11.2 11.3 6 14.5 2.5zM8 14.7 4.4 13c1-2.2 2.4-3.9 4.1-5.1zM9.3 16 11 19.6c2.2-1 3.9-2.4 5.1-4.1zM4 20c1.1-2.6 2.2-3.5 3.6-3.6.2 1.4-.9 2.5-3.6 3.6zM15 7a1.6 1.6 0 1 0 0 3.2A1.6 1.6 0 0 0 15 7z"/></svg></span>`;
}
/** Point vert « en ligne / en direct » en bas à droite. */
export function onlineDot(size: number, online: boolean): string {
  return `<span style="position:absolute;bottom:0;right:0;width:${size}px;height:${size}px;border-radius:50%;border:2px solid #fff;background:${online ? "#16A34A" : "#C2410C"};box-shadow:0 1px 3px rgba(23,20,31,.3);"></span>`;
}
/** Œil barré noir (mode « amis seulement »), en bas à gauche de MON rond. */
function eyeOffBadge(size: number): string {
  return `<span style="position:absolute;bottom:-${Math.round(size * 0.2)}px;left:-${Math.round(size * 0.3)}px;width:${size}px;height:${size}px;border-radius:50%;background:${INK};border:1.5px solid #fff;display:flex;align-items:center;justify-content:center;"><svg viewBox="0 0 24 24" width="${Math.round(size * 0.65)}" height="${Math.round(size * 0.65)}" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M3 3l18 18M10.6 5.3A10.5 10.5 0 0 1 12 5.2c5 0 8.6 4.2 9.6 6.8-.4 1-1.2 2.3-2.4 3.5M6.6 6.6C4.3 8.1 2.9 10.4 2.4 12c1 2.6 4.6 6.8 9.6 6.8 1.7 0 3.2-.4 4.5-1.1M9.9 9.9a3 3 0 0 0 4.2 4.2"/></svg></span>`;
}

export function boostGlowStyle(active: boolean): string {
  // Une seule chose animée sur la carte : la lueur turquoise du boost respire.
  // `hps-breathe` est déclaré par les composants carte (balise <style>), et
  // s'éteint avec « réduire les animations » (halo fixe).
  return active
    ? `box-shadow:0 0 0 4px rgba(6,182,212,.45),0 0 18px 6px rgba(6,182,212,.75),0 2px 6px rgba(23,20,31,.35);animation:hps-breathe 1.6s ease-in-out infinite;`
    : "";
}

// ── Les formes ───────────────────────────────────────────────────────────────
export type MemberPinOptions = {
  role: string;
  premium?: boolean;
  boosted?: boolean;
  /** halo PawFollow (suivi en direct) — PawBoost passe devant. */
  pawFollow?: boolean;
  online?: boolean | null;
  /** Prix « dès » affiché sous le rond au zoom rue. */
  priceLabel?: string | null;
  /** Zoom rue : « Prénom · rôle · prix » (remplace priceLabel s'il est donné). */
  caption?: string | null;
  /** Photo du membre (sinon l'icône du rôle). */
  avatar?: string | null;
  size?: number;
  /** 25/09 (PawMap 585) — TOUS les rôles de la personne, celui du point
   *  d'abord : 2 ou 3 rôles = double (triple) liseré aux couleurs des rôles. */
  roles?: string[] | null;
  /** 590 — bulle de prix au-dessus du rond (règle §1 appliquée par l'appelant). */
  priceBubble?: string | null;
  /** 590 — étiquette sous le rond sur fond sombre (mode nuit). */
  dark?: boolean;
  /** 590 — coche bleue « identité vérifiée ». */
  verified?: boolean;
};

/**
 * Liserés supplémentaires d'une personne à plusieurs rôles : un anneau
 * blanc fin puis un anneau plein à la couleur de chaque rôle suivant
 * (propriétaire orange foncé, gardien bleu, promeneur vert). Rien pour un
 * seul rôle. Couleurs PLEINES (jamais d'opacité : zéro gris).
 */
export function extraRoleRings(roles: string[] | null | undefined, all = false): string {
  const keys = [...new Set((roles || []).map(roleKey))];
  if (keys.length < 2) return "";
  const parts: string[] = [];
  let r = 0;
  for (const k of all ? keys : keys.slice(1)) {
    parts.push(`0 0 0 ${r + 2}px #fff`, `0 0 0 ${r + 5}px ${ROLE_COLOR[k]}`);
    r += 5;
  }
  return parts.join(",");
}

/**
 * Autre membre : LE plus visible de la carte (25/09, PawMap 584 — même règle
 * que l'app). Rond 46 px avec SA PHOTO quand elle existe (anneau 3 px à la
 * couleur du rôle + liseré blanc), sinon la couleur du rôle et son icône
 * blanche. Au zoom rue, « Prénom · rôle · prix » sous le rond.
 */
export function memberPinHtml(o: MemberPinOptions): string {
  const key = roleKey(o.role);
  const size = o.size ?? 46;
  const grad = ringGradient(key);
  const glow = o.boosted
    ? boostGlowStyle(true)
    : o.pawFollow
      ? `box-shadow:0 0 0 4px rgba(124,58,237,.35),0 0 14px 4px rgba(124,58,237,.55),0 3px 8px rgba(23,20,31,.35);`
      : `box-shadow:0 5px 12px -4px rgba(23,20,31,.5);`;
  // 590 — sous le rond : le PRÉNOM seul (le prix part dans la bulle au-dessus).
  const captionText = o.caption || (o.priceBubble ? "" : o.priceLabel || "");
  const caption = captionText ? nameTagHtml(captionText, size + 4, o.dark) : "";
  const bubble = o.priceBubble ? priceBubbleHtml(o.priceBubble, key, size) : "";
  // L'icône du rôle reste DESSOUS la photo : si la photo tarde ou échoue,
  // on voit l'icône, jamais un disque vide.
  const glyphBox = `<span style="position:absolute;inset:${Math.round(size * 0.18)}px;display:block;">${ROLE_GLYPH[key]}</span>`;
  // 590 (§4) — photo : anneau 3 px en DÉGRADÉ du rôle, liseré blanc 2 px,
  // puis la photo ; sans photo : disque en dégradé du rôle + icône blanche.
  const body = o.avatar
    ? `<div style="position:relative;width:100%;height:100%;border-radius:50%;border:2px solid #fff;background:${grad};overflow:hidden;box-sizing:border-box;">${glyphBox}<img src="${escapeHtml(o.avatar)}" alt="" style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;display:block;" onerror="this.style.display='none'" /></div>`
    : ROLE_GLYPH[key];
  const disc = o.avatar
    ? `padding:3px;`
    : `padding:${Math.round(size * 0.2)}px;border:2.5px solid #fff;`;
  // Plusieurs rôles : liserés concentriques aux couleurs des autres rôles,
  // posés sur un calque à part (la lueur PawBoost anime box-shadow).
  const rings = extraRoleRings(o.roles);
  const ringLayer = rings ? `<div style="position:absolute;inset:0;border-radius:50%;box-shadow:${rings};pointer-events:none;"></div>` : "";
  return `<div style="position:relative;width:${size}px;height:${size}px;">${ringLayer}<div style="width:${size}px;height:${size}px;border-radius:50%;background:${grad};${disc}${glow}display:flex;align-items:center;justify-content:center;box-sizing:border-box;position:relative;overflow:hidden;">${body}</div>${o.premium ? crownBadge(20) : ""}${o.boosted ? rocketBadge(18) : o.verified ? verifiedBadge() : ""}${o.online === true || o.online === false ? onlineDot(12, o.online) : ""}${caption}${bubble}</div>`;
}

/** Échappe une chaîne insérée dans le HTML d'une épingle (nom, URL). */
export function escapeHtml(v: string): string {
  return String(v).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c] as string);
}

export type PhotoPinOptions = {
  role: string;
  name: string;
  avatar?: string | null;
  premium?: boolean;
  boosted?: boolean;
  pawFollow?: boolean;
  online?: boolean | null;
  /** « Moi » : anneau du rôle, 56 px, étiquette. */
  me?: boolean;
  meLabel?: string;
  /** Mode « amis seulement » (moi seulement) : anneau pointillé + œil barré. */
  friendsOnly?: boolean;
  /** 25/09 — ami SUIVI en direct : auréole violette PawFollow qui respire. */
  followed?: boolean;
  /** 25/09 — partage actif mais 2-10 min sans signal : « signal perdu ». */
  lost?: boolean;
  /** Petite étiquette sous le rond (« signal perdu », « Prénom »). */
  caption?: string | null;
  /** 25/09 (585) — ami à plusieurs rôles : liserés des rôles autour du rose. */
  roles?: string[] | null;
  /** 590 — bulle de prix au-dessus du rond (règle §1 appliquée par l'appelant). */
  priceBubble?: string | null;
  /** 590 — étiquette sur fond sombre (mode nuit). */
  dark?: boolean;
};

function initials(name: string): string {
  return (name || "?")
    .split(/\s+/)
    .map((w) => w[0] || "")
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

/** Ami (44, anneau rose) ou Moi (56, anneau du rôle + « Moi »). */
export function photoPinHtml(o: PhotoPinOptions): string {
  const key = roleKey(o.role);
  const color = ROLE_COLOR[key];
  const size = o.me ? 56 : 50;
  const ring = o.me ? color : FRIEND_PINK;
  const ringStyle = o.friendsOnly ? "dashed" : "solid";
  const glow = o.boosted
    ? boostGlowStyle(true)
    : o.followed
      ? `box-shadow:0 0 0 3px rgba(124,58,237,.45),0 0 10px 3px rgba(124,58,237,.5);animation:hps-follow 1.8s ease-in-out infinite;`
      : o.pawFollow
        ? `box-shadow:0 0 0 4px rgba(124,58,237,.35),0 0 16px 5px rgba(124,58,237,.55),0 3px 8px rgba(23,20,31,.35);`
        : `box-shadow:0 3px 8px rgba(23,20,31,.35);`;
  const inner = o.avatar
    ? `<img src="${escapeHtml(o.avatar)}" alt="" style="width:100%;height:100%;object-fit:cover;border-radius:50%;display:block;" />`
    : `<span style="color:#fff;font:700 ${o.me ? 18 : 16}px/1 Inter,system-ui,sans-serif;">${escapeHtml(initials(o.name))}</span>`;
  const label = o.me
    ? `<span style="position:absolute;top:${size + 3}px;left:50%;transform:translateX(-50%);background:${INK};color:#fff;border-radius:999px;padding:1px 8px;font:700 11px/1.3 Inter,system-ui,sans-serif;white-space:nowrap;">${escapeHtml(o.meLabel || "Moi")}</span>`
    : o.caption
      ? `<span style="position:absolute;top:${size + 3}px;left:50%;transform:translateX(-50%);background:${o.lost ? "#FFF4E5" : "#fff"};color:${o.lost ? "#9A3412" : color};border:1.5px solid ${o.lost ? "#EA580C" : FRIEND_PINK};border-radius:999px;padding:1px 8px;font:700 11px/1.3 Inter,system-ui,sans-serif;white-space:nowrap;box-shadow:0 1px 4px rgba(23,20,31,.25);">${escapeHtml(o.caption)}</span>`
      : "";
  const rings = o.me ? "" : extraRoleRings(o.roles, true); // ami : le rose d'abord, puis TOUS ses rôles
  const ringLayer = rings ? `<div style="position:absolute;inset:0;border-radius:50%;box-shadow:${rings};pointer-events:none;"></div>` : "";
  const bubble = o.priceBubble ? priceBubbleHtml(o.priceBubble, key, size) : "";
  // 590 (§4) — anneau 3 px en DÉGRADÉ (rose pour un ami, rôle pour moi),
  // liseré blanc 2 px, puis la photo. Mode « amis seulement » : anneau
  // pointillé plein, comme avant (il doit se lire d'un coup d'œil).
  const grad = ringGradient(o.me ? key : "friend");
  const disc = o.friendsOnly
    ? `<div style="width:${size}px;height:${size}px;border-radius:50%;background:${color};border:3px ${ringStyle} ${ring};${glow}display:flex;align-items:center;justify-content:center;overflow:hidden;box-sizing:border-box;">${inner}</div>`
    : `<div style="width:${size}px;height:${size}px;border-radius:50%;background:${grad};padding:3px;${glow}box-sizing:border-box;"><div style="width:100%;height:100%;border-radius:50%;border:2px solid #fff;background:${ringGradient(key)};display:flex;align-items:center;justify-content:center;overflow:hidden;box-sizing:border-box;">${inner}</div></div>`;
  return `<div style="position:relative;width:${size}px;height:${size}px;">${ringLayer}${disc}${o.premium ? crownBadge(o.me ? 24 : 22) : ""}${o.boosted ? rocketBadge(o.me ? 20 : 18) : ""}${o.friendsOnly && o.me ? eyeOffBadge(20) : ""}${!o.me && (o.online === true || o.online === false) ? onlineDot(13, o.online) : ""}${label}${bubble}</div>`;
}

/**
 * Groupe de MEMBRES (25/09, retour de Daniel : « les cadres des groupes et des
 * lieux sont identiques ») : un ROND — comme une personne — plein à la
 * couleur DOMINANTE du rôle, chiffre blanc gras, liseré blanc ; fin anneau
 * rose s'il contient un ami. Jamais un carré (le carré = groupe de lieux).
 */
export function memberClusterHtml(count: number, dominantRole?: string | null, hasFriend = false): string {
  const label = count > 99 ? "99+" : String(count);
  const key = roleKey(dominantRole || "sitter");
  const c = ROLE_COLOR[key];
  const dark = key === "sitter" ? "#1E4FB0" : key === "walker" ? "#15803D" : "#9E1F0B";
  const size = count >= 10 ? 44 : 40;
  const ring = hasFriend ? `box-shadow:0 0 0 2.5px ${FRIEND_PINK},0 3px 8px rgba(23,20,31,.35);` : `box-shadow:0 3px 8px rgba(23,20,31,.35);`;
  return `<div style="width:${size}px;height:${size}px;border-radius:50%;background:linear-gradient(160deg,${c},${dark});border:2.5px solid #fff;${ring}color:#fff;display:flex;align-items:center;justify-content:center;font:800 ${label.length > 2 ? 12 : 15}px/1 Inter,system-ui,sans-serif;box-sizing:border-box;">${label}</div>`;
}

/** Rôle le plus représenté d'un groupe (couleur du rond de groupe). */
export function dominantRole(roles: (string | undefined | null)[]): RoleKey {
  const n: Record<RoleKey, number> = { owner: 0, sitter: 0, walker: 0 };
  for (const r of roles) n[roleKey(r)] += 1;
  return (Object.keys(n) as RoleKey[]).sort((x, y) => n[y] - n[x])[0];
}

/** Lieu : GOUTTE entièrement à la couleur du type, icône blanche (30). */
export function placePinHtml(category: string, size = 30): string {
  const color = PLACE_COLOR[category] || PLACE_COLOR.other;
  const glyph = PLACE_GLYPH[category] || PLACE_GLYPH.other;
  const h = Math.round(size * 1.3);
  return `<div style="position:relative;width:${size}px;height:${h}px;filter:drop-shadow(0 2px 3px rgba(23,20,31,.35));"><svg viewBox="0 0 30 39" width="${size}" height="${h}" aria-hidden="true"><path d="M15 1C7.3 1 1.5 6.8 1.5 14.2c0 9.6 11.2 21.6 12.6 23.1.5.5 1.3.5 1.8 0 1.4-1.5 12.6-13.5 12.6-23.1C28.5 6.8 22.7 1 15 1z" fill="${color}" stroke="#fff" stroke-width="1.6"/><g transform="translate(6.5 5.5) scale(0.7)" fill="#fff">${glyph}</g></svg></div>`;
}

/** Groupe de lieux : CARRÉ arrondi blanc + nombre, bord/nombre du type dominant (36). */
export function placeClusterHtml(count: number, category?: string | null): string {
  const color = category ? PLACE_COLOR[category] || PLACE_COLOR.other : PLACE_COLOR.other;
  const label = count > 99 ? "99+" : String(count);
  // Carré BLANC, bord FIN : discret, jamais confondu avec un groupe de membres (rond plein).
  return `<div style="width:32px;height:32px;border-radius:8px;background:#fff;border:1.5px solid ${color};color:${color};display:flex;align-items:center;justify-content:center;font:800 ${label.length > 2 ? 10 : 12}px/1 Inter,system-ui,sans-serif;box-shadow:0 1px 4px rgba(23,20,31,.25);box-sizing:border-box;">${label}</div>`;
}

/**
 * PawSpot (590, §6 — « plus visibles ») : GOUTTE 40 px (coin bas pointu,
 * tournée de −45°), patte au centre, halo or autour.
 *   PawSpot : fond noir #3A3232 → #171212, patte or, contour or 2,5 px.
 *   PawSpot doré (validé) : fond or #FFE08A → #F0B323 → #C98A08, patte
 *   noire, contour blanc, éclat.
 * Taille constante à l'écran ; au zoom rue, étiquette noire liseré or.
 */
export function spotPinHtml(type: string, golden: boolean, opts: { size?: number; label?: string | null } = {}): string {
  void type;
  const size = opts.size ?? 40;
  const k = size / 40;
  const px = (n: number) => `${Math.round(n * k * 10) / 10}px`;
  const bg = golden ? "linear-gradient(170deg,#FFE08A,#F0B323 50%,#C98A08)" : "linear-gradient(170deg,#3A3232,#171212)";
  const rim = golden ? "#FFFFFF" : "#F0B323";
  const paw = golden ? "#171212" : "#F0B323";
  const halo = `0 0 0 ${px(7)} rgba(240,179,35,${golden ? 0.28 : 0.22}),0 ${px(6)} ${px(12)} -${px(4)} rgba(23,20,31,.55)`;
  const sparkle = golden
    ? `<svg viewBox="0 0 24 24" width="${px(15)}" height="${px(15)}" style="position:absolute;top:-${px(4)};right:-${px(5)};" aria-hidden="true"><path d="M12 1.5l2.2 7.3 7.3 2.2-7.3 2.2-2.2 7.3-2.2-7.3L2.5 11l7.3-2.2z" fill="#fff" stroke="#171212" stroke-width="1.2" stroke-linejoin="round"/></svg>`
    : "";
  const label = opts.label
    ? `<span style="position:absolute;top:${px(52)};left:50%;transform:translateX(-50%);max-width:150px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;background:#171212;border:1.5px solid #F0B323;color:#F5C542;border-radius:9px;padding:2px 7px;font:700 10px/1.25 ${POPPINS};">${escapeHtml(opts.label)}</span>`
    : "";
  return `<div style="position:relative;width:${px(40)};height:${px(50)};">`
    + `<div style="position:absolute;left:0;top:0;width:${px(40)};height:${px(40)};border-radius:50% 50% 50% 0;transform:rotate(-45deg);background:${bg};border:${px(2.5)} solid ${rim};box-shadow:${halo};box-sizing:border-box;"></div>`
    + `<svg viewBox="0 0 24 24" width="${px(20)}" height="${px(20)}" style="position:absolute;left:${px(10)};top:${px(10)};" fill="${paw}" aria-hidden="true">${ROLE_GLYPH_PATH_PAW}</svg>`
    + `${sparkle}${label}</div>`;
}
/** Point d'ancrage (pointe de la goutte) d'une épingle PawSpot de `size` px. */
export function spotPinAnchor(size = 40): [number, number] {
  return [size / 2, Math.round(size * 1.2)];
}
const ROLE_GLYPH_PATH_PAW =
  '<ellipse cx="12" cy="15.6" rx="4.6" ry="3.7"/><ellipse cx="5.3" cy="10.9" rx="2" ry="2.6"/><ellipse cx="9.4" cy="7.4" rx="2" ry="2.7"/><ellipse cx="14.6" cy="7.4" rx="2" ry="2.7"/><ellipse cx="18.7" cy="10.9" rx="2" ry="2.6"/>';

/** Groupe de PawSpots : carré NOIR, nombre en OR (36). */
export function spotClusterHtml(count: number): string {
  const label = count > 99 ? "99+" : String(count);
  return `<div style="width:36px;height:36px;border-radius:10px;background:${INK};border:2px solid ${PREMIUM_GOLD};color:${PREMIUM_GOLD};display:flex;align-items:center;justify-content:center;font:800 ${label.length > 2 ? 11 : 13}px/1 Inter,system-ui,sans-serif;box-shadow:0 2px 6px rgba(23,20,31,.4);">${label}</div>`;
}

/** Signalement : triangle rouge (inchangé), « ! » blanc. */
export function reportPinHtml(size = 30): string {
  return `<div style="width:${size}px;height:${size}px;filter:drop-shadow(0 2px 3px rgba(23,20,31,.35));"><svg viewBox="0 0 24 24" width="${size}" height="${size}" aria-hidden="true"><path d="M12 2.5 22.8 21H1.2z" fill="${REPORT_RED}" stroke="#fff" stroke-width="1.5" stroke-linejoin="round"/><path d="M10.9 9h2.2v6h-2.2zM10.9 16.5h2.2v2.2h-2.2z" fill="#fff"/></svg></div>`;
}

/**
 * Demande d'un propriétaire (590, §1) : BULLE en dégradé orange du service
 * (#FFA94D → #D63D1F), contour blanc, pointe foncée, icône maison (garde) ou
 * marcheur (promenade) + budget. Le propriétaire ne voit que les siennes,
 * sans budget, avec « Ma demande ».
 */
export function requestBubbleHtml(o: { priceLabel?: string | null; service: "sitting" | "walk"; boosted?: boolean; mine?: boolean; mineLabel?: string }): string {
  const [a, b] = RING_GRAD.owner;
  const icon = `<svg viewBox="0 0 24 24" width="14" height="14" fill="#fff" aria-hidden="true">${o.service === "walk" ? MS_WALK : MS_HOME}</svg>`;
  const glow = o.boosted ? boostGlowStyle(true) : "box-shadow:0 0 0 2px #fff,0 6px 12px -4px rgba(23,20,31,.5);";
  const mine = o.mine ? `<span style="position:absolute;top:-17px;left:50%;transform:translateX(-50%);background:${INK};color:#fff;border-radius:999px;padding:0 7px;font:700 10px/1.6 ${POPPINS};white-space:nowrap;">${escapeHtml(o.mineLabel || "Ma demande")}</span>` : "";
  return `<div style="position:relative;width:100%;display:flex;flex-direction:column;align-items:center;">${mine}<div style="position:relative;height:26px;background:linear-gradient(170deg,${a},${b});color:#fff;border-radius:9px;padding:0 ${o.priceLabel ? 9 : 7}px;display:inline-flex;align-items:center;gap:4px;font:700 12px/1 ${POPPINS};white-space:nowrap;${glow}">${icon}${o.priceLabel ? `<span>${escapeHtml(o.priceLabel)}</span>` : ""}</div><svg viewBox="0 0 12 7" width="12" height="7" style="display:block;margin-top:1px;" aria-hidden="true"><path d="M0 0h12L6 7z" fill="${b}"/></svg>${o.boosted ? rocketBadge(16) : ""}</div>`;
}

/**
 * Ordre d'empilement (25/09, PawMap 584) : les PERSONNES passent toujours
 * au-dessus des lieux. Leaflet empile par `y écran + zIndexOffset` : des
 * écarts de 1 000 dominent la hauteur de la carte.
 */
export const PIN_Z = {
  place: 0,
  placeSelected: 1500,
  report: 1000,
  request: 2000,
  // 590 (§6) — les PawSpots passent au-dessus des lieux, signalements et
  // demandes (les personnes restent devant, comme dans l'app).
  spot: 4000,
  spotGolden: 4500,
  member: 5000,
  memberBoosted: 6000,
  friend: 7000,
  friendFollowed: 8000,
  me: 9000,
} as const;

/** Feuille de style partagée par les cartes (lueur PawBoost qui respire). */
export const PAWMAP_KEYFRAMES = `
@keyframes hps-breathe { 0%,100% { box-shadow:0 0 0 3px rgba(6,182,212,.35),0 0 12px 4px rgba(6,182,212,.55),0 2px 6px rgba(23,20,31,.35); } 50% { box-shadow:0 0 0 6px rgba(6,182,212,.5),0 0 26px 10px rgba(6,182,212,.8),0 2px 6px rgba(23,20,31,.35); } }
@keyframes hps-follow { 0%,100% { box-shadow:0 0 0 3px rgba(124,58,237,.45),0 0 10px 3px rgba(124,58,237,.5); } 50% { box-shadow:0 0 0 7px rgba(124,58,237,.28),0 0 26px 10px rgba(124,58,237,.7); } }
@keyframes hps-pulse { 0% { transform:scale(1); opacity:.65; } 70% { transform:scale(2.1); opacity:0; } 100% { transform:scale(2.1); opacity:0; } }
@media (prefers-reduced-motion: reduce) { .leaflet-marker-icon * { animation: none !important; } }
.leaflet-container { font-family: Inter, system-ui, sans-serif; }
@keyframes hps-walk { to { stroke-dashoffset: -40; } }
.hps-walk-trail { animation: hps-walk 1.6s linear infinite; }
@keyframes hps-focus-in { from { opacity: 0; transform: translateY(-8px) scale(.97); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { .hps-walk-trail { animation: none; } }
.hps-dark-tiles { filter: invert(1) hue-rotate(180deg) brightness(0.95) contrast(0.9) saturate(0.75) sepia(0.18); }
.leaflet-popup-content-wrapper { border-radius: 16px; box-shadow: 0 10px 30px -10px rgba(23,20,31,.35); }
.leaflet-popup-content { margin: 12px 14px; }
.leaflet-popup-content a[class*="text-white"] { color: #fff !important; }
`;

export function formatPrice(amount?: number | null, currency?: string | null): string | null {
  if (!amount || amount <= 0) return null;
  const sym: Record<string, string> = { EUR: "€", USD: "$", GBP: "£", CHF: "CHF", KRW: "₩", JPY: "¥", PLN: "zł" };
  const s = sym[(currency || "EUR").toUpperCase()] ?? "€";
  const n = Math.round(amount);
  return s === "$" || s === "£" ? `${s}${n}` : `${n} ${s}`;
}
