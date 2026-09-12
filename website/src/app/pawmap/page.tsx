"use client";

import Link from "next/link";
import { PawMapCTA } from "@/components/PawMapCTA";
import { SubscriptionsExplainer } from "@/components/SubscriptionsExplainer";
import { useT } from "@/lib/i18n/LanguageProvider";
import { PhoneFrame, pawmapShotFor } from "@/lib/screens";

// v493 — page PawMap recentrée sur la carte et la communauté.
// v562 — refonte minimaliste façon Apple (Daniel, 13/09) : la carte
// décorative est remplacée par de VRAIES captures de la v561 (Paris + Dallas,
// itinéraire, « Autour de moi »), cartes gris clair, une seule couleur
// d'accent. Mêmes clés i18n, mêmes routes.
export default function PawMapPage() {
  const { t, lang } = useT();

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

  const steps = [
    { n: "01", body: t("pawmap_step1") },
    { n: "02", body: t("pawspot_desc") },
    { n: "03", body: t("pawmap_pawpoints_desc") },
  ];

  const dir = lang === "fr" ? "fr" : "en";
  const gallery = [
    { src: pawmapShotFor(lang), alt: "PawMap" },
    { src: `/screens/v561/${dir}/${dir === "fr" ? "09-autour-liste" : "09-around-list"}.jpg`, alt: t("pawmap_categories") },
    { src: `/screens/v561/${dir}/${dir === "fr" ? "10-itineraire" : "10-route"}.jpg`, alt: "Itinéraire" },
    { src: `/screens/v561/${dir}/${dir === "fr" ? "11-carte-dallas" : "11-map-dallas"}.jpg`, alt: "PawMap Dallas" },
  ];

  return (
    <div className="bg-white">
      {/* ── 1. HÉRO ── */}
      <div className="mx-auto max-w-4xl px-4 pb-12 pt-20 text-center md:pt-28">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/pawmap_logo_orange.svg" alt="PawMap" width={72} height={72} className="mx-auto" />
        <span className="mt-6 inline-flex items-center gap-2 rounded-full bg-[#F5F5F7] px-3.5 py-1.5 text-xs font-semibold text-[#6E6E73]">
          🌍 {t("hero_badge")}
        </span>
        <h1 className="mt-5 font-display text-[2.75rem] font-bold leading-[1.05] tracking-[-0.03em] text-[#1D1D1F] md:text-6xl">
          {t("pawmap_title")}
        </h1>
        <p className="mx-auto mt-5 max-w-2xl text-lg text-[#6E6E73] md:text-xl">{t("pawmap_sub")}</p>
        <div className="mt-8 flex justify-center">
          <PawMapCTA size="hero" />
        </div>
      </div>

      {/* ── 2. LA CARTE EN VRAI ── 4 captures (Paris, autour de moi, itinéraire, Dallas). */}
      <div className="bg-[#F5F5F7] py-16">
        <div className="mx-auto flex max-w-5xl snap-x snap-mandatory gap-6 overflow-x-auto px-4 pb-4 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          {gallery.map((g) => (
            <PhoneFrame key={g.src} src={g.src} alt={`HoPetSit — ${g.alt}`} className="w-48 shrink-0 snap-center first:ml-auto last:mr-auto" />
          ))}
        </div>
      </div>

      <div className="mx-auto max-w-5xl px-4 py-24">
        {/* ── 3. CATÉGORIES ── */}
        <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
          {t("pawmap_categories")}
        </h2>
        <div className="mt-10 grid grid-cols-2 gap-3 sm:grid-cols-3">
          {cats.map((c) => (
            <div key={c.label} className="flex items-center gap-3 rounded-[18px] bg-[#F5F5F7] p-4">
              <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-white text-xl">{c.emoji}</span>
              <span className="text-sm font-semibold text-[#1D1D1F]">{c.label}</span>
            </div>
          ))}
        </div>

        {/* ── 4. COMMENT ÇA MARCHE ── */}
        <h2 className="mt-24 text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
          {t("nav_how")}
        </h2>
        <div className="mt-10 grid gap-4 md:grid-cols-3">
          {steps.map((s) => (
            <div key={s.n} className="rounded-[24px] bg-[#F5F5F7] p-7">
              <span className="font-display text-sm font-semibold tracking-widest text-owner">{s.n}</span>
              <p className="mt-3 text-[15px] leading-relaxed text-[#1D1D1F]">{s.body}</p>
            </div>
          ))}
        </div>

        {/* ── 5. PAWPREMIUM ── */}
        <section className="mt-24 flex flex-col items-center gap-8 rounded-[28px] bg-[#1D1D1F] p-10 text-center md:flex-row md:p-14 md:text-left">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="PawPremium" width={88} height={88} className="shrink-0" />
          <div className="flex-1">
            <h2 className="font-display text-2xl font-bold tracking-[-0.02em] text-[#FFD34D] md:text-3xl">PawPremium</h2>
            <p className="mx-auto mt-3 max-w-xl text-[15px] leading-relaxed text-white/75 md:mx-0">{t("pawpremium_subtitle")}</p>
            <p className="mx-auto mt-2 max-w-xl text-xs leading-relaxed text-white/50 md:mx-0">{t("premium_signals_note")}</p>
          </div>
          <Link href="/boutique" className="shrink-0 rounded-full bg-white px-7 py-3.5 text-sm font-semibold text-[#1D1D1F] transition hover:bg-[#E8E8ED]">
            {t("pawpremium_cta")} →
          </Link>
        </section>

        <SubscriptionsExplainer compact />

        <div className="mt-10 text-center">
          <Link href="/download" className="inline-block rounded-full bg-owner px-7 py-3.5 text-[15px] font-semibold text-white transition hover:bg-owner-dark">
            {t("nav_download")} →
          </Link>
        </div>
      </div>
    </div>
  );
}
