"use client";
// 29/09/2026 (SAM) — LE VISITEUR REGARDE-T-IL LA PAGE ?
//
// Mesure du 28/09 : ~44 visiteurs de la pub Paris sont arrivés sur
// /garde-animaux/paris, aucun n'a touché un bouton ni une carte. Impossible de
// savoir s'ils sont repartis aussitôt (clic par erreur → problème de pub) ou
// s'ils ont lu sans être convaincus (problème de page). Ce composant ne change
// RIEN à l'affichage : il envoie au plus trois repères par visite, par la même
// mesure maison sans cookie que les boutons (SiteAnalytics) :
//   lecture_3s     — la page est restée à l'écran 3 secondes
//   lecture_15s    — 15 secondes (onglet visible seulement)
//   lecture_moitie — le visiteur a défilé jusqu'à la moitié de la page
// Libellés préfixés « lecture_ » : à retirer du compte des clics dans l'admin.
//
// Règle du dépôt : tous les hooks AVANT tout retour conditionnel.
import { useEffect } from "react";
import { usePathname } from "next/navigation";
import { trackSiteEvent } from "@/components/SiteAnalytics";

const PALIERS = [3, 15];

export default function OwnerPageEngagement() {
  const pathname = usePathname() || "/";

  useEffect(() => {
    const envoye = new Set<string>();
    const send = (label: string) => {
      if (envoye.has(label)) return;
      envoye.add(label);
      trackSiteEvent("cta_click", { label });
    };

    // Temps passé onglet visible (un onglet en arrière-plan ne compte pas).
    let visibleSec = 0;
    const tick = window.setInterval(() => {
      if (document.visibilityState !== "visible") return;
      visibleSec += 1;
      for (const s of PALIERS) if (visibleSec >= s) send(`lecture_${s}s`);
      if (visibleSec >= PALIERS[PALIERS.length - 1]) window.clearInterval(tick);
    }, 1000);

    const onScroll = () => {
      const h = document.documentElement.scrollHeight;
      if (h > 0 && (window.scrollY + window.innerHeight) / h >= 0.5) {
        send("lecture_moitie");
        window.removeEventListener("scroll", onScroll);
      }
    };
    window.addEventListener("scroll", onScroll, { passive: true });

    return () => {
      window.clearInterval(tick);
      window.removeEventListener("scroll", onScroll);
    };
  }, [pathname]);

  return null;
}
