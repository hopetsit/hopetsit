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
      logo: "/pawspot_logo.png",
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
      price: t("home_pawpremium_price_line"),
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
              className="flex flex-col overflow-hidden rounded-3xl border border-ink/10 bg-white shadow-sm transition hover:-translate-y-1 hover:shadow-xl"
            >
              {/* En-tête cadré : logo + nom sur une ligne, prix dans une
                  pastille en dessous — même hauteur pour les 3 cartes. */}
              <div
                className="flex min-h-[124px] flex-col justify-center gap-3 px-6 py-5"
                style={{ backgroundColor: p.soft }}
              >
                <div className="flex items-center gap-3">
                  <span className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-white shadow-sm">
                    {p.key === "ps" ? (
                      <PawSpotGoldCoin size={34} />
                    ) : (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={p.logo} alt="" width={34} height={34} />
                    )}
                  </span>
                  <h3 className="font-display text-2xl font-extrabold leading-tight text-ink">
                    {p.name}
                  </h3>
                </div>
                <p
                  className="inline-flex w-fit items-center rounded-full bg-white px-3 py-1 text-xs font-bold shadow-sm"
                  style={{ color: p.accent === "#15120D" ? "#B8860B" : p.accent }}
                >
                  {p.price}
                </p>
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
