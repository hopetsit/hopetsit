import type { Metadata } from "next";
import { notFound } from "next/navigation";
import OwnerCityPage, { ownerMetadata } from "../../../components/OwnerCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v560 — SEO programmatique côté propriétaire : /custodia-animali/<city> (it).
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("it").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("it", params.city);
  if (!c) return {};
  return ownerMetadata(c, `https://www.hopetsit.com/custodia-animali/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("it", params.city);
  if (!c) notFound();
  return <OwnerCityPage city={c} />;
}
