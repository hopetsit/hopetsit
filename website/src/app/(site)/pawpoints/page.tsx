"use client";

// 02/10/2026 (607, LEO) — page PawPoints du tableau de bord, refaite sur le
// catalogue UNIQUE de ZOE (`catalog607` de GET /pawpoints/catalog, 9 langues) :
// aucun barème, palier ni texte de récompense écrit en dur ici. Plus de
// réductions en % (remplacées par des jours offerts et du PawBoost).
// Sections : solde + palier · échanger · ma collection de peluches (PAM,
// GET /plush/collection) · comment gagner · paliers · derniers gains · notes
// d'honnêteté (jamais d'argent). Tous les hooks EN HAUT (piège du 22/09).

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";
import BackLink from "@/components/BackLink";
import {
  getPawCatalog607,
  getMyPawPoints,
  getPlushCollection,
  redeemPawReward,
  getStoredUser,
  ppText,
  ApiError,
  type PawCatalog607,
  type MyPawPoints607,
  type PlushCollection,
  type Pp607Reward,
} from "@/lib/api";

const GOLD = "#B7791F";
const GOLD_BG = "#FFF6DB";
const INK = "#231715";
const SOFT = "#6E4F48";
const PLUSH_TYPES = ["teddy", "bunny", "kitty", "puppy", "fox"];

