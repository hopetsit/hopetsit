"use client";

// 04/10/2026 (611, LEO) — pastille de rang, carte « Mon rang » et échelle des
// 5 rangs du site. Même dessin que l'app (frontend/lib/widgets/paw_rank611.dart) :
// patte (couronne pour Légende) + nom + 5 crans, teintes pleines du rang.
//  · mode "light" / "dark" : imposé (carte de la PawMap, qui a son propre
//    mode nuit) ; "auto" : suit le thème du système (fenêtre d'aide).
//  · Aucune pastille sans `rank` du serveur (le parent passe null → rien).
// Aucune mention d'avantage ni d'argent : le rang est honorifique.

import type { CSSProperties } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  RANK_CROWN_PATH,
  RANK_PAW_PATH,
  RANK_PAW_TOES,
  rankIsTop,
  rankName611,
  rankPointsToNext,
  rankProgress,
  rankStyle611,
  type Rank611,
  type RanksCatalog611,
} from "@/lib/ranks611";

type Mode = "light" | "dark" | "auto";

export function RankGlyph611({ level, size = 14, color }: { level: number; size?: number; color: string }) {
  if (level >= 5) {
    return (
      <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true" style={{ flexShrink: 0 }}>
        <path d={RANK_CROWN_PATH} fill={color} stroke={color} strokeWidth="1.6" strokeLinejoin="round" />
        <path d="M5.5 20.5h13" stroke={color} strokeWidth="2" strokeLinecap="round" />
      </svg>
    );
  }
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true" style={{ flexShrink: 0 }}>
      {RANK_PAW_TOES.map(([cx, cy]) => <circle key={`${cx}-${cy}`} cx={cx} cy={cy} r="2.1" fill={color} />)}
      <path d={RANK_PAW_PATH} fill={color} />
    </svg>
  );
}

/** Couleurs de la pastille selon le mode, en variables CSS (le mode "auto"
 *  bascule par la classe `dark:` de Tailwind, réglée sur le thème système). */
function pillVars(level: number): CSSProperties {
  const s = rankStyle611(level);
  return {
    ["--rk-bg" as string]: s.lightBg,
    ["--rk-ink" as string]: s.lightInk,
    ["--rk-on" as string]: s.base,
    ["--rk-off" as string]: s.lightPipOff,
    ["--rk-bd" as string]: s.lightBorder,
    ["--rk-bg-d" as string]: s.darkBg,
    ["--rk-ink-d" as string]: s.darkInk,
    ["--rk-on-d" as string]: s.darkInk,
    ["--rk-off-d" as string]: s.darkPipOff,
    ["--rk-bd-d" as string]: s.darkBorder,
  } as CSSProperties;
}
// Classes écrites EN ENTIER (Tailwind ne voit pas une classe assemblée au vol).
const BOX: Record<Mode, string> = {
  light: "border-[var(--rk-bd)] bg-[var(--rk-bg)] text-[var(--rk-ink)]",
  dark: "border-[var(--rk-bd-d)] bg-[var(--rk-bg-d)] text-[var(--rk-ink-d)]",
  auto: "border-[var(--rk-bd)] bg-[var(--rk-bg)] text-[var(--rk-ink)] dark:border-[var(--rk-bd-d)] dark:bg-[var(--rk-bg-d)] dark:text-[var(--rk-ink-d)]",
};
const PIP_ON: Record<Mode, string> = { light: "bg-[var(--rk-on)]", dark: "bg-[var(--rk-on-d)]", auto: "bg-[var(--rk-on)] dark:bg-[var(--rk-on-d)]" };
const PIP_OFF: Record<Mode, string> = { light: "bg-[var(--rk-off)]", dark: "bg-[var(--rk-off-d)]", auto: "bg-[var(--rk-off)] dark:bg-[var(--rk-off-d)]" };

export function RankPill611({ rank, mode = "light", compact = false, className = "" }: { rank: Rank611 | null | undefined; mode?: Mode; compact?: boolean; className?: string }) {
  const { t } = useT();
  if (!rank) return null;
  const name = rankName611(t, rank.key);
  const semantic = t("rank611_semantic").replace("@rank", name);
  const s = rankStyle611(rank.level);
  const on = mode === "dark" ? s.darkInk : s.base;
  return (
    <span
      role="img"
      aria-label={semantic}
      title={semantic}
      data-rank={rank.key}
      data-rank-level={rank.level}
      className={`inline-flex max-w-full shrink-0 items-center gap-1 rounded-[12px] border py-[3px] pl-[5px] ${compact ? "pr-[7px]" : "pr-[9px]"} ${BOX[mode]} ${className}`}
      style={pillVars(rank.level)}
    >
      {mode === "auto" ? (
        <>
          <span className="dark:hidden"><RankGlyph611 level={rank.level} size={compact ? 13 : 14} color={s.base} /></span>
          <span className="hidden dark:inline"><RankGlyph611 level={rank.level} size={compact ? 13 : 14} color={s.darkInk} /></span>
        </>
      ) : (
        <RankGlyph611 level={rank.level} size={compact ? 13 : 14} color={on} />
      )}
      <span aria-hidden="true" className={`truncate font-bold leading-[1.1] ${compact ? "text-[10.5px]" : "text-[11.5px]"}`} style={{ fontFamily: "Poppins, Inter, system-ui, sans-serif" }}>{name}</span>
      {!compact && (
        <span aria-hidden="true" className="ml-[3px] inline-flex shrink-0 items-center gap-[1.5px]">
          {[1, 2, 3, 4, 5].map((i) => (
            <span key={i} className={`block h-1 w-1 rounded-full ${i <= rank.level ? PIP_ON[mode] : PIP_OFF[mode]}`} />
          ))}
        </span>
      )}
    </span>
  );
}

