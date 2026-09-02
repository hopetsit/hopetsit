import type { Metadata } from "next";
import { notFound } from "next/navigation";
import RecruitCityPage, { recruitMetadata } from "../../../components/RecruitCityPage";
import { recruitCitiesFor, recruitCity } from "../../../lib/recruit-cities";

// v547 — 프로그래매틱 SEO (한국): /pet-sitter-korea/<city>.
export const dynamicParams = false;

export function generateStaticParams() {
  return recruitCitiesFor("ko").map((c) => ({ city: c.slug }));
}

export function generateMetadata({ params }: { params: { city: string } }): Metadata {
  const c = recruitCity("ko", params.city);
  if (!c) return {};
  return recruitMetadata(c, `https://www.hopetsit.com/pet-sitter-korea/${c.slug}`);
}

export default function Page({ params }: { params: { city: string } }) {
  const c = recruitCity("ko", params.city);
  if (!c) notFound();
  return <RecruitCityPage city={c} />;
}
