import type { Metadata } from "next";
import { notFound } from "next/navigation";
import OwnerCityPage, { ownerMetadata } from "@/components/OwnerCityPage";
import { ParisHeroForm } from "@/components/ParisHeroForm";
import { recruitCitiesFor, recruitCity } from "@/lib/recruit-cities";

// v560 — SEO programmatique côté propriétaire : /pet-sitting/<city> (en).
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("en").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("en", params.city);
  if (!c) return {};
  return ownerMetadata(c, `https://www.hopetsit.com/pet-sitting/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("en", params.city);
  if (!c) notFound();
  // 31/10/2026 (LEO, feu vert BOB) — New York = page d'arrivée de la pub (nyc_owners) : premier écran =
  // promesse + formulaire en 1 étape (même composant que Paris, en anglais). Les autres villes EN : inchangées.
  if (c.slug === "new-york") {
    return (
      <OwnerCityPage
        city={c}
        heroCta={
          <ParisHeroForm
            city={c.name}
            lang="en"
            country="US"
            campaign="nyc_owners"
            page="/pet-sitting/new-york"
            lead="Trusted pet sitters near you in New York reply by email, with their price. Give your dates, no account needed: your request is posted right away."
            note="Free · no account · you choose and pay later, free cancellation up to 72 h before"
          />
        }
        stickyWatchId="hero-publier"
      />
    );
  }
  return <OwnerCityPage city={c} />;
}
