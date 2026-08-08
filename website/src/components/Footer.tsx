"use client";

import Link from "next/link";
import { LogoWithText } from "./Logo";
import { PawMapCTA } from "./PawMapCTA";
import { useT } from "@/lib/i18n/LanguageProvider";

// v402 — réseaux sociaux officiels HoPetSit (fournis par Daniel).
const SOCIALS: { label: string; href: string; icon: React.ReactNode }[] = [
  {
    label: "Instagram",
    href: "https://www.instagram.com/hopetsit/",
    icon: (
      <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth={2}>
        <rect x="3" y="3" width="18" height="18" rx="5" />
        <circle cx="12" cy="12" r="4" />
        <circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none" />
      </svg>
    ),
  },
  {
    label: "TikTok",
    href: "https://www.tiktok.com/@hopetsit",
    icon: (
      <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
        <path d="M16 3c.3 2.2 1.8 4 4 4.3V10c-1.5 0-2.9-.5-4-1.3V15a5.5 5.5 0 1 1-5.5-5.5c.3 0 .6 0 .9.08v2.7a2.8 2.8 0 1 0 1.9 2.6V3H16z" />
      </svg>
    ),
  },
  {
    label: "YouTube",
    href: "https://www.youtube.com/@HoPetSit",
    icon: (
      <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
        <path d="M21.6 7.2a2.5 2.5 0 0 0-1.8-1.8C18.2 5 12 5 12 5s-6.2 0-7.8.4A2.5 2.5 0 0 0 2.4 7.2 26 26 0 0 0 2 12a26 26 0 0 0 .4 4.8 2.5 2.5 0 0 0 1.8 1.8C5.8 19 12 19 12 19s6.2 0 7.8-.4a2.5 2.5 0 0 0 1.8-1.8A26 26 0 0 0 22 12a26 26 0 0 0-.4-4.8zM10 15V9l5 3-5 3z" />
      </svg>
    ),
  },
  {
    label: "Facebook",
    href: "https://www.facebook.com/people/Hopetsit/61590596619482/",
    icon: (
      <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
        <path d="M14 9h3V6h-3c-2.2 0-4 1.8-4 4v2H7v3h3v6h3v-6h2.5l.5-3H13v-2c0-.6.4-1 1-1z" />
      </svg>
    ),
  },
];

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
        { href: "/delete-account", label: t("footer_delete_account") },
        { href: "/refund",   label: t("footer_refund") },
        { href: "/imprint",  label: t("footer_imprint") },
      ],
    },
    // v532 — SEO : maillage interne vers le blog et les pages villes
    // (libellés volontairement statiques : chaque page est monolingue).
    {
      title: "Guides",
      links: [
        { href: "/blog", label: "Blog" },
        { href: "/petsitter/paris",  label: "Pet sitter à Paris" },
        { href: "/petsitter/madrid", label: "Cuidador en Madrid" },
        { href: "/petsitter/dallas", label: "Pet sitter in Dallas" },
      ],
    },
  ];

  return (
    <footer className="border-t border-ink/5 bg-bg-soft">
      <div className="mx-auto max-w-6xl px-4 py-12">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-6">
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
            {/* v23.1.452 — Daniel : CTA PawMap (fonctionnalité phare) dans le
                footer, présent sur chaque page. */}
            <div className="mt-5">
              <PawMapCTA size="compact" />
            </div>
            {/* v402 — réseaux sociaux HoPetSit (Daniel). */}
            <div className="mt-4 flex items-center gap-3">
              {SOCIALS.map((s) => (
                <a
                  key={s.label}
                  href={s.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label={s.label}
                  title={s.label}
                  className="flex h-9 w-9 items-center justify-center rounded-full bg-white text-ink-muted shadow-sm ring-1 ring-ink/5 transition hover:text-ink hover:shadow"
                >
                  {s.icon}
                </a>
              ))}
            </div>
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
