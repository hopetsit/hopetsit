"use client";

// 02/10/2026 (607, LEO — « plus joli sur le web », Daniel) : blocs PawPoints
// PARTAGÉS par la page membre (/pawpoints) et la page publique
// (/pawpoints-guide). Design seul : mêmes données (catalogue catalog607 de ZOE),
// mêmes clés, aucune logique d'échange ici (le bouton appelle onRedeem).
//  · Paliers : frise de progression (où j'en suis, barre jusqu'au prochain
//    palier), une icône SVG propre par palier, fond dégradé léger de sa couleur,
//    palier actuel mis en avant, paliers futurs éclaircis (jamais d'opacité :
//    une couleur pâle pleine, sinon elle redevient grise).
//  · Grilles en « flex-wrap + grow » : la dernière rangée s'étire, jamais de
//    carte orpheline seule sur sa ligne, quel que soit le nombre d'éléments.

import type { ReactNode } from "react";
import { ppText, type Pp607Earn, type Pp607Level, type Pp607Reward, type Pp607Texts } from "@/lib/api";

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

/** Couleur d'affichage d'un palier : une couleur presque noire (Légendaire)
 *  ne s'éclaircit jamais (elle deviendrait grise) — onyx plein, accent or. */
function isInk(c: string): boolean {
  const n = parseInt(c.slice(1), 16);
  const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  return Math.max(r, g, b) < 70;
}
function levelColor(c: string, pale: boolean): string {
  if (isInk(c)) return "#231715";
  return pale ? mix(c, "#FFFFFF", 0.45) : c;
}
function tintBase(c: string): string {
  return isInk(c) ? "#E8B54A" : c;
}

