"use client";

// v566 — lignes de prix des pages vitrine (accueil, /pawmap, /pricing).
// Avant : « 6,99 €/mois · 49,99 €/an … » écrit EN DUR dans 27 traductions →
// faux dès que l'admin change un prix. Désormais les montants viennent de
// l'API des prix (GET /subscriptions/plans + GET /pawspots/plans, publics) et
// sont injectés dans des gabarits traduits ; tant que l'API n'a pas répondu
// (ou si elle échoue), repli sur une phrase SANS montant.

import { useEffect, useState } from "react";
import { getPawSpotPlans, getSubscriptionPlans, PawSpotPlan, SubscriptionPlan } from "@/lib/api";
import { useT } from "@/lib/i18n/LanguageProvider";

type Prices = { plans: SubscriptionPlan[]; spot: PawSpotPlan[]; trialDays: number };

let cache: Prices | null = null;
let pending: Promise<Prices> | null = null;

function load(): Promise<Prices> {
  if (cache) return Promise.resolve(cache);
  if (!pending) {
    pending = Promise.all([
      getSubscriptionPlans().catch(() => [] as SubscriptionPlan[]),
      getPawSpotPlans(),
    ]).then(([plans, spot]) => {
      cache = { plans, spot, trialDays: 7 };
      return cache;
    });
  }
  return pending;
}

function money(amount: number, currency: string, lang: string): string {
  try {
    return new Intl.NumberFormat(lang, { style: "currency", currency }).format(amount);
  } catch {
    return `${amount.toFixed(2)} ${currency}`;
  }
}

function fill(tpl: string, vars: Record<string, string>): string {
  return Object.entries(vars).reduce((s, [k, v]) => s.split(`{${k}}`).join(v), tpl);
}

export function useShopPriceLines(): { follow: string; spot: string; premium: string } {
  const { t, lang } = useT();
  const [prices, setPrices] = useState<Prices | null>(cache);

  useEffect(() => {
    let alive = true;
    load().then((p) => {
      if (alive) setPrices(p);
    });
    return () => {
      alive = false;
    };
  }, []);

  const plan = (id: string) => prices?.plans.find((p) => p.id === id);
  const spotPlan = (id: string) => prices?.spot.find((p) => p.plan === id);
  const m = plan("monthly");
  const y = plan("yearly");
  const fm = plan("family");
  const fy = plan("family_yearly");
  const pm = plan("premium_monthly");
  const py = plan("premium_yearly");
  const sm = spotPlan("monthly");
  const sy = spotPlan("yearly");

  const follow =
    m && y && fm && fy
      ? fill(t("price566_follow"), {
          m: money(m.amount, m.currency, lang),
          y: money(y.amount, y.currency, lang),
          fm: money(fm.amount, fm.currency, lang),
          fy: money(fy.amount, fy.currency, lang),
        })
      : t("price566_follow_fallback");

  const spotPct = sm && sy && sy.amount < sm.amount * 12 ? Math.round((1 - sy.amount / (sm.amount * 12)) * 100) : 0;
  const spot =
    sm && sy && spotPct > 0
      ? fill(t("price566_spot"), {
          m: money(sm.amount, sm.currency, lang),
          y: money(sy.amount, sy.currency, lang),
          pct: String(spotPct),
          trial: String(prices?.trialDays ?? 7),
        })
      : t("price566_spot_fallback");

  // Économie du bundle = prix annuel Premium contre PawFollow + PawSpot annuels.
  const sep = y && sy && y.currency === sy.currency ? y.amount + sy.amount : 0;
  const premiumPct = py && sep > py.amount ? Math.round((1 - py.amount / sep) * 100) : 0;
  const premium =
    pm && py
      ? fill(t(premiumPct > 0 ? "price566_premium" : "price566_premium_nopct"), {
          m: money(pm.amount, pm.currency, lang),
          y: money(py.amount, py.currency, lang),
          pct: String(premiumPct),
        })
      : t("price566_premium_fallback");

  return { follow, spot, premium };
}
