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
  PawSubReward,
  ApiError,
} from "@/lib/api";

/**
 * v416 — Daniel : refonte PawPoints (design fourni). Stats, barre de niveau,
 * réductions/mois gratuits sur abonnements (échange auto, 1×/user), 7 niveaux
 * exclusifs avec avantages, objectif Paw Legend, + explications complètes.
 * Accent doré E8A00A. Lecture /pawpoints/catalog + /pawpoints/me.
 */

const GOLD = "#E8A00A";
const fmt = (n: number) => n.toLocaleString("fr-FR");

// Médailles/pièces par tier (cf design).
const TIER_ICON: Record<number, string> = { 1: "🥉", 2: "🥈", 3: "🥇", 4: "🟣", 5: "🟡", 6: "🌸" };

function perkLabel(p: string): string {
  const map: Record<string, string> = {
    badge: "Badge exclusif",
    chests_basic: "Accès aux coffres basiques",
    map_visibility: "Visibilité sur la carte",
    bonus_5: "Points bonus +5%",
    bonus_10: "Points bonus +10%",
    free_pawboost: "PawBoost gratuit",
    legendary_frame: "Cadre légendaire",
    legendary_status: "Statut Légendaire",
    pink_crown: "Couronne rose",
    ultimate: "Avantages ultimes",
  };
  return map[p] || p;
}

