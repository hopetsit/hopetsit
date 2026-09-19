"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";
import { useAuth } from "@/lib/useAuth";
import { PawMapLogo } from "./PawMapLogo";

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

  // v567 — le glyphe devient le nouveau logo PawMap (patte-pin). Quelques
  // pixels de plus que l'ancien trait blanc (18/22) pour qu'il reste lisible.
  const glyphSize = size === "compact" ? 22 : 26;

  return (
    <Link
      href={href}
      aria-label={t("cta_open_pawmap")}
      className={
        "inline-flex items-center justify-center whitespace-nowrap rounded-full " +
        "bg-[#D83C28] font-bold text-white shadow-lg transition " +
        "hover:bg-[#B92425] hover:-translate-y-0.5 hover:shadow-xl " +
        sizeCls +
        (className ? " " + className : "")
      }
    >
      {/* Logo PawMap (patte-pin) — le bord blanc le détache de l'orange. */}
      <PawMapLogo size={glyphSize} title={null} className="shrink-0" />
      <span>{t("cta_open_pawmap")}</span>
      <span aria-hidden="true">→</span>
    </Link>
  );
}

export default PawMapCTA;
