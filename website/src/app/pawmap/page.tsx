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

      <div className="mt-12 text-center">
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
