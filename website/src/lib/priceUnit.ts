// 30/09/2026 — LEO (605, décision de Daniel) : un gardien qui n'a QUE des
// tarifs à la semaine / au mois (cas réel : GIRMA, Boulogne, 100 €/sem)
// n'avait aucune bulle de prix. Le serveur (a3d3a01a) renvoie alors
// `priceAlt: { amount, unit: 'week' | 'month' }` quand `priceFrom` = 0.
// Module PUR : `formatPrice` (lib/pawmapLegend.ts, fichier de PAM) n'est pas
// modifié ; on l'utilise tel quel et on ajoute l'unité ici.
import { formatPrice } from "@/lib/pawmapLegend";

export type PriceAlt = { amount: number; unit: "week" | "month" };
export type PriceUnitLabels = { week: string; month: string };

/** `priceAlt` valide ou null (tolère un serveur ancien ou une valeur mal formée). */
export function cleanPriceAlt(v: unknown): PriceAlt | null {
  if (!v || typeof v !== "object") return null;
  const o = v as { amount?: unknown; unit?: unknown };
  const amount = Number(o.amount);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  if (o.unit !== "week" && o.unit !== "month") return null;
  return { amount, unit: o.unit };
}

/** Repli carte publique : semaine d'abord, sinon mois — seulement sans tarif jour / heure. */
export function priceAltFromRates(r: { hourlyRate?: number | null; dailyRate?: number | null; weeklyRate?: number | null; monthlyRate?: number | null }): PriceAlt | null {
  if ((Number(r.dailyRate) || 0) > 0 || (Number(r.hourlyRate) || 0) > 0) return null;
  if ((Number(r.weeklyRate) || 0) > 0) return { amount: Number(r.weeklyRate), unit: "week" };
  if ((Number(r.monthlyRate) || 0) > 0) return { amount: Number(r.monthlyRate), unit: "month" };
  return null;
}

/**
 * Prix affiché : `formatPrice(amount)` s'il existe (inchangé pour tous), sinon
 * « 100 €/sem » / « 350 €/mois » à partir de `alt`, sinon null.
 */
export function formatPriceUnit(
  amount: number | null | undefined,
  currency: string | null | undefined,
  alt: PriceAlt | null | undefined,
  units: PriceUnitLabels,
): string | null {
  const base = formatPrice(amount, currency);
  if (base) return base;
  const a = cleanPriceAlt(alt);
  if (!a) return null;
  const p = formatPrice(a.amount, currency);
  return p ? `${p}/${units[a.unit]}` : null;
}

/** Libellés d'unité traduits (clés pu605_* du site, 9 langues). */
export function priceUnitLabels(t: (k: string) => string): PriceUnitLabels {
  return { week: t("pu605_week"), month: t("pu605_month") };
}
