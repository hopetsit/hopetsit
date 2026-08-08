import type { Metadata } from "next";
import { CityPage } from "../_cityPage";

export const metadata: Metadata = {
  title: "Pet sitter à Paris — garde de chien & chat, promenades | HoPetSit",
  description:
    "Trouvez un pet sitter ou un promeneur de chien vérifié à Paris. Avis réels, paiement sécurisé et suivi GPS de chaque promenade. Gratuit sur HoPetSit.",
  alternates: { canonical: "https://www.hopetsit.com/petsitter/paris" },
};

export default function ParisPage() {
  return (
    <CityPage
      c={{
        city: "Paris",
        lang: "fr",
        h1: "Pet sitter à Paris : garde de chien, chat & promenades",
        intro:
          "Entre le travail, les week-ends et les vacances, difficile d'être toujours là pour son animal à Paris. HoPetSit vous met en relation avec des pet sitters et promeneurs de chiens vérifiés, du Marais à Montmartre, pour une garde en toute confiance.",
        servicesTitle: "Les services près de chez vous",
        services: [
          {
            icon: "🏠",
            t: "Garde à domicile",
            p: "Votre animal reste dans ses repères, ou est accueilli chez un pet sitter passionné de votre quartier.",
          },
          {
            icon: "🚶",
            t: "Promenade de chien",
            p: "Une balade au parc Monceau ou aux Buttes-Chaumont pendant que vous êtes au bureau — suivie en GPS.",
          },
          {
            icon: "🔑",
            t: "Visites à domicile",
            p: "Repas, litière, câlins et médicaments pour votre chat qui préfère rester chez lui.",
          },
        ],
        whyTitle: "Pourquoi les Parisiens choisissent HoPetSit",
        why: [
          "Des profils avec identité vérifiée et de vrais avis issus de réservations réelles.",
          "Le suivi GPS PawFollow : regardez la promenade de votre chien en direct sur la carte.",
          "Le paiement sécurisé dans l'app, débloqué seulement après le service.",
          "La PawMap : les parcs, cafés et vétérinaires pet-friendly de Paris, partagés par la communauté.",
          "Une app gratuite, disponible en français et en 6 langues.",
        ],
        faqTitle: "Questions fréquentes à Paris",
        faq: [
          {
            q: "Combien coûte un pet sitter à Paris ?",
            a: "Comptez 20 à 30 € par jour pour une garde à domicile à Paris, et 12 à 20 € pour une promenade. Chaque pet sitter fixe librement son tarif sur son profil.",
          },
          {
            q: "Comment être sûr du sérieux du pet sitter ?",
            a: "Les profils HoPetSit affichent une vérification d'identité et des avis laissés uniquement après de vraies réservations. Vous échangez par chat avant de confirmer.",
          },
          {
            q: "Puis-je suivre la promenade de mon chien ?",
            a: "Oui — avec PawFollow, la position du promeneur s'affiche en direct sur la carte pendant toute la balade.",
          },
        ],
        ctaTitle: "Trouvez votre pet sitter à Paris",
        ctaBody:
          "Téléchargez HoPetSit gratuitement, comparez les profils près de chez vous et réservez en quelques minutes.",
        ctaButton: "Télécharger l'app HoPetSit",
      }}
    />
  );
}
