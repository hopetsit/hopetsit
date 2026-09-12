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
                className="group relative overflow-hidden rounded-[28px] bg-[#F5F5F7] p-9"
              >
                                <div className="relative">
                  <div className="flex items-center gap-3">
                    <span className={`grid h-12 w-12 place-items-center rounded-full bg-white text-2xl`}>{tier.emoji}</span>
                    <h2 className="text-sm font-semibold uppercase tracking-wider text-[#6E6E73]">{tier.title}</h2>
                  </div>
                  <div className="mt-6 font-display text-4xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
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
                    className="mt-8 inline-flex w-full items-center justify-center rounded-full bg-[#1D1D1F] px-6 py-3 text-sm font-semibold text-white transition hover:bg-black"
                  >
                    {t("nav_signup")} →
                  </Link>
                </div>
              </div>
            ))}
          </div>

          <p className="mx-auto mt-8 max-w-3xl text-center text-sm leading-relaxed text-[#6E6E73]">
            {t("pricing_note")}
          </p>
        </div>
      </section>

      <div className="bg-[#F5F5F7]">
        <div className="mx-auto max-w-6xl px-4 pt-20">
          <SectionTitle>{t("hiw_subs_title")}</SectionTitle>
        </div>
        <SubscriptionsExplainer compact />
      </div>

      {/* ── PawPremium ── v562 : bande noire sobre. */}
      <section className="px-4 py-20">
        <div className="mx-auto flex max-w-4xl flex-col items-center gap-8 rounded-[28px] bg-[#1D1D1F] p-10 text-center md:flex-row md:p-14 md:text-left">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="PawPremium" width={88} height={88} className="shrink-0" />
          <div className="flex-1">
            <h2 className="font-display text-2xl font-bold tracking-[-0.02em] text-[#FFD34D] md:text-3xl">PawPremium</h2>
            <p className="mx-auto mt-3 max-w-xl text-[15px] leading-relaxed text-white/75 md:mx-0">{t("home_pawpremium_blurb")}</p>
            <p className="mt-3 text-sm font-semibold text-[#FFD34D]">{t("home_pawpremium_price_line")}</p>
          </div>
          <Link href="/boutique" className="shrink-0 rounded-full bg-white px-7 py-3.5 text-sm font-semibold text-[#1D1D1F] transition hover:bg-[#E8E8ED]">
            {t("pawpremium_cta")} →
          </Link>
        </div>
      </section>
    </>
  );
}
