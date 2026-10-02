"use client";

// 02/10/2026 (607, LEO) — encart PawPoints de la boutique et de /pricing,
// alimenté par le catalogue UNIQUE de ZOE (catalog607) : exemples de
// récompenses réelles (plus de « -10 / -25 / -50 % »), phrase d'honnêteté du
// catalogue, lien vers la page PawPoints. Rien en dur : sans catalogue, l'encart
// garde seulement son titre et son lien.

import Link from "next/link";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { getPawCatalog607, ppText, type PawCatalog607 } from "@/lib/api";

export function PawPointsTeaser({ className = "" }: { className?: string }) {
  const { t, lang } = useT();
  const [catalog, setCatalog] = useState<PawCatalog607 | null>(null);
  useEffect(() => {
    let alive = true;
    void getPawCatalog607().then((c) => { if (alive) setCatalog(c); });
    return () => { alive = false; };
  }, []);
  // Trois exemples parlants : le moins cher, des jours d'abonnement, du Premium.
  const sorted = [...(catalog?.rewards ?? [])].sort((a, b) => a.cost - b.cost);
  const picks = [sorted[0], sorted.find((r) => r.kind === "free_days" && r.plan !== "premium_monthly"), sorted.find((r) => r.plan === "premium_monthly")]
    .filter((r, i, arr): r is NonNullable<typeof r> => !!r && arr.findIndex((x) => x?.id === r.id) === i);
  let fmt = (n: number) => String(n);
  try { const nf = new Intl.NumberFormat(lang); fmt = (n: number) => nf.format(n); } catch { /* */ }
  const honest = ppText(catalog?.notes?.activityOnly, lang);
  return (
    <Link
      href="/pawpoints"
      data-pp-teaser=""
      className={`flex flex-col gap-3 rounded-[22px] bg-gradient-to-r from-[#FFF6DB] to-white p-4 ring-2 ring-[#F1D9A6] transition hover:brightness-[1.02] sm:flex-row sm:items-center ${className}`}
    >
      <span className="grid h-12 w-12 shrink-0 place-items-center rounded-[14px] bg-[#FFEBB0] text-2xl" aria-hidden="true">🐾</span>
      <span className="min-w-0 flex-1">
        <span className="block text-sm font-extrabold text-[#8A5A00]">{t("pp607_teaser_title")}</span>
        {picks.length > 0 && (
          <span className="mt-1 flex flex-wrap items-center gap-1.5 text-[12px]">
            <span className="font-semibold text-[#6E4F48]">{t("pp607_example")}</span>
            {picks.map((r) => (
              <span key={r.id} className="rounded-full bg-white px-2.5 py-1 font-semibold text-[#231715] ring-1 ring-[#F1D9A6]">
                {r.icon} {ppText(r.texts, lang)} · <span className="font-extrabold text-[#8A5A00]">{fmt(r.cost)} pts</span>
              </span>
            ))}
          </span>
        )}
        {honest && <span className="mt-1 block text-[12px] leading-snug text-[#6E4F48]">{honest}</span>}
      </span>
      <span className="shrink-0 text-sm font-bold text-[#8A5A00]">{t("pp607_see_all")} →</span>
    </Link>
  );
}

export default PawPointsTeaser;
