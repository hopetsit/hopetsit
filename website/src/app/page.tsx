"use client";

import { SubscriptionsExplainer } from "@/components/SubscriptionsExplainer";
import Link from "next/link";
import { PawMapCTA } from "@/components/PawMapCTA";
import StoreBadges from "@/components/StoreBadges";
import { useT } from "@/lib/i18n/LanguageProvider";
import { screensFor, pawmapShotFor, PhoneFrame } from "@/lib/screens";

// v562 — Refonte « minimaliste, pro, façon Apple » (Daniel, 13/09).
// Design uniquement : mêmes clés i18n, mêmes routes (/download, /login,
// /signup, /pawmap, /boutique, /map). Beaucoup d'air, titres centrés en
// grande taille, fonds blanc / gris très clair, une seule couleur d'accent,
// captures réelles de l'app (v561) dans des cadres de téléphone sobres.
// Ordre : héro · preuves · vidéo · comment ça marche · rôles · 3 services ·
// PawMap · l'app en images · abonnements · PawPremium · FAQ · CTA final.
export default function HomePage() {
  const { t, lang } = useT();

  const roles = [
    { color: "owner", title: t("role_owner_title"), body: t("role_owner_body"), emoji: "🐾" },
    { color: "sitter", title: t("role_sitter_title"), body: t("role_sitter_body"), emoji: "🏠" },
    { color: "walker", title: t("role_walker_title"), body: t("role_walker_body"), emoji: "🚶" },
  ] as const;

  const trust = [
    { title: t("trust_id_title"), body: t("trust_id_body"), icon: "✓" },
    { title: t("trust_pay_title"), body: t("trust_pay_body"), icon: "🔒" },
    { title: t("trust_chat_title"), body: t("trust_chat_body"), icon: "💬" },
    { title: t("trust_map_title"), body: t("trust_map_body"), icon: "🗺️" },
  ];

  const services = [
    {
      kind: "petsitting",
      name: "PetSitting",
      title: t("home_app1_title"),
      body: t("home_app1_body"),
      price: t("pricing_owner_price"),
      cta: t("nav_signup"),
      href: "/signup",
      logo: "/pawboost_logo.svg",
    },
    {
      kind: "pawfollow",
      name: "PawFollow",
      title: t("home_app2_title"),
      body: t("home_app2_body"),
      price: "",
      cta: `${t("home_discover")} PawFollow`,
      href: "/boutique",
      logo: "/pawfollow_logo.svg",
    },
    {
      kind: "pawspot",
      name: "PawSpot",
      title: t("home_app3_title"),
      body: t("home_app3_body"),
      price: "",
      cta: `${t("home_discover")} PawSpot`,
      href: "/pawmap",
      logo: "/pawspot_logo.svg",
    },
  ] as const;

  const steps = [
    { n: "01", title: t("how_step1_title"), body: t("how_step1_body") },
    { n: "02", title: t("how_step2_title"), body: t("how_step2_body") },
    { n: "03", title: t("how_step3_title"), body: t("how_step3_body") },
    { n: "04", title: t("how_step4_title"), body: t("how_step4_body") },
  ] as const;

  const faq = Array.from({ length: 10 }, (_, i) => ({
    q: t(`faq_q${i + 1}`),
    a: t(`faq_a${i + 1}`),
  })).filter((x) => x.q && !x.q.startsWith("faq_"));

  const shots = screensFor(lang);
  const pawmapShot = pawmapShotFor(lang);

  return (
    <>
      {/* ── 1. HÉRO ── centré, sobre : titre XXL, sous-titre, 2 CTA, badges
           stores, puis le téléphone avec la PawMap réelle. */}
      <section className="bg-white">
        <div className="mx-auto max-w-4xl px-4 pb-10 pt-20 text-center md:pt-28">
          <span className="inline-flex items-center gap-2 rounded-full bg-[#F5F5F7] px-3.5 py-1.5 text-xs font-semibold text-[#6E6E73]">
            🌍 {t("hero_badge")}
          </span>
          <h1 className="mt-6 font-display text-[2.75rem] font-bold leading-[1.05] tracking-[-0.03em] text-[#1D1D1F] md:text-7xl">
            {t("hero_title")}
          </h1>
          <p className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-[#6E6E73] md:text-xl">
            {t("hero_sub")}
          </p>
          <div className="mt-9 flex flex-wrap justify-center gap-3">
            <Link
              href="/download"
              className="inline-flex items-center gap-2 rounded-full bg-owner px-7 py-3.5 text-[15px] font-semibold text-white transition hover:bg-owner-dark"
            >
              {t("hero_cta_app")}
              <span aria-hidden>→</span>
            </Link>
            <Link
              href="/login"
              className="inline-flex items-center rounded-full bg-[#F5F5F7] px-7 py-3.5 text-[15px] font-semibold text-[#1D1D1F] transition hover:bg-[#E8E8ED]"
            >
              {t("hero_cta_web_login")}
            </Link>
          </div>
          <div className="mt-7 flex justify-center">
            <StoreBadges center />
          </div>
          <ul className="mt-8 flex flex-wrap justify-center gap-x-8 gap-y-2 text-[13px] font-medium text-[#6E6E73]">
            <li className="inline-flex items-center gap-1.5"><span className="text-walker">✓</span>{t("trust_id_title")}</li>
            <li className="inline-flex items-center gap-1.5"><span>🔒</span>{t("trust_pay_title")}</li>
            <li className="inline-flex items-center gap-1.5"><span>🗺️</span>{t("trust_map_title")}</li>
          </ul>
        </div>

        <div className="relative mx-auto max-w-6xl px-4 pb-24">
          <div aria-hidden className="pointer-events-none absolute inset-x-0 bottom-0 top-1/2 rounded-[40px] bg-[#F5F5F7]" />
          <div className="relative flex items-end justify-center gap-6 md:gap-10">
            <PhoneFrame src={shots[2]?.src ?? pawmapShot} alt={shots[2]?.alt ?? "HoPetSit"} className="hidden w-52 md:block" />
            <PhoneFrame src={pawmapShot} alt="HoPetSit — PawMap" className="w-64 md:w-72" priority />
            <PhoneFrame src={shots[3]?.src ?? pawmapShot} alt={shots[3]?.alt ?? "HoPetSit"} className="hidden w-52 md:block" />
          </div>
        </div>
      </section>

      {/* ── 2. PREUVES ── 4 points, sans bande sombre. */}
      <section className="border-y border-black/5 bg-white">
        <div className="mx-auto grid max-w-6xl grid-cols-2 gap-8 px-4 py-12 md:grid-cols-4">
          {trust.map((tr) => (
            <div key={tr.title} className="text-center">
              <div className="mx-auto grid h-11 w-11 place-items-center rounded-full bg-[#F5F5F7] text-base">{tr.icon}</div>
              <div className="mt-3 text-sm font-semibold text-[#1D1D1F]">{tr.title}</div>
              <div className="mt-1 text-xs leading-snug text-[#6E6E73]">{tr.body}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ── 3. VIDÉO ── */}
      <section className="mx-auto max-w-5xl px-4 py-24">
        <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
          {t("video_title")}
        </h2>
        <p className="mx-auto mt-4 max-w-2xl text-center text-lg text-[#6E6E73]">{t("video_sub")}</p>
        <div className="mt-12 overflow-hidden rounded-[28px] bg-black shadow-[0_30px_60px_-30px_rgba(0,0,0,0.5)]">
          <video controls playsInline preload="metadata" poster="/videos/hopetsit_presentation_poster.jpg" className="block h-auto w-full">
            <source src="/videos/hopetsit_presentation.mp4" type="video/mp4" />
          </video>
        </div>
      </section>

      {/* ── 4. COMMENT ÇA MARCHE ── 4 étapes, numéros fins, fond gris clair. */}
      <section className="bg-[#F5F5F7] py-24">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
            {t("how_title")}
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-center text-lg text-[#6E6E73]">{t("how_sub")}</p>
          <div className="mt-14 grid gap-4 md:grid-cols-4">
            {steps.map((s) => (
              <div key={s.n} className="rounded-[24px] bg-white p-7">
                <span className="font-display text-sm font-semibold tracking-widest text-owner">{s.n}</span>
                <h3 className="mt-4 text-lg font-semibold text-[#1D1D1F]">{s.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-[#6E6E73]">{s.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── 5. TROIS RÔLES ── */}
      <section className="mx-auto max-w-6xl px-4 py-24">
        <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
          {t("roles_title")}
        </h2>
        <div className="mt-12 grid gap-4 md:grid-cols-3">
          {roles.map((r) => (
            <div key={r.title} className="rounded-[24px] bg-[#F5F5F7] p-8">
              <div className={`grid h-12 w-12 place-items-center rounded-full bg-${r.color}-light text-2xl`}>{r.emoji}</div>
              <h3 className="mt-5 text-xl font-semibold text-[#1D1D1F]">{r.title}</h3>
              <p className="mt-2 text-[15px] leading-relaxed text-[#6E6E73]">{r.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── 6. 3 SERVICES, UNE SEULE APP ── nouvelles icônes produits. */}
      <section className="bg-[#F5F5F7] py-24">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
            {t("home_3in1_title")}
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-center text-lg text-[#6E6E73]">{t("home_3in1_sub")}</p>
          <div className="mt-12 grid gap-4 md:grid-cols-3">
            {services.map((s) => (
              <div key={s.name} className="flex flex-col rounded-[24px] bg-white p-8">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={s.logo} alt="" width={56} height={56} className="h-14 w-14" />
                <h3 className="mt-5 text-xl font-semibold text-[#1D1D1F]">{s.name}</h3>
                <p className="mt-1 text-xs font-semibold uppercase tracking-wider text-[#6E6E73]">{s.title}</p>
                <p className="mt-3 text-[15px] leading-relaxed text-[#6E6E73]">{s.body}</p>
                <div className="mt-auto flex items-center justify-between gap-3 pt-7">
                  {s.price ? <span className="text-sm font-semibold text-[#1D1D1F]">{s.price}</span> : <span />}
                  <Link href={s.href} className="text-sm font-semibold text-owner hover:underline">
                    {s.cta} →
                  </Link>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── 7. PAWMAP ── la fonctionnalité phare : titre, texte, 2 captures
           réelles (Paris + Dallas). */}
      <section className="mx-auto max-w-6xl px-4 py-24">
        <div className="grid items-center gap-14 md:grid-cols-2">
          <div>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/pawmap_logo_orange.svg" alt="PawMap" width={56} height={56} />
            <h2 className="mt-6 font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
              {t("pawmap_title")}
            </h2>
            <p className="mt-5 max-w-xl text-lg leading-relaxed text-[#6E6E73]">{t("pawmap_sub")}</p>
            <div className="mt-8 rounded-[20px] bg-[#F5F5F7] p-5">
              <div className="flex items-center gap-2 text-sm font-semibold text-[#1D1D1F]">
                <span className="relative flex h-2.5 w-2.5">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-walker opacity-70" />
                  <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-walker" />
                </span>
                {t("hiw_track_title")}
              </div>
              <p className="mt-2 text-sm leading-relaxed text-[#6E6E73]">{t("hiw_track_body")}</p>
            </div>
            <div className="mt-8 flex flex-wrap items-center gap-3">
              <PawMapCTA size="hero" />
              <Link href="/pawmap" className="rounded-full bg-[#F5F5F7] px-6 py-3.5 text-sm font-semibold text-[#1D1D1F] transition hover:bg-[#E8E8ED]">
                {t("home_discover")} PawSpot →
              </Link>
            </div>
          </div>
          <div className="flex items-end justify-center gap-5">
            <PhoneFrame src={pawmapShot} alt="HoPetSit — PawMap Paris" className="w-52 md:w-60" />
            <PhoneFrame src="/screens/v561/fr/11-carte-dallas.jpg" alt="HoPetSit — PawMap Dallas" className="w-44 md:w-52" />
          </div>
        </div>
      </section>

      {/* ── 8. L'APP EN IMAGES ── captures réelles v561, bande défilable. */}
      <section className="bg-[#F5F5F7] py-24">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
            {t("screens_title")}
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-center text-lg text-[#6E6E73]">{t("screens_sub")}</p>
          <div className="mt-12 flex snap-x snap-mandatory gap-5 overflow-x-auto pb-4 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
            {shots.map((s) => (
              <PhoneFrame key={s.src} src={s.src} alt={`HoPetSit — ${s.alt}`} className="w-44 shrink-0 snap-center first:ml-auto last:mr-auto" />
            ))}
          </div>
        </div>
      </section>

      {/* ── 9. ABONNEMENTS EXPLIQUÉS ── */}
      <SubscriptionsExplainer />

      {/* ── 10. PAWPREMIUM ── bande noire sobre. */}
      <section className="px-4 py-20">
        <div className="mx-auto flex max-w-4xl flex-col items-center gap-8 rounded-[28px] bg-[#1D1D1F] p-10 text-center md:flex-row md:p-14 md:text-left">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="PawPremium" width={88} height={88} className="shrink-0" />
          <div className="flex-1">
            <h2 className="font-display text-2xl font-bold tracking-[-0.02em] text-[#FFD34D] md:text-3xl">PawPremium</h2>
            <p className="mx-auto mt-3 max-w-xl text-[15px] leading-relaxed text-white/75 md:mx-0">{t("home_pawpremium_blurb")}</p>
          </div>
          <Link href="/boutique" className="shrink-0 rounded-full bg-white px-7 py-3.5 text-sm font-semibold text-[#1D1D1F] transition hover:bg-[#E8E8ED]">
            {t("home_discover")} PawPremium →
          </Link>
        </div>
      </section>

      {/* ── 11. FAQ ── accordéon natif, une colonne, lignes fines. */}
      <section className="mx-auto max-w-3xl px-4 py-24">
        <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">
          {t("faq_title")}
        </h2>
        <div className="mt-12 divide-y divide-black/10 border-y border-black/10">
          {faq.map((f, i) => (
            <details key={f.q} className="group py-5" open={i === 0}>
              <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-[17px] font-semibold text-[#1D1D1F] [&::-webkit-details-marker]:hidden">
                {f.q}
                <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-[#F5F5F7] text-[#6E6E73] transition group-open:rotate-45">+</span>
              </summary>
              <p className="mt-3 text-[15px] leading-relaxed text-[#6E6E73]">{f.a}</p>
            </details>
          ))}
        </div>
      </section>

      {/* ── 12. CTA FINAL ── */}
      <section className="bg-[#F5F5F7] px-4 py-24">
        <div className="mx-auto max-w-3xl text-center">
          <h2 className="font-display text-3xl font-bold tracking-[-0.02em] text-[#1D1D1F] md:text-5xl">{t("cta_join_title")}</h2>
          <p className="mx-auto mt-4 max-w-2xl text-lg text-[#6E6E73]">{t("cta_join_sub")}</p>
          <div className="mt-8 flex flex-wrap justify-center gap-3">
            <Link href="/signup" className="rounded-full bg-owner px-7 py-3.5 text-[15px] font-semibold text-white transition hover:bg-owner-dark">
              {t("nav_signup")}
            </Link>
            <Link href="/download" className="rounded-full bg-white px-7 py-3.5 text-[15px] font-semibold text-[#1D1D1F] transition hover:bg-[#E8E8ED]">
              {t("nav_download")}
            </Link>
          </div>
          <div className="mt-6 flex justify-center">
            <StoreBadges center />
          </div>
        </div>
      </section>
    </>
  );
}
