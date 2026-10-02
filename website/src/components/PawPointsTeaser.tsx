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

export function PawPointsTeaser({ className = "", href = "/pawpoints" }: { className?: string; href?: string }) {
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
  // 02/10 (607, « plus joli ») — encart lisible : titre + vrai bouton, exemples
  // en pastilles alignées (même largeur), phrase d'honnêteté du catalogue.
  return (
    <section
      data-pp-teaser=""
      className={`rounded-[24px] bg-gradient-to-br from-[#FFF6DB] via-[#FFFBF0] to-white p-5 shadow-[0_18px_40px_-28px_rgba(183,121,31,0.9)] ring-1 ring-[#F1D9A6] md:p-6 ${className}`}
    >
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
        <span className="grid h-14 w-14 shrink-0 place-items-center rounded-[18px] text-[28px] shadow-[0_10px_20px_-12px_rgba(176,120,0,0.8)]" style={{ background: "linear-gradient(160deg,#FFE7A3,#F4C04A)" }} aria-hidden="true">🐾</span>
        <span className="min-w-0 flex-1">
          <span className="block text-balance font-display text-lg font-extrabold leading-tight text-[#8A5A00] md:text-xl">{t("pp607_teaser_title")}</span>
          {honest && <span className="mt-1 block text-[13px] leading-snug text-[#6E4F48]">{honest}</span>}
        </span>
        <Link
          href={href}
          className="inline-flex min-h-[48px] shrink-0 items-center justify-center gap-2 self-start rounded-full px-6 text-sm font-extrabold text-white shadow-[0_12px_24px_-12px_rgba(176,120,0,0.9)] transition hover:-translate-y-0.5 active:scale-[0.98] sm:self-auto"
          style={{ background: "linear-gradient(165deg,#F4C04A,#D99A0B 55%,#B07800)" }}
        >
          {href === "/pawpoints" ? t("pp607_see_all") : t("ppg_link")} <span aria-hidden="true">→</span>
        </Link>
      </div>
      {picks.length > 0 && (
        <div className="mt-4">
          <p className="mb-2 text-[12px] font-extrabold uppercase tracking-[0.06em] text-[#8A5A00]">{t("pp607_example")}</p>
          <ul className="grid gap-2 sm:grid-cols-3">
            {picks.map((r) => (
              <li key={r.id} className="flex min-w-0 items-center gap-2.5 rounded-[18px] bg-white px-3 py-2.5 ring-1 ring-[#F1D9A6]">
                <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#FFF6DB] text-lg" aria-hidden="true">{r.icon}</span>
                <span className="min-w-0 flex-1 break-words text-[13px] font-bold leading-snug text-[#231715]">{ppText(r.texts, lang)}</span>
                <span className="shrink-0 rounded-full bg-[#FFF6DB] px-2 py-0.5 text-[12px] font-extrabold tabular-nums text-[#8A5A00]">{fmt(r.cost)} pts</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}

export default PawPointsTeaser;
