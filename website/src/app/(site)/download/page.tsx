"use client";

import { useEffect, useState } from "react";
import StoreBadges from "@/components/StoreBadges";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { CitySupplyProof } from "@/components/CitySupplyProof";
import OwnerPageEngagement from "@/components/OwnerPageEngagement";
import { currentCampaign } from "@/components/SiteAnalytics";
import { useT } from "@/lib/i18n/LanguageProvider";
import { screensPreviewFor, PhoneFrame } from "@/lib/screens";

// v508 — badges stores réels. v562 — mise en page minimaliste (Daniel) :
// titre XXL centré, badges, puis 4 captures réelles de la v561 dans des
// cadres sobres sur fond gris clair.
//
// 19/10/2026 (SAM) — /download est la page d'arrivée des pubs Android
// « app » (Meta refuse un lien Google Play direct). Mesure 18-19/10 :
// 36 visiteurs venus de nyc_app / paris_app → 0 clic store, contre 13 %
// pour les visiteurs directs. La pub promet « des gardiens près de chez
// vous à New York / Paris » ; la page disait seulement « Téléchargez
// HoPetSit ». Pour ces deux campagnes, le titre reprend la promesse de la
// pub (mêmes mots, aucune promesse nouvelle) et les vrais gardiens de la
// ville s'affichent SOUS les boutons (CitySupplyProof : rien si personne
// ou si le serveur ne répond pas). Hors pub : page inchangée. Le choix se
// fait après l'affichage (useEffect) : même HTML serveur, pas d'écart
// d'hydratation. Tout hook avant le return.
//
// 20/10/2026 (SAM) — 60 arrivées pub Android → 0 clic store. Pour savoir si
// ces visiteurs repartent aussitôt (problème de clic/pub) ou lisent la page
// sans toucher les boutons (problème de page), les repères invisibles
// « lecture_3s / lecture_15s / lecture_moitie » des pages propriétaires sont
// posés ici, pour les visiteurs de ces 2 campagnes seulement (admin › Trafic
// du site › par publicité : stay3s / stay15s). Rien ne change à l'affichage.
// 27/11 — mêmes adresses que components/StoreBadges.tsx.
const PLAY_URL_2711 = "https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit";
const APP_STORE_URL_2711 = "https://apps.apple.com/app/hopetsit/id6763645719";
type Promesse = { city: string; lang: string; title: string; sub: string };
const PROMESSES: Record<string, Promesse> = {
  nyc_app: {
    city: "New York",
    lang: "en",
    title: "Pet sitters near you in New York — in the app",
    sub: "Free app: post your request in 1 minute, local sitters reply, payment secured in the app.",
  },
  paris_app: {
    city: "Paris",
    lang: "fr",
    title: "Des gardiens près de chez toi à Paris — dans l'app",
    sub: "App gratuite : publie ta demande en 1 minute, les gardiens près de chez toi répondent, paiement sécurisé dans l'app.",
  },
};

export default function DownloadPage() {
  const { t, lang } = useT();
  const [promesse, setPromesse] = useState<Promesse | null>(null);
  useEffect(() => {
    setPromesse(PROMESSES[currentCampaign()] ?? null);
    // 27/11/2026 (BOB, ordre de Daniel : « je veux que les propriétaires passent par l'app ») — le propriétaire qui vient de
    // publier sa demande (bouton « Télécharger l'app » de /posts/confirmer, utm_campaign=app) est envoyé DROIT sur son store :
    // un tap de moins. Une seule fois par session (le retour arrière depuis le store réaffiche la page, sans boucle).
    // Ordinateur, tablette inconnue ou autre campagne : page inchangée.
    try {
      // (ZOE, contrôle du lot) — lu dans l'ADRESSE, pas par currentCampaign() : celle-ci garde la campagne de la PREMIÈRE page
      // de l'onglet (ici /posts/confirmer, d'où l'on arrive sans rechargement) et ne vaudrait donc jamais « app ».
      if (new URLSearchParams(window.location.search).get("utm_campaign") !== "app") return;
      if (window.sessionStorage.getItem("dl_auto_store_2711")) return;
      const ua = window.navigator.userAgent || "";
      const store = /iPhone|iPod/i.test(ua) ? APP_STORE_URL_2711 : /Android/i.test(ua) ? PLAY_URL_2711 : "";
      if (!store) return;
      window.sessionStorage.setItem("dl_auto_store_2711", "1");
      // store renseigné : sans lui le serveur range le clic sous « other » (le label n'est gardé que pour cta_click).
      trackSiteEvent("store_click", { store: store === APP_STORE_URL_2711 ? "ios" : "android", label: "dl_auto_store" });
      window.location.href = store;
    } catch { /* stockage ou navigation refusés : la page s'affiche comme avant */ }
  }, []);

  return (
    <div className="bg-white">
      <div className="mx-auto max-w-3xl px-4 pb-10 pt-20 text-center md:pt-28">
        <h1
          className={`font-display font-bold leading-[1.05] tracking-[-0.03em] text-[#231715] ${
            promesse ? "text-[2.1rem] md:text-5xl" : "text-[2.75rem] md:text-6xl"
          }`}
        >
          {promesse ? promesse.title : t("dl_title")}
        </h1>
        <p className="mx-auto mt-5 max-w-xl text-lg text-[#6E4F48]">{promesse ? promesse.sub : t("dl_sub")}</p>
        <div className="mt-10 flex justify-center">
          <StoreBadges center />
        </div>
        {/* 27/11 (BOB, ordre de Daniel) — la ligne « Tu es propriétaire ? Publie ta demande ici, sans app » (31/10) est retirée :
            sur cette page, on envoie vers l'app, plus vers le site. */}
        {promesse ? (
          <div className="mx-auto mt-8 max-w-xl text-left">
            <CitySupplyProof city={promesse.city} lang={promesse.lang} />
          </div>
        ) : null}
      </div>

      {promesse ? <OwnerPageEngagement /> : null}

      <div className="bg-[#FAF1EC] py-16">
        <div className="mx-auto flex max-w-5xl snap-x snap-mandatory gap-6 overflow-x-auto px-4 pb-4 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          {screensPreviewFor(lang).map((s) => (
            <PhoneFrame key={s.src} src={s.src} w={s.w} h={s.h} alt={`HoPetSit — ${s.alt}`} className="w-48 shrink-0 snap-center first:ml-auto last:mr-auto" />
          ))}
        </div>
      </div>
    </div>
  );
}
