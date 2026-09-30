// 30/09/2026 — LEO (demande vocale de Daniel via BOB) : sommaire cliquable en
// haut de « Comprendre la PawMap » (PawMapLegendModal). Les titres des
// sections sont déjà traduits (h587_sec_*, help599_sec_balade, h587_faq_title) ;
// seuls l'intitulé du sommaire et le bouton de retour sont nouveaux. 9 langues,
// fusionné dans translations.ts (même mécanisme que balade2909.ts).
// + 30/09 (décision Daniel) : unités de la bulle de prix des gardiens qui n'ont
// QUE des tarifs à la semaine / au mois (« 100 €/sem », « 350 €/mois »).
import type { Lang } from "./translations";

type D = Record<string, string>;

export const SITE605: Record<Lang, D> = {
  fr: { toc3009_title: "Aller directement à", toc3009_back: "Sommaire", pu605_week: "sem", pu605_month: "mois" },
  en: { toc3009_title: "Jump to", toc3009_back: "Contents", pu605_week: "wk", pu605_month: "mo" },
  es: { toc3009_title: "Ir directamente a", toc3009_back: "Índice", pu605_week: "sem", pu605_month: "mes" },
  de: { toc3009_title: "Direkt zu", toc3009_back: "Inhalt", pu605_week: "Wo.", pu605_month: "Mon." },
  it: { toc3009_title: "Vai direttamente a", toc3009_back: "Indice", pu605_week: "sett.", pu605_month: "mese" },
  pt: { toc3009_title: "Ir diretamente para", toc3009_back: "Índice", pu605_week: "sem.", pu605_month: "mês" },
  ko: { toc3009_title: "바로 가기", toc3009_back: "목차", pu605_week: "주", pu605_month: "월" },
  ja: { toc3009_title: "項目へ移動", toc3009_back: "目次", pu605_week: "週", pu605_month: "月" },
  pl: { toc3009_title: "Przejdź do", toc3009_back: "Spis treści", pu605_week: "tydz.", pu605_month: "mies." },
};
