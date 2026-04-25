"use client";

import { useT } from "@/lib/i18n/LanguageProvider";

export default function FAQPage() {
  const { t } = useT();
  const items = [
    { q: t("faq_q1"), a: t("faq_a1") },
    { q: t("faq_q2"), a: t("faq_a2") },
    { q: t("faq_q3"), a: t("faq_a3") },
    { q: t("faq_q4"), a: t("faq_a4") },
    { q: t("faq_q5"), a: t("faq_a5") },
  ];

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight md:text-5xl">
        {t("faq_title")}
      </h1>

      <div className="mt-12 space-y-3">
        {items.map((it, i) => (
          <details
            key={i}
            className="group rounded-2xl border border-ink/5 bg-white p-5 shadow-card open:bg-bg-soft"
          >
            <summary className="flex cursor-pointer items-center justify-between gap-4 text-base font-semibold text-ink">
              {it.q}
              <span className="grid h-7 w-7 place-items-center rounded-full bg-bg-soft text-xs font-bold text-ink-muted transition group-open:rotate-180">
                ▾
              </span>
            </summary>
            <p className="mt-3 text-sm leading-relaxed text-ink-muted">{it.a}</p>
          </details>
        ))}
      </div>
    </div>
  );
}
