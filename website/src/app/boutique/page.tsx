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
import PawSpotGoldCoin from "@/components/PawSpotGoldCoin";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  ApiError,
  AuthUser,
  BoostPackage,
  BoostStatus,
  BoostTier,
  cancelSubscription,
  getBoostPackages,
  getBoostStatus,
  getMapBoostPackages,
  getMapBoostStatus,
  getStoredUser,
  getSubscriptionPlans,
  getSubscriptionStatus,
  PaymentIntentResponse,
  purchaseBoost,
  purchaseMapBoost,
  resumeSubscription,
  subscribeToPlan,
  SubscriptionPlan,
  SubscriptionStatus,
} from "@/lib/api";
import { useT } from "@/lib/i18n/LanguageProvider";

type Section = "premium" | "boost" | "mapboost" | "pawpremium";

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

  /**
   * v23.1 part 146 — Lance le checkout Airwallex Hosted pour un paiement.
   * Appelle l'endpoint backend approprié pour obtenir un PaymentIntent,
   * puis redirige vers /pay (qui boot le SDK Airwallex et lance la
   * Hosted Payment Page). À la fin, /pay/done auto-confirmera via
   * /confirm.
   */
  async function startCheckout(
    purpose: "subscription" | "boost" | "mapboost",
    planOrTier: string,
    createIntent: () => Promise<PaymentIntentResponse | { clientSecret: string; paymentIntentId: string; amount: number; currency: string }>,
    label: string,
  ) {
    setPurchasing(label);
    setError(null);
    try {
      const intent = await createIntent();
      if (!intent.clientSecret || !intent.paymentIntentId) {
        throw new Error("Réponse backend incomplète (paymentIntent manquant).");
      }
      const country = guessCountryFromCurrency(intent.currency);
      const qs = new URLSearchParams({
        intent: intent.paymentIntentId,
        secret: intent.clientSecret,
        currency: intent.currency,
        country,
        purpose,
        ...(purpose === "subscription" ? { plan: planOrTier } : { tier: planOrTier }),
      });
      // Full-page redirect — la page /pay enchaîne le SDK Airwallex.
      window.location.href = `/pay?${qs.toString()}`;
    } catch (e) {
      setPurchasing(null);
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }
      // 402 PREMIUM_REQUIRED ou autre erreur business.
      setError(
        e instanceof Error
          ? e.message
          : "Impossible de démarrer le paiement. Réessaye dans un instant.",
      );
    }
  }

  // v23.1.387 — type élargi : + family_yearly, premium_monthly, premium_yearly.
  async function handleSubscribePlan(plan: string) {
    return startCheckout(
      "subscription",
      plan,
      () => subscribeToPlan(plan),
      `plan-${plan}`,
    );
  }

  async function handleBuyBoost(tier: BoostTier) {
    return startCheckout(
      "boost",
      tier,
      () => purchaseBoost(tier),
      `boost-${tier}`,
    );
  }

  async function handleBuyMapBoost(tier: BoostTier) {
    return startCheckout(
      "mapboost",
      tier,
      () => purchaseMapBoost(tier),
      `mapboost-${tier}`,
    );
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
          ← {t("nav_dashboard")}
        </Link>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        {t("shop_title")}
      </h1>
      <p className="mt-2 text-ink-muted">
        {t("shop_subtitle")}
      </p>

      {error && (
        <div className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Tabs sections */}
      <div className="mt-8 inline-flex flex-wrap gap-2 rounded-full bg-ink/5 p-1">
        <SectionTab
          label={t("shop_tab_premium")}
          active={section === "premium"}
          onClick={() => setSection("premium")}
        />
        {isProvider && (
          <SectionTab
            label={t("shop_tab_boost")}
            active={section === "boost"}
            onClick={() => setSection("boost")}
          />
        )}
        {/* v23.1.353 — PawSpot communautaire : pour TOUS les rôles (plus
            seulement les prestataires comme l'ancien map boost). */}
        <SectionTab
          label={t("shop_tab_mapboost")}
          active={section === "mapboost"}
          onClick={() => setSection("mapboost")}
          icon={<PawSpotGoldCoin size={18} />}
        />
        {/* v23.1.387 — Paw Premium : bundle PawFollow + PawSpot + exclusifs. */}
        <SectionTab
          label={t("shop_tab_pawpremium")}
          active={section === "pawpremium"}
          onClick={() => setSection("pawpremium")}
          icon={
            // eslint-disable-next-line @next/next/no-img-element
            <img src="/pawpremium_logo.svg" alt="" width={18} height={18} />
          }
        />
      </div>

      {section === "pawpremium" && (
        <PawPremiumSection
          plans={plans}
          status={subStatus}
          onSubscribe={handleSubscribePlan}
          purchasing={purchasing}
          t={t}
        />
      )}

      {section === "premium" && (
        <PremiumSection
          plans={plans}
          status={subStatus}
          onSubscribe={handleSubscribePlan}
          onCancel={handleCancelSubscription}
          onResume={handleResumeSubscription}
          purchasing={purchasing}
          cancelling={cancelling}
        />
      )}

      {section === "boost" && isProvider && (
        <BoostSection
          title={t("shop_boost_title")}
          subtitle={t("shop_boost_subtitle")}
          packages={boostPkgs}
          status={boostStatus}
          purposeKey="boost"
          onBuy={handleBuyBoost}
          purchasing={purchasing}
        />
      )}

      {/* v23.1.353 — refonte PawSpot (Daniel) : fini les paliers de halos sur
          la carte. PawSpot = abonnement communautaire (taguer des spots
          pet-friendly, PawPoints, badges 🥉🥈🥇👑, empreinte dorée 🐾,
          classements, récompenses) — 4,99 €/mois · 39,99 €/an · essai 7 j.
          L'abonnement se prend DANS L'APP (boutique → onglet PawSpot). */}
      {section === "mapboost" && (
        <section className="rounded-3xl border border-ink/5 bg-white p-8 shadow-card">
          <h2 className="font-display text-2xl font-extrabold text-ink">
            <PawSpotGoldCoin size={32} className="mr-2 -mt-1" />
            {t("shop_mapboost_title")}
          </h2>
          <p className="mt-2 max-w-2xl text-ink-muted">{t("shop_mapboost_subtitle")}</p>
          <div className="mt-6 grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="rounded-2xl border border-ink/5 bg-amber-50 p-6">
              <h3 className="text-lg font-bold text-ink">{t("pawspot_monthly_name")}</h3>
              <p className="mt-2 text-3xl font-extrabold text-amber-600">4,99 €</p>
              <p className="mt-2 text-sm text-ink-muted">{t("pawspot_monthly_details")}</p>
            </div>
            <div className="rounded-2xl border-4 border-amber-400 bg-amber-50 p-6 ring-2 ring-amber-200 shadow-lg">
              <h3 className="text-lg font-bold text-ink">
                {t("pawspot_yearly_name")}{" "}
                <span className="ml-1 rounded-full bg-amber-400 px-2 py-0.5 text-xs font-bold text-white">-33%</span>
              </h3>
              <p className="mt-2 text-3xl font-extrabold text-amber-600">39,99 €</p>
              <p className="mt-2 text-sm text-ink-muted">{t("pawspot_yearly_details")}</p>
            </div>
          </div>
          <p className="mt-5 text-sm text-ink-muted">{t("pawspot_footer_note")}</p>
          <a
            href="/download"
            className="mt-6 inline-block rounded-full bg-amber-500 px-7 py-3 text-sm font-semibold text-white hover:bg-amber-600"
          >
            {t("nav_download")} →
          </a>
        </section>
      )}
    </div>
  );
}

