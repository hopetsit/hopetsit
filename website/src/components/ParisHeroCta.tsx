"use client";

import Link from "next/link";
import { trackSiteEvent, useCampaignHref } from "@/components/SiteAnalytics";

// 08/10/2026 (SAM) — ordre de Daniel : « corrige-le en faisant tourner les pubs ».
// Mesure du 07/10 (admin « Trafic du site », visiteurs de la pub paris_owners) :
// 70 arrivées → 17 restent 3 s → 0 choix dans « Vous habitez où ? » → 0 clic
// « Publier ». Le menu déroulant demandait de choisir un quartier AVANT d'agir :
// personne ne le fait. Il est remplacé par UNE phrase + UN gros bouton qui ouvre
// directement le formulaire sans compte (/posts/create). Le premier champ du
// formulaire est la ville, pré-remplie « Paris » : le quartier se précise là.
// La preuve (nombre de gardiens + 3 profils réels avec leur prix) suit juste
// en dessous (CitySupplyProof), toujours dans le premier écran à 375 px.
// L'id « hero-publier » sert à la barre collée : elle reste cachée tant que ce
// bouton est à l'écran (un seul bouton visible à la fois).
// Mesure : « signup_web_hero » (compté « publier » dans l'onglet par pub).
// Retour arrière : remettre ParisQuartierCta dans garde-animaux/paris/page.tsx.
export function ParisHeroCta({ city, lead, label, note }: { city: string; lead: string; label: string; note: string }) {
  const href = useCampaignHref(`/posts/create?city=${encodeURIComponent(city)}`);
  return (
    <div className="mt-3 md:mx-auto md:max-w-md">
      <p className="text-[15px] font-semibold leading-snug text-ink md:text-center md:text-base">{lead}</p>
      <Link
        id="hero-publier"
        href={href}
        onClick={() => trackSiteEvent("cta_click", { label: "signup_web_hero" })}
        className="mt-3 block w-full rounded-full bg-owner px-6 py-4 text-center text-lg font-extrabold text-white shadow-card"
      >
        {label}
      </Link>
      <p className="mt-2 text-center text-xs text-ink-soft">{note}</p>
    </div>
  );
}

export default ParisHeroCta;
