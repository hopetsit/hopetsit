// 19/10/2026 — LEO : PINS du build 618 (PROCHAIN_BUILD_618.md §B, décision de Daniel du 19/10).
// Contrat serveur, même forme partout : `pins: { podium: 1|2|3|null, firstPackLeader: true|false }`.
// Le site ne calcule JAMAIS un pin : il lit le champ envoyé. Champ absent ou illisible (serveur
// d'avant le 618) → null → rien affiché. Honorifique : aucune valeur en argent.

export type Pins1910 = { podium: 1 | 2 | 3 | null; firstPackLeader: boolean };

/** Lit `pins` ; null s'il n'y a rien à montrer (absent, illisible, ou aucun pin). */
export function parsePins1910(raw: unknown): Pins1910 | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const p = r.podium;
  const podium = p === 1 || p === 2 || p === 3 ? p : null;
  const firstPackLeader = r.firstPackLeader === true;
  if (podium == null && !firstPackLeader) return null;
  return { podium, firstPackLeader };
}

/** Teintes des pins : métal plein (dégradé clair → foncé), jamais de gris translucide. */
export const PIN_STYLE = {
  1: { grad: "linear-gradient(160deg,#FFE58A,#F4C04A 45%,#B7791F)", ink: "#5A3A00", ring: "#8A5A00", key: "p1910_pin_gold" },
  2: { grad: "linear-gradient(160deg,#FFFFFF,#D9E2EC 45%,#8DA2B8)", ink: "#23364A", ring: "#5E7690", key: "p1910_pin_silver" },
  3: { grad: "linear-gradient(160deg,#F6C9A0,#CD7F32 50%,#8A4B14)", ink: "#4A2508", ring: "#7A4210", key: "p1910_pin_bronze" },
} as const;
/** « 1er Chef de meute » : violet du rang Chef de meute (ranks611 : #7A3FB8) + étoile or. */
export const FIRST_PACK_STYLE = { grad: "linear-gradient(160deg,#B58BEA,#7A3FB8 55%,#4E2381)", ink: "#FFFFFF", ring: "#4E2381", star: "#F4C04A", key: "p1910_pin_first" } as const;

const STAR_PATH = "M12 2.6l2.8 6.1 6.6.7-5 4.5 1.4 6.5L12 17.1l-5.8 3.3 1.4-6.5-5-4.5 6.6-.7z";

/** Un pin en HTML (épingles Leaflet, légende) : disque métal + chiffre, ou disque violet + étoile. */
export function pinDiscHtml(kind: 1 | 2 | 3 | "first", size = 18): string {
  if (kind === "first") {
    const s = FIRST_PACK_STYLE;
    return `<span data-pin="first" style="display:inline-flex;align-items:center;justify-content:center;width:${size}px;height:${size}px;border-radius:50%;background:${s.grad};border:1.5px solid #fff;box-shadow:0 1px 3px rgba(23,20,31,.4),inset 0 0 0 1px ${s.ring};box-sizing:border-box;"><svg viewBox="0 0 24 24" width="${Math.round(size * 0.66)}" height="${Math.round(size * 0.66)}" aria-hidden="true"><path d="${STAR_PATH}" fill="${s.star}"/></svg></span>`;
  }
  const s = PIN_STYLE[kind];
  return `<span data-pin="${kind}" style="display:inline-flex;align-items:center;justify-content:center;width:${size}px;height:${size}px;border-radius:50%;background:${s.grad};border:1.5px solid #fff;box-shadow:0 1px 3px rgba(23,20,31,.4),inset 0 0 0 1px ${s.ring};box-sizing:border-box;color:${s.ink};font:800 ${Math.round(size * 0.56)}px/1 Inter,system-ui,sans-serif;">${kind}</span>`;
}

/**
 * Badge posé sur l'avatar d'une bulle PawMap (coin haut gauche, libre : la couronne est en haut
 * à droite, la fusée en bas à gauche, la coche et le point en ligne en bas à droite). Si la
 * personne est vérifiée ET a un point en ligne, ce point passe en haut à gauche : le pin descend
 * alors au milieu du bord gauche. Les deux pins côte à côte quand la personne a les deux.
 */