/**
 * v23.1 part 146 — Mapping minimal devise → pays ISO-2 pour Airwallex.
 * Airwallex exige un `country_code` pour le routing du payment intent.
 * Quand on ne peut pas dériver le pays depuis le profil user (peu courant
 * sur le site web), on fallback sur le pays par défaut de la devise.
 */
function guessCountryFromCurrency(currency: string): string {
  const c = (currency || "EUR").toUpperCase();
  if (c === "USD") return "US";
  if (c === "GBP") return "GB";
  if (c === "CHF") return "CH";
  if (c === "CAD") return "CA";
  return "FR";
}

function SectionTab({
  label,
  active,
  onClick,
  icon,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
  /** v23.1.363 — icône custom (ex. pièce dorée PawSpot) avant le label. */
  icon?: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-sm font-semibold transition ${
        active ? "bg-white text-ink shadow-sm" : "text-ink-muted hover:text-ink"
      }`}
    >
      {icon}
      {label}
    </button>
  );
}

function PremiumSection({
  plans,
  status,
  onSubscribe,
  onCancel,
  onResume,
  purchasing,
  cancelling,
}: {
  plans: SubscriptionPlan[];
  status: SubscriptionStatus | null;
  // v23.1.387 — + family_yearly (les premium_* sont filtrés de cette section).
  onSubscribe: (plan: string) => void;
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
            isPremium ? "bg-gradient-to-br from-violet-100 to-violet-50" : "bg-white border border-ink/5"
          }`}
        >
          {isPremium ? (
            <>
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-2xl">🌟</span>
                <h3 className="text-lg font-bold text-ink">Premium actif</h3>
                <span className="rounded-full bg-violet-200 px-2 py-0.5 text-xs font-semibold text-violet-900">
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
                    className="rounded-full bg-violet-600 px-5 py-2 text-sm font-semibold text-white disabled:opacity-60"
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

      {/* Plans — v23.1.387 : les plans premium_* ont leur PROPRE section. */}
      {!isPremium && (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          {plans
            .filter((plan) => !plan.id.startsWith("premium_"))
            .map((plan) => (
              <PlanCard
                key={plan.id}
                plan={plan}
                onPurchase={() => onSubscribe(plan.id)}
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
    // v23.1.387 — Famille annuel (-42%) + plans Paw Premium.
    family_yearly: "Famille Annuel",
    premium_monthly: "Paw Premium Mensuel",
    premium_yearly: "Paw Premium Annuel",
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
        {(plan.id === "yearly" || plan.id === "family_yearly") && (
          <FeatureLi>+12 crédits PawSpot offerts (1/mois)</FeatureLi>
        )}
        {(plan.id === "family" || plan.id === "family_yearly") && (
          <FeatureLi>Jusqu&apos;à 5 utilisateurs</FeatureLi>
        )}
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

// ─── v23.1.387 — Paw Premium (bundle PawFollow + PawSpot + exclusifs) ───────
// Vitrine noir/or fidèle au mockup Daniel : ruban « LE PLUS COMPLET 👑 »,
// 6 avantages, prix barrés des deux abos séparés, -33%.
function PawPremiumSection({
  plans,
  status,
  onSubscribe,
  purchasing,
  t,
}: {
  plans: SubscriptionPlan[];
  status: SubscriptionStatus | null;
  onSubscribe: (plan: string) => void;
  purchasing: string | null;
  t: (k: string) => string;
}) {
  const monthly = plans.find((p) => p.id === "premium_monthly");
  const yearly = plans.find((p) => p.id === "premium_yearly");
  const monthlyPrice = monthly?.amount ?? 7.99;
  const yearlyPrice = yearly?.amount ?? 59.99;
  const cur = monthly?.currency ?? "EUR";
  const fmt = (n: number) =>
    `${n.toFixed(2).replace(".", ",")} ${cur === "EUR" ? "€" : cur}`;
  const bundleActive = status?.premiumBundleActive === true;
  const expiry = status?.premiumExpiry
    ? new Date(status.premiumExpiry)
    : null;

  const features = [
    t("pawpremium_feat_pawfollow"),
    t("pawpremium_feat_pawspot"),
    t("pawpremium_feat_exclusive"),
    t("pawpremium_feat_badge"),
    t("pawpremium_feat_points"),
    t("pawpremium_feat_priority"),
  ];

  return (
    <div className="mt-8">
      {bundleActive && (
        <div className="mb-6 flex items-center gap-3 rounded-2xl border-2 border-amber-400 bg-amber-50 p-5 shadow-card">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="Paw Premium" width={34} height={34} />
          <p className="text-sm font-semibold text-ink">
            {t("pawpremium_active")}
            {expiry && (
              <span className="ml-1 text-ink-muted">
                · {expiry.toLocaleDateString("fr-FR")}
              </span>
            )}
          </p>
        </div>
      )}

      <section className="relative overflow-hidden rounded-3xl border-2 border-amber-400 bg-gradient-to-b from-[#221C12] to-[#15120D] p-8 text-center shadow-xl">
        <span className="inline-block rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-4 py-1 text-xs font-extrabold tracking-wide text-black">
          {t("pawpremium_ribbon")}
        </span>
        <div className="mt-5 flex justify-center">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="Paw Premium" width={96} height={96} />
        </div>
        <h2 className="mt-3 font-display text-3xl font-extrabold text-yellow-400">
          Paw Premium
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-white/85">
          {t("pawpremium_subtitle")}
        </p>
        <p className="mx-auto mt-4 inline-flex items-center gap-1 rounded-full border border-amber-400/50 bg-white/5 px-4 py-1.5 text-xs font-bold">
          <span className="text-white/90">{t("pawpremium_includes")}</span>
          <span className="text-violet-300">PAWFOLLOW</span>
          <span className="text-white/90">+</span>
          <span className="text-yellow-400">PAWSPOT</span>
        </p>

        <ul className="mx-auto mt-6 max-w-md space-y-2 text-left">
          {features.map((f) => (
            <li key={f} className="flex items-start gap-2 text-sm font-medium text-white/90">
              <span className="mt-0.5 text-amber-400">✓</span>
              {f}
            </li>
          ))}
        </ul>

        <div className="mx-auto mt-7 grid max-w-md gap-4 sm:grid-cols-2">
          <PawPremiumPlanCard
            label={t("pawpremium_monthly")}
            price={fmt(monthlyPrice)}
            strike={fmt(11.98)}
            pct="-33%"
            purchasing={purchasing === "plan-premium_monthly"}
            onClick={() => onSubscribe("premium_monthly")}
            cta={t("pawpremium_cta")}
          />
          <PawPremiumPlanCard
            label={t("pawpremium_yearly")}
            price={fmt(yearlyPrice)}
            strike={fmt(89.98)}
            pct="-33%"
            highlight
            purchasing={purchasing === "plan-premium_yearly"}
            onClick={() => onSubscribe("premium_yearly")}
            cta={t("pawpremium_cta")}
          />
        </div>
        <p className="mt-5 text-xs font-semibold text-yellow-300">
          {t("pawpremium_savings")}
        </p>
      </section>
    </div>
  );
}

function PawPremiumPlanCard({
  label,
  price,
  strike,
  pct,
  highlight = false,
  purchasing,
  onClick,
  cta,
}: {
  label: string;
  price: string;
  strike: string;
  pct: string;
  highlight?: boolean;
  purchasing: boolean;
  onClick: () => void;
  cta: string;
}) {
  return (
    <div
      className={`relative rounded-2xl border p-5 ${
        highlight
          ? "border-yellow-400 bg-white/10"
          : "border-amber-400/50 bg-white/5"
      }`}
    >
      <span className="absolute -top-2.5 right-3 rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-2 py-0.5 text-[10px] font-extrabold text-black">
        {pct}
      </span>
      <p className="text-xs font-bold text-white/85">{label}</p>
      <p className="mt-1 text-2xl font-extrabold text-yellow-400">{price}</p>
      <p className="text-xs text-white/50 line-through">{strike}</p>
      <button
        type="button"
        onClick={onClick}
        disabled={purchasing}
        className="mt-3 w-full rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-4 py-2 text-xs font-bold text-black hover:brightness-110 disabled:opacity-60"
      >
        {purchasing ? "…" : cta}
      </button>
    </div>
  );
}

function BoostSection({
  title,
  subtitle,
  packages,
  status,
  purposeKey,
  onBuy,
  purchasing,
}: {
  title: string;
  subtitle: string;
  packages: BoostPackage[];
  status: BoostStatus | null;
  purposeKey: "boost" | "mapboost";
  onBuy: (tier: BoostTier) => void;
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
            onPurchase={() => onBuy(pkg.tier)}
            purchasing={purchasing === `${purposeKey}-${pkg.tier}`}
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
