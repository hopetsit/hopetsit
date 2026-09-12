"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";

/**
 * v556 — Daniel : « explique mieux les abonnements ». Trois cartes, une par
 * abonnement : ce qui est GRATUIT, puis ce que l'abonnement AJOUTE.
 * v562 — refonte minimaliste (Daniel, 13/09) : cartes blanches sur gris
 * clair, nouvelles icônes produits (design « Paw Buttons »), typographie
 * sobre, un seul bouton texte. Mêmes clés, même route (/boutique).
 */
export function SubscriptionsExplainer({ compact = false }: { compact?: boolean }) {
  const { t } = useT();

  const plans = [
    {
      key: "pf",
      name: "PawFollow",
      logo: "/pawfollow_logo.svg",
      accent: "#6A34E0",
      free: t("sub_pf_free"),
      plus: t("sub_pf_plus"),
      price: t("home_pawfollow_price_line"),
    },
    {
      key: "ps",
      name: "PawSpot",
      logo: "/pawspot_logo.svg",
      accent: "#E8890A",
      free: t("sub_ps_free"),
      plus: t("sub_ps_plus"),
      price: t("home_pawspot_price_line"),
    },
    {
      key: "pp",
      name: "PawPremium",
      logo: "/pawpremium_logo.svg",
      accent: "#B8860B",
      free: t("sub_pp_free"),
      plus: t("sub_pp_plus"),
      price: t("home_pawpremium_price_line"),
    },
  ] as const;

  return (
    <section className={compact ? "py-12" : "bg-white py-24"}>
      <div className="mx-auto max-w-6xl px-4">
        <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
          {t("sub_title")}
        </h2>
        <p className="mx-auto mt-4 max-w-2xl text-center text-lg leading-relaxed text-[#6E6E73]">
          {t("sub_sub")}
        </p>

        <div className="mt-12 grid gap-4 md:grid-cols-3">
          {plans.map((p) => (
            <article key={p.key} className="flex flex-col rounded-[24px] bg-[#F5F5F7] p-7">
              <div className="flex items-center gap-4">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={p.logo} alt="" width={56} height={56} className="h-14 w-14 shrink-0" />
                <div>
                  <h3 className="font-display text-xl font-semibold leading-tight text-[#1D1D1F]">{p.name}</h3>
                  <p className="mt-0.5 text-sm font-medium" style={{ color: p.accent }}>{p.price}</p>
                </div>
              </div>

              <div className="mt-6 space-y-4">
                <div>
                  <p className="text-xs font-semibold uppercase tracking-wider text-[#6E6E73]">{t("sub_free_label")}</p>
                  <p className="mt-1 text-[15px] leading-relaxed text-[#1D1D1F]">{p.free}</p>
                </div>
                <div className="rounded-[16px] bg-white p-4">
                  <p className="text-xs font-semibold uppercase tracking-wider" style={{ color: p.accent }}>
                    {t("sub_plus_label")} {p.name}
                  </p>
                  <p className="mt-1 text-[15px] leading-relaxed text-[#1D1D1F]">{p.plus}</p>
                </div>
              </div>

              <Link href="/boutique" className="mt-auto pt-6 text-sm font-semibold text-[#1D1D1F] hover:underline">
                {t("sub_cta")} {p.name} →
              </Link>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
