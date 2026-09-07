"use client";

import Link from "next/link";
import PawSpotGoldCoin from "@/components/PawSpotGoldCoin";
import { useT } from "@/lib/i18n/LanguageProvider";

/**
 * v556 — Daniel : « mets en valeur et explique mieux les abonnements sur la
 * page principale et la page PawMap ». Trois cartes, une par abonnement,
 * chacune en deux temps : ce qui est GRATUIT (option C : le partage de
 * position entre amis et le suivi pendant la garde le sont), puis ce que
 * l'abonnement AJOUTE. Le lecteur comprend en 10 secondes pourquoi payer —
 * ou pourquoi il n'a pas besoin de payer.
 */
export function SubscriptionsExplainer({ compact = false }: { compact?: boolean }) {
  const { t } = useT();

  const plans = [
    {
      key: "pf",
      name: "PawFollow",
      logo: "/pawfollow_logo.svg",
      accent: "#7C3AED",
      soft: "#F0EDFB",
      free: t("sub_pf_free"),
      plus: t("sub_pf_plus"),
      price: t("home_pawfollow_price_line"),
    },
    {
      key: "ps",
      name: "PawSpot",
      logo: "/pawspot_logo.svg",
      accent: "#E8920A",
      soft: "#FFF4DD",
      free: t("sub_ps_free"),
      plus: t("sub_ps_plus"),
      price: t("home_pawspot_price_line"),
    },
    {
      key: "pp",
      name: "PawPremium",
      logo: "/pawpremium_logo.svg",
      accent: "#15120D",
      soft: "#FBF3DD",
      free: t("sub_pp_free"),
      plus: t("sub_pp_plus"),
      price: t("pawpremium_subtitle"),
    },
  ] as const;

  return (
    <section className={compact ? "py-12" : "bg-white py-20"}>
      <div className="mx-auto max-w-6xl px-4">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
          {t("sub_title")}
        </h2>
        <p className="mx-auto mt-3 max-w-2xl text-center text-base leading-relaxed text-ink-muted">
          {t("sub_sub")}
        </p>

        <div className="mt-10 grid gap-6 md:grid-cols-3">
          {plans.map((p) => (
            <article
              key={p.key}
              className="flex flex-col overflow-hidden rounded-3xl border border-ink/10 bg-white shadow-sm"
            >
              <div
                className="flex items-center gap-3 px-6 py-5"
                style={{ backgroundColor: p.soft }}
              >
                {p.key === "ps" ? (
                  <PawSpotGoldCoin size={40} />
                ) : (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={p.logo} alt="" width={40} height={40} />
                )}
                <div>
                  <h3 className="font-display text-xl font-extrabold text-ink">{p.name}</h3>
                  <p className="text-xs font-semibold text-ink-muted">{p.price}</p>
                </div>
              </div>

              <div className="flex flex-1 flex-col gap-4 px-6 py-5">
                <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-4">
                  <p className="mb-1 text-xs font-extrabold uppercase tracking-wide text-emerald-700">
                    ✓ {t("sub_free_label")}
                  </p>
                  <p className="text-sm leading-relaxed text-ink">{p.free}</p>
                </div>
                <div
                  className="rounded-2xl p-4 text-white"
                  style={{ backgroundColor: p.accent }}
                >
                  <p className="mb-1 text-xs font-extrabold uppercase tracking-wide text-white/80">
                    👑 {t("sub_plus_label")} {p.name}
                  </p>
                  <p className="text-sm leading-relaxed">{p.plus}</p>
                </div>
              </div>

              <div className="px-6 pb-6">
                <Link
                  href="/boutique"
                  className="inline-flex w-full items-center justify-center rounded-full px-5 py-3 text-sm font-bold text-white transition hover:-translate-y-0.5 hover:shadow-lg"
                  style={{ backgroundColor: p.accent }}
                >
                  {t("sub_cta")} {p.name} →
                </Link>
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
