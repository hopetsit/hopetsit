"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";
import { PageHero, SectionTitle } from "@/components/PageHero";
import { SubscriptionsExplainer } from "@/components/SubscriptionsExplainer";

/**
 * v556 — « Tarifs » en version premium (Daniel). En-tête commun, deux cartes
 * de rôle (propriétaire / prestataire) avec relief, note, puis les
 * abonnements expliqués (gratuit vs abonnement) et la bande PawPremium.
 * Mêmes clés, mêmes routes.
 */
export default function PricingPage() {
  const { t } = useT();

  const tiers = [
    {
      title: t("pricing_owner_title"),
      price: t("pricing_owner_price"),
      lines: [t("pricing_owner_l1"), t("pricing_owner_l2"), t("pricing_owner_l3")],
      color: "owner",
      emoji: "🐾",
      href: "/signup",
    },
    {
      title: t("pricing_provider_title"),
      price: t("pricing_provider_price"),
      lines: [t("pricing_provider_l1"), t("pricing_provider_l2"), t("pricing_provider_l3")],
      color: "sitter",
      emoji: "🏠",
      href: "/signup",
    },
  ] as const;

  return (
    <>
      <PageHero title={t("pricing_title")} subtitle={t("pricing_sub")} badge={<>💳 {t("nav_pricing")}</>} />

      <section className="bg-white py-20">
        <div className="mx-auto max-w-5xl px-4">
          <div className="grid gap-6 md:grid-cols-2">
            {tiers.map((tier) => (
              <div
                key={tier.title}
                className={`group relative overflow-hidden rounded-[28px] border border-[#efe7e0] bg-white p-9 shadow-card transition hover:-translate-y-1.5 hover:shadow-xl`}
              >
                <div className={`absolute inset-x-0 top-0 h-1.5 bg-${tier.color}`} />
                <div aria-hidden className={`pointer-events-none absolute -right-12 -top-12 h-40 w-40 rounded-full bg-${tier.color}-light opacity-70 blur-2xl`} />
                <div className="relative">
                  <div className="flex items-center gap-3">
                    <span className={`grid h-12 w-12 place-items-center rounded-2xl bg-${tier.color}-light text-2xl`}>{tier.emoji}</span>
                    <h2 className="text-sm font-bold uppercase tracking-wider text-ink-muted">{tier.title}</h2>
                  </div>
                  <div className={`mt-6 font-display text-4xl font-extrabold tracking-tight text-${tier.color}-dark md:text-5xl`}>
                    {tier.price}
                  </div>
                  <ul className="mt-7 space-y-3">
                    {tier.lines.map((l) => (
                      <li key={l} className="flex gap-3 text-sm text-ink">
                        <span className={`mt-0.5 grid h-5 w-5 shrink-0 place-items-center rounded-full bg-${tier.color}-light text-xs font-bold text-${tier.color}-dark`}>
                          ✓
                        </span>
                        <span>{l}</span>
                      </li>
                    ))}
                  </ul>
                  <Link
                    href={tier.href}
                    className={`mt-8 inline-flex w-full items-center justify-center rounded-full bg-${tier.color} px-6 py-3 text-sm font-bold text-white shadow-cta transition hover:-translate-y-0.5`}
                  >
                    {t("nav_signup")} →
                  </Link>
                </div>
              </div>
            ))}
          </div>

          <p className="mx-auto mt-8 max-w-3xl rounded-2xl border border-ink/10 bg-bg-soft px-6 py-5 text-center text-sm leading-relaxed text-ink-muted">
            {t("pricing_note")}
          </p>
        </div>
      </section>

      <div className="bg-bg-soft">
        <div className="mx-auto max-w-6xl px-4 pt-20">
          <SectionTitle>{t("hiw_subs_title")}</SectionTitle>
        </div>
        <SubscriptionsExplainer compact />
      </div>

      {/* ── PawPremium ── */}
      <section className="px-4 py-20">
        <div className="relative mx-auto flex max-w-4xl flex-col items-center gap-7 overflow-hidden rounded-[26px] bg-gradient-to-b from-[#221C12] to-[#15120D] p-9 text-center shadow-2xl ring-1 ring-amber-400/40 md:flex-row md:gap-10 md:p-12 md:text-left">
          <span aria-hidden className="pointer-events-none absolute -right-4 -top-8 rotate-12 select-none text-[110px] leading-none opacity-[0.07]">👑</span>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="PawPremium" width={80} height={80} className="shrink-0 drop-shadow-[0_0_18px_rgba(244,192,74,0.35)]" />
          <div className="flex-1">
            <h2 className="flex items-center justify-center gap-2 font-display text-2xl font-extrabold tracking-tight text-yellow-400 md:justify-start md:text-3xl">
              <span>PawPremium</span>
              <span aria-hidden className="text-xl md:text-2xl">👑</span>
            </h2>
            <p className="mx-auto mt-3 max-w-xl text-sm leading-relaxed text-white/85 md:mx-0">{t("home_pawpremium_blurb")}</p>
            <p className="mt-3 text-sm font-semibold text-yellow-300">{t("home_pawpremium_price_line")}</p>
          </div>
          <Link
            href="/boutique"
            className="shrink-0 rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-7 py-3.5 text-sm font-bold text-black shadow-cta transition hover:brightness-110"
          >
            {t("pawpremium_cta")} →
          </Link>
        </div>
      </section>
    </>
  );
}
