"use client";

import { useT } from "@/lib/i18n/LanguageProvider";
import Link from "next/link";

export default function HowItWorksPage() {
  const { t } = useT();
  const steps = [
    { n: 1, title: t("how_step1_title"), body: t("how_step1_body"), color: "owner" },
    { n: 2, title: t("how_step2_title"), body: t("how_step2_body"), color: "sitter" },
    { n: 3, title: t("how_step3_title"), body: t("how_step3_body"), color: "walker" },
    { n: 4, title: t("how_step4_title"), body: t("how_step4_body"), color: "owner" },
  ] as const;

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight text-ink md:text-5xl">
        {t("how_title")}
      </h1>
      <p className="mx-auto mt-4 max-w-xl text-center text-lg text-ink-muted">{t("how_sub")}</p>

      <ol className="mt-16 space-y-6">
        {steps.map((s) => (
          <li
            key={s.n}
            className="flex gap-5 rounded-2xl border border-ink/5 bg-white p-6 shadow-card"
          >
            <div
              className={`grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-${s.color}-light text-lg font-extrabold text-${s.color}-dark`}
            >
              {s.n}
            </div>
            <div>
              <h2 className="text-lg font-bold text-ink">{s.title}</h2>
              <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">{s.body}</p>
            </div>
          </li>
        ))}
      </ol>

      {/* v23.1.390 — Daniel : grande partie petsitting (les 3 rôles). */}
      <h2 className="mt-20 text-center font-display text-3xl font-extrabold tracking-tight text-ink">
        {t("roles_title")}
      </h2>
      <div className="mt-10 grid gap-5 md:grid-cols-3">
        {[
          { e: "🐾", ti: t("role_owner_title"), bo: t("role_owner_body"), c: "owner" },
          { e: "🏠", ti: t("role_sitter_title"), bo: t("role_sitter_body"), c: "sitter" },
          { e: "🚶", ti: t("role_walker_title"), bo: t("role_walker_body"), c: "walker" },
        ].map((r) => (
          <div key={r.ti} className="rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <div className={`grid h-11 w-11 place-items-center rounded-2xl bg-${r.c}-light text-2xl`}>{r.e}</div>
            <h3 className="mt-4 text-base font-bold text-ink">{r.ti}</h3>
            <p className="mt-2 text-sm text-ink-muted">{r.bo}</p>
          </div>
        ))}
      </div>

      {/* Suivi GRATUIT pendant le service via la PawMap. */}
      <div className="mt-10 rounded-3xl border-2 border-emerald-300 bg-emerald-50 p-8 text-center">
        <div className="text-4xl">🛰️</div>
        <h3 className="mt-3 font-display text-xl font-extrabold text-emerald-800">
          {t("hiw_track_title")}
        </h3>
        <p className="mx-auto mt-2 max-w-xl text-sm text-emerald-900/80">{t("hiw_track_body")}</p>
      </div>

      {/* Vente : PawFollow · PawSpot · surtout PawPremium. */}
      <h2 className="mt-20 text-center font-display text-3xl font-extrabold tracking-tight text-ink">
        {t("hiw_subs_title")}
      </h2>
      <div className="mt-10 grid gap-5 md:grid-cols-2">
        <div className="rounded-2xl border-2 border-violet-300 bg-white p-6 shadow-card">
          <div className="flex items-center gap-3">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/pawfollow_logo.svg" alt="PawFollow" width={40} height={40} />
            <h3 className="text-lg font-extrabold text-violet-700">PawFollow</h3>
          </div>
          <p className="mt-3 text-sm text-ink-muted">{t("home_pawfollow_blurb")}</p>
          <p className="mt-3 text-sm font-semibold text-violet-700">{t("home_pawfollow_price_line")}</p>
        </div>
        <div className="rounded-2xl border-2 border-amber-300 bg-amber-50 p-6 shadow-card">
          <div className="flex items-center gap-3">
            <span className="text-3xl">🐾</span>
            <h3 className="text-lg font-extrabold text-amber-700">PawSpot</h3>
          </div>
          <p className="mt-3 text-sm text-ink-muted">{t("home_pawspot_blurb")}</p>
          <p className="mt-3 text-sm font-semibold text-amber-700">{t("home_pawspot_price_line")}</p>
        </div>
      </div>
      <div className="mt-6 rounded-3xl border-2 border-amber-400 bg-gradient-to-b from-[#221C12] to-[#15120D] p-8 text-center">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/pawpremium_logo.svg" alt="PawPremium" width={72} height={72} className="mx-auto" />
        <h3 className="mt-3 font-display text-2xl font-extrabold text-yellow-400">PawPremium 👑</h3>
        <p className="mx-auto mt-2 max-w-xl text-sm text-white/85">{t("home_pawpremium_blurb")}</p>
        <p className="mt-3 text-sm font-semibold text-yellow-300">{t("home_pawpremium_price_line")}</p>
        <Link
          href="/boutique"
          className="mt-5 inline-block rounded-full bg-gradient-to-r from-amber-500 to-yellow-400 px-7 py-3 text-sm font-bold text-black hover:brightness-110"
        >
          {t("pawpremium_cta")} →
        </Link>
      </div>

      <div className="mt-16 text-center">
        <Link
          href="/signup"
          className="inline-block rounded-full bg-owner px-7 py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark"
        >
          {t("nav_signup")} →
        </Link>
      </div>
    </div>
  );
}
