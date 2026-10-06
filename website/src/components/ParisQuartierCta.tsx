"use client";

import { useState } from "react";
import Link from "next/link";
import { trackSiteEvent, useCampaignHref } from "@/components/SiteAnalytics";

// 06/10/2026 (SAM) — page Paris (cible de la pub) : « Vous habitez où ? » AVANT
// « Publier ma demande ».
// Mesure du 06/10 (admin « Trafic du site », 7 j, visiteurs venus de la pub) :
// 148 restent 3 s → 1 seul visiteur clique « Publier » (barre collée, 5 clics),
// mais 26 cliquent un ARRONDISSEMENT dans le bloc « Votre arrondissement » en
// bas de page, et ils y lisent la même page. Le visiteur veut d'abord « près de
// chez moi ». On lui pose donc cette question-là en premier écran, et le bouton
// plein ouvre le formulaire avec son quartier déjà rempli (?city=Paris 11e — le
// serveur le ramène à « Paris » pour le géocodage, baseCityName).
// Mesure : « quartier_choisi » (choix fait) et « signup_web_quartier » (bouton,
// compté « publier » dans l'onglet par pub puisqu'il commence par « signup »).
// Retour arrière : retirer la prop heroCta de garde-animaux/paris/page.tsx.
export function ParisQuartierCta({ places, city, note }: { places: string[]; city: string; note: string }) {
  const [choix, setChoix] = useState("");
  const href = useCampaignHref(`/posts/create?city=${encodeURIComponent(choix || city)}`);
  return (
    <div className="mt-5 rounded-3xl bg-owner-light p-4 md:mx-auto md:max-w-md">
      <label htmlFor="quartier" className="block text-[15px] font-bold text-ink">
        Vous habitez où ?
      </label>
      <select
        id="quartier"
        value={choix}
        onChange={(e) => {
          setChoix(e.target.value);
          if (e.target.value) trackSiteEvent("cta_click", { label: "quartier_choisi" });
        }}
        className="mt-2 block w-full rounded-2xl border-2 border-owner/40 bg-white px-4 py-3 text-base font-semibold text-ink"
      >
        <option value="">Mon arrondissement ou ma ville</option>
        {places.map((p) => (
          <option key={p} value={p}>{p}</option>
        ))}
      </select>
      <Link
        href={href}
        onClick={() => trackSiteEvent("cta_click", { label: "signup_web_quartier" })}
        className="mt-3 block w-full rounded-full bg-owner px-6 py-3.5 text-center text-base font-bold text-white shadow-card"
      >
        {choix ? `Trouver un gardien à ${choix}` : "Publier ma demande gratuite"}
      </Link>
      <p className="mt-2 text-center text-xs text-ink-soft">{note}</p>
    </div>
  );
}

export default ParisQuartierCta;
