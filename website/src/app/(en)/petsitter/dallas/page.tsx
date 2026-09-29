import type { Metadata } from "next";
import { notFound } from "next/navigation";
import OwnerCityPage from "@/components/OwnerCityPage";
import { recruitCity } from "@/lib/recruit-cities";

// 29/09/2026 (SAM, demande de Daniel : « toutes les pages USA dans ce style »).
// Ancienne page v531 (texte + « Download the app ») : elle affiche maintenant
// le même premier écran que /pet-sitting/dallas (real sitters with prices,
// green line, « Post my request », links to nearby Texas cities). Same
// content → canonical to the main page; the address stays alive.
const CANONICAL = "https://www.hopetsit.com/pet-sitting/dallas";
const TITLE = "Pet sitter in Dallas, TX — dog walking & pet care";
const DESCRIPTION =
  "Find a verified pet sitter or dog walker in Dallas. Real reviews, secure in-app payment and live GPS tracking of every walk. Free on HoPetSit.";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  alternates: { canonical: CANONICAL },
  openGraph: { title: TITLE, description: DESCRIPTION, url: CANONICAL, type: "website", siteName: "HoPetSit", images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }] },
};

export default function DallasPage() {
  const c = recruitCity("en", "dallas");
  if (!c) notFound();
  return <OwnerCityPage city={c} h1="Pet sitter in Dallas: dog & cat care, walks and more" />;
}