export default function PawPointsPage() {
  const { t, lang } = useT();
  const [catalog, setCatalog] = useState<PawCatalog607 | null>(null);
  const [mine, setMine] = useState<MyPawPoints607 | null>(null);
  const [plush, setPlush] = useState<PlushCollection | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [loggedIn, setLoggedIn] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const fmt = useCallback((n: number) => { try { return n.toLocaleString(lang); } catch { return String(n); } }, [lang]);

  const refresh = useCallback(async () => {
    const logged = !!getStoredUser();
    setLoggedIn(logged);
    const [c, m, p] = await Promise.all([
      getPawCatalog607(),
      logged ? getMyPawPoints().catch(() => null) : Promise.resolve(null),
      logged ? getPlushCollection() : Promise.resolve(null),
    ]);
    setCatalog(c);
    setMine(m as MyPawPoints607 | null);
    setPlush(p);
    setLoaded(true);
  }, []);
  useEffect(() => { void refresh(); }, [refresh]);

  const lifetime = mine?.lifetime ?? mine?.points ?? 0;
  const spendable = mine?.spendable ?? 0;
  const levels = [...(catalog?.levels ?? [])].sort((a, b) => a.min - b.min);
  const current = [...levels].reverse().find((l) => lifetime >= l.min) ?? null;
  const next = levels.find((l) => l.min > lifetime) ?? null;
  const prevMin = current?.min ?? 0;
  const progress = next ? Math.min(100, Math.max(0, ((lifetime - prevMin) / (next.min - prevMin)) * 100)) : 100;
  const claimed = new Set(mine?.claimedRewardKeys ?? []);
  const earnByKey = new Map((catalog?.earn ?? []).map((e) => [e.key, e]));
  const limitLabel = (l: string) => (["each", "once", "daily", "streak"].includes(l) ? t(`pp607_limit_${l}`) : "");

  async function onRedeem(r: Pp607Reward) {
    if (!loggedIn) { window.location.href = `/login?redirect=${encodeURIComponent("/pawpoints")}`; return; }
    const label = ppText(r.texts, lang);
    if (spendable < r.cost) return;
    if (!window.confirm(t("pp607_confirm").replace("{cost}", fmt(r.cost)).replace("{label}", label))) return;
    setBusyId(r.id);
    setMsg(null);
    try {
      await redeemPawReward(r.id);
      setMsg({ ok: true, text: t("pp607_done").replace("{label}", label) });
      await refresh();
    } catch (e) {
      const code = e instanceof ApiError ? String((e.details as { code?: string; error?: string } | undefined)?.code || (e.details as { error?: string } | undefined)?.error || "") : "";
      setMsg({
        ok: false,
        text: code === "REWARD_RETIRED" ? t("pp607_retired") : code === "ALREADY_CLAIMED" ? t("pp607_btn_used") : t("pp607_error"),
      });
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="mx-auto max-w-5xl px-4 py-10 md:py-14">
      <div className="mb-6">
        <BackLink href="/dashboard" label={t("nav_dashboard")} />
      </div>

      {/* ── EN-TÊTE ── */}
      <header className="text-center">
        <div className="mx-auto mb-3 grid h-16 w-16 place-items-center rounded-[20px] text-4xl" style={{ background: GOLD_BG }}>🐾</div>
        <h1 className="font-display text-4xl font-extrabold tracking-tight md:text-5xl" style={{ color: INK }}>PawPoints</h1>
        <p className="mx-auto mt-3 max-w-2xl text-base leading-relaxed md:text-lg" style={{ color: SOFT }}>{t("pp607_hero")}</p>
      </header>

      {/* ── SOLDE + PALIER (connecté) ── */}
      {loggedIn && mine && (
        <section className="mt-8 grid gap-3 md:grid-cols-3" data-pp-balance="">
          <div className="rounded-[22px] p-5 text-center ring-1 ring-[#F1D9A6]" style={{ background: GOLD_BG }}>
            <div className="text-[13px] font-bold uppercase tracking-[0.05em]" style={{ color: GOLD }}>{t("pp607_spendable")}</div>
            <div className="mt-1 font-display text-4xl font-extrabold tabular-nums" style={{ color: INK }}>{fmt(spendable)}</div>
          </div>
          <div className="rounded-[22px] bg-white p-5 text-center ring-1 ring-[#F3E6E1]">
            <div className="text-[13px] font-bold uppercase tracking-[0.05em]" style={{ color: SOFT }}>{t("pp607_lifetime")}</div>
            <div className="mt-1 font-display text-4xl font-extrabold tabular-nums" style={{ color: INK }}>{fmt(lifetime)}</div>
          </div>
          <div className="rounded-[22px] bg-white p-5 ring-1 ring-[#F3E6E1]">
            <div className="flex items-center justify-between gap-2">
              <span className="text-[13px] font-bold uppercase tracking-[0.05em]" style={{ color: SOFT }}>{t("pp607_level")}</span>
              {current && <span className="text-sm font-extrabold" style={{ color: current.color }}>{current.emoji} {ppText(current.texts, lang)}</span>}
            </div>
            <div className="mt-3 h-3 w-full overflow-hidden rounded-full bg-[#FBEFE6]">
              <div className="h-full rounded-full" style={{ width: `${progress}%`, background: `linear-gradient(90deg, #F4C04A, ${GOLD})` }} />
            </div>
            <p className="mt-2 text-[13px] font-semibold" style={{ color: INK }}>
              {next ? t("pp607_next").replace("{pts}", fmt(Math.max(0, next.min - lifetime))).replace("{level}", ppText(next.texts, lang)) : t("pp607_max")}
            </p>
            {current && current.bonusPct > 0 && <p className="mt-1 text-[12px] font-bold" style={{ color: GOLD }}>{t("pp607_bonus").replace("{pct}", String(current.bonusPct))}</p>}
          </div>
        </section>
      )}

      {loaded && !loggedIn && (
        <p className="mx-auto mt-8 max-w-md rounded-[20px] bg-white p-5 text-center text-sm ring-1 ring-[#F3E6E1]" style={{ color: SOFT }}>
          <Link href={`/login?redirect=${encodeURIComponent("/pawpoints")}`} className="font-bold underline" style={{ color: GOLD }}>{t("pp607_btn_login")}</Link>{" · "}{t("pp607_login")}
        </p>
      )}

      {msg && (
        <div role="status" className="mx-auto mt-5 max-w-2xl rounded-2xl px-4 py-3 text-center text-sm font-semibold" style={msg.ok ? { background: "#E8F8EE", color: "#0F5C2B" } : { background: "#FDECE8", color: "#9E1F0B" }}>{msg.text}</div>
      )}

      {/* ── ÉCHANGER ── */}
      {catalog && (
        <section className="mt-12" data-pp-rewards="">
          <h2 className="font-display text-2xl font-extrabold" style={{ color: INK }}>{t("pp607_exchange")}</h2>
          <ul className="mt-5 grid gap-3 md:grid-cols-2">
            {[...catalog.rewards].sort((a, b) => a.cost - b.cost).map((r) => {
              const used = r.once && claimed.has(r.id);
              const missing = Math.max(0, r.cost - spendable);
              const can = loggedIn && !used && missing === 0;
              return (
                <li key={r.id} className="flex items-center gap-3 rounded-[20px] bg-white p-4 ring-1 ring-[#F3E6E1]">
                  <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full text-2xl" style={{ background: GOLD_BG }} aria-hidden="true">{r.icon}</span>
                  <div className="min-w-0 flex-1">
                    <div className="break-words text-sm font-bold leading-snug" style={{ color: INK }}>{ppText(r.texts, lang)}</div>
                    <div className="mt-0.5 text-[13px] font-extrabold tabular-nums" style={{ color: GOLD }}>{fmt(r.cost)} pts</div>
                  </div>
                  <button
                    type="button"
                    disabled={busyId === r.id || used || (loggedIn && missing > 0)}
                    onClick={() => void onRedeem(r)}
                    className="min-h-[44px] shrink-0 rounded-full px-4 text-xs font-bold transition disabled:cursor-not-allowed"
                    style={can || !loggedIn ? { background: "linear-gradient(165deg,#F4C04A,#D99A0B 55%,#B07800)", color: "#fff" } : { background: "#FBEFE6", color: SOFT }}
                  >
                    {used ? t("pp607_btn_used") : busyId === r.id ? "…" : !loggedIn ? t("pp607_btn_login") : missing > 0 ? t("pp607_btn_missing").replace("{pts}", fmt(missing)) : t("pp607_btn_redeem")}
                  </button>
                </li>
              );
            })}
          </ul>
        </section>
      )}

      {/* ── MA COLLECTION DE PELUCHES (PAM) ── */}
      {loggedIn && (
        <section className="mt-12 rounded-[26px] p-5 ring-1 ring-[#BFE8CC] md:p-7" style={{ background: "#EFFAF2" }} data-pp-plush="">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="font-display text-2xl font-extrabold" style={{ color: "#0F5C2B" }}>{ppText(catalog?.collection?.texts.title, lang) || t("plush607_collection_title")} 🧸</h2>
            {plush && <span className="rounded-full bg-white px-3 py-1 text-[13px] font-bold" style={{ color: "#0F5C2B" }}>{t("plush607_total").replace("{count}", String(plush.total))}</span>}
          </div>
          <p className="mt-1 text-sm" style={{ color: "#23352A" }}>{t("plush607_collection_sub")}</p>
          <ul className="mt-4 grid grid-cols-5 gap-2 sm:gap-3">
            {PLUSH_TYPES.map((ty) => {
              const n = plush?.counts?.[ty] ?? 0;
              return (
                <li key={ty} className="flex flex-col items-center rounded-[18px] bg-white p-2 text-center sm:p-3" style={{ boxShadow: n > 0 ? "inset 0 0 0 2px #16A34A" : "inset 0 0 0 1.5px #BFE8CC" }} data-plush-type={ty} data-count={n}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={`/plush/${ty}.png`} alt="" width={56} height={56} className="h-12 w-12 object-contain sm:h-14 sm:w-14" />
                  <span className="mt-1 break-words text-[11px] font-bold leading-tight sm:text-xs" style={{ color: INK }}>{t(`plush607_type_${ty}`)}</span>
                  <span className="text-[12px] font-extrabold tabular-nums" style={{ color: n > 0 ? "#15803D" : SOFT }}>×{n}</span>
                </li>
              );
            })}
          </ul>
          {plush && (plush.golden > 0 || plush.streak > 0 || plush.badges.includes("collector")) && (
            <div className="mt-3 flex flex-wrap gap-2 text-[13px] font-bold">
              {plush.badges.includes("collector") && <span className="rounded-full px-3 py-1 text-white" style={{ background: "linear-gradient(165deg,#F4C04A,#B07800)" }}>🏅 {t("plush607_collector_badge")}</span>}
              {plush.golden > 0 && <span className="rounded-full px-3 py-1" style={{ background: GOLD_BG, color: GOLD }}>🌟 {t("plush607_golden_count").replace("{count}", String(plush.golden))}</span>}
              {plush.streak > 0 && <span className="rounded-full bg-white px-3 py-1" style={{ color: "#0F5C2B" }}>📅 {t("plush607_streak").replace("{days}", String(plush.streak))}</span>}
            </div>
          )}
          {plush && plush.total === 0 && <p className="mt-3 text-sm font-semibold" style={{ color: "#0F5C2B" }}>{t("plush607_collection_empty")}</p>}
          <p className="mt-3 text-[12px] leading-snug" style={{ color: "#23352A" }}>{t("plush607_rules")}</p>
        </section>
      )}

      {/* ── COMMENT GAGNER ── */}
      {catalog && (
        <section className="mt-12" data-pp-earn="">
          <h2 className="font-display text-2xl font-extrabold" style={{ color: INK }}>{t("pp607_earn")}</h2>
          <ul className="mt-5 grid gap-3 sm:grid-cols-2">
            {catalog.earn.map((e) => (
              <li key={e.key} className="flex items-center gap-3 rounded-[20px] bg-white p-4 ring-1 ring-[#F3E6E1]">
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-[14px] text-xl" style={{ background: GOLD_BG }} aria-hidden="true">{e.icon}</span>
                <span className="min-w-0 flex-1">
                  <span className="block break-words text-sm font-semibold leading-snug" style={{ color: INK }}>{ppText(e.texts, lang)}</span>
                  {limitLabel(e.limit) && <span className="block text-[12px]" style={{ color: SOFT }}>{limitLabel(e.limit)}</span>}
                </span>
                <span className="shrink-0 text-lg font-extrabold tabular-nums" style={{ color: GOLD }}>+{fmt(e.points)}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      {/* ── PALIERS ── */}
      {levels.length > 0 && (
        <section className="mt-12" data-pp-levels="">
          <h2 className="font-display text-2xl font-extrabold" style={{ color: INK }}>{t("pp607_levels")}</h2>
          <ul className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {levels.map((l) => {
              const reached = loggedIn && lifetime >= l.min;
              return (
                <li key={l.key} className="rounded-[20px] bg-white p-4" style={{ boxShadow: `inset 0 0 0 ${reached ? 2 : 1}px ${reached ? l.color : "#F3E6E1"}` }}>
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
                        <span aria-hidden="true" style={{ color: l.color }}>✓</span>
                        <span className="min-w-0 break-words">{ppText(catalog?.perkTexts?.[p], lang) || p}</span>
                      </li>
                    ))}
                  </ul>
                </li>
              );
            })}
          </ul>
        </section>
      )}

      {/* ── DERNIERS GAINS ── */}
      {loggedIn && mine?.history && mine.history.length > 0 && (
        <section className="mt-12" data-pp-history="">
          <h2 className="font-display text-2xl font-extrabold" style={{ color: INK }}>{t("pp607_history")}</h2>
          <ul className="mt-4 divide-y divide-[#F3E6E1] rounded-[20px] bg-white ring-1 ring-[#F3E6E1]">
            {mine.history.slice(0, 20).map((h, i) => {
              const e = earnByKey.get(h.key);
              let when = "";
              try { when = new Date(h.at).toLocaleDateString(lang, { day: "numeric", month: "short" }); } catch { /* */ }
              return (
                <li key={`${h.key}-${i}`} className="flex items-center gap-3 px-4 py-3">
                  <span aria-hidden="true" className="text-lg">{e?.icon ?? "🐾"}</span>
                  <span className="min-w-0 flex-1 break-words text-sm" style={{ color: INK }}>{e ? ppText(e.texts, lang) : h.key}</span>
                  <span className="shrink-0 text-[12px]" style={{ color: SOFT }}>{when}</span>
                  <span className="shrink-0 text-sm font-extrabold tabular-nums" style={{ color: GOLD }}>+{fmt(h.credited ?? h.points)}</span>
                </li>
              );
            })}
          </ul>
        </section>
      )}

      {/* ── HONNÊTETÉ ── (textes du catalogue) */}
      {catalog?.notes && (
        <section className="mt-12 space-y-2 rounded-[22px] bg-[#FFF8F3] p-5 ring-1 ring-[#F3E6E1]" data-pp-notes="">
          {Object.values(catalog.notes).map((n, i) => (
            <p key={i} className="flex items-start gap-2 text-[13px] leading-snug" style={{ color: INK }}>
              <span aria-hidden="true">🐾</span><span className="min-w-0">{ppText(n, lang)}</span>
            </p>
          ))}
        </section>
      )}

      <div className="mt-10 text-center">
        <Link href="/map" className="inline-flex min-h-[48px] items-center gap-2 rounded-full px-7 text-sm font-bold text-white" style={{ background: "linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C)" }}>
          {t("cta_open_pawmap")} →
        </Link>
      </div>
    </div>
  );
}
