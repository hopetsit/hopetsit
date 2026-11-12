import type { Metadata } from "next";
import DemandeFlow0811 from "@/components/DemandeFlow0811";
import OwnerPageEngagement from "@/components/OwnerPageEngagement";
import { dm } from "@/lib/i18n/demande0811";

// 08/11/2026 (NEO, ordre de Daniel 16 h 45 transmis par BOB) — PAGE D'ARRIVÉE DE LA PUB META « Paris · propriétaires »
// (la pub envoie désormais sur le SITE, plus sur le formulaire Meta). Le propriétaire publie ET vérifie son e-mail d'un
// coup : formulaire 1 étape → code reçu par e-mail tapé ici → demande publiée, session ouverte, app proposée.
// URL pour SAM : https://www.hopetsit.com/demande?city=paris&utm_source=meta&utm_medium=paid&utm_campaign=paris_owners
// Page de pub, pas une page Google (règle du 20/09 : ne plus multiplier les pages indexées) → noindex.
const TITLE = "Publier ma demande de garde à Paris";
const DESCRIPTION = "Des gardiens près de chez toi te répondent avec leur prix. Publie ta demande en 1 minute, sans mot de passe.";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  robots: { index: false, follow: true },
  alternates: { canonical: "https://www.hopetsit.com/demande" },
  openGraph: { title: TITLE, description: DESCRIPTION, url: "https://www.hopetsit.com/demande", type: "website", siteName: "HoPetSit", images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }] },
};

export default function DemandePage() {
  return (
    <main className="min-h-[80vh] bg-[#FFF7F3] px-4 pb-14 pt-6 md:pt-10">
      <div className="mx-auto max-w-3xl">
        <h1 className="text-center font-display text-[26px] font-extrabold leading-tight text-ink md:text-4xl">
          {dm("fr", "title", { city: "Paris" })}
        </h1>
        <DemandeFlow0811 lang="fr" defaultCity="paris" />
        {/* 12/11 SAM : lecture_3s / lecture_15s / lecture_moitie — rien d'affiché, sépare « repart aussitôt » de « lit sans agir » */}
        <OwnerPageEngagement />
      </div>
    </main>
  );
}
