"use client";

import { useEffect, useState } from "react";
import StoreBadges from "@/components/StoreBadges";
import { CitySupplyProof } from "@/components/CitySupplyProof";
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
    title: "Des gardiens près de chez vous à Paris — dans l'app",
    sub: "App gratuite : publiez votre demande en 1 minute, les gardiens près de chez vous répondent, paiement sécurisé dans l'app.",
  },
};

export default function DownloadPage() {
  const { t, lang } = useT();
  const [promesse, setPromesse] = useState<Promesse | null>(null);
  useEffect(() => {
    setPromesse(PROMESSES[currentCampaign()] ?? null);
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
        {promesse ? (
          <div className="mx-auto mt-8 max-w-xl text-left">
            <CitySupplyProof city={promesse.city} lang={promesse.lang} />
          </div>
        ) : null}
      </div>

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
