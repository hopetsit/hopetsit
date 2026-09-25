"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";
import { LogoWithText } from "./Logo";
import { LangSwitcher } from "./LangSwitcher";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";
import { clearAuth } from "@/lib/api";

export function Header() {
  const { t } = useT();
  const router = useRouter();
  const pathname = usePathname();
  const { user, ready } = useAuth();
  const [open, setOpen] = useState(false);

  const links = [
    { href: "/how-it-works", label: t("nav_how") },
    { href: "/pricing",      label: t("nav_pricing") },
    // 25/09 (PawMap 584, point 11) — connecté, « PawMap » = MA PawMap (/map :
    // mes amis, les membres autour de moi, mes demandes, mon rond « Moi »).
    // Sans compte : la carte publique floutée (/pawmap).
    { href: ready && user ? "/map" : "/pawmap", label: t("nav_pawmap"), also: ["/pawmap", "/map"] },
    { href: "/faq",          label: t("nav_faq") },
    { href: "/contact",      label: t("nav_contact") },
  ];

  function onLogout() {
    clearAuth();
    setOpen(false);
    router.push("/");
  }

  // Avatar fallback: first letter of the name (or "?" if missing).
  const initial = user?.name?.trim()?.charAt(0)?.toUpperCase() || "?";
  // Tailwind class names that match the safelist in tailwind.config.ts so the
  // role color survives the production purge.
  const roleColor =
    user?.role === "walker" ? "bg-walker"
    : user?.role === "sitter" ? "bg-sitter"
    : "bg-owner";

  return (
    <header className="sticky top-0 z-40 border-b border-black/[0.06] bg-white/80 backdrop-blur-xl">
      {/* v577 — TABLETTE (21/09/2026). Le menu du haut passait en version
          « bureau » des 768 px : a cette largeur exacte, « Comment ca marche »
          et « Se connecter » n'avaient plus la place, se cassaient en trois
          lignes et DEBORDAIENT de la barre (hauteur fixe h-14), par-dessus le
          logo. Mesure : nav 359 px + logo 103 px + boutons 274 px = 736 px pour
          736 px utiles. La version compacte (logo + langue + S'inscrire +
          menu) court donc maintenant jusqu'a 1024 px. */}
      <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4">
        <Link href="/" className="flex min-h-[44px] items-center" aria-label="HoPetSit">
          <LogoWithText />
        </Link>

        <nav className="hidden items-center gap-1 lg:flex">
          {/* v562 — Daniel : page courante en orange pâle (pas de gris foncé). */}
          {links.map((l) => {
            const current = pathname === l.href || pathname?.startsWith(l.href + "/") || !!("also" in l && l.also?.includes(pathname || ""));
            return (
              <Link
                key={l.href}
                href={l.href}
                aria-current={current ? "page" : undefined}
                className={`whitespace-nowrap rounded-full px-3 py-1.5 text-[13px] font-medium transition ${
                  current ? "bg-owner-light text-owner-dark" : "text-[#231715]/70 hover:bg-[#FAF1EC] hover:text-[#231715]"
                }`}
              >
                {l.label}
              </Link>
            );
          })}
        </nav>

        <div className="flex items-center gap-2">
          {/* v458 — Daniel : retirer le bouton « Ouvrir la PawMap » de la
              barre du haut pour l'instant (il reste dans le footer + les pages). */}
          <LangSwitcher />

          {/* Until we've read localStorage, render a placeholder of the same
              footprint to avoid CLS / a flash of "Login + Sign up" buttons
              for users who are actually authenticated. */}
          {!ready ? (
            <div aria-hidden="true" className="h-9 w-[150px]" />
          ) : user ? (
            <>
              {/* v402 — Daniel : bouton « Mon compte » plus visible. Pilule
                  pleine couleur du rôle + ombre, au lieu d'une fine bordure. */}
              <Link
                href="/dashboard"
                className={`hidden items-center gap-2 rounded-full ${roleColor} px-4 py-2 text-sm font-semibold text-white shadow-cta transition hover:opacity-90 lg:inline-flex`}
                title={user.email}
              >
                <span className="flex h-6 w-6 items-center justify-center rounded-full bg-white/25 text-xs font-bold text-white">
                  {initial}
                </span>
                <span className="max-w-[140px] truncate">
                  {user.name?.split(" ")[0] || t("nav_dashboard")}
                </span>
              </Link>
              <button
                type="button"
                onClick={onLogout}
                className="hidden rounded-full px-3 py-1.5 text-sm font-medium text-ink-muted hover:text-ink lg:inline-block"
              >
                {t("dash_logout")}
              </button>
            </>
          ) : (
            <>
              <Link
                href="/login"
                className="hidden rounded-full px-3 py-1.5 text-[13px] font-medium text-[#231715]/80 hover:text-[#231715] lg:inline-block"
              >
                {t("nav_login")}
              </Link>
              <Link
                href="/signup"
                /* v585 — pouce (Bob, 25/09) : la pastille mesurait 32 px de haut.
                   Zone de toucher portée à 44 px par un calque invisible,
                   pastille visuellement inchangée. */
                className="relative rounded-full bg-owner px-4 py-1.5 text-[13px] font-semibold text-white transition after:absolute after:inset-x-0 after:-inset-y-1.5 after:content-[''] hover:bg-owner-dark"
              >
                {t("nav_signup")}
              </Link>
            </>
          )}

          <button
            type="button"
            /* v583 — pouce (Bob, 22/09) : le bouton du menu mesurait
               34 x 34 px, sous le minimum de 44 px. C'est LA navigation sur
               telephone. Carre de 44 px, icone inchangee. lg:hidden : le
               bureau n'est pas concerne. */
            className="ml-1 flex h-11 w-11 items-center justify-center rounded-xl lg:hidden"
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
        <nav className="border-t border-ink/5 bg-white px-4 py-2 lg:hidden">
          {/* v458 — bouton « Ouvrir la PawMap » retiré du menu (barre du haut)
              pour l'instant. */}
          {links.map((l) => {
            const current = pathname === l.href || pathname?.startsWith(l.href + "/") || !!("also" in l && l.also?.includes(pathname || ""));
            return (
              <Link
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className={`block rounded-xl px-3 py-3 text-sm font-medium ${current ? "bg-owner-light text-owner-dark" : "text-ink"}`}
              >
                {l.label}
              </Link>
            );
          })}
          {ready && user ? (
            <>
              <Link
                href="/dashboard"
                onClick={() => setOpen(false)}
                className="flex min-h-[44px] items-center gap-2 px-2 py-2.5 text-sm font-medium text-ink"
              >
                <span
                  className={`flex h-6 w-6 items-center justify-center rounded-full ${roleColor} text-xs font-bold text-white`}
                >
                  {initial}
                </span>
                {user.name?.split(" ")[0] || t("nav_dashboard")}
              </Link>
              <button
                type="button"
                onClick={onLogout}
                className="block w-full px-2 py-3 text-left text-sm font-medium text-ink-muted"
              >
                {t("dash_logout")}
              </button>
            </>
          ) : (
            <Link
              href="/login"
              onClick={() => setOpen(false)}
              className="block px-2 py-3 text-sm font-medium text-ink"
            >
              {t("nav_login")}
            </Link>
          )}
        </nav>
      )}
    </header>
  );
}
