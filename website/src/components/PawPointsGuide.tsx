"use client";

// 02/10/2026 (607, LEO, demande de Daniel) — PAGE PUBLIQUE PawPoints
// (/pawpoints-guide, indexable) : à quoi ça sert, comment gagner, paliers,
// récompenses et leur coût, collection de peluches (5 + la dorée), honnêteté.
// Tout vient du catalogue UNIQUE de ZOE (catalog607, rendu côté serveur puis
// relu ici) : aucun chiffre en dur. La page membre (/pawpoints) reste privée.

import Link from "next/link";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";
import { getPawCatalog607, ppText, type PawCatalog607 } from "@/lib/api";
import { trackSiteEvent } from "@/components/SiteAnalytics";

const GOLD = "#B7791F";
const GOLD_BG = "#FFF6DB";
const INK = "#231715";
const SOFT = "#6E4F48";
const PLUSH = ["teddy", "bunny", "kitty", "puppy", "fox"];

export function PawPointsGuide({ initial }: { initial: PawCatalog607 | null }) {
  const { t, lang } = useT();
  const { user, ready } = useAuth();
  const [catalog, setCatalog] = useState<PawCatalog607 | null>(initial);
  useEffect(() => {
    if (initial) return;
    let alive = true;
    void getPawCatalog607().then((c) => { if (alive && c) setCatalog(c); });
    return () => { alive = false; };
  }, [initial]);
  let fmt = (n: number) => String(n);
  try { const nf = new Intl.NumberFormat(lang); fmt = (n: number) => nf.format(n); } catch { /* */ }
  const limit = (l: string) => (["each", "once", "daily", "streak"].includes(l) ? t(`pp607_limit_${l}`) : "");
  const levels = [...(catalog?.levels ?? [])].sort((a, b) => a.min - b.min);
  const rewards = [...(catalog?.rewards ?? [])].sort((a, b) => a.cost - b.cost);

  return (
    <div className="mx-auto max-w-5xl px-4 py-10 md:py-14">
      <header className="text-center">
        <div className="mx-auto mb-3 grid h-16 w-16 place-items-center rounded-[20px] text-4xl" style={{ background: GOLD_BG }} aria-hidden="true">🐾</div>
        <h1 className="text-balance font-display text-4xl font-extrabold tracking-tight md:text-5xl" style={{ color: INK }}>{t("ppg_title")}</h1>
        <p className="mx-auto mt-3 max-w-2xl text-base leading-relaxed md:text-lg" style={{ color: SOFT }}>{t("ppg_sub")}</p>
        {catalog?.notes?.activityOnly && (
          <p className="mx-auto mt-4 inline-flex max-w-2xl items-start gap-2 rounded-2xl bg-[#E8F8EE] px-4 py-2.5 text-left text-sm font-semibold text-[#0F5C2B]" data-ppg-honest="">
            <span aria-hidden="true">🔒</span><span className="min-w-0">{ppText(catalog.notes.activityOnly, lang)}</span>
          </p>
        )}
      </header>

      {catalog && (
        <section className="mt-12" data-ppg-earn="">
          <h2 className="font-display text-2xl font-extrabold" style={{ color: INK }}>{t("pp607_earn")}</h2>
          <ul className="mt-5 grid gap-3 sm:grid-cols-2">
            {catalog.earn.map((e) => (
              <li key={e.key} className="flex items-center gap-3 rounded-[20px] bg-white p-4 ring-1 ring-[#F3E6E1]">
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-[14px] text-xl" style={{ background: GOLD_BG }} aria-hidden="true">{e.icon}</span>
                <span className="min-w-0 flex-1">
                  <span className="block break-words text-sm font-semibold leading-snug" style={{ color: INK }}>{ppText(e.texts, lang)}</span>
                  {limit(e.limit) && <span className="block text-[12px]" style={{ color: SOFT }}>{limit(e.limit)}</span>}
                </span>
                <span className="shrink-0 text-lg font-extrabold tabular-nums" style={{ color: GOLD }}>+{fmt(e.points)}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      {rewards.length > 0 && (
        <section className="mt-12" data-ppg-rewards="">
          <h2 className="font-display text-2xl font-extrabold" style={{ color: INK }}>{t("pp607_exchange")}</h2>
          <ul className="mt-5 grid gap-3 md:grid-cols-2">
            {rewards.map((r) => (
              <li key={r.id} className="flex items-center gap-3 rounded-[20px] bg-white p-4 ring-1 ring-[#F3E6E1]">
                <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full text-2xl" style={{ background: GOLD_BG }} aria-hidden="true">{r.icon}</span>
                <span className="min-w-0 flex-1 break-words text-sm font-bold leading-snug" style={{ color: INK }}>{ppText(r.texts, lang)}</span>
                <span className="shrink-0 text-sm font-extrabold tabular-nums" style={{ color: GOLD }}>{fmt(r.cost)} pts</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="mt-12 rounded-[26px] p-5 ring-1 ring-[#BFE8CC] md:p-7" style={{ background: "#EFFAF2" }} data-ppg-plush="">
        <h2 className="font-display text-2xl font-extrabold" style={{ color: "#0F5C2B" }}>{t("ppg_plush_title")} 🧸</h2>
        <p className="mt-1 whitespace-pre-line text-sm leading-relaxed" style={{ color: "#23352A" }}>{t("help607_plush_body")}</p>
        <ul className="mt-4 grid grid-cols-3 gap-2 sm:grid-cols-6 sm:gap-3">
          {PLUSH.map((ty, i) => (
            <li key={ty} className="flex flex-col items-center rounded-[18px] bg-white p-2 text-center sm:p-3">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={`/plush/${ty}.png`} alt={t(`help607_plush_names_${i + 1}`)} width={64} height={64} className="h-14 w-14 object-contain sm:h-16 sm:w-16" />
              <span className="mt-1 break-words text-xs font-bold leading-tight" style={{ color: INK }}>{t(`help607_plush_names_${i + 1}`)}</span>
            </li>
          ))}
          <li className="flex flex-col items-center rounded-[18px] p-2 text-center ring-2 ring-[#F1D9A6] sm:p-3" style={{ background: GOLD_BG }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/plush/teddy_gold.png" alt={t("help607_plush_gold")} width={64} height={64} className="h-14 w-14 object-contain sm:h-16 sm:w-16" />
            <span className="mt-1 break-words text-xs font-extrabold leading-tight" style={{ color: "#8A5A00" }}>{t("help607_plush_gold")}</span>
          </li>
        </ul>
        <p className="mt-4 whitespace-pre-line rounded-2xl bg-white p-4 text-sm font-semibold leading-relaxed" style={{ color: INK }}>{t("help607_plush_bonus")}</p>
      </section>

      {catalog?.notes && (
        <section className="mt-12 space-y-2 rounded-[22px] bg-[#FFF8F3] p-5 ring-1 ring-[#F3E6E1]">
          {Object.values(catalog.notes).map((n, i) => (
            <p key={i} className="flex items-start gap-2 text-[13px] leading-snug" style={{ color: INK }}><span aria-hidden="true">🐾</span><span className="min-w-0">{ppText(n, lang)}</span></p>
          ))}
        </section>
      )}

      {levels.length > 0 && (
        <section className="mt-12" data-ppg-levels="">
          <h2 className="font-display text-2xl font-extrabold" style={{ color: INK }}>{t("pp607_levels")}</h2>
          <ul className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {levels.map((l) => (
              <li key={l.key} className="rounded-[20px] bg-white p-4" style={{ boxShadow: `inset 0 0 0 1.5px ${l.color}` }}>
                <div className="flex items-center gap-3">
                  <span className="grid h-11 w-11 shrink-0 place-items-center rounded-[14px] text-2xl" style={{ background: GOLD_BG }} aria-hidden="true">{l.emoji}</span>
                  <div className="min-w-0">
                    <div className="break-words text-sm font-extrabold" style={{ color: l.color }}>{l.index}. {ppText(l.texts, lang)}</div>
                    <div className="text-[12px] font-semibold tabular-nums" style={{ color: SOFT }}>{fmt(l.min)} pts</div>
                  </div>
                </div>
                <ul className="mt-3 space-y-1">
                  {l.perks.map((p) => (
                    <li key={p} className="flex items-start gap-2 text-[13px]" style={{ color: INK }}>
                      <span aria-hidden="true" style={{ color: l.color }}>✓</span><span className="min-w-0 break-words">{ppText(catalog?.perkTexts?.[p], lang) || p}</span>
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="mt-12 rounded-[28px] bg-[#231715] p-8 text-center md:p-10">
        <h2 className="font-display text-2xl font-bold text-white md:text-3xl">{t("ppg_cta_title")}</h2>
        <div className="mt-6 flex flex-col items-center justify-center gap-3 sm:flex-row">
          {ready && user ? (
            <Link href="/pawpoints" className="inline-flex min-h-[48px] items-center rounded-full px-7 text-sm font-bold text-white" style={{ background: "linear-gradient(165deg,#F4C04A,#D99A0B 55%,#B07800)" }}>{t("ppg_member_link")} →</Link>
          ) : (
            <Link href="/signup" onClick={() => trackSiteEvent("cta_click", { label: "ppg_signup" })} className="inline-flex min-h-[48px] items-center rounded-full px-7 text-sm font-bold text-white" style={{ background: "linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C)" }}>{t("ppg_cta_signup")} →</Link>
          )}
          <Link href="/download" className="inline-flex min-h-[48px] items-center rounded-full bg-white px-7 text-sm font-bold text-[#231715]">{t("s607_app")}</Link>
        </div>
      </section>
    </div>
  );
}

export default PawPointsGuide;
