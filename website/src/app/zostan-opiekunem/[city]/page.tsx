import type { Metadata } from "next";
import { notFound } from "next/navigation";
import RecruitCityPage, { recruitMetadata } from "../../../components/RecruitCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v547 — SEO programowe (Polska): /zostan-opiekunem/<miasto>.
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("pl").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("pl", params.city);
  if (!c) return {};
  return recruitMetadata(c, `https://www.hopetsit.com/zostan-opiekunem/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("pl", params.city);
  if (!c) notFound();
  return <RecruitCityPage city={c} />;
}
