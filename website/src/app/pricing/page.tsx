"use client";

import { useT } from "@/lib/i18n/LanguageProvider";

export default function PricingPage() {
  const { t } = useT();

  const tiers = [
    {
      title: t("pricing_owner_title"),
      price: t("pricing_owner_price"),
      lines: [t("pricing_owner_l1"), t("pricing_owner_l2"), t("pricing_owner_l3")],
      color: "owner",
    },
    {
      title: t("pricing_provider_title"),
      price: t("pricing_provider_price"),
      lines: [t("pricing_provider_l1"), t("pricing_provider_l2"), t("pricing_provider_l3")],
      color: "sitter",
    },
  ] as const;

  return (
    <div className="mx-auto max-w-5xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight md:text-5xl">
        {t("pricing_title")}
      </h1>
      <p className="mx-auto mt-4 max-w-2xl text-center text-lg text-ink-muted">{t("pricing_sub")}</p>

      <div className="mt-14 grid gap-6 md:grid-cols-2">
        {tiers.map((tier) => (
          <div
            key={tier.title}
            className={`relative overflow-hidden rounded-3xl bg-white p-8 shadow-card ring-1 ring-${tier.color}/20`}
          >
            <div className={`absolute inset-x-0 top-0 h-1.5 bg-${tier.color}`} />
            <h2 className="text-sm font-semibold uppercase tracking-wider text-ink-muted">
              {tier.title}
            </h2>
            <div className={`mt-3 text-4xl font-extrabold text-${tier.color}-dark`}>
              {tier.price}
            </div>
            <ul className="mt-6 space-y-3">
              {tier.lines.map((l) => (
                <li key={l} className="flex gap-3 text-sm text-ink">
                  <span className={`mt-0.5 grid h-5 w-5 shrink-0 place-items-center rounded-full bg-${tier.color}-light text-xs font-bold text-${tier.color}-dark`}>
                    ✓
                  </span>
                  <span>{l}</span>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <p className="mt-10 rounded-xl bg-bg-soft p-5 text-center text-sm text-ink-muted">
        {t("pricing_note")}
      </p>
    </div>
  );
}
