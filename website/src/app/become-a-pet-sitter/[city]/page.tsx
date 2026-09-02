import type { Metadata } from "next";
import { notFound } from "next/navigation";
import RecruitCityPage, { recruitMetadata } from "../../../components/RecruitCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v547 — programmatic SEO (US): /become-a-pet-sitter/<city>.
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("en").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("en", params.city);
  if (!c) return {};
  return recruitMetadata(c, `https://www.hopetsit.com/become-a-pet-sitter/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("en", params.city);
  if (!c) notFound();
  return <RecruitCityPage city={c} />;
}
