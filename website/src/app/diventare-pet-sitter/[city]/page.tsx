import type { Metadata } from "next";
import { notFound } from "next/navigation";
import RecruitCityPage, { recruitMetadata } from "../../../components/RecruitCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v547 — programmatic SEO (US): /diventare-pet-sitter/<city>.
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("it").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("it", params.city);
  if (!c) return {};
  return recruitMetadata(c, `https://www.hopetsit.com/diventare-pet-sitter/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("it", params.city);
  if (!c) notFound();
  return <RecruitCityPage city={c} />;
}
