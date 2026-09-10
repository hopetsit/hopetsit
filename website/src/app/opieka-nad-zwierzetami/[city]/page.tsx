import type { Metadata } from "next";
import { notFound } from "next/navigation";
import OwnerCityPage, { ownerMetadata } from "../../../components/OwnerCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v560 — SEO programmatique côté propriétaire : /opieka-nad-zwierzetami/<city> (pl).
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("pl").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("pl", params.city);
  if (!c) return {};
  return ownerMetadata(c, `https://www.hopetsit.com/opieka-nad-zwierzetami/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("pl", params.city);
  if (!c) notFound();
  return <OwnerCityPage city={c} />;
}
