import type { Metadata } from "next";
import Link from "next/link";
import { RECRUIT_CITIES, RECRUIT_PATH_PREFIX, OWNER_PATH_PREFIX, type RecruitLang } from "@/lib/recruit-cities";

// v560 — moteur de croissance : page « hub » qui relie les 152 pages villes
// (9 langues × recrutement + propriétaires). Un lien depuis le pied de page
// suffit pour que Google découvre et recrawle tout le lot.

export const metadata: Metadata = {
  // v577 — `absolute` : la marque est deja en tete du titre (voir /blog).
  title: { absolute: "HoPetSit près de chez vous — pet sitters et promeneurs par ville" },
  description:
    "Toutes les villes HoPetSit : trouver un pet sitter ou devenir pet sitter à Paris, Lyon, Madrid, Berlin, Milan, Lisbonne, Varsovie, Séoul, Tokyo, New York et plus.",
  alternates: { canonical: "https://www.hopetsit.com/villes" },
};

const LANG_ORDER: RecruitLang[] = ["fr", "en", "es", "de", "it", "pt", "pl", "ko", "ja"];
const LANG_LABEL: Record<RecruitLang, { flag: string; name: string; owner: string; recruit: string }> = {
  fr: { flag: "🇫🇷", name: "France", owner: "Trouver un pet sitter", recruit: "Devenir pet sitter" },
  en: { flag: "🌍", name: "USA · United Kingdom · Europe (English)", owner: "Find a pet sitter", recruit: "Become a pet sitter" },
  es: { flag: "🇪🇸", name: "España", owner: "Encontrar un cuidador", recruit: "Ser cuidador" },
  de: { flag: "🇩🇪", name: "Deutschland", owner: "Tiersitter finden", recruit: "Tiersitter werden" },
  it: { flag: "🇮🇹", name: "Italia", owner: "Trovare un pet sitter", recruit: "Diventare pet sitter" },
  pt: { flag: "🇵🇹", name: "Portugal", owner: "Encontrar um pet sitter", recruit: "Ser pet sitter" },
  pl: { flag: "🇵🇱", name: "Polska", owner: "Znajdź opiekuna", recruit: "Zostań opiekunem" },
  ko: { flag: "🇰🇷", name: "대한민국", owner: "펫시터 찾기", recruit: "펫시터 되기" },
  ja: { flag: "🇯🇵", name: "日本", owner: "シッターを探す", recruit: "シッターになる" },
};

// Pages villes « entieres », ecrites a la main, hors RECRUIT_CITIES.
const BIG_CITIES: { href: string; label: string }[] = [
  { href: "/garde-animaux/paris", label: "Garde d'animaux à Paris" },
  { href: "/devenir-petsitter/paris", label: "Devenir pet sitter à Paris" },
  { href: "/petsitter/paris", label: "Pet sitter à Paris" },
  { href: "/petsitter/madrid", label: "Cuidador en Madrid" },
  { href: "/petsitter/dallas", label: "Pet sitter in Dallas" },
];

export default function CitiesHubPage() {
  return (
    <div className="mx-auto max-w-5xl px-4 py-16 md:py-24">
      <h1 className="font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">HoPetSit près de chez vous</h1>
      <p className="mt-4 max-w-2xl text-lg text-ink-muted">
        Pet sitters, promeneurs et propriétaires : la communauté HoPetSit grandit ville par ville. Choisissez la vôtre.
      </p>
      {/* v577 — SEO (21/09/2026). Le hub listait uniquement RECRUIT_CITIES, qui
          contient « paris-1 » a « paris-20 » mais PAS « paris » tout court : les
          trois grandes pages Paris, celles ou la publicite envoie, n'etaient
          donc reliees par aucun menu, aucune liste et aucun hub, et Google ne
          connaissait meme pas leur adresse (releve du 20/09). Meme chose pour
          Madrid et Dallas. Ces pages existent deja : on ne fait que les relier. */}
      <section className="mt-10 rounded-2xl border border-ink/10 bg-bg-soft p-5">
        <h2 className="font-display text-xl font-extrabold text-ink">Les grandes villes</h2>
        <ul className="mt-3 flex flex-wrap gap-x-5 gap-y-2 text-sm">
          {BIG_CITIES.map((c) => (
            <li key={c.href}>
              <Link href={c.href} className="font-semibold text-ink underline-offset-4 hover:text-owner hover:underline">{c.label}</Link>
            </li>
          ))}
        </ul>
      </section>

      {LANG_ORDER.map((lang) => {
        const cities = RECRUIT_CITIES.filter((c) => c.lang === lang);
        if (!cities.length) return null;
        const L = LANG_LABEL[lang];
        return (
          <section key={lang} className="mt-12">
            <h2 className="font-display text-2xl font-extrabold text-ink">
              {L.flag} {L.name}
            </h2>
            <div className="mt-4 grid gap-6 md:grid-cols-2">
              <div className="rounded-2xl border border-owner/20 bg-owner-light/40 p-5">
                <h3 className="text-sm font-bold uppercase tracking-wider text-owner-dark">{L.owner}</h3>
                <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-2 text-sm">
                  {cities.map((c) => (
                    <li key={`o-${c.slug}`}>
                      <Link href={`${OWNER_PATH_PREFIX[lang]}/${c.slug}`} className="text-ink underline-offset-4 hover:text-owner hover:underline">{c.name}</Link>
                    </li>
                  ))}
                </ul>
              </div>
              <div className="rounded-2xl border border-sitter/20 bg-sitter-light/40 p-5">
                <h3 className="text-sm font-bold uppercase tracking-wider text-sitter-dark">{L.recruit}</h3>
                <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-2 text-sm">
                  {cities.map((c) => (
                    <li key={`r-${c.slug}`}>
                      <Link href={`${RECRUIT_PATH_PREFIX[lang]}/${c.slug}`} className="text-ink underline-offset-4 hover:text-sitter-dark hover:underline">{c.name}</Link>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </section>
        );
      })}
    </div>
  );
}
