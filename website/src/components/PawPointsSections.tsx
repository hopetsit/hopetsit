"use client";

// 02/10/2026 (607, LEO — « plus joli sur le web », Daniel) : blocs PawPoints
// PARTAGÉS par la page membre (/pawpoints) et la page publique
// (/pawpoints-guide). Design seul : mêmes données (catalogue catalog607 de ZOE),
// mêmes clés, aucune logique d'échange ici (le bouton appelle onRedeem).
//  · Grilles en « flex-wrap + grow » : la dernière rangée s'étire, jamais de
//    carte orpheline seule sur sa ligne, quel que soit le nombre d'éléments.

import type { ReactNode } from "react";
import { ppText, type Pp607Earn, type Pp607Reward } from "@/lib/api";

export const PP_INK = "#231715";
export const PP_SOFT = "#6E4F48";
export const PP_GOLD = "#B7791F";
export const PP_GOLD_BG = "#FFF6DB";
const GOLD_GRAD = "linear-gradient(165deg,#F4C04A,#D99A0B 55%,#B07800)";

/** Mélange PLEIN de deux couleurs hex (t = part de b). */
export function mix(a: string, b: string, t: number): string {
  const h = (x: string) => [1, 3, 5].map((i) => parseInt(x.slice(i, i + 2), 16));
  const A = h(a.length === 4 ? `#${a[1]}${a[1]}${a[2]}${a[2]}${a[3]}${a[3]}` : a);
  const B = h(b);
  return `#${A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, "0")).join("")}`;
}

/** En-tête de section, un peu plus présent que le h2 brut. */
export function PpTitle({ children, sub }: { children: ReactNode; sub?: ReactNode }) {
  return (
    <div className="mb-5">
      <h2 className="text-balance font-display text-2xl font-extrabold tracking-[-0.02em] md:text-[28px]" style={{ color: PP_INK }}>{children}</h2>
      {sub && <p className="mt-1 text-sm" style={{ color: PP_SOFT }}>{sub}</p>}
    </div>
  );
}

// 04/10 (611) — l'ancienne frise des 7 paliers (LevelsLadder) est retirée :
// les rangs (Chiot → Légende) sont dessinés par components/Rank611.tsx.

// ─── COMMENT GAGNER ───────────────────────────────────────────────────────
export function EarnGrid({ earn, lang, t, fmt }: { earn: Pp607Earn[]; lang: string; t: (k: string) => string; fmt: (n: number) => string }) {
  const limit = (l: string) => (["each", "once", "daily", "daily2", "streak"].includes(l) ? t(`pp607_limit_${l}`) : "");
  return (
    <ul className="flex flex-wrap gap-3" data-pp-earn-grid="">
      {earn.map((e) => (
        <li key={e.key} className="flex min-w-[min(100%,260px)] grow basis-[260px] items-center gap-3 rounded-[24px] bg-white p-4 shadow-[0_14px_30px_-22px_rgba(183,121,31,0.7)] ring-1 ring-[#F6E7C4]">
          <span className="grid h-12 w-12 shrink-0 place-items-center rounded-[16px] text-[22px]" style={{ background: "linear-gradient(160deg,#FFF6DB,#FFE7A3)" }} aria-hidden="true">{e.icon}</span>
          <span className="min-w-0 flex-1">
            <span className="block break-words text-[14px] font-semibold leading-snug" style={{ color: PP_INK }}>{ppText(e.texts, lang)}</span>
            {limit(e.limit) && <span className="mt-0.5 inline-block rounded-full bg-[#FBEFE6] px-2 py-0.5 text-[11px] font-bold" style={{ color: PP_SOFT }}>{limit(e.limit)}</span>}
          </span>
          <span className="shrink-0 rounded-full px-3 py-1.5 text-[15px] font-extrabold tabular-nums text-white" style={{ background: GOLD_GRAD, boxShadow: "0 8px 16px -10px #B07800" }}>+{fmt(e.points)}</span>
        </li>
      ))}
    </ul>
  );
}

