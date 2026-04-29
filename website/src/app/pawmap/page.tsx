"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";

type Plan = {
  name: string;
  price: string;
  period: string;
  tagline: string;
  features: string[];
  highlighted: boolean;
  badge?: string;
};

type Offer = {
  name: string;
  price: string;
  details: string;
};

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
      ],
      highlighted: false,
      badge: t("pawfollow_family_badge"),
    },
  ];

  const pawspotOffers: Offer[] = [
    { name: t("pawspot_24h_name"), price: "1,99 €", details: t("pawspot_24h_details") },
    { name: t("pawspot_7d_name"), price: "8,99 €", details: t("pawspot_7d_details") },
    { name: t("pawspot_30d_name"), price: "24,99 €", details: t("pawspot_30d_details") },
  ];

  return (
    <div className="mx-auto max-w-5xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight md:text-5xl">
        {t("pawmap_title")}
      </h1>
      <p className="mx-auto mt-4 max-w-2xl text-center text-lg text-ink-muted">{t("pawmap_sub")}</p>
      <p className="mt-3 text-center text-sm font-semibold text-walker-dark">{t("pawmap_categories")}</p>

      <div className="mt-14 grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-3">
        {cats.map((c) => (
          <div key={c.label} className="flex items-center gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
            <span className="grid h-10 w-10 place-items-center rounded-xl bg-walker-light text-xl">{c.emoji}</span>
            <span className="text-sm font-semibold text-ink">{c.label}</span>
          </div>
        ))}
      </div>

      <div className="mt-20">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
          {t("pawfollow_title")}
        </h2>
        <p className="mx-auto mt-3 max-w-2xl text-center text-base text-ink-muted">
          {t("pawfollow_desc")}
        </p>

        <div className="mt-10 grid grid-cols-1 gap-5 md:grid-cols-3">
          {pawfollowPlans.map((p) => (
            <div
              key={p.name}
              className={
                "relative rounded-2xl border bg-white p-6 shadow-card transition " +
                (p.highlighted ? "border-walker ring-2 ring-walker scale-[1.02]" : "border-ink/5")
              }
            >
              {p.badge ? (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-walker px-3 py-1 text-xs font-semibold text-white">
                  {p.badge}
                </span>
              ) : null}
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

      <div className="mt-20">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
          {t("pawspot_title")}
        </h2>
        <p className="mx-auto mt-3 max-w-2xl text-center text-base text-ink-muted">
          {t("pawspot_desc")}
        </p>

        <div className="mt-10 grid grid-cols-1 gap-5 md:grid-cols-3">
          {pawspotOffers.map((o) => (
            <div key={o.name} className="rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
              <h3 className="text-lg font-bold text-ink">{o.name}</h3>
              <p className="mt-3 text-3xl font-extrabold text-walker-dark">{o.price}</p>
              <p className="mt-2 text-sm text-ink-muted">{o.details}</p>
            </div>
          ))}
        </div>
        <p className="mx-auto mt-6 max-w-xl text-center text-xs text-ink-muted">
          {t("pawspot_footer_note")}
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
