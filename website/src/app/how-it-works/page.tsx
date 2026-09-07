"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";
import { PageHero, SectionTitle } from "@/components/PageHero";
import { SubscriptionsExplainer } from "@/components/SubscriptionsExplainer";
import StoreBadges from "@/components/StoreBadges";

/**
 * v556 — « Comment ça marche » en version premium (Daniel). Même langage que
 * l'accueil : en-tête crème + trame, 4 étapes reliées par un fil (une
 * couleur par étape), 3 rôles, bande sombre « suivi gratuit pendant le
 * service », abonnements expliqués, appel final. Mêmes clés, mêmes routes.
 */
export default function HowItWorksPage() {
  const { t } = useT();
  const steps = [
    { n: "01", emoji: "✨", title: t("how_step1_title"), body: t("how_step1_body"), tone: "bg-owner text-white" },
    { n: "02", emoji: "🔎", title: t("how_step2_title"), body: t("how_step2_body"), tone: "bg-sitter text-white" },
    { n: "03", emoji: "💳", title: t("how_step3_title"), body: t("how_step3_body"), tone: "bg-walker text-white" },
    { n: "04", emoji: "⭐", title: t("how_step4_title"), body: t("how_step4_body"), tone: "bg-amber-400 text-ink" },
  ] as const;

  const roles = [
    { e: "🐾", ti: t("role_owner_title"), bo: t("role_owner_body"), c: "owner" },
    { e: "🏠", ti: t("role_sitter_title"), bo: t("role_sitter_body"), c: "sitter" },
    { e: "🚶", ti: t("role_walker_title"), bo: t("role_walker_body"), c: "walker" },
  ] as const;

  return (
    <>
      <PageHero title={t("how_title")} subtitle={t("how_sub")} badge={<>🐾 HoPetSit</>}>
        <div className="flex flex-wrap justify-center gap-3">
          <Link
            href="/signup"
            className="inline-flex items-center gap-2 rounded-full bg-owner px-7 py-3.5 text-sm font-bold text-white shadow-cta transition hover:-translate-y-0.5 hover:bg-owner-dark"
          >
            {t("nav_signup")} <span aria-hidden>→</span>
          </Link>
          <Link
            href="/download"
            className="inline-flex items-center rounded-full border border-ink/15 bg-white px-7 py-3.5 text-sm font-bold text-ink shadow-sm transition hover:-translate-y-0.5 hover:border-ink/30"
          >
            {t("nav_download")}
          </Link>
        </div>
      </PageHero>

      {/* ── 4 étapes ── */}
      <section className="bg-white py-20">
        <div className="mx-auto max-w-6xl px-4">
          <div className="relative grid gap-6 md:grid-cols-4">
            <div aria-hidden className="absolute left-[12%] right-[12%] top-9 hidden h-px bg-gradient-to-r from-owner/30 via-sitter/30 to-amber-400/40 md:block" />
            {steps.map((s) => (
              <div key={s.n} className="group relative rounded-[26px] border border-[#efe7e0] bg-white p-7 shadow-card transition hover:-translate-y-1.5 hover:shadow-xl">
                <div className="flex items-center gap-3">
                  <span className={`grid h-[4.5rem] w-[4.5rem] shrink-0 place-items-center rounded-2xl text-3xl shadow-lg ${s.tone}`}>{s.emoji}</span>
                  <span className="font-display text-4xl font-extrabold tracking-tight text-ink/10">{s.n}</span>
                </div>
                <h2 className="mt-5 text-lg font-extrabold text-ink">{s.title}</h2>
                <p className="mt-2 text-sm leading-relaxed text-ink-muted">{s.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── 3 rôles ── */}
      <section className="bg-bg-soft py-20">
        <div className="mx-auto max-w-6xl px-4">
          <SectionTitle>{t("roles_title")}</SectionTitle>
          <div className="mt-12 grid gap-6 md:grid-cols-3">
            {roles.map((r) => (
              <div key={r.ti} className="group relative overflow-hidden rounded-[26px] border border-[#efe7e0] bg-white p-8 shadow-card transition hover:-translate-y-1.5 hover:shadow-xl">
                <div className={`absolute inset-x-0 top-0 h-1.5 bg-${r.c}`} />
                <div aria-hidden className={`pointer-events-none absolute -right-10 -top-10 h-32 w-32 rounded-full bg-${r.c}-light opacity-70 blur-2xl`} />
                <div className={`grid h-14 w-14 place-items-center rounded-2xl bg-${r.c}-light text-3xl shadow-sm transition group-hover:scale-110`}>{r.e}</div>
                <h3 className="mt-5 text-lg font-extrabold text-ink">{r.ti}</h3>
                <p className="mt-2 text-sm leading-relaxed text-ink-muted">{r.bo}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── Suivi GRATUIT pendant le service ── bande sombre. */}
      <section className="relative overflow-hidden bg-[#17141f] py-20 text-white">
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{ background: "radial-gradient(55% 70% at 20% 40%, rgba(22,163,74,0.28) 0%, rgba(22,163,74,0) 65%), radial-gradient(40% 55% at 85% 70%, rgba(255,106,0,0.22) 0%, rgba(255,106,0,0) 65%)" }}
        />
        <div className="relative mx-auto flex max-w-4xl flex-col items-center gap-6 px-4 text-center">
          <span className="grid h-16 w-16 place-items-center rounded-2xl bg-white/10 text-4xl ring-1 ring-white/15">🛰️</span>
          <h2 className="font-display text-3xl font-extrabold tracking-tight md:text-4xl">{t("hiw_track_title")}</h2>
          <p className="max-w-2xl text-base leading-relaxed text-white/80">{t("hiw_track_body")}</p>
          <Link href="/pawmap" className="rounded-full bg-[#FF6A00] px-7 py-3.5 text-sm font-bold text-white shadow-lg transition hover:-translate-y-0.5 hover:bg-[#E85F00]">
            {t("home_discover")} PawMap →
          </Link>
        </div>
      </section>

      {/* ── Abonnements ── */}
      <div className="bg-white">
        <div className="mx-auto max-w-6xl px-4 pt-20">
          <SectionTitle>{t("hiw_subs_title")}</SectionTitle>
        </div>
        <SubscriptionsExplainer compact />
      </div>

      {/* ── Appel final ── */}
      <section className="mx-auto max-w-6xl px-4 py-20">
        <div className="relative overflow-hidden rounded-[26px] bg-gradient-to-br from-owner to-[#d93a1f] p-10 text-white shadow-2xl md:p-14">
          <span aria-hidden className="pointer-events-none absolute -bottom-6 right-8 -rotate-12 select-none text-[110px] leading-none opacity-10">🐾</span>
          <div className="relative">
            <h2 className="font-display text-3xl font-extrabold tracking-tight md:text-4xl">{t("cta_join_title")}</h2>
            <p className="mt-3 max-w-2xl text-white/90">{t("cta_join_sub")}</p>
            <div className="mt-7 flex flex-wrap gap-3">
              <Link href="/signup" className="rounded-full bg-white px-6 py-3 text-sm font-bold text-owner shadow-lg transition hover:-translate-y-0.5 hover:bg-bg-soft">
                {t("nav_signup")}
              </Link>
            </div>
            <div className="mt-5">
              <StoreBadges />
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
