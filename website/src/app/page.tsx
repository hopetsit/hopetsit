"use client";

import Link from "next/link";
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
                    <div className="text-sm font-semibold text-ink">Sophie · Pet sitter</div>
                    <div className="text-xs text-ink-muted">Lyon · 4.9 ★ · Top Sitter</div>
                  </div>
                </div>
                <div className="mt-5 grid grid-cols-3 gap-2 text-center">
                  {[
                    { t: "Day", v: "€30" },
                    { t: "Week", v: "€180" },
                    { t: "Month", v: "€620" },
                  ].map((x) => (
                    <div key={x.t} className="rounded-xl bg-bg-soft p-2">
                      <div className="text-[10px] uppercase tracking-wider text-ink-soft">{x.t}</div>
                      <div className="text-sm font-bold text-ink">{x.v}</div>
                    </div>
                  ))}
                </div>
                <div className="mt-5 rounded-xl bg-sitter-light/70 p-3">
                  <div className="text-[11px] uppercase text-sitter-dark">Estimated earning</div>
                  <div className="mt-1 text-2xl font-extrabold text-sitter-dark">€48.00</div>
                  <div className="text-[11px] text-ink-muted">1 day × €40 + 20% commission</div>
                </div>
                <div className="mt-4 grid grid-cols-2 gap-2">
                  <button className="rounded-full border border-ink/10 py-2 text-xs font-semibold text-ink">Details</button>
                  <button className="rounded-full bg-owner py-2 text-xs font-semibold text-white">Send request</button>
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
