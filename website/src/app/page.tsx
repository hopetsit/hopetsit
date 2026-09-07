"use client";

import { SubscriptionsExplainer } from "@/components/SubscriptionsExplainer";
import Link from "next/link";
import PawSpotGoldCoin from "@/components/PawSpotGoldCoin";
import { PawMemberBadge } from "@/components/PawMemberBadge";
import { PawMapCTA } from "@/components/PawMapCTA";
import StoreBadges from "@/components/StoreBadges";
import { useT } from "@/lib/i18n/LanguageProvider";
// v534 — captures d'ecran par langue (EN / FR).
import { screensFor } from "@/lib/screens";

// v556 — Refonte « premium » de l'accueil (Daniel : « trop simple, refais-la »).
// Design uniquement : mêmes clés i18n, mêmes routes (/download, /login,
// /signup, /pawmap, /boutique, /map). Ordre des 12 blocs :
//   1 Héro · 2 Confiance · 3 Vidéo · 4 Comment ça marche (4 étapes) ·
//   5 Trois rôles · 6 Trois services · 7 Bande PawMap (suivi gratuit + CTA) ·
//   8 L'app en images · 9 Abonnements expliqués · 10 PawPremium · 11 FAQ ·
//   12 CTA final.
export default function HomePage() {
  const { t, lang } = useT();

  const roles = [
    { color: "owner",  title: t("role_owner_title"),  body: t("role_owner_body"),  emoji: "🐾" },
    { color: "sitter", title: t("role_sitter_title"), body: t("role_sitter_body"), emoji: "🏠" },
    { color: "walker", title: t("role_walker_title"), body: t("role_walker_body"), emoji: "🚶" },
  ] as const;

  const trust = [
    { title: t("trust_id_title"),   body: t("trust_id_body"),   icon: "✓" },
    { title: t("trust_pay_title"),  body: t("trust_pay_body"),  icon: "🔒" },
    { title: t("trust_chat_title"), body: t("trust_chat_body"), icon: "💬" },
    { title: t("trust_map_title"),  body: t("trust_map_body"),  icon: "🗺️" },
  ];

  // « 3 services, une seule app » — 3 cartes (PetSitting · PawFollow · PawSpot).
  const services = [
    {
      kind: "petsitting",
      name: "PetSitting",
      title: t("home_app1_title"),
      body: t("home_app1_body"),
      price: t("pricing_owner_price"),
      cta: t("nav_signup"),
      href: "/signup",
      accent: "owner",
    },
    {
      kind: "pawfollow",
      name: "PawFollow",
      title: t("home_app2_title"),
      body: t("home_app2_body"),
      // v497 — Daniel : pas de prix sur PawFollow/PawSpot en accueil → CTA
      // « Découvrir <marque> » à la place.
      price: "",
      cta: `${t("home_discover")} PawFollow`,
      href: "/boutique",
      accent: "violet",
    },
    {
      kind: "pawspot",
      name: "PawSpot",
      title: t("home_app3_title"),
      body: t("home_app3_body"),
      price: "",
      cta: `${t("home_discover")} PawSpot`,
      href: "/pawmap",
      accent: "amber",
    },
  ] as const;

  // v556 — « Comment ça marche » en 4 étapes (clés how_step1..4, déjà
  // traduites dans les 9 langues).
  const steps = [
    { n: "01", emoji: "✨", title: t("how_step1_title"), body: t("how_step1_body"), tone: "owner" },
    { n: "02", emoji: "🔎", title: t("how_step2_title"), body: t("how_step2_body"), tone: "sitter" },
    { n: "03", emoji: "💳", title: t("how_step3_title"), body: t("how_step3_body"), tone: "walker" },
    { n: "04", emoji: "⭐", title: t("how_step4_title"), body: t("how_step4_body"), tone: "amber" },
  ] as const;

  // v556 — FAQ (10 questions, clés faq_q1..10 / faq_a1..10).
  const faq = Array.from({ length: 10 }, (_, i) => ({
    q: t(`faq_q${i + 1}`),
    a: t(`faq_a${i + 1}`),
  })).filter((x) => x.q && !x.q.startsWith("faq_"));

  const pawmapShot = lang === "fr" ? "/screens/02_pawmap.jpg" : "/screens/02_pawmap_us.jpg";

  return (
    <>
      {/* ── 1. HERO ── v556 (Daniel : « accueil pro, premium, propre »).
           Fond : dégradé crème + deux halos de couleur très doux (owner /
           sitter) + trame fine ; titre en grande échelle ; 2 CTA ; 3 preuves
           en puces sous les boutons ; à droite la carte démo « flottante »
           avec deux étiquettes (en direct, note). Mêmes clés, mêmes routes. */}
      <section className="relative overflow-hidden bg-[#FAF7F2]">
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              "radial-gradient(60% 55% at 12% 18%, rgba(201,42,18,0.10) 0%, rgba(201,42,18,0) 60%)," +
              "radial-gradient(45% 45% at 88% 30%, rgba(37,99,235,0.10) 0%, rgba(37,99,235,0) 60%)," +
              "radial-gradient(40% 40% at 70% 95%, rgba(22,163,74,0.08) 0%, rgba(22,163,74,0) 60%)",
          }}
        />
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 opacity-[0.35]"
          style={{
            backgroundImage:
              "linear-gradient(rgba(23,19,15,0.045) 1px, transparent 1px), linear-gradient(90deg, rgba(23,19,15,0.045) 1px, transparent 1px)",
            backgroundSize: "44px 44px",
            maskImage: "radial-gradient(70% 70% at 50% 40%, #000 30%, transparent 100%)",
            WebkitMaskImage: "radial-gradient(70% 70% at 50% 40%, #000 30%, transparent 100%)",
          }}
        />

        <div className="relative mx-auto grid max-w-6xl items-center gap-12 px-4 py-20 md:grid-cols-[1.05fr_0.95fr] md:py-28">
          <div className="flex flex-col justify-center">
            <span className="mb-5 inline-flex w-fit items-center gap-2 rounded-full border border-owner/20 bg-white/80 px-3.5 py-1.5 text-xs font-bold text-owner shadow-sm backdrop-blur">
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-owner opacity-60" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-owner" />
              </span>
              🌍 {t("hero_badge")}
            </span>
            <h1 className="font-display text-[2.6rem] font-extrabold leading-[1.04] tracking-[-0.02em] text-ink md:text-6xl">
              {t("hero_title")}
            </h1>
            <p className="mt-6 max-w-xl text-lg leading-relaxed text-ink-muted">
              {t("hero_sub")}
            </p>
            <div className="mt-9 flex flex-wrap gap-3">
              <Link
                href="/download"
                className="inline-flex items-center gap-2 rounded-full bg-owner px-7 py-3.5 text-sm font-bold text-white shadow-cta transition hover:-translate-y-0.5 hover:bg-owner-dark hover:shadow-xl"
              >
                {t("hero_cta_app")}
                <span aria-hidden>→</span>
              </Link>
              <Link
                href="/login"
                className="inline-flex items-center whitespace-nowrap rounded-full border border-ink/15 bg-white px-7 py-3.5 text-sm font-bold text-ink shadow-sm transition hover:-translate-y-0.5 hover:border-ink/30 hover:shadow-md"
              >
                {t("hero_cta_web_login")}
              </Link>
            </div>
            {/* v508 — l'app est EN LIGNE sur Google Play 🎉 → badges stores. */}
            <div className="mt-6">
              <StoreBadges />
            </div>
            {/* v556 — 3 preuves en puces (mêmes textes que la bande confiance). */}
            <ul className="mt-7 flex flex-wrap gap-x-6 gap-y-2 text-[13px] font-semibold text-ink-soft">
              <li className="inline-flex items-center gap-1.5"><span className="text-walker">✓</span>{t("trust_id_title")}</li>
              <li className="inline-flex items-center gap-1.5"><span>🔒</span>{t("trust_pay_title")}</li>
              <li className="inline-flex items-center gap-1.5"><span>🗺️</span>{t("trust_map_title")}</li>
            </ul>
          </div>

          <div className="relative">
            <div className="relative mx-auto w-full max-w-sm">
              {/* Cartes d'arrière-plan (bleu gardien / vert promeneur), plus
                  douces qu'avant : ombre portée large, rotation légère. */}
              <div className="absolute -right-5 top-8 h-72 w-full rotate-3 rounded-[28px] bg-gradient-to-br from-sitter to-[#1d4ed8] opacity-90 shadow-2xl" />
              <div className="absolute -left-5 top-14 h-72 w-full -rotate-2 rounded-[28px] bg-gradient-to-br from-walker to-[#15803d] opacity-90 shadow-2xl" />

              {/* Étiquette flottante « en direct » (PawFollow). */}
              <div className="absolute -left-6 -top-5 z-10 inline-flex items-center gap-2 rounded-full border border-white bg-white/90 px-3 py-1.5 text-xs font-bold text-ink shadow-lg backdrop-blur">
                <span className="relative flex h-2.5 w-2.5">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-walker opacity-70" />
                  <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-walker" />
                </span>
                PawFollow · {t("dash_live")}
              </div>
              {/* Étiquette flottante « note ». */}
              <div className="absolute -right-4 top-24 z-10 inline-flex items-center gap-1.5 rounded-full border border-white bg-white/90 px-3 py-1.5 text-xs font-bold text-ink shadow-lg backdrop-blur">
                <span className="text-amber-500">★</span> 4.9 <span className="font-medium text-ink-muted">· Top Sitter</span>
              </div>

              <div className="relative w-full rounded-[28px] border border-white bg-white/95 p-6 shadow-[0_30px_60px_-20px_rgba(23,19,15,0.35)] backdrop-blur">
                <div className="flex items-center justify-between">
                  <div className="flex items-start gap-3">
                    <div className="grid h-12 w-12 place-items-center rounded-2xl bg-owner-light text-2xl shadow-inner">🐕</div>
                    <div>
                      {/* v519 — Daniel : « prénom américain + USD » (marché
                          mondial, USA inclus — la démo parle au plus grand
                          nombre). Devises réelles listées sous la carte. */}
                      <div className="text-sm font-bold text-ink">Emily · {t("home_sophie_role")}</div>
                      <div className="text-xs text-ink-muted">New York · 4.9 ★ · Top Sitter</div>
                    </div>
                  </div>
                  <span className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-sitter-light text-xs font-bold text-sitter-dark ring-1 ring-sitter/20">
                    ✓
                  </span>
                </div>
                <div className="mt-5 grid grid-cols-3 gap-2 text-center">
                  {[
                    { t: t("home_card_day"), v: "$30" },
                    { t: t("home_card_week"), v: "$180" },
                    { t: t("home_card_month"), v: "$620" },
                  ].map((x) => (
                    <div key={x.t} className="rounded-xl border border-ink/5 bg-bg-soft p-2.5">
                      <div className="text-[10px] uppercase tracking-wider text-ink-soft">{x.t}</div>
                      <div className="text-sm font-extrabold text-ink">{x.v}</div>
                    </div>
                  ))}
                </div>
                <div className="mt-5 rounded-2xl bg-gradient-to-br from-sitter-light to-white p-3.5 ring-1 ring-sitter/15">
                  <div className="text-[11px] font-semibold uppercase tracking-wide text-sitter-dark">{t("home_est_earning")}</div>
                  <div className="mt-1 font-display text-2xl font-extrabold text-sitter-dark">$48.00</div>
                  <div className="text-[11px] text-ink-muted">{t("home_est_detail")}</div>
                </div>
                <div className="mt-4 grid grid-cols-2 gap-2">
                  <button className="rounded-full border border-ink/10 py-2.5 text-xs font-semibold text-ink transition hover:bg-bg-soft">{t("home_card_details")}</button>
                  <button className="rounded-full bg-owner py-2.5 text-xs font-semibold text-white shadow-cta transition hover:bg-owner-dark">{t("home_card_request")}</button>
                </div>
              </div>
              {/* v519 — Daniel : « petite phrase en dessous de l'image » avec
                  TOUTES les devises acceptées par l'app (pricingService :
                  EUR / GBP / CHF / USD). */}
              <p className="relative mt-6 text-center text-xs font-semibold text-ink-muted">
                💱 {t("home_currencies")}
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ── 2. BANDE CONFIANCE ── v556 : fond sombre profond, 4 preuves en
           cartes « verre » (bord clair, fond translucide), icône dans une
           pastille orange. */}
      <section className="relative overflow-hidden bg-[#17141f] py-12">
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{ background: "radial-gradient(50% 80% at 50% 0%, rgba(201,42,18,0.22) 0%, rgba(201,42,18,0) 70%)" }}
        />
        <div className="relative mx-auto grid max-w-6xl grid-cols-1 gap-4 px-4 sm:grid-cols-2 md:grid-cols-4">
          {trust.map((tr) => (
            <div
              key={tr.title}
              className="flex items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.06] p-4 transition hover:bg-white/[0.1]"
            >
              <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-owner text-base text-white shadow-cta">
                {tr.icon}
              </div>
              <div>
                <div className="text-sm font-bold text-white">{tr.title}</div>
                <div className="mt-0.5 text-xs leading-snug text-white/65">{tr.body}</div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* ── v505 — Daniel : VIDÉO DE PRÉSENTATION sur l'accueil. Fichier local
           compressé (4K 156 Mo → 1080p 9,7 Mo, faststart) servi par Vercel.
           preload="metadata" + poster → n'alourdit pas le chargement. */}
      <section className="mx-auto max-w-5xl px-4 py-24">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
          {t("video_title")}
        </h2>
        <span aria-hidden className="mx-auto mt-4 block h-1 w-14 rounded-full bg-gradient-to-r from-owner to-amber-400" />
        <p className="mx-auto mt-4 max-w-2xl text-center text-ink-muted">
          {t("video_sub")}
        </p>
        <div className="mt-10 overflow-hidden rounded-[28px] border border-ink/10 shadow-[0_30px_60px_-24px_rgba(23,19,15,0.45)] ring-1 ring-black/5">
          <video
            controls
            playsInline
            preload="metadata"
            poster="/videos/hopetsit_presentation_poster.jpg"
            className="block h-auto w-full bg-black"
          >
            <source src="/videos/hopetsit_presentation.mp4" type="video/mp4" />
          </video>
        </div>
      </section>

      {/* ── 4. COMMENT ÇA MARCHE ── v556 : 4 étapes numérotées reliées par un
           fil, une couleur par étape. */}
      <section className="relative overflow-hidden bg-white py-24">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
            {t("how_title")}
          </h2>
          <span aria-hidden className="mx-auto mt-4 block h-1 w-14 rounded-full bg-gradient-to-r from-owner to-amber-400" />
          <p className="mx-auto mt-4 max-w-2xl text-center text-ink-muted">{t("how_sub")}</p>

          <div className="relative mt-14 grid gap-6 md:grid-cols-4">
            <div aria-hidden className="absolute left-[12%] right-[12%] top-9 hidden h-px bg-gradient-to-r from-owner/30 via-sitter/30 to-amber-400/40 md:block" />
            {steps.map((s) => {
              const tone =
                s.tone === "owner"
                  ? "bg-owner text-white"
                  : s.tone === "sitter"
                    ? "bg-sitter text-white"
                    : s.tone === "walker"
                      ? "bg-walker text-white"
                      : "bg-amber-400 text-ink";
              return (
                <div key={s.n} className="group relative rounded-[26px] border border-[#efe7e0] bg-white p-7 shadow-card transition hover:-translate-y-1.5 hover:shadow-xl">
                  <div className="flex items-center gap-3">
                    <span className={`grid h-[4.5rem] w-[4.5rem] shrink-0 place-items-center rounded-2xl text-3xl shadow-lg ${tone}`}>
                      {s.emoji}
                    </span>
                    <span className="font-display text-4xl font-extrabold tracking-tight text-ink/10">{s.n}</span>
                  </div>
                  <h3 className="mt-5 text-lg font-extrabold text-ink">{s.title}</h3>
                  <p className="mt-2 text-sm leading-relaxed text-ink-muted">{s.body}</p>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* ── 3. UNE APP, TROIS RÔLES ── 3 cartes. */}
      <section className="mx-auto max-w-6xl px-4 py-24">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
          {t("roles_title")}
        </h2>
        <span aria-hidden className="mx-auto mt-4 block h-1 w-14 rounded-full bg-gradient-to-r from-owner to-amber-400" />
        <div className="mt-12 grid gap-6 md:grid-cols-3">
          {roles.map((r) => {
            const accent = r.color;
            return (
              <div
                key={r.title}
                className="group relative overflow-hidden rounded-[26px] border border-[#efe7e0] bg-white p-8 shadow-card transition hover:-translate-y-1.5 hover:shadow-[0_24px_48px_-20px_rgba(23,19,15,0.35)]"
              >
                <div className={`absolute inset-x-0 top-0 h-1.5 bg-${accent}`} />
                <div aria-hidden className={`pointer-events-none absolute -right-10 -top-10 h-32 w-32 rounded-full bg-${accent}-light opacity-70 blur-2xl`} />
                {/* v507 — design : icône plus présente + zoom doux au survol. */}
                <div className={`grid h-14 w-14 place-items-center rounded-2xl bg-${accent}-light text-3xl shadow-sm transition group-hover:scale-110`}>
                  {r.emoji}
                </div>
                <h3 className="mt-5 text-lg font-extrabold text-ink">{r.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-ink-muted">{r.body}</p>
              </div>
            );
          })}
        </div>
      </section>

      {/* ── 4. 3 SERVICES, UNE SEULE APP ── fusion PawSpot + PawFollow + « 3 apps
           en 1 » : 3 cartes (PetSitting · PawFollow · PawSpot), prix en ligne +
           1 CTA chacune. Mêmes routes /signup · /boutique · /pawmap. */}
      <section className="bg-bg-soft py-24">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
            {t("home_3in1_title")}
          </h2>
          <span aria-hidden className="mx-auto mt-4 block h-1 w-14 rounded-full bg-gradient-to-r from-owner to-amber-400" />
          <p className="mx-auto mt-3 max-w-2xl text-center text-base leading-relaxed text-ink-muted">
            {t("home_3in1_sub")}
          </p>
          <div className="mt-12 grid gap-5 md:grid-cols-3">
            {services.map((s) => {
              const isPf = s.kind === "pawfollow";
              const isPs = s.kind === "pawspot";
              const ring = isPf
                ? "border-violet-300"
                : isPs
                  ? "border-amber-300"
                  : "border-owner/20";
              const bar = isPf ? "bg-violet-500" : isPs ? "bg-amber-400" : "bg-owner";
              const titleCls = isPf ? "text-violet-700" : isPs ? "text-amber-700" : "text-owner-dark";
              const btn = isPf
                ? "bg-violet-600 hover:bg-violet-700"
                : isPs
                  ? "bg-amber-500 hover:bg-amber-600"
                  : "bg-owner hover:bg-owner-dark";
              return (
                <div
                  key={s.name}
                  className={`group relative flex flex-col overflow-hidden rounded-[22px] border bg-white p-7 shadow-card transition hover:-translate-y-1 hover:shadow-xl ${ring}`}
                >
                  <div className={`absolute inset-x-0 top-0 h-1.5 ${bar}`} />
                  <div className="mb-4 flex items-center gap-3">
                    {isPf ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src="/pawfollow_logo.svg" alt="" width={46} height={46} />
                    ) : isPs ? (
                      <PawSpotGoldCoin size={46} />
                    ) : (
                      <div className="grid h-11 w-11 place-items-center rounded-2xl bg-owner-light text-2xl">🏠</div>
                    )}
                    <h3 className={`text-lg font-extrabold ${titleCls}`}>{s.name}</h3>
                  </div>
                  <p className="text-xs font-bold uppercase tracking-wider text-ink-muted">{s.title}</p>
                  <p className="mb-5 mt-2 text-sm leading-relaxed text-ink-muted">{s.body}</p>
                  {/* v493 — PawSpot : « voir les membres proches » + badge rose. */}
                  {isPs && (
                    <p className="mb-4 flex items-center gap-2 text-xs font-semibold text-pink-700">
                      <PawMemberBadge size={18} />
                      <span>{t("pawspot_feat_nearby")}</span>
                    </p>
                  )}
                  {/* v497 — Daniel : pas de prix sur PawFollow/PawSpot → CTA
                      « Découvrir … » seul, pleine largeur. PetSitting garde son prix.
                      v507 — design : mt-auto → les 3 boutons ALIGNÉS en bas,
                      quelle que soit la longueur du texte au-dessus. */}
                  <div className="mt-auto flex items-center justify-between gap-2 border-t border-[#efe7e0] pt-4">
                    {s.price ? (
                      <span className={`text-sm font-extrabold ${titleCls}`}>{s.price}</span>
                    ) : null}
                    <Link
                      href={s.href}
                      className={`rounded-full px-4 py-2 text-xs font-bold text-white transition ${btn} ${s.price ? "" : "w-full text-center"}`}
                    >
                      {s.cta} →
                    </Link>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* ── 7. BANDE PAWMAP ── v556 : LA fonctionnalité phare (Daniel) en
           pleine largeur : capture réelle de la carte + suivi gratuit pendant
           le service + CTA orange PawMap. */}
      <section className="relative overflow-hidden bg-[#17141f] py-24 text-white">
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              "radial-gradient(55% 70% at 15% 30%, rgba(255,106,0,0.28) 0%, rgba(255,106,0,0) 65%)," +
              "radial-gradient(40% 55% at 90% 80%, rgba(124,58,237,0.25) 0%, rgba(124,58,237,0) 65%)",
          }}
        />
        <div className="relative mx-auto grid max-w-6xl items-center gap-12 px-4 md:grid-cols-2">
          <div>
            <div className="mb-5 flex items-center gap-3">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src="/pawmap_logo_orange.svg" alt="PawMap" width={56} height={56} className="drop-shadow-lg" />
              <span className="inline-flex items-center gap-1.5 rounded-full border border-white/15 bg-white/10 px-3 py-1 text-xs font-bold text-white/90">
                🌍 {t("hero_badge")}
              </span>
            </div>
            <h2 className="font-display text-3xl font-extrabold tracking-tight md:text-5xl">
              {t("pawmap_title")}
            </h2>
            <p className="mt-5 max-w-xl text-base leading-relaxed text-white/80">{t("pawmap_sub")}</p>

            <div className="mt-8 rounded-2xl border border-walker/40 bg-walker/10 p-5">
              <div className="flex items-center gap-2 text-sm font-extrabold text-emerald-300">
                <span className="relative flex h-2.5 w-2.5">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-70" />
                  <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-emerald-400" />
                </span>
                {t("hiw_track_title")}
              </div>
              <p className="mt-2 text-sm leading-relaxed text-white/80">{t("hiw_track_body")}</p>
            </div>

            <div className="mt-8 flex flex-wrap items-center gap-3">
              <PawMapCTA size="hero" />
              <Link
                href="/pawmap"
                className="rounded-full border border-white/25 px-6 py-3.5 text-sm font-bold text-white transition hover:bg-white/10"
              >
                {t("home_discover")} PawSpot →
              </Link>
            </div>
          </div>

          <div className="relative mx-auto w-full max-w-[340px]">
            <div aria-hidden className="absolute -inset-6 rounded-[44px] bg-gradient-to-br from-[#FF6A00]/40 via-transparent to-violet-500/30 blur-2xl" />
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={pawmapShot}
              alt="HoPetSit — PawMap"
              width={640}
              height={1385}
              loading="lazy"
              className="relative w-full rounded-[32px] border-[6px] border-[#2a2433] shadow-[0_40px_80px_-30px_rgba(0,0,0,0.8)]"
            />
            <div className="absolute -left-6 top-12 inline-flex items-center gap-2 rounded-full border border-white/20 bg-[#17141f]/90 px-3 py-1.5 text-xs font-bold shadow-xl backdrop-blur">
              <PawMemberBadge size={18} />
              PawSpot
            </div>
            <div className="absolute -right-6 bottom-16 inline-flex items-center gap-2 rounded-full border border-white/20 bg-[#17141f]/90 px-3 py-1.5 text-xs font-bold shadow-xl backdrop-blur">
              <span className="text-lg">🐾</span> PawFollow
            </div>
          </div>
        </div>
      </section>

      {/* ── v507 — L'APP EN IMAGES ── vraies captures store (Daniel, 6 visuels
           /screens/01..06) en bande défilable horizontale. Les visuels ont déjà
           leur fond orange + titre intégré → simples cartes arrondies. */}
      <section className="mx-auto max-w-6xl px-4 py-20">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
          📱 {t("screens_title")}
        </h2>
        <p className="mx-auto mt-3 max-w-2xl text-center text-ink-muted">{t("screens_sub")}</p>
        {/* w-40 + gap-4 → les 6 captures tiennent SANS coupure dans max-w-6xl ;
            first:ml-auto/last:mr-auto = centré quand ça tient, scroll sinon. */}
        <div className="mt-10 flex snap-x snap-mandatory gap-4 overflow-x-auto pb-4 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          {/* v534 — captures choisies selon la langue : jeu FRANÇAIS quand le site est
              en français, ANGLAIS sinon. Avant, les visuels anglais (suffixe
              _us) étaient affichés en dur, y compris aux visiteurs français. */}
          {screensFor(lang).map((s) => (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              key={s.src}
              src={s.src}
              alt={`HoPetSit — ${s.alt}`}
              loading="lazy"
              width={640}
              height={1385}
              className="w-40 shrink-0 snap-center rounded-2xl shadow-xl ring-1 ring-black/5 transition first:ml-auto last:mr-auto hover:-translate-y-1 hover:shadow-2xl"
            />
          ))}
        </div>
      </section>

      {/* ── 9. ABONNEMENTS EXPLIQUÉS ── (Daniel : « explique mieux les
           abonnements ») : gratuit vs ce que chaque formule ajoute. */}
      <SubscriptionsExplainer />

      {/* ── 5. PAW PREMIUM ── une seule bande compacte (noir/or), CTA boutique.
           v493 — plus d'air : carte centrée avec marges, padding & gaps généreux. */}
      <section className="px-4 py-20">
        <div className="relative mx-auto flex max-w-4xl flex-col items-center gap-7 overflow-hidden rounded-[26px] bg-gradient-to-b from-[#221C12] to-[#15120D] p-9 text-center shadow-2xl ring-1 ring-amber-400/40 md:flex-row md:gap-10 md:p-12 md:text-left">
          {/* v507 — design : couronne en filigrane + liseré or. */}
          <span
            aria-hidden
            className="pointer-events-none absolute -right-4 -top-8 rotate-12 select-none text-[110px] leading-none opacity-[0.07]"
          >
            👑
          </span>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="PawPremium" width={80} height={80} className="shrink-0 drop-shadow-[0_0_18px_rgba(244,192,74,0.35)]" />
          <div className="flex-1">
            {/* v497 — Daniel : PawPremium + couronne alignés horizontalement,
                texte plus propre. */}
            <h2 className="flex items-center justify-center gap-2 font-display text-2xl font-extrabold tracking-tight text-yellow-400 md:justify-start md:text-3xl">
              <span>PawPremium</span>
              <span aria-hidden className="text-xl md:text-2xl">👑</span>
            </h2>
            <p className="mx-auto mt-3 max-w-xl text-sm leading-relaxed text-white/85 md:mx-0">
              {t("home_pawpremium_blurb")}
            </p>
          </div>
          <Link
            href="/boutique"
            className="shrink-0 rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-7 py-3.5 text-sm font-bold text-black shadow-cta transition hover:brightness-110"
          >
            {t("home_discover")} PawPremium →
          </Link>
        </div>
      </section>

      {/* ── 11. FAQ ── v556 : 10 questions en accordéon natif (<details>),
           2 colonnes sur desktop. */}
      <section className="bg-bg-soft py-24">
        <div className="mx-auto max-w-5xl px-4">
          <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
            {t("faq_title")}
          </h2>
          <span aria-hidden className="mx-auto mt-4 block h-1 w-14 rounded-full bg-gradient-to-r from-owner to-amber-400" />
          <div className="mt-12 grid gap-4 md:grid-cols-2">
            {faq.map((f, i) => (
              <details
                key={f.q}
                className="group rounded-2xl border border-ink/10 bg-white p-5 shadow-sm open:shadow-lg"
                open={i === 0}
              >
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-[15px] font-bold text-ink [&::-webkit-details-marker]:hidden">
                  {f.q}
                  <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-owner-light text-owner transition group-open:rotate-45">+</span>
                </summary>
                <p className="mt-3 text-sm leading-relaxed text-ink-muted">{f.a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ── 6. CTA FINAL ── */}
      <section className="mx-auto max-w-6xl px-4 py-20">
        <div className="relative overflow-hidden rounded-[26px] bg-gradient-to-br from-owner to-[#d93a1f] p-10 text-white shadow-2xl md:p-14">
          <div className="absolute -right-10 -top-10 h-48 w-48 rounded-full bg-white/10" />
          <div className="absolute -bottom-16 -left-10 h-48 w-48 rounded-full bg-white/10" />
          {/* v507 — design : patte en filigrane + dégradé + CTA avec relief. */}
          <span
            aria-hidden
            className="pointer-events-none absolute -bottom-6 right-8 -rotate-12 select-none text-[110px] leading-none opacity-10"
          >
            🐾
          </span>
          <div className="relative">
            <h2 className="font-display text-3xl font-extrabold tracking-tight md:text-4xl">
              {t("cta_join_title")}
            </h2>
            <p className="mt-3 max-w-2xl text-white/90">{t("cta_join_sub")}</p>
            <div className="mt-7 flex flex-wrap gap-3">
              <Link
                href="/signup"
                className="rounded-full bg-white px-6 py-3 text-sm font-bold text-owner shadow-lg transition hover:-translate-y-0.5 hover:bg-bg-soft"
              >
                {t("nav_signup")}
              </Link>
              <Link
                href="/download"
                className="rounded-full border border-white/40 px-6 py-3 text-sm font-bold text-white transition hover:-translate-y-0.5 hover:bg-white/10"
              >
                {t("nav_download")}
              </Link>
            </div>
            {/* v508 — badges stores (Google Play EN LIGNE). */}
            <div className="mt-5">
              <StoreBadges />
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
