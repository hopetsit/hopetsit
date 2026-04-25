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
