"use client";

// 02/10/2026 (607, LEO) — page PawPoints du tableau de bord, refaite sur le
// catalogue UNIQUE de ZOE (`catalog607` de GET /pawpoints/catalog, 9 langues) :
// aucun barème, palier ni texte de récompense écrit en dur ici. Plus de
// réductions en % (remplacées par des jours offerts et du PawBoost).
// Ordre (aligné sur l'app, ZOE 02/10) : solde + palier · comment gagner ·
// échanger · collection de peluches · « ils ne s'achètent pas » · paliers ·
// derniers gains. Tous les hooks EN HAUT (piège du 22/09).

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";
import BackLink from "@/components/BackLink";
import { PlushVideo } from "@/components/PlushVideo";
import { EarnGrid, RewardsGrid, PlushShowcase, PpTitle } from "@/components/PawPointsSections";
import { RankProgress611, RanksLadder611 } from "@/components/Rank611";
import { parseRank611 } from "@/lib/ranks611";
import {
  getPawCatalog607,
  getMyPawPoints,
  getPawPointsHistory611,
  getPlushCollection,
  redeemPawReward,
  getStoredUser,
  ppText,
  ApiError,
  type PawCatalog607,
  type MyPawPoints607,
  type PlushCollection,
  type Pp607Reward,
  type PawHistory611,
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
  const [hist, setHist] = useState<PawHistory611 | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [loggedIn, setLoggedIn] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const fmt = useCallback((n: number) => { try { return n.toLocaleString(lang); } catch { return String(n); } }, [lang]);

  const refresh = useCallback(async () => {
    const logged = !!getStoredUser();
    setLoggedIn(logged);
    const [c, m, p, h] = await Promise.all([
      getPawCatalog607(),
      logged ? getMyPawPoints().catch(() => null) : Promise.resolve(null),
      logged ? getPlushCollection() : Promise.resolve(null),
      logged ? getPawPointsHistory611() : Promise.resolve(null),
    ]);
    setCatalog(c);
    setMine(m as MyPawPoints607 | null);
    setPlush(p);
    setHist(h);
    setLoaded(true);
  }, []);
  useEffect(() => { void refresh(); }, [refresh]);

  const lifetime = mine?.lifetime ?? mine?.points ?? 0;
  const spendable = mine?.spendable ?? 0;
  // 04/10 (611) — UN SEUL système : les 5 rangs envoyés par le serveur
  // (`rank` de /pawpoints/me, `ranks611` du catalogue). L'ancien palier à
  // 7 niveaux + bonus en % n'est plus lu. Ancien serveur → rien d'affiché.
  const myRank = parseRank611(mine?.rank);
  const claimed = new Set(mine?.claimedRewardKeys ?? []);
  const earnByKey = new Map((catalog?.earn ?? []).map((e) => [e.key, e]));
  const limitLabel = (l: string) => (["each", "once", "daily", "daily2", "streak"].includes(l) ? t(`pp607_limit_${l}`) : "");

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

      {/* ── SOLDE + MON RANG (connecté) ── */}
      {loggedIn && mine && (
        <section className="mt-8 grid gap-3 md:grid-cols-2" data-pp-balance="">
          <div className="rounded-[22px] p-5 text-center ring-1 ring-[#F1D9A6]" style={{ background: GOLD_BG }}>
            <div className="text-[13px] font-bold uppercase tracking-[0.05em]" style={{ color: GOLD }}>{t("pp607_spendable")}</div>
            <div className="mt-1 font-display text-4xl font-extrabold tabular-nums" style={{ color: INK }}>{fmt(spendable)}</div>
          </div>
          <div className="rounded-[22px] bg-white p-5 text-center ring-1 ring-[#F3E6E1]">
            <div className="text-[13px] font-bold uppercase tracking-[0.05em]" style={{ color: SOFT }}>{t("pp607_lifetime")}</div>
            <div className="mt-1 font-display text-4xl font-extrabold tabular-nums" style={{ color: INK }}>{fmt(lifetime)}</div>
          </div>
          {/* Mon rang : pleine largeur sous les deux soldes (lisible à 768 px). */}
          <RankProgress611 rank={myRank} className="md:col-span-2" />
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

      {/* ── COMMENT GAGNER ── (02/10 : cartes partagées, PawPointsSections) */}
      {catalog && (
        <section className="mt-12" data-pp-earn="">
          <PpTitle>{t("pp607_earn")}</PpTitle>
          <EarnGrid earn={catalog.earn} lang={lang} t={t} fmt={fmt} />
        </section>
      )}

      {/* ── ÉCHANGER ── */}
      {catalog && (
        <section className="mt-12" data-pp-rewards="">
          <PpTitle>{t("pp607_exchange")}</PpTitle>
          <RewardsGrid rewards={catalog.rewards} lang={lang} t={t} fmt={fmt} spendable={spendable} claimed={claimed} loggedIn={loggedIn} busyId={busyId} onRedeem={(r) => void onRedeem(r)} />
        </section>
      )}

      {/* ── MA COLLECTION DE PELUCHES (PAM) ── */}
      {loggedIn && (
        <section className="mt-12 rounded-[28px] p-5 md:p-8" style={{ background: "linear-gradient(160deg,#EFFAF2,#FFFFFF 70%)", boxShadow: "inset 0 0 0 1px #BFE8CC, 0 20px 40px -30px #16A34A" }} data-pp-plush="">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
            <h2 className="font-display text-2xl font-extrabold tracking-[-0.02em] md:text-[28px]" style={{ color: "#0F5C2B" }}>{ppText(catalog?.collection?.texts.title, lang) || t("plush607_collection_title")} 🧸</h2>
            {plush && <span className="rounded-full bg-[#16A34A] px-3 py-1 text-[13px] font-extrabold text-white">{t("plush607_total").replace("{count}", String(plush.total))}</span>}
          </div>
          <div className="mb-5 grid items-center gap-5 md:grid-cols-[minmax(0,1fr)_240px]">
            <p className="text-sm" style={{ color: "#23352A" }}>{t("plush607_collection_sub")}</p>
            {/* 02/10 (609) — vidéo « attraper une peluche ». */}
            <PlushVideo />
          </div>
          <PlushShowcase t={t} counts={plush?.counts ?? {}} golden={plush?.golden ?? 0}>
            {plush && (plush.streak > 0 || plush.badges.includes("collector")) && (
              <div className="mt-4 flex flex-wrap gap-2 text-[13px] font-bold">
                {plush.badges.includes("collector") && <span className="rounded-full px-3 py-1 text-white" style={{ background: "linear-gradient(165deg,#F4C04A,#B07800)" }}>🏅 {t("plush607_collector_badge")}</span>}
                {plush.streak > 0 && <span className="rounded-full bg-white px-3 py-1" style={{ color: "#0F5C2B" }}>📅 {t("plush607_streak").replace("{days}", String(plush.streak))}</span>}
              </div>
            )}
            {plush && plush.total === 0 && <p className="mt-4 text-sm font-semibold" style={{ color: "#0F5C2B" }}>{t("plush607_collection_empty")}</p>}
            <p className="mt-4 whitespace-pre-line rounded-[18px] bg-white p-4 text-[13px] font-semibold leading-relaxed" style={{ color: INK }}>{t("help607_plush_bonus")}</p>
          </PlushShowcase>
        </section>
      )}

      {/* ── HONNÊTETÉ ── (textes du catalogue) */}
      {catalog?.notes && (
        <section className="mt-12 space-y-2 rounded-[24px] bg-[#FFF8F3] p-5 ring-1 ring-[#F3E6E1]" data-pp-notes="">
          {Object.values(catalog.notes).map((n, i) => (
            <p key={i} className="flex items-start gap-2 text-[13px] leading-snug" style={{ color: INK }}>
              <span aria-hidden="true">🐾</span><span className="min-w-0">{ppText(n, lang)}</span>
            </p>
          ))}
        </section>
      )}

      {/* ── LES RANGS ── (611 : Chiot → Légende, honorifiques) */}
      {catalog?.ranks611 && (
        <section className="mt-12" data-pp-ranks="">
          <PpTitle>{t("rank611_title")}</PpTitle>
          <RanksLadder611 catalog={catalog.ranks611} mine={loggedIn ? myRank : null} />
        </section>
      )}

      {/* ── D'OÙ VIENNENT MES POINTS (611) — GET /pawpoints/history : 30 derniers
          gains (date + raison + points) et UNE ligne pour les points d'avant le
          journal. Route absente (ancien serveur) → hist = null → section absente,
          l'ancienne liste « derniers gains » reste. ── */}
      {loggedIn && hist && (
        <section className="mt-12" data-pp-history611="">
          <PpTitle>{t("hist611_title")}</PpTitle>
          {hist.items.length === 0 && hist.beforeJournal === 0 ? (
            <p className="mt-4 rounded-[20px] bg-white px-4 py-4 text-sm ring-1 ring-[#F3E6E1]" style={{ color: SOFT }} data-hist-empty="">{t("hist611_empty")}</p>
          ) : (
            <ul className="mt-4 divide-y divide-[#F3E6E1] rounded-[20px] bg-white ring-1 ring-[#F3E6E1]">
              {hist.items.map((h, i) => {
                let when = "";
                try { when = new Date(h.at).toLocaleDateString(lang, { day: "numeric", month: "short" }); } catch { /* */ }
                const k = `hist611_${h.key}`;
                const label = t(k) !== k ? t(k) : t("hist611_other");
                const neg = h.points < 0;
                return (
                  <li key={`${h.key}-${h.at}-${i}`} className="flex items-center gap-3 px-4 py-3" data-hist-row="">
                    <span className="min-w-0 flex-1 break-words text-sm font-semibold" style={{ color: INK }}>{label}</span>
                    <span className="shrink-0 text-[12px]" style={{ color: SOFT }}>{when}</span>
                    <span className="shrink-0 text-sm font-extrabold tabular-nums" style={{ color: neg ? "#B42318" : GOLD }}>{neg ? "−" : "+"}{fmt(Math.abs(h.points))}</span>
                  </li>
                );
              })}
              {hist.beforeJournal > 0 && (
                <li className="flex items-center gap-3 px-4 py-3" data-hist-before="">
                  <span className="min-w-0 flex-1 break-words text-sm font-semibold" style={{ color: SOFT }}>{t("hist611_before").replace("@n", fmt(hist.beforeJournal))}</span>
                </li>
              )}
            </ul>
          )}
        </section>
      )}

      {/* ── DERNIERS GAINS (ancien serveur seulement) ── */}
      {loggedIn && !hist && mine?.history && mine.history.length > 0 && (
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

      <div className="mt-10 text-center">
        <Link href="/map" className="inline-flex min-h-[48px] items-center gap-2 rounded-full px-7 text-sm font-bold text-white" style={{ background: "linear-gradient(165deg,#E0553F,#C92A12 55%,#A31F0C)" }}>
          {t("cta_open_pawmap")} →
        </Link>
      </div>
    </div>
  );
}
