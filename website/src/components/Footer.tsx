"use client";

import Link from "next/link";
import { LogoWithText } from "./Logo";
import { useT } from "@/lib/i18n/LanguageProvider";

export function Footer() {
  const { t } = useT();
  const year = new Date().getFullYear();

  const cols = [
    {
      title: t("footer_about"),
      links: [
        { href: "/how-it-works", label: t("nav_how") },
        { href: "/pricing",      label: t("nav_pricing") },
        { href: "/pawmap",       label: t("nav_pawmap") },
      ],
    },
    {
      title: t("footer_help"),
      links: [
        { href: "/faq",      label: t("nav_faq") },
        { href: "/contact",  label: t("nav_contact") },
        { href: "/download", label: t("nav_download") },
      ],
    },
    {
      title: t("footer_legal"),
      links: [
        { href: "/terms",    label: t("footer_terms") },
        { href: "/privacy",  label: t("footer_privacy") },
        { href: "/refund",   label: t("footer_refund") },
        { href: "/imprint",  label: t("footer_imprint") },
      ],
    },
  ];

  return (
    <footer className="border-t border-ink/5 bg-bg-soft">
      <div className="mx-auto max-w-6xl px-4 py-12">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4">
          <div className="col-span-2">
            <LogoWithText />
            <p className="mt-3 max-w-sm text-sm text-ink-muted">
              {t("footer_company")}
            </p>
            <p className="mt-2 text-sm text-ink-muted">
              <a href="mailto:contact@hopetsit.com" className="hover:text-ink">
                contact@hopetsit.com
              </a>
            </p>
          </div>
          {cols.map((c) => (
            <div key={c.title}>
              <h4 className="text-xs font-semibold uppercase tracking-wider text-ink-soft">
                {c.title}
              </h4>
              <ul className="mt-3 space-y-2">
                {c.links.map((l) => (
                  <li key={l.href}>
                    <Link
                      href={l.href}
                      className="text-sm text-ink-muted hover:text-ink"
                    >
                      {l.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="mt-10 border-t border-ink/5 pt-6 text-xs text-ink-soft">
          © {year} CARDELLI HERMANOS LIMITED · {t("footer_rights")}
        </div>
      </div>
    </footer>
  );
}
