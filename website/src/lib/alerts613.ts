// 07/10/2026 — LEO (613) : épingles d'ALERTE (signalements) du site = celles de l'app 613.
// Source : frontend/lib/views/map/widgets/pawmap_alerts613.dart (gravité, couleurs, âge)
// et pawmap_report_pin613.dart + models/map_report_model.dart (emoji, icône de secours).
// - rond blanc, ANNEAU à la couleur de la gravité : danger #DC2626, attention #EA580C, info #2563EB ;
// - alerte de moins de 2 h : auréole FIXE de sa couleur (pas de pulsation, comme l'app) ;
// - elle pâlit en vieillissant : pleine jusqu'à 24 h, 0,78 jusqu'à 36 h, puis 0,58 ;
// - JAMAIS de rond vide : l'emoji est dessiné une fois dans un canvas ; s'il ne laisse pas
//   d'encre (⚠️ sur l'iPhone de Daniel le 06/10), on pose une icône SVG à la place.
// Fichier sans React ni Leaflet : testé par scripts/test-613.mjs (comparé au Dart).

export type AlertLevel613 = "danger" | "attention" | "info";

const DANGER = new Set(["hazard", "poison", "trap", "aggressive_dog", "chemical", "fire_smoke"]);
const INFO = new Set(["water_active", "vet_open", "lost_pet", "found_pet", "poop", "pee", "other"]);

/** Gravité d'un type de signalement (table `pawAlertLevel613` de l'app). */
export function alertLevel613(type: string): AlertLevel613 {
  if (DANGER.has(type)) return "danger";
  if (INFO.has(type)) return "info";
  return "attention";
}

/** Couleurs (aucun gris) — `pawAlertColor613`. */
export const ALERT_COLOR_613: Record<AlertLevel613, string> = {
  danger: "#DC2626",
  attention: "#EA580C",
  info: "#2563EB",
};

export const ALERT_FRESH_MS_613 = 2 * 3600 * 1000;

/** Alerte « fraîche » : moins de 2 h. */
export function alertFresh613(createdAt: string | number | Date, now: number = Date.now()): boolean {
  const t = new Date(createdAt).getTime();
  return Number.isFinite(t) && now - t < ALERT_FRESH_MS_613;
}

/** Opacité selon l'âge (`pawAlertAlpha613`) : 1 avant 24 h, 0,78 avant 36 h, puis 0,58. */
export function alertAlpha613(createdAt: string | number | Date, now: number = Date.now()): number {
  const t = new Date(createdAt).getTime();
  if (!Number.isFinite(t)) return 1;
  const h = Math.floor((now - t) / 60000) / 60;
  if (h < 24) return 1;
  if (h < 36) return 0.78;
  return 0.58;
}

/** Emoji du type (`ReportTypes.emoji` de l'app, mêmes caractères). */
export const REPORT_EMOJI_613: Record<string, string> = {
  poop: "💩",
  pee: "💧",
  water_active: "🚰",
  water_broken: "🚱",
  hazard: "⚠️",
  aggressive_dog: "🐕",
  lost_pet: "🔎",
  found_pet: "🤝",
  dead_animal: "🪦",
  trap: "🪤",
  poison: "☠️",
  stray_pet: "🐾",
  construction: "🚧",
  busy_traffic: "🚗",
  fire_smoke: "🔥",
  flood: "🌊",
  fallen_tree: "🌳",
  chemical: "🧴",
  wildlife: "🦊",
  no_dogs_zone: "🚫",
  food: "🍖",
  trash: "🗑️",
  vet_open: "🏥",
  leash_required: "🦮",
  heat_hot_ground: "🌡️",
  tick_zone: "🕷️",
};
export function reportEmoji613(type: string): string {
  return REPORT_EMOJI_613[type] ?? "📍";
}

// ── Icônes de secours (Material Symbols, pleines) : une par gravité. ──────────
// L'app choisit une icône Material par type ; le site, sans la police d'icônes de
// Flutter, pose le signe de la gravité dans la couleur de l'anneau. Jamais vide.
const GLYPH_613: Record<AlertLevel613, string> = {
  // warning
  danger: '<path d="M2.73 21h18.54c.77 0 1.25-.83.87-1.5L12.87 3.5c-.39-.67-1.35-.67-1.74 0L1.86 19.5c-.38.67.1 1.5.87 1.5zM13 18h-2v-2h2v2zm-1-4c-.55 0-1-.45-1-1v-3c0-.55.45-1 1-1s1 .45 1 1v3c0 .55-.45 1-1 1z"/>',
  // error (rond « ! »)
  attention: '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 11c-.55 0-1-.45-1-1V8c0-.55.45-1 1-1s1 .45 1 1v4c0 .55-.45 1-1 1zm1 4h-2v-2h2v2z"/>',
  // info
  info: '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 15c-.55 0-1-.45-1-1v-4c0-.55.45-1 1-1s1 .45 1 1v4c0 .55-.45 1-1 1zm1-8h-2V7h2v2z"/>',
};

