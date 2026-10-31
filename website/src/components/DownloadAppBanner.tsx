"use client";

import Link from "@/components/SiteLink";
import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { useT } from "@/lib/i18n/LanguageProvider";
import { AppIcon } from "@/components/AppIcon";

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
const DL_KEY = "hps_dl_bandeau_ferme_3110";
// Pages où l'on ne propose pas l'app : tout s'y fait sur le web.
const NO_APP_PATH = /^\/(posts|application|pay|signup|login|verify-email|p|ad-leads|download)(\/|$)/;

export function DownloadAppBanner() {
  const { t } = useT();
  const [shown, setShown] = useState(false);
  // 26/10 (LEO — retour de FLO) : sur la page des candidats et du paiement, le bouton flottant
  // recouvrait les cartes et « Choisir » ; on n'y propose pas l'app (on y paie sur le web).
  const pathname = usePathname() || "";
  const noFloat = /^\/(posts|application|pay)(\/|$)/.test(pathname);

  // Bande bureau : décidée après le montage (mémoire du navigateur + présence du formulaire dans la page).
  const [showBar, setShowBar] = useState(false);
  useEffect(() => {
    let closed = false;
    try {
      const at = Number(window.localStorage.getItem(DL_KEY) || 0);
      closed = at > 0 && Date.now() - at < 30 * 24 * 3600 * 1000;
    } catch { /* stockage bloqué : on affiche */ }
    const noApp = NO_APP_PATH.test(pathname);
    // Le formulaire 1 étape (accueil fr/en, Paris, New York, villes, « Réserver <prénom> ») : le parcours se fait sur le site.
    const hasForm = () => !!document.querySelector("[data-hero-form-3110],[data-hero-done-3110],[data-hero-pending-3110]");
    setShowBar(!closed && !noApp && !hasForm());
    // Le formulaire peut arriver un peu après (chargement de la page) : on revérifie une fois.
    const id = window.setTimeout(() => { if (hasForm()) setShowBar(false); }, 600);
    return () => window.clearTimeout(id);
  }, [pathname]);
  function dismiss() {
    setShowBar(false);
    try { window.localStorage.setItem(DL_KEY, String(Date.now())); } catch { /* sans mémoire : fermé pour cette page */ }
  }

  useEffect(() => {
    const onScroll = () => setShown(window.scrollY > 420);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <>
      {/* Bureau : 31/10 soir (LEO, passe 14 — Daniel : « plus joli, qu'on comprenne bien »). L'ancienne barre noire avec un
          bouton orange plein concurrençait « Publier ma demande ». Maintenant : fine bande crème (36 px), texte au « tu »,
          simple lien, fermable (mémorisé 30 jours dans ce navigateur), et absente des pages où tout se fait sans l'app
          (candidats, paiement, demandes, inscription/connexion, et toute page qui porte le formulaire 1 étape). */}
      {showBar && (
        <div className="hidden w-full border-b border-[#F6D9CC] bg-[#FFF3EC] md:block" data-dl-bandeau-3110="">
          <div className="relative mx-auto flex h-9 max-w-7xl items-center justify-center gap-3 px-12 text-[13px]">
            <span className="inline-flex items-center gap-2 whitespace-nowrap font-semibold text-ink">
              <AppIcon name="download" size={15} color="#9E1F0B" /> {t("dl_banner_title")}
            </span>
            <span aria-hidden="true" className="text-[#C9A79C]">·</span>
            <Link href="/download" className="whitespace-nowrap font-bold text-owner-dark underline-offset-4 hover:underline">
              {t("nav_download")} →
            </Link>
            <button
              type="button"
              onClick={dismiss}
              aria-label={t("common_close") || "Close"}
              className="absolute right-3 top-1/2 flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded-full text-[#6E4F48] transition hover:bg-[#FBE3D8] hover:text-ink"
            >
              <svg width="12" height="12" viewBox="0 0 12 12" aria-hidden="true"><path d="M2 2l8 8M10 2l-8 8" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>
            </button>
          </div>
        </div>
      )}

      {/* Mobile : bouton flottant en bas à droite, après le héro (jamais sur les candidats / le paiement). */}
      {!noFloat && <Link
        href="/download"
        aria-hidden={!shown}
        tabIndex={shown ? 0 : -1}
        className={
          "fixed bottom-4 right-4 z-30 inline-flex min-h-[44px] items-center gap-1.5 rounded-full bg-owner px-4 py-2.5 text-sm font-semibold text-white shadow-cta transition-all duration-300 md:hidden " +
          (shown ? "translate-y-0 opacity-100" : "pointer-events-none translate-y-6 opacity-0")
        }
      >
        <AppIcon name="download" size={16} color="#fff" /> {t("dl_float")}
      </Link>}
    </>
  );
}

export default DownloadAppBanner;
