"use client";

import Link from "next/link";
import { useT } from "@/lib/i18n/LanguageProvider";

/**
 * v23.1.452 — Daniel : pousser fort le téléchargement de l'app, en priorité #2
 * derrière la Paw Map. Bannière de téléchargement présente sur TOUT le site
 * (rendue dans layout.tsx), non masquable (toujours visible).
 *
 *   - Desktop (md+) : barre fine pleine largeur, dans le flux du document (pas
 *     fixe) → elle ne recouvre jamais le contenu ni le Header sticky. Discrète
 *     pour ne pas concurrencer le CTA Paw Map (priorité #1).
 *   - Mobile (< md) : petit bouton flottant en bas à droite, toujours visible.
 */
export function DownloadAppBanner() {
  const { t } = useT();

  return (
    <>
      {/* Desktop : barre fine en flux, sous le Header. */}
      <div className="hidden w-full items-center justify-center gap-4 border-b border-ink/5 bg-ink px-4 py-2 text-white md:flex">
        <span className="text-sm font-medium">📱 {t("dl_banner_title")}</span>
        <Link
          href="/download"
          className="rounded-full bg-white/15 px-4 py-1.5 text-sm font-semibold text-white transition hover:bg-white/25"
        >
          {t("nav_download")}
        </Link>
      </div>

      {/* Mobile : bouton flottant en bas à droite. */}
      <Link
        href="/download"
        className="fixed bottom-4 right-4 z-30 inline-flex items-center gap-1.5 rounded-full bg-owner px-4 py-2.5 text-sm font-semibold text-white shadow-cta md:hidden"
      >
        📱 {t("dl_float")}
      </Link>
    </>
  );
}

export default DownloadAppBanner;