// ── L'emoji se dessine-t-il vraiment ? (même règle que `pawPinHasInk613`) ─────
const inkCache = new Map<string, boolean>();
const EMOJI_FONT = '"Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji","Segoe UI Symbol",sans-serif';

/** Encre au centre d'une image RGBA (pixel opaque plus sombre ou plus coloré que le blanc). */
export function hasInk613(rgba: ArrayLike<number>, w: number, h: number, box = 26, minPixels = 14): boolean {
  const x0 = Math.floor((w - box) / 2), y0 = Math.floor((h - box) / 2);
  let n = 0;
  for (let y = y0; y < y0 + box; y++) {
    for (let x = x0; x < x0 + box; x++) {
      const i = (y * w + x) * 4;
      const r = rgba[i], g = rgba[i + 1], b = rgba[i + 2], a = rgba[i + 3];
      if (a < 128) continue;
      const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
      if (mn < 205 || mx - mn > 40) n++;
      if (n >= minPixels) return true;
    }
  }
  return false;
}

/**
 * Vrai si le navigateur DESSINE cet emoji (canvas 56 px, fond blanc, comme l'app).
 * Dans le doute (pas de canvas, lecture bloquée), faux : on pose l'icône.
 */
export function emojiDraws613(emoji: string): boolean {
  const hit = inkCache.get(emoji);
  if (hit !== undefined) return hit;
  let ok = false;
  try {
    if (typeof document !== "undefined") {
      const c = document.createElement("canvas");
      c.width = 56; c.height = 56;
      const g = c.getContext("2d", { willReadFrequently: true });
      if (g) {
        g.fillStyle = "#fff"; g.fillRect(0, 0, 56, 56);
        g.font = `27px ${EMOJI_FONT}`;
        g.textAlign = "center"; g.textBaseline = "middle";
        g.fillStyle = "#fff"; // un glyphe monochrome (police texte) serait blanc sur blanc : pas d'encre
        g.fillText(emoji, 28, 30);
        ok = hasInk613(g.getImageData(0, 0, 56, 56).data, 56, 56);
      }
    }
  } catch {
    ok = false;
  }
  inkCache.set(emoji, ok);
  return ok;
}

/** Pour les tests : vide le cache (ex. après avoir simulé une police sans ⚠️). */
export function resetEmojiCache613(): void {
  inkCache.clear();
}

/**
 * Épingle d'alerte (HTML pour un divIcon Leaflet ou une ligne de liste).
 * [emojiOk] : résultat de `emojiDraws613` (calculé par l'appelant, côté navigateur).
 */
export function alertPinHtml613(type: string, o: { size?: number; fresh?: boolean; emojiOk?: boolean } = {}): string {
  const size = o.size ?? 36;
  const level = alertLevel613(type);
  const color = ALERT_COLOR_613[level];
  const fresh = !!o.fresh;
  const k = size / 56; // mêmes proportions que l'image de l'app (56 px)
  const disk = Math.round((fresh ? 56 - 12 : 56 - 4) * k);
  const ring = Math.max(2, Math.round(3 * k * 10) / 10);
  const halo = fresh
    ? `box-shadow:0 0 0 ${Math.max(2, Math.round(3 * k))}px ${color}33,0 0 ${Math.round(6 * k)}px ${Math.round(3 * k)}px ${color}8C;`
    : "box-shadow:0 1.5px 4px rgba(23,20,31,.30);";
  const emoji = reportEmoji613(type);
  const fs = Math.round((fresh ? 24 : 27) * k * 10) / 10;
  const inner = o.emojiOk
    ? `<span data-alert-emoji="" style="font:${fs}px/1 ${EMOJI_FONT};">${emoji}</span>`
    : `<svg data-alert-fallback="" viewBox="0 0 24 24" width="${Math.round(fs * 1.05)}" height="${Math.round(fs * 1.05)}" fill="${color}" aria-hidden="true">${GLYPH_613[level]}</svg>`;
  return `<div data-alert-pin="${level}" data-alert-type="${type}"${fresh ? ' data-alert-fresh=""' : ""} style="width:${size}px;height:${size}px;display:flex;align-items:center;justify-content:center;">`
    + `<div style="width:${disk}px;height:${disk}px;box-sizing:border-box;border-radius:50%;background:#fff;border:${ring}px solid ${color};display:flex;align-items:center;justify-content:center;${halo}">${inner}</div></div>`;
}
