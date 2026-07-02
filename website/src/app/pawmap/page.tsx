"use client";

import Link from "next/link";
import PawSpotGoldCoin from "@/components/PawSpotGoldCoin";
import { PawMapCTA } from "@/components/PawMapCTA";
import { useT } from "@/lib/i18n/LanguageProvider";

// v493 — Refonte design (design-only) : page PawMap recentrée sur la CARTE et
// la communauté. Les pavés de prix (PawPremium / PawFollow / PawSpot /
// PawPoints détaillés) sont RETIRÉS (ils vivent sur la page Tarifs = /boutique)
// et remplacés par une seule bande « Débloquez les spots premium » → /boutique.
// Aucune donnée/route/logique touchée : mêmes clés i18n, mêmes liens.
export default function PawMapPage() {
  const { t } = useT();

  // Clés map_cat_* déjà traduites dans les 6 langues.
  // v506 — design : une teinte pastel PAR catégorie (au lieu du vert uniforme).
  const cats = [
    { emoji: "🩺", label: t("map_cat_vet"), tint: "bg-red-50" },
    { emoji: "🛒", label: t("map_cat_shop"), tint: "bg-blue-50" },
    { emoji: "✂️", label: t("map_cat_groomer"), tint: "bg-pink-50" },
    { emoji: "🌳", label: t("map_cat_park"), tint: "bg-green-50" },
    { emoji: "🏖️", label: t("map_cat_beach"), tint: "bg-amber-50" },
    { emoji: "💧", label: t("map_cat_water"), tint: "bg-cyan-50" },
    { emoji: "🎓", label: t("map_cat_trainer"), tint: "bg-violet-50" },
    { emoji: "🏨", label: t("map_cat_hotel"), tint: "bg-indigo-50" },
    { emoji: "🍽️", label: t("map_cat_restaurant"), tint: "bg-orange-50" },
  ];

  // « Comment ça marche » communautaire en 3 étapes (Explorer → Taguer/noter →
  // PawPoints) — réutilise des clés existantes (aucune nouvelle traduction).
  // v506 — design : chaque étape a sa couleur (orange / rose / ambre).
  const steps = [
    { n: "1", emoji: "🔍", body: t("pawmap_msg_places"), badge: "bg-owner", tint: "bg-owner-light" },
    { n: "2", emoji: "📍", body: t("pawspot_desc"), badge: "bg-[#e83e8c]", tint: "bg-pink-50" },
    { n: "3", emoji: "🐾", body: t("pawmap_pawpoints_desc"), badge: "bg-amber-500", tint: "bg-amber-50" },
  ];

  return (
    <div className="mx-auto max-w-5xl px-4 py-16 md:py-24">
      {/* ── 1. HERO ── logo + badge 177 pays + titre + sous-titre + aperçu
           carte + CTA. v506 — design : badge héro + logo dans une pastille. */}
      <div className="grid items-center gap-10 md:grid-cols-2">
        <div className="text-center md:text-left">
          <div className="mb-5 flex items-center justify-center gap-4 md:justify-start">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/pawmap_logo_orange.svg" alt="PawMap" width={84} height={84} className="drop-shadow-md" />
            <span className="inline-flex items-center gap-1.5 rounded-full border border-owner/25 bg-white px-3 py-1 text-xs font-bold text-owner shadow-sm">
              🌍 {t("hero_badge")}
            </span>
          </div>
          <h1 className="font-display text-4xl font-extrabold tracking-tight text-ink md:text-5xl">
            {t("pawmap_title")}
          </h1>
          <p className="mt-4 max-w-xl text-lg text-ink-muted">{t("pawmap_sub")}</p>
          <div className="mt-7 flex flex-wrap justify-center gap-3 md:justify-start">
            <PawMapCTA size="hero" />
          </div>
        </div>

        {/* Aperçu visuel de la carte : pins par catégorie + chips de filtre +
            un spot mis en avant (décoratif). */}
        <div className="relative">
          <div className="relative mx-auto aspect-square w-full max-w-sm overflow-hidden rounded-[26px] border border-[#efe7e0] bg-gradient-to-br from-walker-light via-white to-sitter-light/50 shadow-card">
            {/* chips de filtre */}
            <div className="absolute left-3 right-3 top-3 flex flex-wrap gap-1.5">
              {cats.slice(0, 4).map((c) => (
                <span key={c.label} className="rounded-full bg-white/90 px-2.5 py-1 text-[10px] font-bold text-ink shadow-sm">
                  {c.emoji} {c.label}
                </span>
              ))}
            </div>
            {/* pins dispersés */}
            {[
              { e: "🩺", top: "32%", left: "22%", bg: "bg-owner" },
              { e: "🌳", top: "52%", left: "62%", bg: "bg-walker" },
              { e: "💧", top: "70%", left: "30%", bg: "bg-sitter" },
              { e: "🍽️", top: "40%", left: "78%", bg: "bg-amber-500" },
            ].map((p) => (
              <span
                key={p.e}
                className={`absolute grid h-9 w-9 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full ${p.bg} text-base shadow-card ring-2 ring-white`}
                style={{ top: p.top, left: p.left }}
              >
                {p.e}
              </span>
            ))}
            {/* spot mis en avant */}
            <div className="absolute bottom-3 left-3 right-3 flex items-center gap-3 rounded-2xl bg-white/95 p-3 shadow-card">
              <PawSpotGoldCoin size={34} />
              <div className="min-w-0">
                <div className="truncate text-xs font-extrabold text-amber-700">{t("map_cat_park")}</div>
                <div className="truncate text-[11px] text-ink-muted">4.9 ★ · PawSpot</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ── 2. GRILLE DES 9 CATÉGORIES ── */}
      <div className="mt-16">
        <h2 className="text-center font-display text-2xl font-extrabold tracking-tight text-ink md:text-3xl">
          {t("pawmap_categories")}
        </h2>
        <div className="mt-8 grid grid-cols-2 gap-3 sm:grid-cols-3">
          {cats.map((c) => (
            <div
              key={c.label}
              className="flex items-center gap-3 rounded-2xl border border-[#efe7e0] bg-white p-4 shadow-card transition hover:-translate-y-0.5 hover:shadow-lg"
            >
              <span className={`grid h-11 w-11 shrink-0 place-items-center rounded-xl text-xl ${c.tint}`}>{c.emoji}</span>
              <span className="text-sm font-semibold text-ink">{c.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* ── 3. COMMENT ÇA MARCHE (communauté, 3 étapes) ── */}
      <div className="mt-20">
        <h2 className="text-center font-display text-2xl font-extrabold tracking-tight text-ink md:text-3xl">
          {t("nav_how")}
        </h2>
        <div className="mt-8 grid gap-5 md:grid-cols-3">
          {steps.map((s) => (
            <div
              key={s.n}
              className="relative rounded-[22px] border border-[#efe7e0] bg-white p-6 shadow-card transition hover:-translate-y-0.5 hover:shadow-lg"
            >
              <div className="flex items-center gap-3">
                <span className={`grid h-9 w-9 place-items-center rounded-full text-sm font-extrabold text-white shadow-sm ${s.badge}`}>{s.n}</span>
                <span className={`grid h-11 w-11 place-items-center rounded-xl text-2xl ${s.tint}`}>{s.emoji}</span>
              </div>
              <p className="mt-4 text-sm leading-relaxed text-ink-muted">{s.body}</p>
            </div>
          ))}
        </div>
      </div>

      {/* ── 4. DÉBLOQUEZ LES SPOTS PREMIUM ── une seule bande → Tarifs (/boutique).
           Remplace TOUS les anciens pavés de prix (Premium/PawFollow/PawSpot).
           v493 — plus d'air : marge haute + padding & espacements internes généreux. */}
      <section className="mt-24 overflow-hidden rounded-[26px] bg-gradient-to-b from-[#221C12] to-[#15120D] p-9 text-center md:p-12">
        <div className="flex justify-center">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="PawPremium" width={72} height={72} />
        </div>
        <h2 className="mt-4 font-display text-2xl font-extrabold tracking-tight text-yellow-400 md:text-3xl">
          PawPremium 👑
        </h2>
        <p className="mx-auto mt-3 max-w-xl text-sm leading-relaxed text-white/85">{t("pawpremium_subtitle")}</p>
        <p className="mx-auto mt-3 max-w-xl text-xs leading-relaxed text-white/60">{t("premium_signals_note")}</p>
        <Link
          href="/boutique"
          className="mt-7 inline-block rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-7 py-3.5 text-sm font-bold text-black shadow-cta transition hover:brightness-110"
        >
          {t("pawpremium_cta")} →
        </Link>
      </section>

      {/* ── 5. CTA FINAL ── */}
      <div className="mt-14 text-center">
        <Link
          href="/download"
          className="inline-block rounded-full bg-walker px-7 py-3.5 text-sm font-bold text-white shadow-cta transition hover:bg-walker-dark"
        >
          {t("nav_download")} →
        </Link>
      </div>
    </div>
  );
}
