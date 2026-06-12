"use client";

import Link from "next/link";
import PawSpotGoldCoin from "@/components/PawSpotGoldCoin";
import { useT } from "@/lib/i18n/LanguageProvider";

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

  // v23.1 part 240 — Daniel : "MET A JOUR TOUT LE SITE WEB AVEC LES
  // NOUVELLES FONCTIONALITER deep work". Surfacing the 4 headline
  // features added in v240 right on the homepage so visitors landing
  // from social or organic search see the differentiation immediately.
  const v240Features = [
    {
      emoji: "👨‍👩‍👧",
      title: t("v240_feat_family_title"),
      body: t("v240_feat_family_body"),
      color: "owner",
    },
    {
      emoji: "📍",
      title: t("v240_feat_pawspot_title"),
      body: t("v240_feat_pawspot_body"),
      color: "sitter",
    },
    {
      emoji: "🛰️",
      title: t("v240_feat_live_title"),
      body: t("v240_feat_live_body"),
      color: "walker",
    },
    {
      emoji: "🪪",
      title: t("v240_feat_kyc_title"),
      body: t("v240_feat_kyc_body"),
      color: "owner",
    },
  ] as const;

  // v23.1.279 — Daniel : "mettre 4 façons d'utiliser HoPetSit + l'onglet
  // PawFamily". La 4e carte (PawFamily) est en VIOLET = code couleur famille.
  const usageWays = [
    { emoji: "🔎", title: t("home_way1_title"), body: t("home_way1_body"), accent: "owner" },
    { emoji: "💼", title: t("home_way2_title"), body: t("home_way2_body"), accent: "sitter" },
    { emoji: "📍", title: t("home_way3_title"), body: t("home_way3_body"), accent: "walker" },
    { emoji: "👨‍👩‍👧", title: t("home_way4_title"), body: t("home_way4_body"), accent: "family" },
  ] as const;

  return (
    <>
      {/* Hero — orange gradient, the same accent as the mobile app primary. */}
      <section className="relative overflow-hidden bg-gradient-to-br from-owner-light via-white to-sitter-light/40">
        <div className="mx-auto grid max-w-6xl gap-10 px-4 py-20 md:grid-cols-2 md:py-28">
          <div className="flex flex-col justify-center">
            <span className="mb-4 inline-flex w-fit items-center gap-2 rounded-full border border-owner/30 bg-white px-3 py-1 text-xs font-medium text-owner">
              🇪🇺 29 European countries
            </span>
            <h1 className="font-display text-4xl font-extrabold leading-tight tracking-tight text-ink md:text-5xl">
              {t("hero_title")}
            </h1>
            <p className="mt-5 max-w-xl text-lg leading-relaxed text-ink-muted">
              {t("hero_sub")}
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link
                href="/download"
                className="rounded-full bg-owner px-6 py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark"
              >
                {t("hero_cta_app")}
              </Link>
              <Link
                href="/how-it-works"
                className="rounded-full border border-ink/15 bg-white px-6 py-3 text-sm font-semibold text-ink hover:border-ink/40"
              >
                {t("hero_cta_how")} →
              </Link>
            </div>
          </div>

          <div className="relative">
            {/* Decorative hero card stack */}
            <div className="relative mx-auto w-full max-w-sm">
              <div className="absolute -right-4 top-6 h-72 w-full rotate-3 rounded-3xl bg-sitter shadow-card" />
              <div className="absolute -left-4 top-12 h-72 w-full -rotate-2 rounded-3xl bg-walker shadow-card" />
              <div className="relative h-72 w-full rounded-3xl bg-white p-6 shadow-card ring-1 ring-ink/5">
                <div className="flex items-start gap-3">
                  <div className="grid h-12 w-12 place-items-center rounded-2xl bg-owner-light text-2xl">🐕</div>
                  <div>
                    <div className="text-sm font-semibold text-ink">Sophie · {t("home_sophie_role")}</div>
                    <div className="text-xs text-ink-muted">Lyon · 4.9 ★ · Top Sitter</div>
                  </div>
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

      {/* Three roles */}
      <section className="mx-auto max-w-6xl px-4 py-20">
        <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
          {t("roles_title")}
        </h2>
        <div className="mt-12 grid gap-6 md:grid-cols-3">
          {roles.map((r) => {
            const accent = r.color; // tailwind picks the right brand colour
            return (
              <div
                key={r.title}
                className={`group relative overflow-hidden rounded-2xl border border-ink/5 bg-white p-7 shadow-card transition-transform hover:-translate-y-1`}
              >
                <div className={`absolute inset-x-0 top-0 h-1 bg-${accent}`} />
                <div className={`grid h-12 w-12 place-items-center rounded-2xl bg-${accent}-light text-2xl`}>
                  {r.emoji}
                </div>
                <h3 className="mt-5 text-lg font-bold text-ink">{r.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-ink-muted">{r.body}</p>
              </div>
            );
          })}
        </div>
      </section>

      {/* v23.1.355 — Daniel : "parle du PawSpot sur la 1re page du site".
          Section dédiée au nouveau PawSpot communautaire (spots tagués,
          PawPoints, badges, empreinte dorée) — identité DORÉE. */}
      <section className="bg-gradient-to-br from-amber-50 via-white to-amber-100/60 py-20">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
            <PawSpotGoldCoin size={40} className="mr-2 -mt-1" />
            {t("home_pawspot_title")}
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-center text-base text-ink-muted">
            {t("home_pawspot_sub")}
          </p>
          <div className="mt-10 grid gap-5 md:grid-cols-3">
            <div className="rounded-2xl border border-amber-200 bg-white p-6 shadow-card">
              <div className="text-3xl">📍</div>
              <h3 className="mt-3 text-base font-bold text-ink">{t("home_pawspot_b1_title")}</h3>
              <p className="mt-2 text-sm text-ink-muted">{t("home_pawspot_b1_body")}</p>
            </div>
            <div className="rounded-2xl border border-amber-200 bg-white p-6 shadow-card">
              <div className="text-3xl">🏆</div>
              <h3 className="mt-3 text-base font-bold text-ink">{t("home_pawspot_b2_title")}</h3>
              <p className="mt-2 text-sm text-ink-muted">{t("home_pawspot_b2_body")}</p>
            </div>
            <div className="rounded-2xl border-2 border-amber-400 bg-white p-6 shadow-card">
              <PawSpotGoldCoin size={34} />
              <h3 className="mt-3 text-base font-bold text-ink">{t("home_pawspot_b3_title")}</h3>
              <p className="mt-2 text-sm text-ink-muted">{t("home_pawspot_b3_body")}</p>
            </div>
          </div>
          <p className="mt-8 text-center text-sm font-semibold text-amber-700">
            {t("home_pawspot_price_line")}
          </p>
          <div className="mt-5 text-center">
            <Link
              href="/pawmap"
              className="inline-block rounded-full bg-amber-500 px-7 py-3 text-sm font-semibold text-white shadow-cta hover:bg-amber-600"
            >
              {t("home_pawspot_cta")} →
            </Link>
          </div>

          {/* v23.1.388 — Daniel : "en dessous de PawSpot parle aussi de
              PawFollow + une ligne Paw Premium : les deux en un". */}
          <div className="mt-12 grid gap-5 md:grid-cols-2">
            <div className="rounded-2xl border-2 border-violet-300 bg-white p-6 shadow-card">
              <div className="flex items-center gap-3">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src="/pawfollow_logo.svg" alt="PawFollow" width={44} height={44} />
                <h3 className="text-lg font-extrabold text-violet-700">PawFollow</h3>
              </div>
              <p className="mt-3 text-sm text-ink-muted">{t("home_pawfollow_blurb")}</p>
              <p className="mt-3 text-sm font-semibold text-violet-700">
                {t("home_pawfollow_price_line")}
              </p>
            </div>
            <div className="rounded-2xl border-2 border-amber-400 bg-gradient-to-b from-[#221C12] to-[#15120D] p-6 shadow-card">
              <div className="flex items-center gap-3">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src="/pawpremium_logo.svg" alt="Paw Premium" width={44} height={44} />
                <h3 className="text-lg font-extrabold text-yellow-400">Paw Premium 👑</h3>
              </div>
              <p className="mt-3 text-sm text-white/85">{t("home_pawpremium_blurb")}</p>
              <p className="mt-3 text-sm font-semibold text-yellow-300">
                {t("home_pawpremium_price_line")}
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Trust grid */}
      <section className="bg-bg-soft py-20">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
            {t("trust_title")}
          </h2>
          <div className="mt-12 grid gap-5 md:grid-cols-2 lg:grid-cols-4">
            {trust.map((tr) => (
              <div key={tr.title} className="rounded-2xl bg-white p-6 shadow-card">
                <div className="grid h-10 w-10 place-items-center rounded-full bg-owner text-lg text-white">
                  {tr.icon}
                </div>
                <h3 className="mt-4 text-base font-bold text-ink">{tr.title}</h3>
                <p className="mt-2 text-sm text-ink-muted">{tr.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* v23.1 part 240 — "What's new" feature spotlight (4 cards). */}
      <section className="mx-auto max-w-6xl px-4 py-20">
        <div className="mb-10 text-center">
          <span className="mb-3 inline-flex items-center gap-2 rounded-full border border-owner/30 bg-owner-light px-3 py-1 text-xs font-semibold uppercase tracking-wider text-owner">
            ✨ {t("v240_new_eyebrow")}
          </span>
          <h2 className="font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
            {t("v240_new_title")}
          </h2>
          <p className="mx-auto mt-3 max-w-2xl text-base leading-relaxed text-ink-muted">
            {t("v240_new_sub")}
          </p>
        </div>
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {v240Features.map((f) => (
            <div
              key={f.title}
              className="group relative overflow-hidden rounded-2xl border border-ink/5 bg-white p-6 shadow-card transition-transform hover:-translate-y-1"
            >
              <div className={`absolute inset-x-0 top-0 h-1 bg-${f.color}`} />
              <div
                className={`mb-4 grid h-12 w-12 place-items-center rounded-2xl bg-${f.color}-light text-2xl`}
              >
                {f.emoji}
              </div>
              <h3 className="text-base font-bold text-ink">{f.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* v23.1.279 — Daniel : "4 façons d'utiliser HoPetSit + onglet PawFamily".
          4 cartes ; la 4e (PawFamily) en VIOLET = code couleur famille. */}
      <section className="bg-bg-soft py-20">
        <div className="mx-auto max-w-6xl px-4">
          <h2 className="text-center font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
            {t("home_ways_title")}
          </h2>
          <p className="mx-auto mt-3 max-w-2xl text-center text-base leading-relaxed text-ink-muted">
            {t("home_ways_sub")}
          </p>
          <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {usageWays.map((w) => {
              const isFamily = w.accent === "family";
              return (
                <div
                  key={w.title}
                  className={
                    "group relative overflow-hidden rounded-2xl border bg-white p-6 shadow-card transition-transform hover:-translate-y-1 " +
                    (isFamily ? "border-violet-300 ring-1 ring-violet-200" : "border-ink/5")
                  }
                >
                  <div
                    className={
                      isFamily
                        ? "absolute inset-x-0 top-0 h-1 bg-violet-500"
                        : `absolute inset-x-0 top-0 h-1 bg-${w.accent}`
                    }
                  />
                  <div
                    className={
                      isFamily
                        ? "mb-4 grid h-12 w-12 place-items-center rounded-2xl bg-violet-100 text-2xl"
                        : `mb-4 grid h-12 w-12 place-items-center rounded-2xl bg-${w.accent}-light text-2xl`
                    }
                  >
                    {w.emoji}
                  </div>
                  <h3 className={"text-base font-bold " + (isFamily ? "text-violet-700" : "text-ink")}>
                    {w.title}
                  </h3>
                  <p className="mt-2 text-sm leading-relaxed text-ink-muted">{w.body}</p>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* Big CTA */}
      <section className="mx-auto max-w-6xl px-4 py-20">
        <div className="relative overflow-hidden rounded-3xl bg-owner p-10 text-white md:p-14">
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
                className="rounded-full bg-white px-6 py-3 text-sm font-semibold text-owner hover:bg-bg-soft"
              >
                {t("nav_signup")}
              </Link>
              <Link
                href="/download"
                className="rounded-full border border-white/40 px-6 py-3 text-sm font-semibold text-white hover:bg-white/10"
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
