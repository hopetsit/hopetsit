"use client";

import Link from "next/link";
import PawSpotGoldCoin from "@/components/PawSpotGoldCoin";
import { PawMapCTA } from "@/components/PawMapCTA";
import { useT } from "@/lib/i18n/LanguageProvider";

type Plan = {
  name: string;
  price: string;
  period: string;
  tagline: string;
  features: string[];
  highlighted: boolean;
  badge?: string;
  isFamily?: boolean;
};

type Offer = {
  name: string;
  price: string;
  details: string;
  // v23.1.357 — Daniel : "le PawSpot annuel avec un cadre jaune, ça donne
  // envie de l'acheter".
  highlighted?: boolean;
  badge?: string;
};

export default function PawMapPage() {
  const { t } = useT();

  // v23.1.147 — fix traduction : on réutilise les clés map_cat_* qui sont
  // déjà définies dans translations.ts pour les 6 langues (EN/FR/ES/DE/IT/PT).
  // Avant : labels hardcodés en anglais → restait "Vets, Pet shops..." même
  // quand l'utilisateur choisissait espagnol/italien/etc.
  const cats = [
    { emoji: "🩺", label: t("map_cat_vet") },
    { emoji: "🛒", label: t("map_cat_shop") },
    { emoji: "✂️", label: t("map_cat_groomer") },
    { emoji: "🌳", label: t("map_cat_park") },
    { emoji: "🏖️", label: t("map_cat_beach") },
    { emoji: "💧", label: t("map_cat_water") },
    { emoji: "🎓", label: t("map_cat_trainer") },
    { emoji: "🏨", label: t("map_cat_hotel") },
    { emoji: "🍽️", label: t("map_cat_restaurant") },
  ];

  const pawfollowPlans: Plan[] = [
    {
      name: t("pawfollow_monthly_name"),
      price: "6,99 €",
      period: t("pawfollow_monthly_period"),
      tagline: t("pawfollow_monthly_tagline"),
      features: [
        t("pawfollow_monthly_f1"),
        t("pawfollow_monthly_f2"),
        t("pawfollow_monthly_f3"),
        t("pawfollow_monthly_f4"),
      ],
      highlighted: false,
    },
    {
      name: t("pawfollow_yearly_name"),
      price: "49,99 €",
      period: t("pawfollow_yearly_period"),
      tagline: t("pawfollow_yearly_tagline"),
      features: [
        t("pawfollow_yearly_f1"),
        t("pawfollow_yearly_f2"),
        t("pawfollow_yearly_f3"),
      ],
      highlighted: true,
      badge: t("pawfollow_yearly_badge"),
    },
    {
      name: t("pawfollow_family_name"),
      price: "9,99 €",
      period: t("pawfollow_monthly_period"),
      tagline: t("pawfollow_family_tagline"),
      features: [
        t("pawfollow_family_f1"),
        t("pawfollow_family_f2"),
        t("pawfollow_family_f3"),
        t("pawfollow_family_f4"),
        // v23.1.357 — itinéraires vers les lieux gratuits inclus aussi.
        t("pawfollow_monthly_f4"),
      ],
      highlighted: false,
      badge: t("pawfollow_family_badge"),
      isFamily: true,
    },
    {
      // v23.1.398 — Daniel : ajouter PawFamily ANNUEL sur la page PawMap.
      name: t("pawfollow_family_yearly_name"),
      price: "69,99 €",
      period: t("pawfollow_yearly_period"),
      tagline: t("pawfollow_family_tagline"),
      features: [
        t("pawfollow_family_f1"),
        t("pawfollow_family_f2"),
        t("pawfollow_family_f3"),
        t("pawfollow_family_f4"),
        t("pawfollow_monthly_f4"),
      ],
      highlighted: true,
      badge: t("pawfollow_family_yearly_badge"),
      isFamily: true,
    },
  ];

  // v23.1.353 — refonte PawSpot : abonnement communautaire (spots tagués,
  // PawPoints, badges, empreinte dorée 🐾) — 2 plans + essai 7 jours.
  const pawspotOffers: Offer[] = [
    { name: t("pawspot_monthly_name"), price: "4,99 €", details: t("pawspot_monthly_details") },
    { name: t("pawspot_yearly_name"), price: "39,99 €", details: t("pawspot_yearly_details"), highlighted: true, badge: t("pawspot_save_badge_site") },
  ];

  return (
    <div className="mx-auto max-w-5xl px-4 py-16 md:py-24">
      {/* v414 — logo PawMap (patte bleu→vert + chien & chat). */}
      <div className="mb-4 flex justify-center">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/pawmap_logo.svg" alt="PawMap" width={96} height={96} />
      </div>
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight md:text-5xl">
        {t("pawmap_title")}
      </h1>
      <p className="mx-auto mt-4 max-w-2xl text-center text-lg text-ink-muted">{t("pawmap_sub")}</p>
      <p className="mt-3 text-center text-sm font-semibold text-walker-dark">{t("pawmap_categories")}</p>

      {/* v23.1.452 — Daniel : message marketing Paw Map juste sous le titre. */}
      <div className="mx-auto mt-5 max-w-md space-y-1 text-center text-sm text-ink-muted">
        <p>{t("pawmap_msg_countries")}</p>
        <p>{t("pawmap_msg_live")}</p>
        <p>{t("pawmap_msg_places")}</p>
        <p>{t("pawmap_msg_platforms")}</p>
      </div>

      {/* v23.1.452 — Daniel : CTA Paw Map phare (orange #FF6A00) vers la carte
          interactive (login requis → redirect /map). Remplace l'ancien bouton
          vert. La couche amis vit dans la carte unique (chip PawFollow). */}
      <div className="mt-7 flex flex-wrap justify-center gap-3">
        <PawMapCTA size="hero" />
      </div>

      <div className="mt-14 grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-3">
        {cats.map((c) => (
          <div key={c.label} className="flex items-center gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
            <span className="grid h-10 w-10 place-items-center rounded-xl bg-walker-light text-xl">{c.emoji}</span>
            <span className="text-sm font-semibold text-ink">{c.label}</span>
          </div>
        ))}
      </div>

      {/* v23.1.388 — Daniel : "mets en avant le tarif Paw Premium D'ABORD,
          puis PawFollow et PawSpot séparés". Vitrine noir/or en tête. */}
      <div className="mt-20">
        <section className="mx-auto max-w-3xl rounded-3xl border-2 border-amber-400 bg-gradient-to-b from-[#221C12] to-[#15120D] p-8 text-center shadow-xl">
          <span className="inline-block rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-4 py-1 text-xs font-extrabold tracking-wide text-black">
            {t("pawpremium_ribbon")}
          </span>
          <div className="mt-4 flex justify-center">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/pawpremium_logo.svg" alt="Paw Premium" width={80} height={80} />
          </div>
          <h2 className="mt-2 font-display text-2xl font-extrabold text-yellow-400">Paw Premium 👑</h2>
          <p className="mx-auto mt-2 max-w-md text-sm text-white/85">{t("pawpremium_subtitle")}</p>
          <ul className="mx-auto mt-4 max-w-md space-y-1.5 text-left">
            {["pawpremium_feat_pawfollow","pawpremium_feat_pawspot","pawpremium_feat_exclusive","pawpremium_feat_badge","pawpremium_feat_points","pawpremium_feat_priority"].map((k) => (
              <li key={k} className="flex items-start gap-2 text-xs font-medium text-white/90"><span className="text-amber-400">✓</span>{t(k)}</li>
            ))}
          </ul>
          <div className="mx-auto mt-5 grid max-w-md gap-4 sm:grid-cols-2">
            <div className="rounded-2xl border border-amber-400/50 bg-white/5 p-4">
              <p className="text-xs font-bold text-white/85">{t("pawpremium_monthly")}</p>
              <p className="mt-1 text-2xl font-extrabold text-yellow-400">7,99 €</p>
              <p className="text-xs text-white/50 line-through">11,98 €</p>
            </div>
            <div className="relative rounded-2xl border-2 border-yellow-400 bg-white/10 p-4">
              <span className="absolute -top-2.5 right-3 rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-2 py-0.5 text-[10px] font-extrabold text-black">-33%</span>
              <p className="text-xs font-bold text-white/85">{t("pawpremium_yearly")}</p>
              <p className="mt-1 text-2xl font-extrabold text-yellow-400">59,99 €</p>
              <p className="text-xs text-white/50 line-through">89,98 €</p>
            </div>
          </div>
          <p className="mt-4 text-xs font-semibold text-yellow-300">{t("pawpremium_savings")}</p>
          <Link
            href="/boutique"
            className="mt-5 inline-block rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-7 py-3 text-sm font-bold text-black hover:brightness-110"
          >
            {t("pawpremium_cta")} →
          </Link>
        </section>

        <h2 className="mt-16 text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
          {t("pawfollow_title")}
        </h2>
        <p className="mx-auto mt-3 max-w-2xl text-center text-base text-ink-muted">
          {t("pawfollow_desc")}
        </p>

        {/* v23.1.354 — Daniel : "PawFollow = VIOLET partout" (app + map +
            site). Section 1 : Suis ton animal (PawFollow individuel). */}
        <h3 className="mt-10 text-center font-display text-xl font-extrabold text-violet-700">
          🐾 {t("pawfollow_section_solo")}
        </h3>
        <div className="mt-6 grid grid-cols-1 gap-5 md:mx-auto md:max-w-3xl md:grid-cols-2">
          {pawfollowPlans
            .filter((p) => !p.isFamily)
            .map((p) => (
              <div
                key={p.name}
                className={
                  "relative rounded-2xl border bg-white p-6 shadow-card transition " +
                  (p.highlighted ? "border-violet-600 ring-2 ring-violet-600 scale-[1.02]" : "border-ink/5")
                }
              >
                {p.badge ? (
                  <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-violet-600 px-3 py-1 text-xs font-semibold text-white">
                    {p.badge}
                  </span>
                ) : null}
                <h4 className="text-lg font-bold text-ink">{p.name}</h4>
                <p className="mt-3 text-3xl font-extrabold text-violet-700">
                  {p.price}
                  <span className="ml-1 text-sm font-medium text-ink-muted">{p.period}</span>
                </p>
                <p className="mt-1 text-xs text-ink-muted">{p.tagline}</p>
                <ul className="mt-5 space-y-2">
                  {p.features.map((f) => (
                    <li key={f} className="flex items-start gap-2 text-sm text-ink">
                      <span className="mt-0.5 text-violet-600">✓</span>
                      <span>{f}</span>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
        </div>

        {/* Section 2 : PawFamily (suivi en famille — VIOLET, code couleur famille). */}
        <h3 className="mt-12 text-center font-display text-xl font-extrabold text-violet-700">
          👨‍👩‍👧 PawFamily
        </h3>
        <p className="mx-auto mt-2 max-w-xl text-center text-sm text-ink-muted">
          {t("pawfollow_section_family_sub")}
        </p>
        {/* v23.1.400 — Daniel : les 2 forfaits PawFamily (mensuel + annuel)
            côte à côte en horizontal. */}
        <div className="mt-6 grid grid-cols-1 gap-5 md:mx-auto md:max-w-3xl md:grid-cols-2">
          {pawfollowPlans
            .filter((p) => p.isFamily)
            .map((p) => (
              <div
                key={p.name}
                className="relative rounded-2xl border-2 border-violet-500 bg-violet-50 p-6 shadow-card ring-1 ring-violet-200 transition"
              >
                {p.badge ? (
                  <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-violet-600 px-3 py-1 text-xs font-semibold text-white">
                    {p.badge}
                  </span>
                ) : null}
                <h4 className="text-lg font-bold text-violet-800">{p.name}</h4>
                <p className="mt-3 text-3xl font-extrabold text-violet-700">
                  {p.price}
                  <span className="ml-1 text-sm font-medium text-ink-muted">{p.period}</span>
                </p>
                <p className="mt-1 text-xs text-ink-muted">{p.tagline}</p>
                <ul className="mt-5 space-y-2">
                  {p.features.map((f) => (
                    <li key={f} className="flex items-start gap-2 text-sm text-ink">
                      <span className="mt-0.5 text-violet-600">✓</span>
                      <span>{f}</span>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
        </div>
      </div>

      <div className="mt-20">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
          {/* v23.1.362 — l'emoji PawSpot doré officiel dans la description. */}
          <PawSpotGoldCoin size={42} className="mr-2 -mt-1" />
          {t("pawspot_title")}
        </h2>
        <p className="mx-auto mt-3 max-w-2xl text-center text-base text-ink-muted">
          {t("pawspot_desc")}
        </p>

        <div className="mx-auto mt-10 grid max-w-3xl grid-cols-1 gap-5 md:grid-cols-2">
          {pawspotOffers.map((o) => (
            <div
              key={o.name}
              className={
                o.highlighted
                  ? "relative rounded-2xl border-4 border-amber-400 bg-amber-50 p-6 shadow-card ring-2 ring-amber-200 md:scale-[1.03]"
                  : "rounded-2xl border border-ink/5 bg-white p-6 shadow-card"
              }
            >
              {o.badge ? (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-amber-400 px-3 py-1 text-xs font-bold text-white">
                  {o.badge}
                </span>
              ) : null}
              <h3 className="text-lg font-bold text-ink">{o.name}</h3>
              <p className="mt-3 text-3xl font-extrabold text-amber-600">{o.price}</p>
              <p className="mt-2 text-sm text-ink-muted">{o.details}</p>
            </div>
          ))}
        </div>
        <p className="mx-auto mt-6 max-w-xl text-center text-xs text-ink-muted">
          {t("pawspot_footer_note")}
        </p>
        {/* v414 — Daniel : "met signalement premium débloqué si un abonnement
            acheté sur tous les abonnements et précise-le dans la description". */}
        <p className="mx-auto mt-4 max-w-2xl rounded-2xl border border-walker/20 bg-walker-light/40 px-5 py-3 text-center text-sm font-semibold text-walker-dark">
          {t("premium_signals_note")}
        </p>

        {/* v416 — Daniel : "rajoute toute l'explication PawPoints là où tu
            présentes PawSpot". Encart PawPoints : gains, niveaux, récompenses. */}
        <div className="mx-auto mt-14 max-w-3xl rounded-3xl border-2 border-amber-300 bg-gradient-to-b from-amber-50 to-white p-8 text-center shadow-card">
          <div className="mx-auto mb-3 grid h-14 w-14 place-items-center rounded-2xl bg-amber-100 text-3xl">🐾</div>
          <h3 className="font-display text-2xl font-extrabold text-amber-700">{t("pawmap_pawpoints_title")}</h3>
          <p className="mx-auto mt-2 max-w-xl text-sm text-ink-muted">
            {t("pawmap_pawpoints_desc")}
          </p>
          <div className="mx-auto mt-5 grid max-w-2xl grid-cols-2 gap-3 sm:grid-cols-4 text-left">
            {[
              { e: "📍", t: t("pawmap_pp_earn_spot") },
              { e: "📷", t: t("pawmap_pp_earn_photo") },
              { e: "✅", t: t("pawmap_pp_earn_validated") },
              { e: "⭐", t: t("pawmap_pp_earn_popular") },
            ].map((x) => (
              <div key={x.t} className="rounded-xl bg-white px-3 py-2 text-xs font-semibold text-ink shadow-sm">
                <span className="mr-1">{x.e}</span>
                {x.t}
              </div>
            ))}
          </div>
          <Link
            href="/pawpoints"
            className="mt-6 inline-block rounded-full bg-amber-500 px-7 py-3 text-sm font-bold text-white hover:brightness-110"
          >
            {t("pawmap_pawpoints_cta")} →
          </Link>
        </div>
      </div>

      <div className="mt-16 text-center">
        <Link
          href="/download"
          className="inline-block rounded-full bg-walker px-7 py-3 text-sm font-semibold text-white hover:bg-walker-dark"
        >
          {t("nav_download")} →
        </Link>
      </div>
    </div>
  );
}
