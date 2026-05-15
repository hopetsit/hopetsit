"use client";

// v23.1 part 146 — Boutique HoPetSit côté web.
// 3 sections :
//   1. PawFollow Premium (subscriptions) — features Premium : signalements,
//      friends map, chat amplifié, alertes proximité, map-boost credits…
//   2. Profile Boost — mettre son annonce en avant (sitter/walker)
//   3. PawSpot (Map Boost) — apparaître sur la carte avec custom location
//
// Paiement : Airwallex PaymentIntent → flow client_secret + 3DS challenge.
// Pour MVP sur le web, on redirige le user vers l'app mobile (bridge OTT
// pour auto-login) où il peut finaliser le paiement via le SDK Airwallex
// natif. Sur desktop sans app installée, on affiche un message "Téléchargez
// l'app pour finaliser l'achat".

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  ApiError,
  AuthUser,
  BoostPackage,
  BoostStatus,
  cancelSubscription,
  getBoostPackages,
  getBoostStatus,
  getMapBoostPackages,
  getMapBoostStatus,
  getStoredUser,
  getSubscriptionPlans,
  getSubscriptionStatus,
  openInApp,
  resumeSubscription,
  SubscriptionPlan,
  SubscriptionStatus,
} from "@/lib/api";
import { useT } from "@/lib/i18n/LanguageProvider";

type Section = "premium" | "boost" | "mapboost";