/** Icône SVG propre par palier (clé du catalogue) — plus d'emoji répété. */
function LevelIcon({ k, size = 24 }: { k: string; size?: number }) {
  const p = { width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "#fff", strokeWidth: 2, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, "aria-hidden": true };
  switch (k) {
    case "explorer": return <svg {...p}><circle cx="12" cy="12" r="9" /><path d="M15.5 8.5l-2 5-5 2 2-5z" fill="#fff" /></svg>;
    case "contributor": return <svg {...p} fill="#fff" stroke="none"><circle cx="7" cy="10" r="2" /><circle cx="17" cy="10" r="2" /><circle cx="10" cy="6" r="2" /><circle cx="14" cy="6" r="2" /><path d="M12 11.5c-2.6 0-4.6 2.2-4.6 4.2 0 1.3 1 2.3 2.3 2.3.9 0 1.5-.4 2.3-.4s1.4.4 2.3.4c1.3 0 2.3-1 2.3-2.3 0-2-2-4.2-4.6-4.2z" /></svg>;
    case "expert": return <svg {...p} fill="#fff" stroke="none"><path d="M12 2.8l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17.2l-5.6 3 1.1-6.3L2.9 9.5l6.3-.9z" /></svg>;
    case "ambassador": return <svg {...p}><path d="M4 10v4h3l7 4V6l-7 4z" fill="#fff" /><path d="M17.5 9.5a3.5 3.5 0 0 1 0 5" /></svg>;
    case "pawmaster": return <svg {...p}><path d="M7 4h10v4a5 5 0 0 1-10 0z" fill="#fff" /><path d="M7 6H4a3 3 0 0 0 3 4M17 6h3a3 3 0 0 1-3 4M12 13v4M8.5 20h7" /></svg>;
    case "legend": return <svg {...p}><path d="M6 4h12l3 5-9 11L3 9z" fill="#fff" /><path d="M3 9h18M9 4l3 16M15 4l-3 16" stroke="rgba(0,0,0,.18)" /></svg>;
    case "paw_legend": return <svg {...p} fill="#fff" stroke="none"><path d="M2.5 8 7 11.5 12 5l5 6.5L21.5 8l-2 10.5h-15z" /><rect x="4.5" y="19.8" width="15" height="2" rx="1" /></svg>;
    default: return <svg {...p} fill="#fff" stroke="none"><circle cx="12" cy="12" r="6" /></svg>;
  }
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

// ─── PALIERS ──────────────────────────────────────────────────────────────
export function LevelsLadder({ levels, lifetime, lang, perkTexts, t, fmt }: {
  levels: Pp607Level[];
  /** null = page publique (aucun « tu es ici »). */
  lifetime: number | null;
  lang: string;
  perkTexts?: Record<string, Pp607Texts>;
  t: (k: string) => string;
  fmt: (n: number) => string;
}) {
  const sorted = [...levels].sort((a, b) => a.min - b.min);
  const curIdx = lifetime == null ? -1 : sorted.reduce((acc, l, i) => (lifetime >= l.min ? i : acc), -1);
  const next = lifetime == null ? null : sorted.find((l) => l.min > lifetime) ?? null;
  const prevMin = curIdx >= 0 ? sorted[curIdx].min : 0;
  const pct = lifetime == null ? 0 : next ? Math.max(0, Math.min(100, ((lifetime - prevMin) / (next.min - prevMin)) * 100)) : 100;
  // Remplissage de la frise : jusqu'au palier atteint + part vers le suivant.
  const trackPct = lifetime == null || sorted.length < 2 ? 0 : Math.min(100, ((Math.max(curIdx, 0) + (curIdx >= 0 ? pct / 100 : 0)) / (sorted.length - 1)) * 100);
  const state = (i: number) => (curIdx < 0 ? (lifetime == null ? "neutral" : "future") : i < curIdx ? "done" : i === curIdx ? "current" : "future");

  return (
    <div data-pp-ladder="">
      {lifetime != null && (
        <div className="mb-6 rounded-[24px] p-5 md:p-6" style={{ background: `linear-gradient(135deg, ${mix(next?.color ?? sorted[sorted.length - 1]?.color ?? "#B7791F", "#FFFFFF", 0.88)}, #FFFFFF)`, boxShadow: `0 16px 36px -22px ${next?.color ?? "#B7791F"}` }}>
          <div className="flex flex-wrap items-end justify-between gap-2">
            <p className="text-sm font-bold" style={{ color: PP_INK }}>
              {next ? t("pp607_next").replace("{pts}", fmt(Math.max(0, next.min - lifetime))).replace("{level}", ppText(next.texts, lang)) : t("pp607_max")}
            </p>
            <p className="text-[13px] font-extrabold tabular-nums" style={{ color: PP_GOLD }}>{fmt(lifetime)}{next ? ` / ${fmt(next.min)}` : ""} pts</p>
          </div>
          <div className="mt-3 h-3.5 w-full overflow-hidden rounded-full" style={{ background: mix(next?.color ?? "#B7791F", "#FFFFFF", 0.82) }}>
            <div className="h-full rounded-full" style={{ width: `${pct}%`, background: `linear-gradient(90deg, ${curIdx >= 0 ? sorted[curIdx].color : "#F4C04A"}, ${next?.color ?? "#B7791F"})` }} />
          </div>
        </div>
      )}

      {/* Bureau / tablette : frise horizontale, une colonne par palier (aucune orpheline). */}
      <div className="relative hidden md:block">
        <div className="absolute left-[calc(100%/14)] right-[calc(100%/14)] top-7 h-1.5 rounded-full" style={{ background: "#F3E6E1" }} />
        {lifetime != null && <div className="absolute left-[calc(100%/14)] top-7 h-1.5 rounded-full" style={{ width: `calc((100% - 100% / 7) * ${trackPct / 100})`, background: "linear-gradient(90deg,#F4C04A,#B7791F)" }} />}
        <ol className="relative grid gap-2" style={{ gridTemplateColumns: `repeat(${sorted.length}, minmax(0, 1fr))` }}>
          {sorted.map((l, i) => {
            const st = state(i);
            const pale = st === "future";
            const c = levelColor(l.color, pale);
            const tb = tintBase(l.color);
            return (
              <li key={l.key} className="flex min-w-0 flex-col items-center text-center" data-level={l.key} data-state={st}>
                <span className="relative grid h-14 w-14 place-items-center rounded-full" style={{ background: `linear-gradient(160deg, ${mix(c, "#FFFFFF", 0.25)}, ${c})`, border: "3px solid #fff", boxShadow: st === "current" ? `0 0 0 4px ${mix(tb, "#FFFFFF", 0.6)}, 0 10px 20px -8px ${l.color}` : `0 8px 16px -10px ${c}` }}>
                  <LevelIcon k={l.key} size={st === "current" ? 26 : 22} />
                  {st === "done" && <span className="absolute -right-1 -top-1 grid h-5 w-5 place-items-center rounded-full bg-[#16A34A] text-[11px] font-black text-white ring-2 ring-white">✓</span>}
                </span>
                <div className="mt-3 w-full rounded-[18px] px-2 py-3" style={{ background: `linear-gradient(180deg, ${mix(tb, "#FFFFFF", st === "current" ? 0.8 : 0.92)}, #FFFFFF)`, boxShadow: st === "current" ? `inset 0 0 0 2px ${l.color}` : `inset 0 0 0 1px ${mix(tb, "#FFFFFF", 0.7)}` }}>
                  {st === "current" && <span className="mb-1 inline-block rounded-full px-2 py-0.5 text-[10.5px] font-extrabold text-white" style={{ background: l.color }}>{t("ppl607_here")}</span>}
                  <div className="break-words text-[13px] font-extrabold leading-tight" style={{ color: isInk(l.color) ? PP_INK : pale ? mix(l.color, PP_INK, 0.35) : l.color }}>{ppText(l.texts, lang)}</div>
                  <div className="mt-0.5 text-[11.5px] font-bold tabular-nums" style={{ color: PP_SOFT }}>{fmt(l.min)} pts</div>
                  <ul className="mt-2 space-y-1 text-left">
                    {l.perks.map((pk) => (
                      <li key={pk} className="flex items-start gap-1 text-[11.5px] leading-snug" style={{ color: PP_INK }}>
                        <span aria-hidden="true" className="font-black" style={{ color: l.color }}>✓</span>
                        <span className="min-w-0 break-words">{ppText(perkTexts?.[pk], lang) || pk}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </li>
            );
          })}
        </ol>
      </div>

      {/* Téléphone : échelle verticale. */}
      <ol className="relative space-y-3 md:hidden">
        <span aria-hidden="true" className="absolute bottom-6 left-[27px] top-6 w-1.5 rounded-full" style={{ background: "#F3E6E1" }} />
        {sorted.map((l, i) => {
          const st = state(i);
          const pale = st === "future";
          const c = levelColor(l.color, pale);
            const tb = tintBase(l.color);
          return (
            <li key={l.key} className="relative flex items-start gap-3" data-level={l.key} data-state={st}>
              <span className="relative z-[1] grid h-14 w-14 shrink-0 place-items-center rounded-full" style={{ background: `linear-gradient(160deg, ${mix(c, "#FFFFFF", 0.25)}, ${c})`, border: "3px solid #fff", boxShadow: st === "current" ? `0 0 0 4px ${mix(tb, "#FFFFFF", 0.6)}` : `0 8px 16px -10px ${c}` }}>
                <LevelIcon k={l.key} />
                {st === "done" && <span className="absolute -right-1 -top-1 grid h-5 w-5 place-items-center rounded-full bg-[#16A34A] text-[11px] font-black text-white ring-2 ring-white">✓</span>}
              </span>
              <div className="min-w-0 flex-1 rounded-[20px] px-4 py-3" style={{ background: `linear-gradient(135deg, ${mix(tb, "#FFFFFF", st === "current" ? 0.8 : 0.92)}, #FFFFFF)`, boxShadow: st === "current" ? `inset 0 0 0 2px ${l.color}` : `inset 0 0 0 1px ${mix(tb, "#FFFFFF", 0.7)}` }}>
                <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
                  <span className="break-words text-[15px] font-extrabold" style={{ color: isInk(l.color) ? PP_INK : pale ? mix(l.color, PP_INK, 0.35) : l.color }}>{ppText(l.texts, lang)}</span>
                  <span className="text-[12px] font-bold tabular-nums" style={{ color: PP_SOFT }}>{fmt(l.min)} pts</span>
                  {st === "current" && <span className="rounded-full px-2 py-0.5 text-[10.5px] font-extrabold text-white" style={{ background: l.color }}>{t("ppl607_here")}</span>}
                </div>
                <ul className="mt-1.5 space-y-0.5">
                  {l.perks.map((pk) => (
                    <li key={pk} className="flex items-start gap-1.5 text-[13px] leading-snug" style={{ color: PP_INK }}>
                      <span aria-hidden="true" className="font-black" style={{ color: l.color }}>✓</span><span className="min-w-0 break-words">{ppText(perkTexts?.[pk], lang) || pk}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </li>
          );
        })}
      </ol>
    </div>
  );
}

// ─── COMMENT GAGNER ───────────────────────────────────────────────────────
export function EarnGrid({ earn, lang, t, fmt }: { earn: Pp607Earn[]; lang: string; t: (k: string) => string; fmt: (n: number) => string }) {
  const limit = (l: string) => (["each", "once", "daily", "streak"].includes(l) ? t(`pp607_limit_${l}`) : "");
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