// ─── ÉCHANGER ─────────────────────────────────────────────────────────────
export function RewardsGrid({ rewards, lang, t, fmt, spendable, claimed, loggedIn, busyId, onRedeem }: {
  rewards: Pp607Reward[];
  lang: string;
  t: (k: string) => string;
  fmt: (n: number) => string;
  /** null = page publique : coût seul, pas de bouton. */
  spendable: number | null;
  claimed?: Set<string>;
  loggedIn?: boolean;
  busyId?: string | null;
  onRedeem?: (r: Pp607Reward) => void;
}) {
  const sorted = [...rewards].sort((a, b) => a.cost - b.cost);
  return (
    <ul className="flex flex-wrap gap-3" data-pp-rewards-grid="">
      {sorted.map((r) => {
        const used = !!(r.once && claimed?.has(r.id));
        const missing = spendable == null ? 0 : Math.max(0, r.cost - spendable);
        const can = !!loggedIn && !used && missing === 0;
        const pctTo = spendable == null ? 0 : Math.min(100, (spendable / r.cost) * 100);
        return (
          <li key={r.id} className="flex min-w-[min(100%,300px)] grow basis-[400px] flex-col gap-3 rounded-[24px] p-4 ring-1 ring-[#F6E7C4]" style={{ background: can ? "linear-gradient(160deg,#FFF6DB,#FFFFFF 60%)" : "#FFFFFF", boxShadow: can ? "0 16px 32px -20px rgba(183,121,31,0.8)" : "0 12px 26px -22px rgba(183,121,31,0.6)" }}>
            <div className="flex items-center gap-3">
              <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full text-[22px]" style={{ background: "linear-gradient(160deg,#FFF6DB,#FFE7A3)" }} aria-hidden="true">{r.icon}</span>
              <span className="min-w-0 flex-1 break-words text-[14px] font-bold leading-snug" style={{ color: PP_INK }}>{ppText(r.texts, lang)}</span>
              <span className="shrink-0 text-[15px] font-extrabold tabular-nums" style={{ color: PP_GOLD }}>{fmt(r.cost)} pts</span>
            </div>
            {spendable != null && (
              <div className="flex items-center gap-3">
                <div className="h-2 flex-1 overflow-hidden rounded-full bg-[#FBEFE6]" aria-hidden="true">
                  <div className="h-full rounded-full" style={{ width: `${used ? 100 : pctTo}%`, background: used ? "#16A34A" : GOLD_GRAD }} />
                </div>
                <button
                  type="button"
                  disabled={!onRedeem || busyId === r.id || used || (!!loggedIn && missing > 0)}
                  onClick={() => onRedeem?.(r)}
                  className="min-h-[44px] shrink-0 rounded-full px-4 text-[13px] font-extrabold transition active:scale-[0.97] disabled:cursor-not-allowed"
                  style={used ? { background: "#E8F8EE", color: "#0F5C2B" } : can || !loggedIn ? { background: GOLD_GRAD, color: "#fff", boxShadow: "0 8px 18px -10px #B07800" } : { background: "#FBEFE6", color: PP_SOFT }}
                >
                  {used ? `✓ ${t("pp607_btn_used")}` : busyId === r.id ? "…" : !loggedIn ? t("pp607_btn_login") : missing > 0 ? t("pp607_btn_missing").replace("{pts}", fmt(missing)) : t("pp607_btn_redeem")}
                </button>
              </div>
            )}
          </li>
        );
      })}
    </ul>
  );
}

// ─── PELUCHES ─────────────────────────────────────────────────────────────
const PLUSH = ["teddy", "bunny", "kitty", "puppy", "fox"];
export function PlushShowcase({ t, counts, golden, children }: { t: (k: string) => string; counts?: Record<string, number> | null; golden?: number; children?: ReactNode }) {
  return (
    <div>
      <ul className="grid grid-cols-3 gap-2.5 sm:grid-cols-6 sm:gap-3" data-pp-plush-grid="">
        {PLUSH.map((ty, i) => {
          const n = counts ? counts[ty] ?? 0 : null;
          return (
            <li key={ty} className="flex flex-col items-center rounded-[22px] bg-white px-2 pb-3 pt-2 text-center" style={{ boxShadow: n ? "inset 0 0 0 2px #16A34A, 0 12px 24px -16px #16A34A" : "inset 0 0 0 1.5px #BFE8CC, 0 12px 24px -18px #16A34A" }} data-plush-type={ty} data-count={n ?? undefined}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={`/plush/${ty}.png`} alt="" width={96} height={96} className="h-20 w-20 object-contain drop-shadow-[0_6px_10px_rgba(22,163,74,0.35)] sm:h-24 sm:w-24" />
              <span className="mt-1 break-words text-[12px] font-extrabold leading-tight" style={{ color: PP_INK }}>{t(`help607_plush_names_${i + 1}`)}</span>
              {n != null && <span className="mt-0.5 rounded-full px-2 py-0.5 text-[12px] font-extrabold tabular-nums" style={n ? { background: "#16A34A", color: "#fff" } : { background: "#EFFAF2", color: "#0F5C2B" }}>×{n}</span>}
            </li>
          );
        })}
        <li className="flex flex-col items-center rounded-[22px] px-2 pb-3 pt-2 text-center" style={{ background: "linear-gradient(160deg,#FFF6DB,#FFE7A3)", boxShadow: "inset 0 0 0 2px #E8B54A, 0 12px 24px -14px #B07800" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/plush/teddy_gold.png" alt="" width={96} height={96} className="h-20 w-20 object-contain drop-shadow-[0_6px_10px_rgba(176,120,0,0.45)] sm:h-24 sm:w-24" />
          <span className="mt-1 break-words text-[12px] font-extrabold leading-tight text-[#8A5A00]">{t("help607_plush_gold")}</span>
          {golden != null && <span className="mt-0.5 rounded-full bg-white px-2 py-0.5 text-[12px] font-extrabold tabular-nums text-[#8A5A00]">×{golden}</span>}
        </li>
      </ul>
      {children}
    </div>
  );
}
