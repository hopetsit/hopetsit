"use client";

import Link from "next/link";
import PawSpotGoldCoin from "@/components/PawSpotGoldCoin";
import { PawMemberBadge } from "@/components/PawMemberBadge";
import { useT } from "@/lib/i18n/LanguageProvider";

// v493 — Refonte design (design-only) : page d'accueil ramenée de ~9 sections
// à 6 (Hero · Bande confiance · 3 rôles · 3 services · Paw Premium · CTA final).
// Aucune donnée/route/logique modifiée : on réutilise EXACTEMENT les mêmes
// clés i18n et les mêmes liens (/download, /login, /signup, /pawmap, /boutique).
export default function HomePage() {
  const { t } = useT();

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

  // « 3 services, une seule app » — fusion des anciennes sections PawSpot /
  // PawFollow / « 3 apps en 1 » (doublons) en UNE grille de 3 cartes, avec
  // prix en ligne + 1 CTA chacun. Mêmes clés + mêmes routes qu'avant.
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
      price: t("home_pawfollow_price_line"),
      cta: t("home_pawfollow_price_line"),
      href: "/boutique",
      accent: "violet",
    },
    {
      kind: "pawspot",
      name: "PawSpot",
      title: t("home_app3_title"),
      body: t("home_app3_body"),
      price: t("home_pawspot_price_line"),
      cta: t("home_pawspot_cta"),
      href: "/pawmap",
      accent: "amber",
    },
  ] as const;

  return (
    <>
      {/* ── 1. HERO ── orange → blanc, carte sitter flottante. */}
      <section className="relative overflow-hidden bg-gradient-to-br from-owner-light via-white to-sitter-light/40">
        <div className="mx-auto grid max-w-6xl gap-10 px-4 py-20 md:grid-cols-2 md:py-28">
          <div className="flex flex-col justify-center">
            <span className="mb-4 inline-flex w-fit items-center gap-2 rounded-full border border-owner/30 bg-white px-3 py-1 text-xs font-semibold text-owner">
              🇪🇺 29 European countries
            </span>
            <h1 className="font-display text-4xl font-extrabold leading-[1.08] tracking-tight text-ink md:text-6xl">
              {t("hero_title")}
            </h1>
            <p className="mt-5 max-w-xl text-lg leading-relaxed text-ink-muted">
              {t("hero_sub")}
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link
                href="/download"
                className="rounded-full bg-owner px-7 py-3.5 text-sm font-bold text-white shadow-cta transition hover:bg-owner-dark"
              >
                {t("hero_cta_app")}
              </Link>
              <Link
                href="/login"
                className="whitespace-nowrap rounded-full bg-[#17141f] px-7 py-3.5 text-sm font-bold text-white shadow-cta transition hover:bg-black"
              >
                {t("hero_cta_web_login")}
              </Link>
            </div>
          </div>

          <div className="relative">
            <div className="relative mx-auto w-full max-w-sm">
              <div className="absolute -right-4 top-6 h-72 w-full rotate-3 rounded-[26px] bg-sitter shadow-card" />
              <div className="absolute -left-4 top-12 h-72 w-full -rotate-2 rounded-[26px] bg-walker shadow-card" />
              <div className="relative w-full rounded-[26px] border border-[#efe7e0] bg-white p-6 shadow-card">
                <div className="flex items-center justify-between">
                  <div className="flex items-start gap-3">
                    <div className="grid h-12 w-12 place-items-center rounded-2xl bg-owner-light text-2xl">🐕</div>
                    <div>
                      <div className="text-sm font-bold text-ink">Sophie · {t("home_sophie_role")}</div>
                      <div className="text-xs text-ink-muted">Lyon · 4.9 ★ · Top Sitter</div>
                    </div>
                  </div>
                  <span className="inline-flex items-center gap-1 rounded-full bg-sitter-light px-2.5 py-1 text-[10px] font-bold text-sitter-dark">
                    ✓
                  </span>
                </div>
                <div className="mt-5 grid grid-cols-3 gap-2 text-center">
                  {[
                    { t: t("home_card_day"), v: "€30" },
                    { t: t("home_card_week"), v: "€180" },
                    { t: t("home_card_month"), v: "€620" },
                  ].map((x) => (
                    <div key={x.t} className="rounded-xl bg-bg-soft p-2">
                      <div className="text-[10px] uppercase tracking-wider text-ink-soft">{x.t}</div>
                      <div className="text-sm font-bold text-ink">{x.v}</div>
                    </div>
                  ))}
                </div>
                <div className="mt-5 rounded-xl bg-sitter-light/70 p-3">
                  <div className="text-[11px] uppercase text-sitter-dark">{t("home_est_earning")}</div>
                  <div className="mt-1 text-2xl font-extrabold text-sitter-dark">€48.00</div>
                  <div className="text-[11px] text-ink-muted">{t("home_est_detail")}</div>
                </div>
                <div className="mt-4 grid grid-cols-2 gap-2">
                  <button className="rounded-full border border-ink/10 py-2 text-xs font-semibold text-ink">{t("home_card_details")}</button>
                  <button className="rounded-full bg-owner py-2 text-xs font-semibold text-white">{t("home_card_request")}</button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── 2. BANDE CONFIANCE COMPACTE ── fond sombre, 4 preuves en ligne
           (fusion des anciennes sections « confiance » + « sécurité »). */}
      <section className="bg-[#17141f] py-10">
        <div className="mx-auto grid max-w-6xl grid-cols-2 gap-x-6 gap-y-6 px-4 md:grid-cols-4">
          {trust.map((tr) => (
            <div key={tr.title} className="flex items-start gap-3">
              <div className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-owner text-base text-white">
                {tr.icon}
              </div>
              <div>
                <div className="text-sm font-bold text-white">{tr.title}</div>
                <div className="mt-0.5 text-xs leading-snug text-white/60">{tr.body}</div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* ── 3. UNE APP, TROIS RÔLES ── 3 cartes. */}
      <section className="mx-auto max-w-6xl px-4 py-20">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
          {t("roles_title")}
        </h2>
        <div className="mt-12 grid gap-6 md:grid-cols-3">
          {roles.map((r) => {
            const accent = r.color;
            return (
              <div
                key={r.title}
                className="group relative overflow-hidden rounded-[22px] border border-[#efe7e0] bg-white p-7 shadow-card transition-transform hover:-translate-y-1"
              >
                <div className={`absolute inset-x-0 top-0 h-1.5 bg-${accent}`} />
                <div className={`grid h-12 w-12 place-items-center rounded-2xl bg-${accent}-light text-2xl`}>
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
      <section className="bg-bg-soft py-20">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
            {t("home_3in1_title")}
          </h2>
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
                  className={`group relative flex flex-col overflow-hidden rounded-[22px] border bg-white p-7 shadow-card transition-transform hover:-translate-y-1 ${ring}`}
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
                  <p className="mt-2 text-sm leading-relaxed text-ink-muted">{s.body}</p>
                  {/* v493 — PawSpot : « voir les membres proches » + badge rose. */}
                  {isPs && (
                    <p className="mt-3 flex items-center gap-2 text-xs font-semibold text-pink-700">
                      <PawMemberBadge size={18} />
                      <span>{t("pawspot_feat_nearby")}</span>
                    </p>
                  )}
                  <div className="mt-5 flex items-center justify-between gap-2 border-t border-[#efe7e0] pt-4">
                    <span className={`text-sm font-extrabold ${titleCls}`}>{s.price}</span>
                    <Link
                      href={s.href}
                      className={`rounded-full px-4 py-2 text-xs font-bold text-white transition ${btn}`}
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

      {/* ── 5. PAW PREMIUM ── une seule bande compacte (noir/or), CTA boutique.
           v493 — plus d'air : carte centrée avec marges, padding & gaps généreux. */}
      <section className="px-4 py-20">
        <div className="mx-auto flex max-w-4xl flex-col items-center gap-7 rounded-[26px] bg-gradient-to-b from-[#221C12] to-[#15120D] p-9 text-center md:flex-row md:gap-10 md:p-12 md:text-left">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/pawpremium_logo.svg" alt="Paw Premium" width={80} height={80} className="shrink-0" />
          <div className="flex-1">
            <h2 className="font-display text-2xl font-extrabold tracking-tight text-yellow-400 md:text-3xl">
              Paw Premium 👑
            </h2>
            <p className="mx-auto mt-3 max-w-xl text-sm leading-relaxed text-white/85 md:mx-0">
              {t("home_pawpremium_blurb")}
            </p>
          </div>
          <Link
            href="/boutique"
            className="shrink-0 rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-7 py-3.5 text-sm font-bold text-black shadow-cta transition hover:brightness-110"
          >
            {t("home_pawpremium_price_line")} →
          </Link>
        </div>
      </section>

      {/* ── 6. CTA FINAL ── */}
      <section className="mx-auto max-w-6xl px-4 py-20">
        <div className="relative overflow-hidden rounded-[26px] bg-owner p-10 text-white md:p-14">
          <div className="absolute -right-10 -top-10 h-48 w-48 rounded-full bg-white/10" />
          <div className="absolute -bottom-16 -left-10 h-48 w-48 rounded-full bg-white/10" />
          <div className="relative">
            <h2 className="font-display text-3xl font-extrabold tracking-tight md:text-4xl">
              {t("cta_join_title")}
            </h2>
            <p className="mt-3 max-w-2xl text-white/90">{t("cta_join_sub")}</p>
            <div className="mt-7 flex flex-wrap gap-3">
              <Link
                href="/signup"
                className="rounded-full bg-white px-6 py-3 text-sm font-bold text-owner hover:bg-bg-soft"
              >
                {t("nav_signup")}
              </Link>
              <Link
                href="/download"
                className="rounded-full border border-white/40 px-6 py-3 text-sm font-bold text-white hover:bg-white/10"
              >
                {t("nav_download")}
              </Link>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