/** Carte « Mon rang » + barre + « Encore N points pour … » (écran PawPoints, tableau de bord). */
export function RankProgress611({ rank, showHow = true, className = "" }: { rank: Rank611 | null | undefined; showHow?: boolean; className?: string }) {
  const { t, lang } = useT();
  if (!rank) return null;
  const s = rankStyle611(rank.level);
  let n = String(rankPointsToNext(rank));
  try { n = rankPointsToNext(rank).toLocaleString(lang); } catch { /* */ }
  const line = rankIsTop(rank) ? t("rank611_top") : t("rank611_to_next").replace("@n", n).replace("@rank", rankName611(t, rank.nextKey));
  const pct = Math.round(rankProgress(rank) * 100);
  return (
    <div data-rank-progress={rank.key} className={`rounded-[22px] p-5 ${className}`} style={{ background: s.lightBg, boxShadow: `inset 0 0 0 1.5px ${s.lightBorder}` }}>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-[13px] font-extrabold uppercase tracking-[0.05em]" style={{ color: s.lightInk }}>{t("rank611_my_rank")}</span>
        <RankPill611 rank={rank} />
      </div>
      <div className="mt-3 h-2.5 w-full overflow-hidden rounded-full" style={{ background: s.lightPipOff }} role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={pct} aria-label={line}>
        <div data-rank-bar="" className="h-full rounded-full" style={{ width: `${pct}%`, background: `linear-gradient(90deg, ${s.base}, ${mixHex(s.base, "#FFC23D", 0.35)})` }} />
      </div>
      <p data-rank-line="" className="mt-2 text-[14px] font-bold leading-snug" style={{ color: s.lightInk }}>{line}</p>
      {showHow && <p className="mt-1 text-[12.5px] leading-snug" style={{ color: s.lightInk }}>{t("rank611_how")}</p>}
    </div>
  );
}

/** Échelle des 5 rangs (catalogue `ranks611`), « Tu es ici » si mon rang est connu. */
export function RanksLadder611({ catalog, mine }: { catalog: RanksCatalog611; mine: Rank611 | null }) {
  const { t, lang } = useT();
  const txt = (m?: Record<string, string>) => (m ? m[lang] || m.en || m.fr || "" : "");
  let fmt = (v: number) => String(v);
  try { const nf = new Intl.NumberFormat(lang); fmt = (v: number) => nf.format(v); } catch { /* */ }
  return (
    <div data-ranks-ladder="">
      <ol className="grid grid-cols-1 gap-2.5 sm:grid-cols-5">
        {catalog.ranks.map((r) => {
          const s = rankStyle611(r.level);
          const here = mine?.level === r.level;
          const done = !!mine && r.level < mine.level;
          return (
            <li
              key={r.key}
              data-rank-step={r.key}
              data-state={here ? "current" : done ? "done" : "other"}
              className="flex min-w-0 items-center gap-3 rounded-[20px] p-3 sm:flex-col sm:p-4 sm:text-center"
              style={{ background: `linear-gradient(160deg, ${s.lightBg}, #FFFFFF)`, boxShadow: here ? `inset 0 0 0 2px ${s.base}, 0 12px 24px -16px ${s.base}` : `inset 0 0 0 1px ${s.lightBorder}` }}
            >
              <span className="relative grid h-12 w-12 shrink-0 place-items-center rounded-full" style={{ background: `linear-gradient(160deg, ${mixHex(s.base, "#FFFFFF", 0.25)}, ${s.base})`, border: "3px solid #fff", boxShadow: `0 8px 16px -10px ${s.base}` }}>
                <RankGlyph611 level={r.level} size={22} color="#FFFFFF" />
                {done && <span className="absolute -right-1 -top-1 grid h-5 w-5 place-items-center rounded-full bg-[#16A34A] text-[11px] font-black text-white ring-2 ring-white" aria-hidden="true">✓</span>}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block break-words text-[15px] font-extrabold leading-tight" style={{ color: s.lightInk }}>{txt(r.texts) || rankName611(t, r.key)}</span>
                <span className="mt-0.5 block text-[12px] font-bold tabular-nums" style={{ color: s.lightInk }}>{fmt(r.min)} pts</span>
                {here && <span className="mt-1 inline-block rounded-full px-2 py-0.5 text-[10.5px] font-extrabold text-white" style={{ background: s.lightInk }}>{t("ppl607_here")}</span>}
              </span>
            </li>
          );
        })}
      </ol>
      {(catalog.texts?.explainer || catalog.texts?.noMoney) && (
        <div className="mt-4 space-y-1.5 rounded-[20px] bg-[#FFF8F3] p-4 ring-1 ring-[#F3E6E1]">
          {catalog.texts?.explainer && <p className="text-[13px] leading-snug text-[#231715]">{txt(catalog.texts.explainer)}</p>}
          {catalog.texts?.noMoney && <p className="text-[13px] font-semibold leading-snug text-[#6E4F48]">{txt(catalog.texts.noMoney)}</p>}
        </div>
      )}
    </div>
  );
}

function mixHex(a: string, b: string, k: number): string {
  const h = (x: string) => [1, 3, 5].map((i) => parseInt(x.slice(i, i + 2), 16));
  const A = h(a);
  const B = h(b);
  return `#${A.map((v, i) => Math.round(v + (B[i] - v) * k).toString(16).padStart(2, "0")).join("")}`;
}
