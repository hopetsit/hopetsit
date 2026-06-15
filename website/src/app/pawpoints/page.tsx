"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  getPawPointsCatalog,
  getMyPawPoints,
  redeemPawReward,
  getStoredUser,
  PawCatalog,
  MyPawPoints,
  ApiError,
} from "@/lib/api";

/**
 * v414 — Daniel : « met à jour sur app et site web car je peux pas voir paw
 * points dans le site web ». Page PawPoints publique : barème (comment gagner),
 * badges, et catalogue de récompenses (lu depuis /pawpoints/catalog → 100%
 * synchronisé avec ce que l'admin édite, sans rebuild). Si connecté : solde +
 * échange. Accent doré E8A00A (cohérent avec PawSpot communautaire).
 */
export default function PawPointsPage() {
  const [catalog, setCatalog] = useState<PawCatalog | null>(null);
  const [mine, setMine] = useState<MyPawPoints | null>(null);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const loggedIn = typeof window !== "undefined" && !!getStoredUser();

  async function refresh() {
    try {
      const c = await getPawPointsCatalog();
      setCatalog(c);
    } catch {
      /* catalogue indispo → on affiche juste le barème statique plus bas */
    }
    if (getStoredUser()) {
      try {
        setMine(await getMyPawPoints());
      } catch {
        /* pas connecté / token expiré → vue publique */
      }
    }
    setLoading(false);
  }

  useEffect(() => {
    refresh();
  }, []);

  async function onRedeem(id: string, cost: number, title: string) {
    if (!loggedIn) {
      window.location.href = "/login";
      return;
    }
    if ((mine?.points ?? 0) < cost) {
      setMsg(`Il te manque des PawPoints pour « ${title} ».`);
      return;
    }
    if (!confirm(`Échanger ${cost} PawPoints contre « ${title} » ?`)) return;
    setBusyId(id);
    setMsg(null);
    try {
      const res = await redeemPawReward(id);
      setMine((m) => (m ? { ...m, points: res.newBalance } : m));
      setMsg(`✓ Échangé ! Nouveau solde : ${res.newBalance} PawPoints.`);
      await refresh();
    } catch (e) {
      setMsg(e instanceof ApiError ? e.message : "Échange impossible.");
    } finally {
      setBusyId(null);
    }
  }

  const gold = "#E8A00A";

  return (
    <div className="mx-auto max-w-4xl px-4 py-14 md:py-20">
      <div className="text-center">
        <div className="mx-auto mb-3 grid h-16 w-16 place-items-center rounded-2xl bg-amber-100 text-4xl">
          🐾
        </div>
        <h1 className="font-display text-4xl font-extrabold tracking-tight md:text-5xl">
          PawPoints
        </h1>
        <p className="mx-auto mt-3 max-w-2xl text-lg text-ink-muted">
          Gagne des PawPoints en faisant vivre la communauté PawMap, puis échange-les
          contre des récompenses.
        </p>
      </div>

      {/* Mon solde (si connecté) */}
      {loggedIn && mine && (
        <div className="mx-auto mt-8 max-w-md rounded-3xl border-2 border-amber-300 bg-gradient-to-b from-amber-50 to-white p-6 text-center shadow-card">
          <p className="text-sm font-semibold text-ink-muted">Mon solde</p>
          <p className="mt-1 text-5xl font-extrabold" style={{ color: gold }}>
            {mine.points}
            <span className="ml-2 text-lg font-bold text-ink-muted">PawPoints</span>
          </p>
          <div className="mt-3 flex flex-wrap items-center justify-center gap-2 text-sm">
            {mine.badge ? (
              <span className="rounded-full bg-amber-100 px-3 py-1 font-semibold text-amber-800">
                {mine.badge.emoji} {mine.badge.key}
              </span>
            ) : (
              <span className="text-ink-muted">Pas encore de badge</span>
            )}
            {mine.nextBadge && (
              <span className="text-xs text-ink-muted">
                Prochain : {mine.nextBadge.emoji} à {mine.nextBadge.min} pts
              </span>
            )}
          </div>
          {mine.isGoldCreator && (
            <p className="mt-2 text-xs font-semibold text-amber-700">
              🥇 Gold Creator — empreinte dorée sur tous tes spots !
            </p>
          )}
        </div>
      )}

      {!loggedIn && (
        <div className="mx-auto mt-8 max-w-md rounded-2xl border border-ink/10 bg-white p-5 text-center text-sm text-ink-muted shadow-card">
          <Link href="/login" className="font-semibold text-amber-700 underline">
            Connecte-toi
          </Link>{" "}
          pour voir ton solde et échanger tes points.
        </div>
      )}

      {msg && (
        <div className="mx-auto mt-5 max-w-md rounded-xl bg-amber-50 px-4 py-3 text-center text-sm text-amber-800">
          {msg}
        </div>
      )}

      {/* Comment gagner */}
      <section className="mt-14">
        <h2 className="text-center font-display text-2xl font-extrabold">
          Comment gagner des points ?
        </h2>
        <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-2">
          {(catalog?.earnRules ?? []).map((r) => (
            <div
              key={r.key}
              className="flex items-center gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card"
            >
              <span className="grid h-11 w-11 place-items-center rounded-xl bg-amber-50 text-xl">
                {r.icon}
              </span>
              <span className="flex-1 text-sm font-medium text-ink">{r.label}</span>
              <span className="text-lg font-extrabold" style={{ color: gold }}>
                +{r.points}
              </span>
            </div>
          ))}
        </div>
      </section>

      {/* Badges */}
      {catalog?.badges?.length ? (
        <section className="mt-14">
          <h2 className="text-center font-display text-2xl font-extrabold">Badges</h2>
          <div className="mt-6 flex flex-wrap justify-center gap-3">
            {catalog.badges.map((b) => (
              <div
                key={b.key}
                className="rounded-2xl border border-ink/5 bg-white px-5 py-4 text-center shadow-card"
              >
                <div className="text-3xl">{b.emoji}</div>
                <div className="mt-1 text-sm font-bold capitalize text-ink">{b.key}</div>
                <div className="text-xs text-ink-muted">{b.min} pts</div>
              </div>
            ))}
          </div>
          {catalog.goldCreatorMin > 0 && (
            <p className="mx-auto mt-4 max-w-xl text-center text-xs text-ink-muted">
              🥇 À partir de {catalog.goldCreatorMin} pts, tu deviens <strong>Gold Creator</strong> :
              empreinte dorée sur tous tes PawSpots.
            </p>
          )}
        </section>
      ) : null}

      {/* Récompenses */}
      <section className="mt-14">
        <h2 className="text-center font-display text-2xl font-extrabold">Récompenses 🎁</h2>
        {loading ? (
          <p className="mt-6 text-center text-ink-muted">Chargement…</p>
        ) : catalog?.rewards?.length ? (
          <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2">
            {catalog.rewards.map((rw) => {
              const affordable = (mine?.points ?? 0) >= rw.cost;
              return (
                <div
                  key={rw.id}
                  className="flex flex-col rounded-2xl border border-ink/5 bg-white p-5 shadow-card"
                >
                  <div className="flex items-start gap-3">
                    <span className="grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-amber-50 text-2xl">
                      {rw.icon}
                    </span>
                    <div className="min-w-0 flex-1">
                      <h3 className="font-bold text-ink">{rw.title}</h3>
                      {rw.valueLabel && (
                        <span className="mt-0.5 inline-block rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-800">
                          {rw.valueLabel}
                        </span>
                      )}
                      {rw.description && (
                        <p className="mt-1 text-sm text-ink-muted">{rw.description}</p>
                      )}
                    </div>
                  </div>
                  <div className="mt-4 flex items-center justify-between">
                    <span className="text-xl font-extrabold" style={{ color: gold }}>
                      {rw.cost} <span className="text-sm font-bold text-ink-muted">pts</span>
                    </span>
                    <button
                      disabled={busyId === rw.id || rw.soldOut}
                      onClick={() => onRedeem(rw.id, rw.cost, rw.title)}
                      className={
                        "rounded-full px-5 py-2 text-sm font-semibold transition disabled:cursor-not-allowed " +
                        (rw.soldOut
                          ? "bg-ink/10 text-ink-muted"
                          : loggedIn && !affordable
                            ? "bg-amber-100 text-amber-700"
                            : "bg-amber-500 text-white hover:brightness-110")
                      }
                    >
                      {rw.soldOut
                        ? "Épuisé"
                        : busyId === rw.id
                          ? "…"
                          : loggedIn
                            ? affordable
                              ? "Échanger"
                              : "Pas assez"
                            : "Se connecter"}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <p className="mt-6 text-center text-ink-muted">
            Les récompenses arrivent bientôt — reviens vite !
          </p>
        )}
      </section>

      <div className="mt-16 text-center">
        <Link
          href="/pawmap"
          className="inline-block rounded-full bg-amber-500 px-7 py-3 text-sm font-semibold text-white hover:brightness-110"
        >
          Découvrir la PawMap →
        </Link>
      </div>
    </div>
  );
}
