"use client";

/**
 * 06/11/2026 (SAM, ordre de Daniel « oui fais tout ») — pixel Meta du site, APRÈS consentement.
 * Inséré une seule fois dans RootShell (à côté de SiteAnalytics). Ne rend que le bandeau.
 *   - au montage : si le visiteur a déjà dit « oui », le pixel se charge et envoie PageView ;
 *   - à chaque changement de page (usePathname) : PageView ;
 *   - quand il clique « Accepter » (événement CONSENT_EVENT) : chargement + PageView de la page courante.
 * Les autres événements (Lead, ViewContent, InitiateCheckout, Purchase) partent de trackSiteEvent
 * (SiteAnalytics.tsx → lib/metaPixel0611.ts), là où la mesure maison existe déjà.
 * Règle des hooks : tous avant tout return.
 */
import { useEffect } from "react";
import { usePathname } from "next/navigation";
import ConsentBanner from "@/components/ConsentBanner";
import { CONSENT_EVENT, pixelAllowed, pixelTrack } from "@/lib/metaPixel0611";

export default function MetaPixel() {
  const pathname = usePathname();

  useEffect(() => {
    if (pixelAllowed(pathname || "/")) pixelTrack("PageView");
  }, [pathname]);

  useEffect(() => {
    const onConsent = (e: Event) => {
      const v = (e as CustomEvent<string>).detail;
      if (v === "yes" && pixelAllowed(window.location.pathname)) pixelTrack("PageView");
    };
    window.addEventListener(CONSENT_EVENT, onConsent);
    return () => window.removeEventListener(CONSENT_EVENT, onConsent);
  }, []);

  return <ConsentBanner />;
}
