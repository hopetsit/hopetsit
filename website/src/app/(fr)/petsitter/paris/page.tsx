import type { Metadata } from "next";
import OwnerCityPage from "@/components/OwnerCityPage";
import { PARIS_CITY } from "@/lib/recruit-cities";

// 29/09/2026 (SAM, demande de Daniel : « toutes les pages Paris dans ce
// style »). Cette ancienne page (v531 : texte + bouton « Télécharger l'app »)
// affiche maintenant le même premier écran que /garde-animaux/paris : vrais
// gardiens avec prix, ligne verte, « Publier ma demande », maillage.
// Même contenu → canonique vers la page principale (une seule page Paris
// pour Google) ; l'adresse reste en vie pour les liens déjà partagés.
const CANONICAL = "https://www.hopetsit.com/garde-animaux/paris";
const TITLE = "Pet sitter à Paris — garde de chien & chat, promenades";
const DESCRIPTION =
  "Trouvez un pet sitter ou un promeneur de chien vérifié à Paris. Avis réels, paiement sécurisé et suivi GPS de chaque promenade. Gratuit sur HoPetSit.";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  alternates: { canonical: CANONICAL },
  openGraph: { title: TITLE, description: DESCRIPTION, url: CANONICAL, type: "website", siteName: "HoPetSit", images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }] },
};

export default function ParisPage() {
  return <OwnerCityPage city={PARIS_CITY} h1="Pet sitter à Paris : garde de chien, chat & promenades" />;
}
