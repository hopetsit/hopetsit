import type { Metadata } from "next";
import { notFound } from "next/navigation";
import RecruitCityPage, { recruitMetadata } from "../../../components/RecruitCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v547 — programmatic SEO (US): /pet-sitter-japan/<city>.
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("ja").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("ja", params.city);
  if (!c) return {};
  return recruitMetadata(c, `https://www.hopetsit.com/pet-sitter-japan/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("ja", params.city);
  if (!c) notFound();
  return <RecruitCityPage city={c} />;
}
