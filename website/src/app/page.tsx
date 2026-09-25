"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import StoreBadges from "@/components/StoreBadges";
import { AppIcon, type AppIconName } from "@/components/AppIcon";
import { PageTitle } from "@/components/PageTitle";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";
import { pawmapShotFor, PhoneFrame } from "@/lib/screens";
import { ROLE_COLOR } from "@/lib/pawmapLegend";

// v562 — Refonte « minimaliste, pro, façon Apple » (Daniel, 13/09).
// 24/09/2026 — LOT B (plan de LEO validé par Daniel « oui, valide tout ») :
//   étape 0 : plus aucun débordement à 375 px (les deux téléphones côte à côte
//             faisaient 404 px dans 375 : la page glissait de côté) ;
//   étape 1 : « Réserve ici en 2 minutes » — recherche ville/service en haut,
//             puis LA CARTE RÉELLE + le tableau de bord en 2e position,
//             sections en double fusionnées (preuves → héro, services +
//             abonnements + bande Premium → une seule grille, galerie de
//             captures → /download), 8 écrans max sur téléphone.
// Mêmes routes ; zéro emoji (icônes maison AppIcon) ; zéro gris.
const PublicPawMap = dynamic(() => import("@/components/PublicPawMap"), {
  ssr: false,
  loading: () => (
    <div className="flex h-[360px] items-center justify-center rounded-[28px] bg-[#FAF1EC] md:h-[420px]">
      <span className="h-6 w-6 animate-spin rounded-full border-2 border-[#C92A12] border-t-transparent" />
    </div>
  ),
});

const PARIS: [number, number] = [48.8566, 2.3522];

// v585 — mobile (Bob, 25/09) : à 375 px le titre coupait « pet-/sitter » et
// laissait « 2 » seul en bout de ligne. Les mots à trait d'union restent
// entiers et un nombre reste collé au mot suivant. Fonction simple (pas un
// hook), sans effet sur les langues sans espaces (ja, ko).
function keepTogether(text: string) {
  const joined = text.replace(/(\d+) (?=\S)/g, "$1\u00A0");
  return joined.split(/(\S*-\S*)/).map((part, i) =>
    part.includes("-") && !/\s/.test(part) ? <span key={i} className="whitespace-nowrap">{part}</span> : part,
  );
}