export default function BoutiquePage() {
  const { t } = useT();
  const router = useRouter();
  const [user, setUser] = useState<AuthUser | null>(null);

  // Subscriptions
  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [subStatus, setSubStatus] = useState<SubscriptionStatus | null>(null);

  // Profile boost (sitter/walker only)
  const [boostPkgs, setBoostPkgs] = useState<BoostPackage[]>([]);
  const [boostStatus, setBoostStatus] = useState<BoostStatus | null>(null);

  // Map boost
  const [mapBoostPkgs, setMapBoostPkgs] = useState<BoostPackage[]>([]);
  const [mapBoostStatus, setMapBoostStatus] = useState<BoostStatus | null>(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [section, setSection] = useState<Section>("premium");
  const [purchasing, setPurchasing] = useState<string | null>(null);
  const [cancelling, setCancelling] = useState(false);

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace("/login");
      return;
    }
    setUser(u);

    (async () => {
      const errors: string[] = [];
      // Plans / status premium — tout le monde.
      const subResults = await Promise.allSettled([
        getSubscriptionPlans(),
        getSubscriptionStatus(),
      ]);
      if (subResults[0].status === "fulfilled") setPlans(subResults[0].value);
      else errors.push("plans");
      if (subResults[1].status === "fulfilled") setSubStatus(subResults[1].value);
      else errors.push("status");

      // Boost annonce + map boost : sitter/walker only.
      if (u.role === "sitter" || u.role === "walker") {
        const boostResults = await Promise.allSettled([
          getBoostPackages(),
          getBoostStatus(),
          getMapBoostPackages(),
          getMapBoostStatus(),
        ]);
        if (boostResults[0].status === "fulfilled") setBoostPkgs(boostResults[0].value);
        if (boostResults[1].status === "fulfilled") setBoostStatus(boostResults[1].value);
        if (boostResults[2].status === "fulfilled") setMapBoostPkgs(boostResults[2].value);
        if (boostResults[3].status === "fulfilled") setMapBoostStatus(boostResults[3].value);
      }

      if (errors.length === 2) {
        setError("Impossible de charger la boutique. Réessaye plus tard.");
      }
      setLoading(false);
    })();
  }, [router]);

  async function handlePurchase(label: string) {
    // v23.1 part 146 — paiement = redirection vers l'app via bridge OTT.
    // Le SDK Airwallex natif gère le 3DS challenge correctement, alors
    // que le faire dans une webview Next.js demanderait beaucoup plus
    // de code. On laisse l'app finaliser.
    setPurchasing(label);
    setError(null);
    try {
      await openInApp();
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }
      setError(
        e instanceof Error
          ? e.message
          : "Impossible d'ouvrir l'app. Télécharge HoPetSit pour finaliser l'achat.",
      );
    } finally {
      setTimeout(() => setPurchasing(null), 2000);
    }
  }

  async function handleCancelSubscription() {
    if (!confirm("Annuler ton abonnement Premium ? Il restera actif jusqu'à la fin de la période en cours.")) {
      return;
    }
    setCancelling(true);
    try {
      const s = await cancelSubscription();
      setSubStatus(s);
    } catch (e) {
      alert(e instanceof Error ? e.message : "Erreur");
    } finally {
      setCancelling(false);
    }
  }

  async function handleResumeSubscription() {
    setCancelling(true);
    try {
      const s = await resumeSubscription();
      setSubStatus(s);
    } catch (e) {
      alert(e instanceof Error ? e.message : "Erreur");
    } finally {
      setCancelling(false);
    }
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-24 text-center text-ink-muted">
        {t("common_loading")}
      </div>
    );
  }

  const isProvider = user?.role === "sitter" || user?.role === "walker";

  return (
    <div className="mx-auto max-w-5xl px-4 py-12 md:py-16">
      <div className="mb-6">
        <Link href="/dashboard" className="text-sm text-ink-muted hover:text-ink">
          ← Dashboard
        </Link>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        Boutique HoPetSit
      </h1>
      <p className="mt-2 text-ink-muted">
        Active Premium, mets ton annonce en avant ou apparais sur la carte.
      </p>

      {error && (
        <div className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Tabs sections */}
      <div className="mt-8 inline-flex flex-wrap gap-2 rounded-full bg-ink/5 p-1">
        <SectionTab
          label="🌟 Premium"
          active={section === "premium"}
          onClick={() => setSection("premium")}
        />
        {isProvider && (
          <>
            <SectionTab
              label="🚀 Boost annonce"
              active={section === "boost"}
              onClick={() => setSection("boost")}
            />
            <SectionTab
              label="📍 PawSpot"
              active={section === "mapboost"}
              onClick={() => setSection("mapboost")}
            />
          </>
        )}
      </div>

      {section === "premium" && (
        <PremiumSection
          plans={plans}
          status={subStatus}
          onPurchase={handlePurchase}
          onCancel={handleCancelSubscription}
          onResume={handleResumeSubscription}
          purchasing={purchasing}
          cancelling={cancelling}
        />
      )}

      {section === "boost" && isProvider && (
        <BoostSection
          title="🚀 Boost annonce"
          subtitle="Apparais en haut de la liste pour les owners qui cherchent un sitter dans ta zone."
          packages={boostPkgs}
          status={boostStatus}
          onPurchase={handlePurchase}
          purchasing={purchasing}
        />
      )}

      {section === "mapboost" && isProvider && (
        <BoostSection
          title="📍 PawSpot — Visibilité carte"
          subtitle="Ton profil apparaît directement sur la PawMap des owners autour de toi."
          packages={mapBoostPkgs}
          status={mapBoostStatus}
          onPurchase={handlePurchase}
          purchasing={purchasing}
        />
      )}
    </div>
  );
}

