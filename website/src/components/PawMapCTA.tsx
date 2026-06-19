"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";

/**
 * v23.1.452 — Daniel : "la PawMap est LA fonctionnalité phare du site".
 *
 * CTA orange premium réutilisable, 30-40% plus grand que les CTA normaux du
 * site (≈ px-4 py-2 text-sm) pour qu'il ressorte partout. Orange spécifique
 * PawMap demandé par Daniel : #FF6A00 (hover #E85F00).
 *
 *   - size="hero"     → grand format (hero des pages)
 *   - size="compact"  → format réduit (Header / Footer)
 *
 * Comportement : si l'utilisateur est connecté côté web il va directement sur
 * la carte interactive `/map` ; sinon on l'envoie sur `/login?redirect=%2Fmap`
 * (la page de connexion le renverra sur la carte après login, cf login/page).
 */
export function PawMapCTA({
  size = "hero",
  className = "",
}: {
  size?: "hero" | "compact";
  className?: string;
}) {
  const { t } = useT();
  const { user, ready } = useAuth();

  const href = ready && user ? "/map" : "/login?redirect=%2Fmap";

  const sizeCls =
    size === "compact"
      ? "px-5 py-2.5 text-sm gap-1.5"
      : "px-8 py-4 text-base md:text-lg gap-2";

  const glyphSize = size === "compact" ? 18 : 22;

  return (
    <Link
      href={href}
      aria-label={t("cta_open_pawmap")}
      className={
        "inline-flex items-center justify-center whitespace-nowrap rounded-full " +
        "bg-[#FF6A00] font-bold text-white shadow-lg transition " +
        "hover:bg-[#E85F00] hover:-translate-y-0.5 hover:shadow-xl " +
        sizeCls +
        (className ? " " + className : "")
      }
    >
      {/* Glyphe carte + patte (blanc) — lisible sur l'orange. */}
      <svg
        width={glyphSize}
        height={glyphSize}
        viewBox="0 0 24 24"
        fill="none"
        aria-hidden="true"
        className="shrink-0"
      >
        {/* carte pliée */}
        <path
          d="M9 4 3 6.2v13.6L9 17.6l6 2.2 6-2.2V4l-6 2.2L9 4Z"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinejoin="round"
          fill="rgba(255,255,255,0.18)"
        />
        {/* empreinte de patte */}
        <circle cx="12" cy="12.4" r="1.7" fill="currentColor" />
        <circle cx="9.6" cy="10.4" r="0.85" fill="currentColor" />
        <circle cx="14.4" cy="10.4" r="0.85" fill="currentColor" />
        <circle cx="11" cy="9.4" r="0.8" fill="currentColor" />
        <circle cx="13" cy="9.4" r="0.8" fill="currentColor" />
      </svg>
      <span>{t("cta_open_pawmap")}</span>
      <span aria-hidden="true">→</span>
    </Link>
  );
}

export default PawMapCTA;