export function pinsOnAvatarHtml(pins: Pins1910 | null | undefined, size: number, opts?: { leftMiddle?: boolean }): string {
  if (!pins) return "";
  const d = Math.max(16, Math.round(size * 0.36));
  const discs = [pins.podium ? pinDiscHtml(pins.podium, d) : "", pins.firstPackLeader ? pinDiscHtml("first", d) : ""].filter(Boolean).join("");
  if (!discs) return "";
  const pos = opts?.leftMiddle ? `top:50%;left:-${Math.round(d * 0.45)}px;transform:translateY(-50%);flex-direction:column;` : `top:-${Math.round(d * 0.3)}px;left:-${Math.round(d * 0.3)}px;`;
  return `<span data-pins-avatar="" style="position:absolute;${pos}display:flex;gap:2px;z-index:2;pointer-events:none;">${discs}</span>`;
}

/** Podium public (GET /pawpoints/pins, cache 60 s). Null sur un serveur d'avant le 618. */
export type PublicPins1910 = {
  podium: { userId: string; role: string; name: string; points: number }[];
  firstPackLeader: { userId: string; role: string; name: string; at: string | null } | null;
};
export function parsePublicPins1910(raw: unknown): PublicPins1910 | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  if (!Array.isArray(r.podium)) return null;
  const podium = (r.podium as unknown[])
    .filter((x): x is Record<string, unknown> => !!x && typeof x === "object")
    .map((x) => ({ userId: String(x.userId ?? ""), role: String(x.role ?? ""), name: String(x.name ?? "").trim(), points: Number(x.points) || 0 }))
    .filter((x) => x.name)
    .slice(0, 3);
  const f = r.firstPackLeader && typeof r.firstPackLeader === "object" ? (r.firstPackLeader as Record<string, unknown>) : null;
  const firstPackLeader = f && String(f.name ?? "").trim() ? { userId: String(f.userId ?? ""), role: String(f.role ?? ""), name: String(f.name).trim(), at: f.at ? String(f.at) : null } : null;
  return { podium, firstPackLeader };
}

/** Collection du mois (GET /plush/collection → `monthly`, §C). Null sur un ancien serveur. */
export type Monthly1910 = { key: string; theme: string; label: string; color: string | null; caughtTypes: string[]; complete: boolean; bonusPoints: number; startsAt: string | null; endsAt: string | null };
export function parseMonthly1910(raw: unknown, lang: string): Monthly1910 | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const key = typeof r.key === "string" && /^\d{4}-\d{2}$/.test(r.key) ? r.key : null;
  if (!key) return null;
  let label = "";
  if (typeof r.label === "string") label = r.label;
  else if (r.label && typeof r.label === "object") {
    const l = r.label as Record<string, unknown>;
    label = String(l[lang] ?? l.en ?? l.fr ?? "");
  }
  const color = typeof r.color === "string" && /^#[0-9a-fA-F]{6}$/.test(r.color) ? r.color : null;
  return {
    key,
    theme: typeof r.theme === "string" ? r.theme : "",
    label,
    color,
    caughtTypes: Array.isArray(r.caughtTypes) ? (r.caughtTypes as unknown[]).map(String) : [],
    complete: r.complete === true,
    bonusPoints: Number(r.bonusPoints) || 500,
    startsAt: typeof r.startsAt === "string" ? r.startsAt : null,
    endsAt: typeof r.endsAt === "string" ? r.endsAt : null,
  };
}

/** « novembre 2026 » dans la langue du site, à partir de « 2026-11 ». */
export function monthLabel1910(key: string, lang: string): string {
  const [y, m] = key.split("-").map(Number);
  try {
    return new Intl.DateTimeFormat(lang, { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(Date.UTC(y, m - 1, 15)));
  } catch {
    return key;
  }
}
