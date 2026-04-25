"use client";

import Link from "next/link";
import { useState } from "react";
import { LogoWithText } from "./Logo";
import { LangSwitcher } from "./LangSwitcher";
import { useT } from "@/lib/i18n/LanguageProvider";

export function Header() {
  const { t } = useT();
  const [open, setOpen] = useState(false);

  const links = [
    { href: "/how-it-works", label: t("nav_how") },
    { href: "/pricing",      label: t("nav_pricing") },
    { href: "/pawmap",       label: t("nav_pawmap") },
    { href: "/faq",          label: t("nav_faq") },
    { href: "/contact",      label: t("nav_contact") },
  ];

  return (
    <header className="sticky top-0 z-40 border-b border-ink/5 bg-white/85 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4">
        <Link href="/" className="flex items-center" aria-label="HoPetSit">
          <LogoWithText />
        </Link>

        <nav className="hidden items-center gap-6 md:flex">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className="text-sm font-medium text-ink-muted hover:text-ink"
            >
              {l.label}
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <LangSwitcher />
          <Link
            href="/login"
            className="hidden rounded-full px-3 py-1.5 text-sm font-medium text-ink hover:bg-bg-soft md:inline-block"
          >
            {t("nav_login")}
          </Link>
          <Link
            href="/signup"
            className="rounded-full bg-owner px-4 py-1.5 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark"
          >
            {t("nav_signup")}
          </Link>
          <button
            type="button"
            className="ml-1 rounded-md p-1.5 md:hidden"
            aria-label="Toggle menu"
            onClick={() => setOpen((v) => !v)}
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              {open
                ? <path d="M6 6l12 12M6 18L18 6" />
                : <><path d="M4 6h16" /><path d="M4 12h16" /><path d="M4 18h16" /></>}
            </svg>
          </button>
        </div>
      </div>

      {open && (
        <nav className="border-t border-ink/5 bg-white px-4 py-2 md:hidden">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              onClick={() => setOpen(false)}
              className="block px-2 py-2.5 text-sm font-medium text-ink"
            >
              {l.label}
            </Link>
          ))}
          <Link
            href="/login"
            onClick={() => setOpen(false)}
            className="block px-2 py-2.5 text-sm font-medium text-ink"
          >
            {t("nav_login")}
          </Link>
        </nav>
      )}
    </header>
  );
}