export default function HomePage() {
  const { t, lang } = useT();
  const router = useRouter();
  const { user, ready } = useAuth();
  const [city, setCity] = useState("");
  const [service, setService] = useState<"sitting" | "walk">("sitting");
  const logged = ready && !!user;

  const roles = [
    { key: "owner", icon: "paw" as AppIconName, color: ROLE_COLOR.owner, bg: "#FBE9E5", title: t("role_owner_title"), body: t("role_owner_body"), price: t("pricing_owner_price") },
    { key: "sitter", icon: "home" as AppIconName, color: ROLE_COLOR.sitter, bg: "#E3EFFE", title: t("role_sitter_title"), body: t("role_sitter_body"), price: t("pricing_provider_price") },
    { key: "walker", icon: "walker" as AppIconName, color: ROLE_COLOR.walker, bg: "#DEF7E5", title: t("role_walker_title"), body: t("role_walker_body"), price: t("pricing_provider_price") },
  ] as const;

  const trust: { icon: AppIconName; label: string }[] = [
    { icon: "shield-check", label: t("trust_id_title") },
    { icon: "lock", label: t("trust_pay_title") },
    { icon: "chat", label: t("trust_chat_title") },
    { icon: "map", label: t("trust_map_title") },
  ];

  // 3 services + PawPremium dans UNE grille (fusion des sections « 3 apps »,
  // « abonnements expliqués » et « bande PawPremium » de la v562).
  const products = [
    { name: "PetSitting", title: t("home_app1_title"), body: t("home_app1_body"), logo: "/pawboost_logo.svg", href: "/pawmap", cta: t("home_book_on_site"), dark: false },
    { name: "PawFollow", title: t("home_app2_title"), body: t("home_app2_body"), logo: "/pawfollow_logo.svg", href: "/pricing", cta: `${t("home_discover")} PawFollow`, dark: false },
    { name: "PawSpot", title: t("home_app3_title"), body: t("home_app3_body"), logo: "/pawspot_logo.svg", href: "/pawmap", cta: `${t("home_discover")} PawSpot`, dark: false },
    { name: "PawPremium", title: t("home_pawpremium_title_short"), body: t("home_pawpremium_blurb"), logo: "/pawpremium_logo.svg", href: "/boutique", cta: `${t("home_discover")} PawPremium`, dark: true },
  ] as const;

  const steps = [
    { n: "01", title: t("how_step1_title"), body: t("how_step1_body") },
    { n: "02", title: t("how_step2_title"), body: t("how_step2_body") },
    { n: "03", title: t("how_step3_title"), body: t("how_step3_body") },
    { n: "04", title: t("how_step4_title"), body: t("how_step4_body") },
  ] as const;

  const faq = Array.from({ length: 10 }, (_, i) => ({ q: t(`faq_q${i + 1}`), a: t(`faq_a${i + 1}`) }))
    .filter((x) => x.q && !x.q.startsWith("faq_"))
    .slice(0, 4);

  const pawmapShot = pawmapShotFor(lang);

  function submitSearch(e: React.FormEvent) {
    e.preventDefault();
    const qs = new URLSearchParams();
    if (city.trim()) qs.set("city", city.trim());
    qs.set("service", service);
    router.push(`/pawmap?${qs.toString()}`);
  }

  const dashHref = logged ? "/dashboard" : "/login?redirect=%2Fdashboard";

  return (
    <>
      <PageTitle titleKey="page_title_home" descKey="page_desc_home" />

      {/* ── 1. HÉRO ── « Réserve ici en 2 minutes » : recherche en haut,
           l'app en second. Une colonne sur téléphone, téléphone à droite sur
           grand écran seulement (plus jamais 3 cadres côte à côte). */}
      <section className="overflow-x-hidden bg-white">
        <div className="mx-auto grid max-w-6xl items-center gap-10 px-4 pb-12 pt-12 md:pt-20 lg:grid-cols-[1.15fr_0.85fr]">
          <div className="min-w-0 text-center lg:text-left">
            <span className="inline-flex items-center gap-2 rounded-full bg-[#FAF1EC] px-3.5 py-1.5 text-xs font-semibold text-[#6E4F48]">
              <AppIcon name="globe" size={14} color="#C92A12" />
              {t("hero_badge")}
            </span>
            <h1 className="mt-5 font-display text-[2.4rem] font-bold leading-[1.05] tracking-[-0.03em] text-[#231715] md:text-6xl">
              {keepTogether(t("home_hero_title_book"))}
            </h1>
            <p className="mx-auto mt-5 max-w-2xl text-base leading-relaxed text-[#6E4F48] md:text-xl lg:mx-0">
              {t("home_hero_sub_book")}
            </p>

            {/* Recherche : ville + service → la carte publique centrée sur la ville. */}
            <form onSubmit={submitSearch} className="mx-auto mt-7 flex w-full max-w-xl flex-col gap-2 rounded-[22px] bg-[#FAF1EC] p-2 lg:mx-0 lg:max-w-none lg:flex-row lg:items-center lg:rounded-full" role="search" aria-label={t("home_search_aria")}>
              <label className="flex min-h-[48px] min-w-0 flex-1 items-center gap-2 rounded-full bg-white px-4">
                <AppIcon name="pin" size={18} color="#C92A12" className="shrink-0" />
                <input
                  value={city}
                  onChange={(e) => setCity(e.target.value)}
                  placeholder={t("home_search_city_ph")}
                  aria-label={t("home_search_city_ph")}
                  className="min-w-0 flex-1 bg-transparent text-sm text-[#231715] outline-none placeholder:text-ink-soft"
                />
              </label>
              <div className="flex flex-wrap gap-2">
                <div className="flex min-h-[52px] basis-full items-center rounded-full bg-white p-1 sm:flex-1 sm:basis-0 lg:flex-none lg:basis-auto">
                  {(["sitting", "walk"] as const).map((s) => (
                    <button
                      key={s}
                      type="button"
                      onClick={() => setService(s)}
                      aria-pressed={service === s}
                      className={`inline-flex min-h-[44px] flex-1 items-center justify-center gap-1.5 whitespace-nowrap rounded-full px-3 text-xs font-semibold transition sm:text-sm lg:flex-none ${service === s ? "bg-owner text-white" : "text-[#231715] hover:bg-[#FAF1EC]"}`}
                    >
                      <AppIcon name={s === "walk" ? "walker" : "home"} size={15} color={service === s ? "#fff" : "#231715"} />
                      {s === "walk" ? t("home_service_walk") : t("home_service_sitting")}
                    </button>
                  ))}
                </div>
                <button type="submit" className="inline-flex min-h-[52px] basis-full items-center justify-center gap-2 rounded-full bg-[#231715] px-5 text-sm font-semibold text-white transition hover:bg-black sm:flex-1 sm:basis-0 lg:min-h-[48px] lg:flex-none lg:basis-auto">
                  <AppIcon name="search" size={16} color="#fff" />
                  <span className="whitespace-nowrap">{t("home_search_btn")}</span>
                </button>
              </div>
            </form>

            <div className="mt-5 flex flex-wrap items-center justify-center gap-3 lg:justify-start">
              <Link href="/download" className="hidden min-h-[44px] items-center gap-2 rounded-full bg-[#FAF1EC] px-5 text-sm font-semibold text-[#231715] transition hover:bg-[#F0E3DF] sm:inline-flex">
                <AppIcon name="download" size={16} />
                {t("hero_cta_app")}
              </Link>
              <StoreBadges className="justify-center lg:justify-start" />
            </div>

            <ul className="mt-6 flex flex-wrap justify-center gap-x-5 gap-y-2 text-[13px] font-medium text-[#6E4F48] lg:justify-start">
              {trust.map((tr) => (
                <li key={tr.label} className="inline-flex items-center gap-1.5">
                  <AppIcon name={tr.icon} size={15} color="#16A34A" />
                  {tr.label}
                </li>
              ))}
            </ul>
          </div>
          <div className="hidden justify-center lg:flex">
            <PhoneFrame src={pawmapShot} alt="HoPetSit — PawMap" className="w-64" priority />
          </div>
        </div>
      </section>

      {/* ── 2. CARTE + TABLEAU DE BORD ── la vraie PawMap (sans compte) et le
           tableau de bord web, mis en avant dès le 2e écran. */}
      <section className="bg-[#FAF1EC] py-12 md:py-20">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#231715] md:text-5xl">
            {t("home_map_dash_title")}
          </h2>
          <p className="mx-auto mt-3 max-w-2xl text-center text-base text-[#6E4F48] md:text-lg">{t("home_map_dash_sub")}</p>

          <div className="mt-10 grid gap-5 lg:grid-cols-[1.25fr_0.75fr]">
            {/* La carte réelle : gardiens et promeneurs de Paris, floutés à ~1 km. */}
            <div className="rounded-[32px] bg-white p-2">
              <PublicPawMap center={PARIS} zoom={12} height="clamp(300px, 42vh, 460px)" compact />
              <div className="flex flex-wrap items-center justify-between gap-2 px-3 py-3">
                <span className="inline-flex items-center gap-2 text-sm font-semibold text-[#231715]">
                  <AppIcon name="map" size={18} color="#C92A12" />
                  {t("home_map_caption")}
                </span>
                <span className="inline-flex items-center gap-1.5 text-xs text-[#6E4F48]">
                  <AppIcon name="lock" size={13} />
                  {t("pawmap_public_privacy")}
                </span>
              </div>
            </div>

            {/* Le tableau de bord web : ce qu'on y fait, et le bouton. */}
            <div className="flex flex-col rounded-[32px] bg-[#231715] p-6 text-white md:p-8">
              <div className="flex items-center gap-3">
                <span className="grid h-11 w-11 place-items-center rounded-2xl bg-owner"><AppIcon name="calendar" size={22} color="#fff" /></span>
                <h3 className="font-display text-xl font-bold tracking-[-0.02em]">{t("home_dash_title")}</h3>
              </div>
              <p className="mt-3 text-[15px] leading-relaxed text-[#FDF8F7]">{t("home_dash_sub")}</p>

              {/* Aperçu « à faire aujourd'hui » (illustration du bloc réel du tableau de bord). */}
              <div className="mt-5 hidden grid-cols-3 gap-2 sm:grid">
                {([
                  ["wallet", t("dash_today_to_pay"), ROLE_COLOR.owner],
                  ["chat", t("dash_card_messages_title"), ROLE_COLOR.sitter],
                  ["calendar", t("dash_today_next"), ROLE_COLOR.walker],
                ] as [AppIconName, string, string][]).map(([icon, label, color]) => (
                  <div key={label} className="rounded-2xl bg-white/10 p-3 text-center">
                    <span className="mx-auto grid h-9 w-9 place-items-center rounded-full" style={{ background: color }}><AppIcon name={icon} size={18} color="#fff" /></span>
                    <span className="mt-2 block text-[11px] font-semibold leading-tight text-[#FDF8F7]">{label}</span>
                  </div>
                ))}
              </div>

              <ul className="mt-4 hidden space-y-2 text-sm text-[#FDF8F7] sm:block">
                {[t("home_dash_l1"), t("home_dash_l2"), t("home_dash_l3")].map((l) => (
                  <li key={l} className="flex items-start gap-2"><AppIcon name="check" size={16} color="#F4C04A" className="mt-0.5 shrink-0" />{l}</li>
                ))}
              </ul>

              <Link href={dashHref} className="mt-6 inline-flex min-h-[52px] items-center justify-center gap-2 rounded-[18px] bg-owner px-6 text-[15px] font-bold text-white transition hover:bg-owner-dark">
                <span className="grid h-8 w-8 place-items-center rounded-full bg-white"><AppIcon name="profile" size={16} color="#C92A12" /></span>
                {logged ? t("home_dash_cta_open") : t("home_dash_cta_login")}
              </Link>
              {!logged && (
                <Link href="/signup" className="mt-3 text-center text-sm font-semibold text-[#F4C04A] hover:underline">
                  {t("nav_signup")} →
                </Link>
              )}
            </div>
          </div>
        </div>
      </section>

      {/* ── 3. RÉSERVER EN 4 ÉTAPES ── */}
      <section className="mx-auto max-w-6xl px-4 py-12 md:py-20">
        <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#231715] md:text-5xl">
          {t("home_steps_title")}
        </h2>
        <div className="-mx-4 mt-8 flex snap-x snap-mandatory gap-3 overflow-x-auto px-4 pb-2 [-ms-overflow-style:none] [scrollbar-width:none] md:mx-0 md:mt-12 md:grid md:grid-cols-4 md:gap-4 md:overflow-visible md:px-0 [&::-webkit-scrollbar]:hidden">
          {steps.map((s) => (
            <div key={s.n} className="w-[78%] shrink-0 snap-center rounded-[20px] bg-[#FAF1EC] p-5 md:w-auto md:rounded-[24px] md:p-7">
              <span className="font-display text-sm font-semibold tracking-widest text-owner">{s.n}</span>
              <h3 className="mt-2 text-[15px] font-semibold leading-snug text-[#231715] md:mt-4 md:text-lg">{s.title}</h3>
              <p className="mt-1.5 text-[13px] leading-relaxed text-[#6E4F48] md:text-sm">{s.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── 4. TROIS RÔLES, UN COMPTE ── + les 4 produits (une seule grille). */}
      <section className="bg-[#FAF1EC] py-12 md:py-20">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-bold tracking-[-0.02em] text-[#231715] md:text-5xl">
            {t("roles_title")}
          </h2>
          <div className="mt-8 grid gap-3 md:mt-12 md:grid-cols-3 md:gap-4">
            {roles.map((r) => (
              <div key={r.key} className="flex items-start gap-4 rounded-[24px] bg-white p-5 md:block md:p-8">
                <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full" style={{ background: r.bg }}>
                  <AppIcon name={r.icon} size={24} color={r.color} />
                </span>
                <div className="min-w-0">
                  <h3 className="text-lg font-semibold text-[#231715] md:mt-5 md:text-xl">{r.title}</h3>
                  <p className="mt-1 text-sm leading-relaxed text-[#6E4F48] md:mt-2 md:text-[15px]">{r.body}</p>
                  <p className="mt-2 text-sm font-semibold" style={{ color: r.color }}>{r.price}</p>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-8 grid gap-2 md:mt-10 md:grid-cols-4 md:gap-3">
            {products.map((p) => (
              <Link
                key={p.name}
                href={p.href}
                className={`flex items-center gap-3 rounded-[20px] p-3 transition hover:-translate-y-0.5 md:flex-col md:items-start md:rounded-[22px] md:p-6 ${p.dark ? "bg-[#231715] text-white" : "bg-white text-[#231715]"}`}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={p.logo} alt="" width={44} height={44} className="h-10 w-10 shrink-0 md:h-11 md:w-11" />
                <span className="min-w-0 flex-1 md:flex md:flex-1 md:flex-col">
                  <span className={`block font-display text-base font-bold md:mt-3 ${p.dark ? "text-[#FFD34D]" : ""}`}>{p.name}</span>
                  <span className={`block text-[11px] font-semibold uppercase tracking-wider ${p.dark ? "text-[#FDF8F7]" : "text-[#6E4F48]"}`}>{p.title}</span>
                  <span className={`mt-2 hidden text-sm leading-relaxed md:block ${p.dark ? "text-[#FDF8F7]" : "text-[#6E4F48]"}`}>{p.body}</span>
                  <span className={`mt-auto hidden items-center gap-1 pt-3 text-sm font-semibold md:inline-flex ${p.dark ? "text-[#FFD34D]" : "text-owner"}`}>
                    {p.cta} <AppIcon name="arrow-right" size={14} />
                  </span>
                </span>
                <AppIcon name="arrow-right" size={18} color={p.dark ? "#FFD34D" : "#C92A12"} className="shrink-0 md:hidden" />
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* ── 5. VIDÉO ── */}
      <section className="mx-auto max-w-4xl px-4 py-12 md:py-20">
        <h2 className="text-center font-display text-2xl font-bold tracking-[-0.02em] text-[#231715] md:text-4xl">
          {t("video_title")}
        </h2>
        <div className="mt-6 overflow-hidden rounded-[24px] bg-black shadow-[0_30px_60px_-30px_rgba(35,23,21,0.5)] md:mt-8">
          <video controls playsInline preload="metadata" poster="/videos/hopetsit_presentation_poster.jpg" className="block h-auto w-full">
            <source src="/videos/hopetsit_presentation.mp4" type="video/mp4" />
          </video>
        </div>
      </section>

      {/* ── 6. VILLES ── v562 (Search Console 17/09) : liens directs vers les
          pages Paris / Île-de-France et USA (exploration Google). Rendu dans les
          deux langues quel que soit le choix de l'utilisateur. Contenu inchangé. */}
      <section className="mx-auto max-w-5xl px-4 pb-6 pt-4">
        <div className="grid gap-8 md:grid-cols-2">
          <div>
            <h2 className="font-display text-xl font-bold tracking-[-0.02em] text-[#231715] md:text-2xl">Pet sitters à Paris et en Île-de-France</h2>
            <ul className="mt-3 flex flex-wrap gap-1.5 text-sm">
              {Array.from({ length: 20 }, (_, i) => i + 1).map((n) => (
                <li key={`p${n}`}><Link href={`/garde-animaux/paris-${n}`} className="inline-flex items-center rounded-full bg-[#FAF1EC] px-3 py-1.5 text-[#231715] transition hover:bg-owner-light hover:text-owner-dark max-lg:min-h-[44px]">Paris {n}{n === 1 ? "er" : "e"}</Link></li>
              ))}
              {[["boulogne-billancourt","Boulogne"],["neuilly-sur-seine","Neuilly"],["levallois-perret","Levallois"],["issy-les-moulineaux","Issy"],["vincennes","Vincennes"],["montreuil","Montreuil"],["versailles","Versailles"]].map(([slug, name]) => (
                <li key={slug}><Link href={`/garde-animaux/${slug}`} className="inline-flex items-center rounded-full bg-[#FAF1EC] px-3 py-1.5 text-[#231715] transition hover:bg-owner-light hover:text-owner-dark max-lg:min-h-[44px]">{name}</Link></li>
              ))}
            </ul>
            <p className="mt-3 text-sm"><Link href="/devenir-petsitter/paris" className="font-semibold text-owner hover:underline">Devenir pet sitter à Paris →</Link></p>
          </div>
          <div>
            <h2 className="font-display text-xl font-bold tracking-[-0.02em] text-[#231715] md:text-2xl">Pet sitters in the United States</h2>
            <ul className="mt-3 flex flex-wrap gap-1.5 text-sm">
              {[["dallas","Dallas"],["fort-worth","Fort Worth"],["plano","Plano"],["frisco","Frisco"],["houston","Houston"],["austin","Austin"],["new-york","New York"],["los-angeles","Los Angeles"],["chicago","Chicago"],["miami","Miami"],["san-francisco","San Francisco"],["seattle","Seattle"],["boston","Boston"],["atlanta","Atlanta"],["denver","Denver"],["phoenix","Phoenix"]].map(([slug, name]) => (
                <li key={slug}><Link href={`/pet-sitting/${slug}`} className="inline-flex items-center rounded-full bg-[#FAF1EC] px-3 py-1.5 text-[#231715] transition hover:bg-owner-light hover:text-owner-dark max-lg:min-h-[44px]">{name}</Link></li>
              ))}
            </ul>
            <p className="mt-3 text-sm"><Link href="/become-a-pet-sitter/dallas" className="font-semibold text-owner hover:underline">Become a pet sitter in Dallas →</Link> · <Link href="/villes" className="text-[#6E4F48] hover:underline">All cities</Link></p>
          </div>
        </div>
      </section>

      {/* ── 7. FAQ ── 5 questions, le reste sur /faq. */}
      <section className="mx-auto max-w-3xl px-4 py-12 md:py-20">
        <h2 className="text-center font-display text-2xl font-bold tracking-[-0.02em] text-[#231715] md:text-4xl">
          {t("faq_title")}
        </h2>
        <div className="mt-8 divide-y divide-[#EADFDC] border-y border-[#EADFDC]">
          {faq.map((f, i) => (
            <details key={f.q} className="group py-4" open={i === 0}>
              <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-[16px] font-semibold text-[#231715] [&::-webkit-details-marker]:hidden">
                {f.q}
                <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-[#FAF1EC] text-[#6E4F48] transition group-open:rotate-45">+</span>
              </summary>
              <p className="mt-3 text-[15px] leading-relaxed text-[#6E4F48]">{f.a}</p>
            </details>
          ))}
        </div>
        <p className="mt-4 text-center text-sm"><Link href="/faq" className="font-semibold text-owner hover:underline">{t("home_faq_more")} →</Link></p>
      </section>

      {/* ── 8. CTA FINAL ── */}
      <section className="bg-[#FAF1EC] px-4 py-12 md:py-20">
        <div className="mx-auto max-w-3xl text-center">
          <h2 className="font-display text-3xl font-bold tracking-[-0.02em] text-[#231715] md:text-5xl">{t("cta_join_title")}</h2>
          <p className="mx-auto mt-4 max-w-2xl text-base text-[#6E4F48] md:text-lg">{t("cta_join_sub")}</p>
          <div className="mt-7 flex flex-wrap justify-center gap-3">
            <Link href="/pawmap" className="inline-flex min-h-[48px] items-center gap-2 rounded-full bg-owner px-7 text-[15px] font-semibold text-white transition hover:bg-owner-dark">
              <AppIcon name="calendar" size={18} color="#fff" />{t("home_book_on_site")}
            </Link>
            <Link href="/download" className="inline-flex min-h-[48px] items-center gap-2 rounded-full bg-white px-7 text-[15px] font-semibold text-[#231715] transition hover:bg-[#F0E3DF]">
              <AppIcon name="download" size={18} />{t("nav_download")}
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
