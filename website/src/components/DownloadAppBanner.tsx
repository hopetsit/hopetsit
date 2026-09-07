"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";

/**
 * v23.1.452 — Daniel : pousser fort le téléchargement de l'app, en priorité #2
 * derrière la PawMap. Bannière de téléchargement présente sur TOUT le site
 * (rendue dans layout.tsx), non masquable (toujours visible).
 *
 *   - Desktop (md+) : barre fine pleine largeur, dans le flux du document (pas
 *     fixe) → elle ne recouvre jamais le contenu ni le Header sticky. Discrète
 *     pour ne pas concurrencer le CTA PawMap (priorité #1).
 *   - Mobile (< md) : petit bouton flottant en bas à droite.
 *     v556 — il chevauchait le titre du héro sur les petits écrans. Il
 *     n'apparaît plus qu'après avoir fait défiler le héro (≈ 420 px) : le
 *     visiteur a lu le titre, le rappel arrive ensuite, sans rien cacher.
 */
export function DownloadAppBanner() {
  const { t } = useT();
  const [shown, setShown] = useState(false);

  useEffect(() => {
    const onScroll = () => setShown(window.scrollY > 420);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

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

      {/* Mobile : bouton flottant en bas à droite, après le héro. */}
      <Link
        href="/download"
        aria-hidden={!shown}
        tabIndex={shown ? 0 : -1}
        className={
          "fixed bottom-4 right-4 z-30 inline-flex items-center gap-1.5 rounded-full bg-owner px-4 py-2.5 text-sm font-semibold text-white shadow-cta transition-all duration-300 md:hidden " +
          (shown ? "translate-y-0 opacity-100" : "pointer-events-none translate-y-6 opacity-0")
        }
      >
        📱 {t("dl_float")}
      </Link>
    </>
  );
}

export default DownloadAppBanner;
