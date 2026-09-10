import type { Metadata } from "next";
import { notFound } from "next/navigation";
import OwnerCityPage, { ownerMetadata } from "../../../components/OwnerCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v560 — SEO programmatique côté propriétaire : /garde-animaux/<city> (fr).
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("fr").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("fr", params.city);
  if (!c) return {};
  return ownerMetadata(c, `https://www.hopetsit.com/garde-animaux/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("fr", params.city);
  if (!c) notFound();
  return <OwnerCityPage city={c} />;
}