function SectionTab({
  label,
  active,
  onClick,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-full px-4 py-2 text-sm font-semibold transition ${
        active ? "bg-white text-ink shadow-sm" : "text-ink-muted hover:text-ink"
      }`}
    >
      {label}
    </button>
  );
}

function PremiumSection({
  plans,
  status,
  onPurchase,
  onCancel,
  onResume,
  purchasing,
  cancelling,
}: {
  plans: SubscriptionPlan[];
  status: SubscriptionStatus | null;
  onPurchase: (label: string) => void;
  onCancel: () => void;
  onResume: () => void;
  purchasing: string | null;
  cancelling: boolean;
}) {
  const isPremium = status?.isPremium;
  const willCancel = status?.cancelAtPeriodEnd;

  return (
    <div className="mt-8 space-y-6">
      {/* Statut actuel */}
      {status && (
        <div
          className={`rounded-2xl p-5 shadow-card ${
            isPremium ? "bg-gradient-to-br from-amber-100 to-amber-50" : "bg-white border border-ink/5"
          }`}
        >
          {isPremium ? (
            <>
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-2xl">🌟</span>
                <h3 className="text-lg font-bold text-ink">Premium actif</h3>
                <span className="rounded-full bg-amber-200 px-2 py-0.5 text-xs font-semibold text-amber-900">
                  {status.plan}
                </span>
              </div>
              {status.currentPeriodEnd && (
                <p className="mt-1 text-sm text-ink-muted">
                  {willCancel ? "Se terminera" : "Renouvellement"} le{" "}
                  {new Date(status.currentPeriodEnd).toLocaleDateString("fr-FR")}
                </p>
              )}
              {typeof status.mapBoostCreditsRemaining === "number" && (
                <p className="mt-1 text-xs text-ink-muted">
                  {status.mapBoostCreditsRemaining} crédit(s) PawSpot inclus restants
                </p>
              )}
              <div className="mt-4">
                {willCancel ? (
                  <button
                    type="button"
                    onClick={onResume}
                    disabled={cancelling}
                    className="rounded-full bg-walker px-5 py-2 text-sm font-semibold text-white disabled:opacity-60"
                  >
                    {cancelling ? "…" : "Réactiver le renouvellement"}
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={onCancel}
                    disabled={cancelling}
                    className="rounded-full border border-ink/15 px-5 py-2 text-sm font-semibold text-ink hover:border-ink/30 disabled:opacity-60"
                  >
                    {cancelling ? "…" : "Annuler le renouvellement"}
                  </button>
                )}
              </div>
            </>
          ) : (
            <p className="text-sm text-ink-muted">
              Tu n&apos;as pas d&apos;abonnement Premium actif. Choisis un plan ci-dessous.
            </p>
          )}
        </div>
      )}

      {/* Plans */}
      {!isPremium && (
        <div className="grid gap-4 md:grid-cols-3">
          {plans.map((plan) => (
            <PlanCard
              key={plan.id}
              plan={plan}
              onPurchase={() => onPurchase(`plan-${plan.id}`)}
              purchasing={purchasing === `plan-${plan.id}`}
              highlighted={plan.id === "yearly"}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function PlanCard({
  plan,
  onPurchase,
  purchasing,
  highlighted,
}: {
  plan: SubscriptionPlan;
  onPurchase: () => void;
  purchasing: boolean;
  highlighted: boolean;
}) {
  const intervalLabel =
    plan.intervalDays >= 365
      ? "/an"
      : plan.intervalDays >= 30
        ? "/mois"
        : `/${plan.intervalDays}j`;
  const planLabels: Record<string, string> = {
    monthly: "Mensuel",
    yearly: "Annuel",
    family: "Famille",
  };

  return (
    <div
      className={`relative rounded-2xl border bg-white p-6 shadow-card transition ${
        highlighted
          ? "border-walker ring-2 ring-walker scale-[1.02]"
          : "border-ink/5"
      }`}
    >
      {highlighted && (
        <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-walker px-3 py-1 text-xs font-semibold text-white">
          Économise 40%
        </span>
      )}
      <h3 className="text-lg font-bold text-ink">
        {plan.name || planLabels[plan.id] || plan.id}
      </h3>
      <p className="mt-3 text-3xl font-extrabold text-walker-dark">
        {plan.amount} {plan.currency}
        <span className="ml-1 text-sm font-medium text-ink-muted">
          {intervalLabel}
        </span>
      </p>
      <ul className="mt-5 space-y-2 text-sm">
        <FeatureLi>Signalements communautaires complets</FeatureLi>
        <FeatureLi>Amis sur la carte + alertes proximité</FeatureLi>
        <FeatureLi>Chat sans limite</FeatureLi>
        {plan.id === "yearly" && (
          <FeatureLi>+12 crédits PawSpot offerts (1/mois)</FeatureLi>
        )}
        {plan.id === "family" && <FeatureLi>Jusqu&apos;à 4 utilisateurs</FeatureLi>}
      </ul>
      <button
        type="button"
        onClick={onPurchase}
        disabled={purchasing}
        className="mt-6 w-full rounded-full bg-walker px-5 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
      >
        {purchasing ? "Ouverture app…" : "S'abonner"}
      </button>
    </div>
  );
}

function BoostSection({
  title,
  subtitle,
  packages,
  status,
  onPurchase,
  purchasing,
}: {
  title: string;
  subtitle: string;
  packages: BoostPackage[];
  status: BoostStatus | null;
  onPurchase: (label: string) => void;
  purchasing: string | null;
}) {
  return (
    <div className="mt-8 space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-ink">{title}</h2>
        <p className="mt-1 text-sm text-ink-muted">{subtitle}</p>
      </div>

      {/* Statut actuel */}
      {status?.isActive && (
        <div className="rounded-2xl bg-gradient-to-br from-amber-100 to-amber-50 p-5 shadow-card">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-2xl">✨</span>
            <h3 className="font-bold text-ink">Boost actif — {status.tier}</h3>
          </div>
          {status.expiresAt && (
            <p className="mt-1 text-sm text-ink-muted">
              Expire le {new Date(status.expiresAt).toLocaleDateString("fr-FR")}
              {typeof status.remainingDays === "number" &&
                ` (${status.remainingDays} jour${status.remainingDays > 1 ? "s" : ""} restant${status.remainingDays > 1 ? "s" : ""})`}
            </p>
          )}
        </div>
      )}

      {/* Packages */}
      <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-4">
        {packages.map((pkg) => (
          <PackageCard
            key={pkg.tier}
            pkg={pkg}
            onPurchase={() => onPurchase(`pkg-${pkg.tier}`)}
            purchasing={purchasing === `pkg-${pkg.tier}`}
          />
        ))}
      </div>
    </div>
  );
}

function PackageCard({
  pkg,
  onPurchase,
  purchasing,
}: {
  pkg: BoostPackage;
  onPurchase: () => void;
  purchasing: boolean;
}) {
  const tierColors: Record<string, string> = {
    bronze: "from-amber-700 to-amber-500",
    silver: "from-slate-500 to-slate-300",
    gold: "from-yellow-500 to-amber-400",
    platinum: "from-violet-700 to-violet-500",
  };
  const tierEmoji: Record<string, string> = {
    bronze: "🥉",
    silver: "🥈",
    gold: "🥇",
    platinum: "💎",
  };

  return (
    <div className="overflow-hidden rounded-2xl border border-ink/5 bg-white shadow-card">
      <div
        className={`bg-gradient-to-br ${tierColors[pkg.tier] || "from-ink to-ink-muted"} p-4 text-white`}
      >
        <div className="flex items-center justify-between">
          <span className="text-2xl">{tierEmoji[pkg.tier] || "✨"}</span>
          <span className="text-xs font-semibold uppercase tracking-wider opacity-90">
            {pkg.tier}
          </span>
        </div>
        <div className="mt-3 text-2xl font-extrabold">
          {pkg.amount} {pkg.currency}
        </div>
        <div className="text-xs opacity-90">{pkg.days} jour{pkg.days > 1 ? "s" : ""}</div>
      </div>
      <div className="p-4">
        <button
          type="button"
          onClick={onPurchase}
          disabled={purchasing}
          className="w-full rounded-full bg-ink px-3 py-2 text-xs font-semibold text-white disabled:opacity-60"
        >
          {purchasing ? "…" : "Acheter"}
        </button>
      </div>
    </div>
  );
}

function FeatureLi({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex items-start gap-2 text-sm text-ink">
      <span className="mt-0.5 text-walker">✓</span>
      <span>{children}</span>
    </li>
  );
}
