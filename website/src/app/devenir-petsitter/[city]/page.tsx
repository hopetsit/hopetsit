import type { Metadata } from "next";
import { notFound } from "next/navigation";
import RecruitCityPage, { recruitMetadata } from "../../../components/RecruitCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v547 — SEO programmatique FR : /devenir-petsitter/<ville|arrondissement>.
// (/devenir-petsitter/paris reste la page rédigée à la main : Next donne la
// priorité au segment statique sur le segment dynamique.)
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("fr").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("fr", params.city);
  if (!c) return {};
  return recruitMetadata(c, `https://www.hopetsit.com/devenir-petsitter/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("fr", params.city);
  if (!c) notFound();
  return <RecruitCityPage city={c} />;
}
