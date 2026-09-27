"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";
import { PageHero } from "@/components/PageHero";

/**
 * v556 — FAQ en version premium (Daniel). En-tête commun, accordéon en deux
 * colonnes (1re question ouverte), carte « toujours une question ? » vers le
 * contact. Mêmes 10 clés faq_q1..10 et faq_a1..10.
 */
export default function FAQPage() {
  const { t } = useT();
  const items = Array.from({ length: 10 }, (_, i) => ({
    q: t(`faq_q${i + 1}`),
    a: t(`faq_a${i + 1}`),
  })).filter((x) => x.q && !x.q.startsWith("faq_"));

  return (
    <>
      <PageHero title={t("faq_title")} badge={<>❓ FAQ</>} />

      <section className="bg-white py-16">
        <div className="mx-auto max-w-5xl px-4">
          <div className="grid gap-4 md:grid-cols-2">
            {items.map((it, i) => (
              <details
                key={it.q}
                className="group rounded-2xl border border-ink/10 bg-white p-5 shadow-sm transition open:border-owner/30 open:shadow-lg"
                open={i === 0}
              >
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-[15px] font-bold text-ink [&::-webkit-details-marker]:hidden">
                  {it.q}
                  <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-owner-light text-owner transition group-open:rotate-45">+</span>
                </summary>
                <p className="mt-3 text-sm leading-relaxed text-ink-muted">{it.a}</p>
              </details>
            ))}
          </div>

          <div className="mt-14 flex flex-col items-center gap-4 rounded-[26px] border border-ink/10 bg-bg-soft p-8 text-center md:flex-row md:justify-between md:text-left">
            <div>
              <p className="font-display text-xl font-extrabold text-ink">{t("contact_title")}</p>
              <p className="mt-1 text-sm text-ink-muted">{t("contact_sub")}</p>
            </div>
            <Link href="/contact" className="rounded-full bg-owner px-6 py-3 text-sm font-bold text-white shadow-cta transition hover:-translate-y-0.5 hover:bg-owner-dark">
              {t("nav_contact")} →
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
