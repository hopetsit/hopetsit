"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";

export default function PawMapPage() {
  const { t } = useT();
  const cats = [
    { emoji: "🩺", label: "Vets" },
    { emoji: "🛒", label: "Pet shops" },
    { emoji: "✂️", label: "Groomers" },
    { emoji: "🌳", label: "Dog parks" },
    { emoji: "🏖️", label: "Pet beaches" },
    { emoji: "💧", label: "Water points" },
    { emoji: "🎓", label: "Trainers" },
    { emoji: "🏨", label: "Pet-friendly hotels" },
    { emoji: "🍽️", label: "Pet-friendly restaurants" },
  ];

  // v23.1 — PawFollow plans (formerly PawPass).
  const pawfollowPlans = [
    {
      name: "PawFollow Mensuel",
      price: "6,99 €",
      period: "/ mois",
      tagline: "Sans engagement",
      features: [
        "Reports communautaires sur la PawMap",
        "Carte des amis et alertes proximité",
        "Chat illimité",
        "1 PawSpot offert / mois",
      ],
      highlighted: false,
      badge: undefined as string | undefined,
    },
    {
      name: "PawFollow Annuel",
      price: "49,99 €",
      period: "/ an",
      tagline: "≈ 4,17 € / mois — économise 40%",
      features: [
        "Tout PawFollow Mensuel",
        "2 mois offerts vs mensuel",
        "Engagement 12 mois",
      ],
      highlighted: true,
      badge: "ÉCONOMIQUE" as string | undefined,
    },
    {
      name: "PawFollow Famille",
      price: "9,99 €",
      period: "/ mois",
      tagline: "Jusqu'à 5 utilisateurs",
      features: [
        "Tout PawFollow Mensuel",
        "Partage avec 5 membres famille",
        "Suivi temps-réel partagé",
        "Chat groupe famille + sitter / walker",
      ],
      highlighted: false,
      badge: "POPULAIRE" as string | undefined,
    },
  ];

  // PawSpot — boost ponctuel d'un lieu sur la PawMap.
  const pawspotOffers = [
    { name: "PawSpot 24h", price: "1,99 €", details: "Mise en avant 24 heures sur la carte" },
    { name: "PawSpot 7 jours", price: "8,99 €", details: "Mise en avant 1 semaine + halo lumineux" },
    { name: "PawSpot 30 jours", price: "24,99 €", details: "Mise en avant 1 mois + push notifications proximité" },
  ];

  return (
    <div className="mx-auto max-w-5xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight md:text-5xl">
        {t("pawmap_title")}
      </h1>
      <p className="mx-auto mt-4 max-w-2xl text-center text-lg text-ink-muted">{t("pawmap_sub")}</p>
      <p className="mt-3 text-center text-sm font-semibold text-walker-dark">
        {t("pawmap_categories")}
      </p>

      <div className="mt-14 grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-3">
        {cats.map((c) => (
          <div
            key={c.label}
            className="flex items-center gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card"
          >
            <span className="grid h-10 w-10 place-items-center rounded-xl bg-walker-light text-xl">
              {c.emoji}
            </span>
            <span className="text-sm font-semibold text-ink">{c.label}</span>
          </div>
        ))}
      </div>

      {/* PawFollow plans */}
      <div className="mt-20">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
          PawFollow
        </h2>
        <p className="mx-auto mt-3 max-w-2xl text-center text-base text-ink-muted">
          Débloque toutes les fonctionnalités de la PawMap, le suivi temps-réel
          et le chat illimité avec ton sitter / walker.
        </p>

        <div className="mt-10 grid grid-cols-1 gap-5 md:grid-cols-3">
          {pawfollowPlans.map((p) => (
            <div
              key={p.name}
              className={`relative rounded-2xl border bg-white p-6 shadow-card transition ${
                p.highlighted
                  ? "border-walker ring-2 ring-walker scale-[1.02]"
                  : "border-ink/5"
              }`}
            >
              {p.badge && (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-walker px-3 py-1 text-xs font-semibold text-white">
                  {p.badge}
                </span>
              )}
              <h3 className="text-lg font-bold text-ink">{p.name}</h3>
              <p className="mt-3 text-3xl font-extrabold text-walker-dark">
                {p.price}
                <span className="ml-1 text-sm font-medium text-ink-muted">{p.period}</span>
              </p>
              <p className="mt-1 text-xs text-ink-muted">{p.tagline}</p>
              <ul className="mt-5 space-y-2">
                {p.features.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm text-ink">
                    <span className="mt-0.5 text-walker">✓</span>
                    <span>{f}</span>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>

      {/* PawSpot offers */}
      <div className="mt-20">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
          PawSpot
        </h2>
        <p className="mx-auto mt-3 max-w-2xl text-center text-base text-ink-muted">
          Mets en avant un lieu (cabinet véto, pet shop, salon de toilettage, café
          pet-friendly…) sur la PawMap pour être vu en priorité par les utilisateurs
          autour de toi.
        </p>

        <div className="mt-10 grid grid-cols-1 gap-5 md:grid-cols-3">
          {pawspotOffers.map((o) => (
            <div
              key={o.name}
              className="rounded-2xl border border-ink/5 bg-white p-6 shadow-card"
            >
              <h3 className="text-lg font-bold text-ink">{o.name}</h3>
              <p className="mt-3 text-3xl font-extrabold text-walker-dark">{o.price}</p>
              <p className="mt-2 text-sm text-ink-muted">{o.details}</p>
            </div>
          ))}
        </div>
        <p className="mx-auto mt-6 max-w-xl text-center text-xs text-ink-muted">
          Chaque abonnement PawFollow inclut 1 PawSpot 24h offert par mois.
        </p>
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