export default function PawPointsPage() {
  const [catalog, setCatalog] = useState<PawCatalog | null>(null);
  const [mine, setMine] = useState<MyPawPoints | null>(null);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const loggedIn = typeof window !== "undefined" && !!getStoredUser();

  async function refresh() {
    try {
      setCatalog(await getPawPointsCatalog());
    } catch {
      /* catalogue indispo */
    }
    if (getStoredUser()) {
      try {
        setMine(await getMyPawPoints());
      } catch {
        /* vue publique */
      }
    }
    setLoading(false);
  }

  useEffect(() => {
    refresh();
  }, []);

  async function onRedeem(r: PawSubReward) {
    if (!loggedIn) {
      window.location.href = "/login";
      return;
    }
    if (mine?.claimedRewardKeys?.includes(r.id)) {
      setMsg("Tu as déjà utilisé cette récompense.");
      return;
    }
    if ((mine?.spendable ?? 0) < r.cost) {
      setMsg(`Il te manque ${fmt(r.cost - (mine?.spendable ?? 0))} PawPoints pour cette récompense.`);
      return;
    }
    const label =
      r.kind === "discount"
        ? `-${r.percent}% sur ${r.target}`
        : `${(r.days ?? 0) >= 90 ? "3 mois" : "1 mois"} gratuit(s) ${r.target}`;
    if (!confirm(`Échanger ${fmt(r.cost)} PawPoints contre « ${label} » ?\n(Valable 1 seule fois)`)) return;
    setBusyId(r.id);
    setMsg(null);
    try {
      const res = await redeemPawReward(r.id);
      setMsg(
        res.applied === "fulfilled"
          ? "✓ Récompense activée ! Ton abonnement a été crédité."
          : "✓ Échangé ! La réduction s'appliquera automatiquement à ton prochain achat de cet abonnement.",
      );
      await refresh();
    } catch (e) {
      setMsg(e instanceof ApiError ? e.message : "Échange impossible.");
    } finally {
      setBusyId(null);
    }
  }

  const lifetime = mine?.lifetime ?? 0;
  const levels = catalog?.levels ?? mine?.levels ?? [];
  const level = mine?.level ?? null;
  const nextLevel = mine?.nextLevel ?? null;
  const prevMin = level?.min ?? 0;
  const nextMin = nextLevel?.min ?? prevMin;
  const progress = nextLevel
    ? Math.min(100, Math.max(0, ((lifetime - prevMin) / (nextMin - prevMin)) * 100))
    : 100;
  const pawLegendMin = levels.length ? levels[levels.length - 1].min : 1000000;

  return (
    <div className="mx-auto max-w-4xl px-4 py-12 md:py-16">
      <div className="text-center">
        <div className="mx-auto mb-3 grid h-16 w-16 place-items-center rounded-2xl bg-amber-100 text-4xl">🐾</div>
        <h1 className="font-display text-4xl font-extrabold tracking-tight md:text-5xl">PawPoints</h1>
        <p className="mx-auto mt-3 max-w-2xl text-lg text-ink-muted">
          Gagne des PawPoints en faisant vivre la communauté PawMap, monte de niveau, et échange tes
          points contre des réductions ou des mois gratuits d'abonnement.
        </p>
      </div>

      {/* Stats du haut (connecté) */}
      {loggedIn && mine && (
        <div className="mt-8 grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard emoji="🚩" value={fmt(mine.contributions)} label="signalements" hint="Tes contributions" />
          <StatCard emoji="❤️" value={fmt(mine.spotsLiked)} label="spots aimés" hint="Merci pour ton soutien" />
          <StatCard
            emoji="🏅"
            value={level ? `${level.index}` : "0"}
            label={level ? level.label : "Aucun"}
            hint="Niveau actuel"
            accent
          />
          <StatCard emoji="🪙" value={fmt(mine.spendable)} label="pts à dépenser" hint="Points actuels" accent />
        </div>
      )}

      {/* Barre de progression de niveau */}
      {loggedIn && mine && (
        <div className="mt-4 rounded-2xl border border-ink/10 bg-white p-5 shadow-card">
          <div className="flex items-center justify-between text-sm">
            <span className="font-semibold text-ink">
              {nextLevel
                ? `${fmt(Math.max(0, nextMin - lifetime))} pts pour passer ${nextLevel.label}`
                : "Niveau maximum atteint 👑"}
            </span>
            <span className="text-ink-muted">
              {fmt(lifetime)} {nextLevel ? `/ ${fmt(nextMin)}` : "pts"}
            </span>
          </div>
          <div className="mt-2 h-3 w-full overflow-hidden rounded-full bg-ink/10">
            <div className="h-full rounded-full" style={{ width: `${progress}%`, background: `linear-gradient(90deg, #F472B6, ${GOLD})` }} />
          </div>
          {mine.bonusPct > 0 && (
            <p className="mt-2 text-xs font-semibold text-amber-700">
              ⚡ Bonus de niveau actif : +{mine.bonusPct}% de PawPoints sur chaque gain.
            </p>
          )}
        </div>
      )}

      {!loggedIn && (
        <div className="mx-auto mt-8 max-w-md rounded-2xl border border-ink/10 bg-white p-5 text-center text-sm text-ink-muted shadow-card">
          <Link href="/login" className="font-semibold text-amber-700 underline">Connecte-toi</Link>{" "}
          pour voir ton niveau, ton solde et échanger tes points.
        </div>
      )}

      {msg && (
        <div className="mx-auto mt-5 max-w-2xl rounded-xl bg-amber-50 px-4 py-3 text-center text-sm text-amber-800">{msg}</div>
      )}

      {/* Réductions sur abonnements */}
      <section className="mt-12">
        <h2 className="font-display text-2xl font-extrabold">Réductions sur abonnements</h2>
        <p className="mt-1 text-sm text-ink-muted">
          Échange tes points contre des réductions ou des mois gratuits sur nos abonnements.
          Chaque récompense est utilisable <strong>une seule fois</strong> et s'applique{" "}
          <strong>automatiquement</strong>.
        </p>
        <div className="mt-5 space-y-3">
          {(catalog?.subscriptionRewards ?? []).map((r) => {
            const claimed = mine?.claimedRewardKeys?.includes(r.id);
            const affordable = (mine?.spendable ?? 0) >= r.cost;
            const valueLabel = r.kind === "discount" ? `-${r.percent}%` : (r.days ?? 0) >= 90 ? "3 mois GRATUITS" : "1 mois GRATUIT";
            const free = r.kind === "free_month";
            return (
              <div key={r.id} className="flex items-center gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
                <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-amber-50 text-2xl">{TIER_ICON[r.tier] ?? "🪙"}</span>
                <div className="w-24 shrink-0">
                  <div className="text-base font-extrabold text-ink">{fmt(r.cost)}</div>
                  <div className="text-xs text-ink-muted">pts</div>
                </div>
                <div
                  className={
                    "shrink-0 rounded-xl px-3 py-2 text-center text-sm font-extrabold " +
                    (free ? "bg-violet-600 text-white" : "bg-amber-100 text-amber-800")
                  }
                >
                  {valueLabel}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-semibold text-ink">sur {r.target}</div>
                  <div className="text-xs text-ink-muted">Valable 1 fois</div>
                </div>
                <button
                  disabled={busyId === r.id || claimed}
                  onClick={() => onRedeem(r)}
                  className={
                    "shrink-0 rounded-full px-4 py-2 text-xs font-semibold transition disabled:cursor-not-allowed " +
                    (claimed
                      ? "bg-ink/10 text-ink-muted"
                      : loggedIn && !affordable
                        ? "bg-amber-100 text-amber-700"
                        : "bg-amber-500 text-white hover:brightness-110")
                  }
                >
                  {claimed ? "✓ Utilisé" : busyId === r.id ? "…" : loggedIn ? (affordable ? "Échanger" : "Pas assez") : "Se connecter"}
                </button>
              </div>
            );
          })}
        </div>
      </section>

      {/* Niveaux & paliers exclusifs */}
      <section className="mt-12">
        <h2 className="font-display text-2xl font-extrabold">Niveaux &amp; paliers exclusifs</h2>
        <p className="mt-1 text-sm text-ink-muted">
          Plus tu contribues, plus tu débloques des récompenses uniques et un statut prestigieux.
        </p>
        <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {levels.map((l) => {
            const reached = lifetime >= l.min;
            return (
              <div
                key={l.key}
                className={"rounded-2xl border bg-white p-4 shadow-card " + (reached ? "border-amber-300" : "border-ink/5 opacity-90")}
              >
                <div className="flex items-center gap-3">
                  <span className="grid h-11 w-11 place-items-center rounded-xl text-2xl" style={{ background: l.color + "22" }}>{l.emoji}</span>
                  <div>
                    <div className="text-sm font-bold" style={{ color: l.color }}>
                      {l.index}. {l.label}
                    </div>
                    <div className="text-xs text-ink-muted">{fmt(l.min)} pts {reached ? "· atteint ✓" : ""}</div>
                  </div>
                </div>
                <ul className="mt-3 space-y-1">
                  {l.perks.map((p) => (
                    <li key={p} className="flex items-start gap-2 text-xs text-ink">
                      <span style={{ color: l.color }}>✓</span>
                      {perkLabel(p)}
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </div>

        {/* Objectif Paw Legend */}
        <div className="mt-5 flex flex-col items-center gap-3 rounded-3xl border-2 border-pink-300 bg-gradient-to-r from-pink-50 to-amber-50 p-6 text-center md:flex-row md:text-left">
          <span className="text-4xl">👑</span>
          <div className="flex-1">
            <h3 className="font-display text-lg font-extrabold text-pink-600">
              Atteins {fmt(pawLegendMin)} points pour devenir Paw Legend
            </h3>
            <p className="mt-1 text-sm text-ink-muted">
              Un statut unique, visible sur ton profil, qui donne accès aux avantages les plus exclusifs de PawWorld.
            </p>
          </div>
          {loggedIn && mine && (
            <div className="rounded-2xl bg-white px-5 py-3 text-center shadow-card">
              <div className="text-2xl font-extrabold" style={{ color: GOLD }}>{fmt(lifetime)} pts</div>
              <div className="text-xs text-ink-muted">
                Plus que {fmt(Math.max(0, pawLegendMin - lifetime))} pts
              </div>
            </div>
          )}
        </div>
      </section>

      {/* Comment gagner */}
      <section className="mt-12">
        <h2 className="font-display text-2xl font-extrabold">Comment gagner des points ?</h2>
        <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-2">
          {(catalog?.earnRules ?? mine?.earnRules ?? []).map((r) => (
            <div key={r.key} className="flex items-center gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
              <span className="grid h-11 w-11 place-items-center rounded-xl bg-amber-50 text-xl">{r.icon}</span>
              <span className="flex-1 text-sm font-medium text-ink">{r.label}</span>
              <span className="text-lg font-extrabold" style={{ color: GOLD }}>+{r.points}</span>
            </div>
          ))}
        </div>
        <p className="mx-auto mt-4 max-w-2xl text-center text-xs text-ink-muted">
          🥇 À partir de {fmt(catalog?.goldCreatorMin ?? 1000)} pts, tu deviens <strong>Gold Creator</strong> :
          empreinte dorée sur tous tes PawSpots. Avec un abonnement Paw Premium actif, tous tes gains sont <strong>doublés</strong>.
        </p>
      </section>

      <div className="mt-12 text-center">
        <Link href="/pawmap" className="inline-block rounded-full bg-amber-500 px-7 py-3 text-sm font-semibold text-white hover:brightness-110">
          Découvrir la PawMap →
        </Link>
      </div>
    </div>
  );
}

function StatCard({
  emoji,
  value,
  label,
  hint,
  accent,
}: {
  emoji: string;
  value: string;
  label: string;
  hint: string;
  accent?: boolean;
}) {
  return (
    <div className={"rounded-2xl border bg-white p-4 text-center shadow-card " + (accent ? "border-amber-300" : "border-ink/5")}>
      <div className="text-2xl">{emoji}</div>
      <div className="mt-1 text-2xl font-extrabold" style={accent ? { color: GOLD } : undefined}>{value}</div>
      <div className="text-xs font-semibold text-ink">{label}</div>
      <div className="mt-0.5 text-[11px] text-ink-muted">{hint}</div>
    </div>
  );
}
