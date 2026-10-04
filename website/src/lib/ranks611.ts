// 04/10/2026 (611, LEO) — RANGS façon Waze (contrat de PAM :
// ~/hopetsit-social/ranks_611/CONTRAT.md) : Chiot → Jeune chien → Chien
// adulte → Chef de meute → Légende.
//
// Le site ne calcule JAMAIS un rang : il lit le champ `rank` que le serveur
// envoie ({key, level, pointsEarned, nextAt, nextKey}). Champ absent ou
// illisible (ancien serveur, projection partielle) → null → rien affiché
// (jamais de faux « Chiot »). Les seuils ne servent qu'à la barre.
// Teintes = celles de l'app (frontend/lib/widgets/paw_rank611.dart), pleines,
// zéro gris, une version claire et une version sombre.
// Le rang est honorifique : aucun avantage payant, aucune valeur en argent.

export const RANK_KEYS_611 = ["puppy", "young_dog", "adult_dog", "pack_leader", "legend"] as const;
export type RankKey611 = (typeof RANK_KEYS_611)[number];
export const RANK_MINS_611 = [0, 150, 800, 3000, 10000] as const;

export type Rank611 = {
  key: RankKey611;
  level: number; // 1..5
  pointsEarned: number;
  nextAt: number | null;
  nextKey: RankKey611 | null;
};

/** Bloc `ranks611` de GET /pawpoints/catalog (absent sur un ancien serveur). */
export type RanksCatalog611 = {
  version: number;
  langs?: string[];
  ranks: { level: number; key: RankKey611; min: number; color: string; texts: Record<string, string> }[];
  texts?: { title?: Record<string, string>; explainer?: Record<string, string>; noMoney?: Record<string, string> };
  rules?: { basedOn?: string; money?: boolean; paidPerks?: boolean };
};

const isKey = (k: unknown): k is RankKey611 => typeof k === "string" && (RANK_KEYS_611 as readonly string[]).includes(k);
const num = (v: unknown): number | null => (typeof v === "number" && Number.isFinite(v) ? v : null);

/** Lit un `rank` du serveur ; null si absent ou illisible. */
export function parseRank611(raw: unknown): Rank611 | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const level = num(r.level);
  if (!isKey(r.key) || level == null || level < 1 || level > 5 || RANK_KEYS_611[level - 1] !== r.key) return null;
  const nextAt = num(r.nextAt);
  return {
    key: r.key,
    level,
    pointsEarned: Math.max(0, Math.floor(num(r.pointsEarned) ?? 0)),
    nextAt: nextAt == null ? null : nextAt,
    nextKey: isKey(r.nextKey) ? r.nextKey : null,
  };
}

/** Lit le bloc `ranks611` du catalogue ; null si absent ou incomplet. */
export function parseRanksCatalog611(raw: unknown): RanksCatalog611 | null {
  if (!raw || typeof raw !== "object") return null;
  const c = raw as RanksCatalog611;
  if (!Array.isArray(c.ranks) || c.ranks.length !== 5) return null;
  if (!c.ranks.every((r) => isKey(r?.key) && typeof r.min === "number" && typeof r.color === "string" && r.texts)) return null;
  return { ...c, ranks: [...c.ranks].sort((a, b) => a.level - b.level) };
}

export function rankIsTop(r: Rank611): boolean {
  return r.nextAt == null;
}
export function rankPointsToNext(r: Rank611): number {
  return r.nextAt == null ? 0 : Math.max(0, r.nextAt - r.pointsEarned);
}
/** Progression 0..1 entre le seuil du rang et le suivant (1 = Légende). */
export function rankProgress(r: Rank611): number {
  if (r.nextAt == null) return 1;
  const from = RANK_MINS_611[Math.min(4, Math.max(0, r.level - 1))];
  const span = r.nextAt - from;
  if (span <= 0) return 1;
  return Math.min(1, Math.max(0, (r.pointsEarned - from) / span));
}

export type RankStyle611 = { base: string; lightBg: string; lightInk: string; darkBg: string; darkInk: string; lightPipOff: string; darkPipOff: string; lightBorder: string; darkBorder: string };
// Couleurs PLEINES (pas d'opacité : sur fond clair elle redevient grise) —
// les « crans éteints » et bordures sont des mélanges pleins calculés une fois.
const STYLES: RankStyle611[] = [
  // Chiot — miel
  { base: "#E0A045", lightBg: "#FCEBCB", lightInk: "#7A4A06", darkBg: "#4A2F0A", darkInk: "#FFD58C", lightPipOff: "#F0CF9C", darkPipOff: "#956826", lightBorder: "#EDC68B", darkBorder: "#C98D3A" },
  // Jeune chien — orange
  { base: "#E07A2E", lightBg: "#FDE2CC", lightInk: "#8A3A06", darkBg: "#52260A", darkInk: "#FFBE8A", lightPipOff: "#F2C3A0", darkPipOff: "#9A501C", lightBorder: "#EFB487", darkBorder: "#CB6E2A" },
  // Chien adulte — brique
  { base: "#C9442A", lightBg: "#FADAD2", lightInk: "#8A2410", darkBg: "#55190E", darkInk: "#FFAE9C", lightPipOff: "#EBB2A6", darkPipOff: "#8F2F1D", lightBorder: "#E39D8F", darkBorder: "#B33E27" },
  // Chef de meute — violet royal
  { base: "#7A3FB8", lightBg: "#EBDDFB", lightInk: "#4B1D85", darkBg: "#34175A", darkInk: "#D9BCFF", lightPipOff: "#CBB4E5", darkPipOff: "#57298A", lightBorder: "#B796DC", darkBorder: "#6C39A3" },
  // Légende — or
  { base: "#C9961A", lightBg: "#FBEDC4", lightInk: "#6E4E00", darkBg: "#4A3604", darkInk: "#FFDC73", lightPipOff: "#E9D49F", darkPipOff: "#8D6A12", lightBorder: "#E1C47A", darkBorder: "#B58718" },
];
export function rankStyle611(level: number): RankStyle611 {
  return STYLES[Math.min(4, Math.max(0, level - 1))];
}

/** Nom du rang dans la langue du site (clés rank611_*, textes de PAM). */
export function rankName611(t: (k: string) => string, key: RankKey611 | null | undefined): string {
  return key ? t(`rank611_${key}`) : "";
}

/** Glyphes maison (mêmes tracés que l'app : patte pleine, couronne pour Légende). */
export const RANK_PAW_PATH =
  "M12 10.5c-3 0-6 3.6-6 6.2 0 1.7 1.4 2.6 3 2.3 1.1-.2 2-.6 3-.6s1.9.4 3 .6c1.6.3 3-.6 3-2.3 0-2.6-3-6.2-6-6.2z";
export const RANK_PAW_TOES: [number, number][] = [[6.5, 9], [10, 5.6], [14, 5.6], [17.5, 9]];
export const RANK_CROWN_PATH = "M3.5 8.5l4.5 4L12 5.5l4 7 4.5-4-1.5 10h-14z";
