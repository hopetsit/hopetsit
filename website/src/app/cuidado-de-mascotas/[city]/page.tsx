import type { Metadata } from "next";
import { notFound } from "next/navigation";
import OwnerCityPage, { ownerMetadata } from "../../../components/OwnerCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v560 — SEO programmatique côté propriétaire : /cuidado-de-mascotas/<city> (es).
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("es").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("es", params.city);
  if (!c) return {};
  return ownerMetadata(c, `https://www.hopetsit.com/cuidado-de-mascotas/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("es", params.city);
  if (!c) notFound();
  return <OwnerCityPage city={c} />;
}
