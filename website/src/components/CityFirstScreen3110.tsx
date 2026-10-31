"use client";

// 31/10/2026 (LEO, étape 3 — décision 3 de BOB, règle de Daniel du 07/10 « Paris 100 % propriétaires,
// autres villes gardiens jusqu'à ~10 actifs ») — PREMIER ÉCRAN des pages villes fr/en (hors Paris et
// New York, qui ont leur formulaire fixe) décidé PAR LES DONNÉES, jamais en dur par ville :
//   · ≥ 3 gardiens/promeneurs réels AVEC PHOTO autour de la ville (route publique /supply/city/faces :
//     exclut comptes de test, masqués, bannis ; « Paris 11e » compte comme « Paris »)
//       → le formulaire 1 étape (ParisHeroForm, même parcours que Paris/NY) ;
//   · sinon → « Devenir gardien » en premier (page de recrutement de la ville), avec un petit lien
//     « Publier ma demande quand même » vers le formulaire de l'accueil (ville à saisir).
// ⚠️ La route faces ne connaît pas les prix : le seuil porte sur « réel + photo », pas « + prix »
// (dit dans le rapport). Pendant le chargement : un cadre de la même hauteur (pas de saut de page).
// Hooks en tête, aucun retour conditionnel avant.

import { useEffect, useState } from "react";
import Link from "@/components/SiteLink";
import { ParisHeroForm } from "@/components/ParisHeroForm";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { API_BASE } from "@/lib/api";
import { OWNER_PATH_PREFIX, RECRUIT_PATH_PREFIX, type RecruitCity } from "@/lib/recruit-cities";

export const CITY_FORM_MIN_SITTERS = 3;

const TXT = {
  fr: {
    lead: (c: string) => `Des gardiens vérifiés près de chez toi à ${c} te répondent avec leur prix. Sans compte, tout de suite.`,
    note: "Gratuit · sans compte · tu choisis et tu paies ensuite, annulation gratuite jusqu'à 72 h avant",
    few_title: (c: string) => `Il manque encore des gardiens actifs à ${c} : sois parmi les premiers.`,
    few_body: "Tu gardes des animaux près de chez toi ? Inscris-toi, fixe tes tarifs, et reçois les demandes du quartier en premier.",
    few_cta: "Devenir gardien",
    few_owner: "Tu cherches un gardien ? Publie ta demande quand même →",
  },
  en: {
    lead: (c: string) => `Trusted pet sitters near you in ${c} reply with their price. No account, posted right away.`,
    note: "Free · no account · you choose and pay later, free cancellation up to 72 h before",
    few_title: (c: string) => `${c} still needs active sitters: be one of the first.`,
    few_body: "You look after pets near you? Sign up, set your rates, and get the neighbourhood's requests first.",
    few_cta: "Become a sitter",
    few_owner: "Looking for a sitter? Post your request anyway →",
  },
};

export function baseCity3110(name: string): string {
  return name.replace(/\s+\d+\s*(er|e|ème|eme|th|st|nd|rd)?$/i, "").trim() || name;
}

export function CityFirstScreen3110({ city }: { city: RecruitCity }) {
  const lang: "fr" | "en" = city.lang === "en" ? "en" : "fr";
  const [faces, setFaces] = useState<number | null>(null);
  useEffect(() => {
    const ctrl = new AbortController();
    const base = baseCity3110(city.name);
    fetch(`${API_BASE}/supply/city/faces?${new URLSearchParams({ city: base, limit: "6" })}`, { signal: ctrl.signal })
      .then((r) => (r.ok ? r.json() : null))
      .then((j) => { if (!ctrl.signal.aborted) setFaces(Array.isArray(j?.faces) ? j.faces.length : 0); })
      .catch(() => { if (!ctrl.signal.aborted) setFaces(0); });
    return () => ctrl.abort();
  }, [city.name]);
  useEffect(() => {
    if (faces == null) return;
    trackSiteEvent("cta_click", { label: faces >= CITY_FORM_MIN_SITTERS ? "ville_ecran_formulaire" : "ville_ecran_gardien" });
  }, [faces]);

  const t = TXT[lang];
  if (faces == null) {
    return <div className="mt-3 min-h-[120px] rounded-3xl border border-owner/20 bg-owner-light/60" aria-busy="true" data-city-first-3110="loading" />;
  }
  if (faces >= CITY_FORM_MIN_SITTERS) {
    return (
      <div data-city-first-3110="form" data-city-faces={faces}>
        <ParisHeroForm
          city={baseCity3110(city.name)}
          lang={lang}
          country={lang === "fr" ? "FR" : "US"}
          campaign={`city_${lang}`}
          page={`${OWNER_PATH_PREFIX[city.lang]}/${city.slug}`}
          lead={t.lead(city.name)}
          note={t.note}
        />
      </div>
    );
  }
  return (
    <div className="mt-3 rounded-3xl border border-sitter/25 p-4 md:mx-auto md:max-w-md" style={{ background: "#E3EFFE" }} data-city-first-3110="recruit" data-city-faces={faces}>
      <p className="text-[17px] font-extrabold leading-snug" style={{ color: "#1E4FB0" }}>{t.few_title(city.name)}</p>
      <p className="mt-1.5 text-[14px] leading-snug text-ink">{t.few_body}</p>
      <Link
        href={`${RECRUIT_PATH_PREFIX[city.lang]}/${city.slug}`}
        id="hero-publier"
        className="mt-3 block w-full rounded-full px-6 py-4 text-center text-lg font-extrabold text-white shadow-card"
        style={{ background: "linear-gradient(135deg,#2F6FD6,#1E4FB0)" }}
        onClick={() => trackSiteEvent("cta_click", { label: "ville_devenir_gardien" })}
      >
        {t.few_cta}
      </Link>
      <Link href="/#publier" className="mt-3 block text-center text-[13px] font-bold underline-offset-2 hover:underline" style={{ color: "#9E1F0B" }} onClick={() => trackSiteEvent("cta_click", { label: "ville_publier_quand_meme" })}>
        {t.few_owner}
      </Link>
    </div>
  );
}

export default CityFirstScreen3110;
