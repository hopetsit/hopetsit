import type { Metadata } from "next";
import { notFound } from "next/navigation";
import RecruitCityPage, { recruitMetadata } from "../../../components/RecruitCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v547 — programmatic SEO (US): /ser-cuidador-de-mascotas/<city>.
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("es").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("es", params.city);
  if (!c) return {};
  return recruitMetadata(c, `https://www.hopetsit.com/ser-cuidador-de-mascotas/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("es", params.city);
  if (!c) notFound();
  return <RecruitCityPage city={c} />;
}
