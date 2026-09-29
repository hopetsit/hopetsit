import { TrackedLink } from "@/components/TrackedLink";
import { parisEntry } from "@/components/ParisLocalPlaces";
import {
  OWNER_PATH_PREFIX,
  RECRUIT_PATH_PREFIX,
  PARIS_CITY,
  PARIS_ARR_SUBURBS,
  parisArrondissement,
  nearbyCities,
  recruitCity,
  type RecruitCity,
  type RecruitLang,
} from "@/lib/recruit-cities";

// 29/09/2026 (SAM, demande de Daniel : « peut-être du maillage à rajouter »).
//
// UN seul composant pour relier les pages villes entre elles, côté
// propriétaire (/garde-animaux, /pet-sitting…) comme côté gardien
// (/devenir-petsitter, /become-a-pet-sitter…) :
//   - un fil d'Ariane (visible + BreadcrumbList pour Google) : Accueil ›
//     Toutes les villes › Paris › Paris 11e ;
//   - un bloc « Autour de Paris 11e » : les arrondissements voisins, tout
//     Paris, les communes de la petite couronne qui touchent l'arrondissement ;
//     pour une ville des États-Unis, ses voisines du même État puis du pays ;
//   - le lien vers la page jumelle (propriétaire ↔ gardien) de la même ville.
// Tout est rendu côté serveur : de vrais <a href> dans le HTML, texte d'ancre
// avec le nom de la ville. Chaque clic est compté (cta_click « maillage »,
// lisible dans /admin/site-analytics). Aucune page n'est créée ici.

type Mode = "owner" | "recruit";

type T = {
  home: string;
  cities: string;
  breadcrumb: string;
  around: (n: string) => string;
  ownerAnchor: (n: string) => string;
  recruitAnchor: (n: string) => string;
  toRecruit: (n: string) => string;
  toOwner: (n: string) => string;
};

const T: Record<RecruitLang, T> = {
  fr: {
    home: "Accueil", cities: "Toutes les villes", breadcrumb: "Fil d'Ariane",
    around: (n) => `Autour de ${n}`,
    ownerAnchor: (n) => `Garde d'animaux ${n}`,
    recruitAnchor: (n) => `Devenir pet sitter ${n}`,
    toRecruit: (n) => `Vous aimez les animaux ? Devenez pet sitter à ${n} →`,
    toOwner: (n) => `Vous êtes propriétaire ? Trouver un pet sitter à ${n} →`,
  },
  en: {
    home: "Home", cities: "All cities", breadcrumb: "Breadcrumb",
    around: (n) => `Around ${n}`,
    ownerAnchor: (n) => `Pet sitting in ${n}`,
    recruitAnchor: (n) => `Become a pet sitter in ${n}`,
    toRecruit: (n) => `Love animals? Become a pet sitter in ${n} →`,
    toOwner: (n) => `Pet owner? Find a pet sitter in ${n} →`,
  },
  es: {
    home: "Inicio", cities: "Todas las ciudades", breadcrumb: "Ruta de navegación",
    around: (n) => `Cerca de ${n}`,
    ownerAnchor: (n) => `Cuidado de mascotas en ${n}`,
    recruitAnchor: (n) => `Ser cuidador en ${n}`,
    toRecruit: (n) => `¿Te gustan los animales? Sé cuidador de mascotas en ${n} →`,
    toOwner: (n) => `¿Tienes mascota? Encuentra un cuidador en ${n} →`,
  },
  de: {
    home: "Startseite", cities: "Alle Städte", breadcrumb: "Navigationspfad",
    around: (n) => `Rund um ${n}`,
    ownerAnchor: (n) => `Tierbetreuung in ${n}`,
    recruitAnchor: (n) => `Tiersitter werden in ${n}`,
    toRecruit: (n) => `Tierfreund? Werde Tiersitter in ${n} →`,
    toOwner: (n) => `Tierhalter? Finde einen Tiersitter in ${n} →`,
  },
  it: {
    home: "Home", cities: "Tutte le città", breadcrumb: "Percorso",
    around: (n) => `Vicino a ${n}`,
    ownerAnchor: (n) => `Pet sitting a ${n}`,
    recruitAnchor: (n) => `Diventare pet sitter a ${n}`,
    toRecruit: (n) => `Ami gli animali? Diventa pet sitter a ${n} →`,
    toOwner: (n) => `Hai un animale? Trova un pet sitter a ${n} →`,
  },
  pt: {
    home: "Início", cities: "Todas as cidades", breadcrumb: "Navegação",
    around: (n) => `Perto de ${n}`,
    ownerAnchor: (n) => `Cuidado de animais em ${n}`,
    recruitAnchor: (n) => `Ser pet sitter em ${n}`,
    toRecruit: (n) => `Gostas de animais? Sê pet sitter em ${n} →`,
    toOwner: (n) => `Tens um animal? Encontra um pet sitter em ${n} →`,
  },
  pl: {
    home: "Strona główna", cities: "Wszystkie miasta", breadcrumb: "Ścieżka nawigacji",
    around: (n) => `W okolicy: ${n}`,
    ownerAnchor: (n) => `Opieka nad zwierzętami — ${n}`,
    recruitAnchor: (n) => `Zostań opiekunem — ${n}`,
    toRecruit: (n) => `Kochasz zwierzęta? Zostań opiekunem — ${n} →`,
    toOwner: (n) => `Masz zwierzaka? Znajdź opiekuna — ${n} →`,
  },
  ko: {
    home: "홈", cities: "모든 도시", breadcrumb: "탐색 경로",
    around: (n) => `${n} 주변`,
    ownerAnchor: (n) => `${n} 펫시팅`,
    recruitAnchor: (n) => `${n} 펫시터 되기`,
    toRecruit: (n) => `동물을 좋아하세요? ${n} 펫시터 되기 →`,
    toOwner: (n) => `보호자이신가요? ${n} 펫시터 찾기 →`,
  },
  ja: {
    home: "ホーム", cities: "すべての都市", breadcrumb: "パンくずリスト",
    around: (n) => `${n}の周辺`,
    ownerAnchor: (n) => `${n}のペットシッティング`,
    recruitAnchor: (n) => `${n}でペットシッターになる`,
    toRecruit: (n) => `動物が好きな方へ：${n}でペットシッターになる →`,
    toOwner: (n) => `飼い主の方へ：${n}でペットシッターを探す →`,
  },
};

const SITE = "https://www.hopetsit.com";
const HUB = "/villes";

function prefix(mode: Mode, lang: RecruitLang) {
  return mode === "owner" ? OWNER_PATH_PREFIX[lang] : RECRUIT_PATH_PREFIX[lang];
}

/** Paris intra-muros ou petite couronne : la page « Paris » entière est le parent. */
function isGreaterParis(city: RecruitCity) {
  return city.lang === "fr" && city.slug !== "paris" && (parisArrondissement(city.slug) !== undefined || city.region === "Île-de-France");
}

/** Villes à relier depuis cette page, dans l'ordre d'affichage (jamais la page elle-même). */
function linkedCities(city: RecruitCity): RecruitCity[] {
  const out: RecruitCity[] = [];
  const add = (c?: RecruitCity) => { if (c && c.slug !== city.slug && !out.some((o) => o.slug === c.slug)) out.push(c); };
  const arr = city.lang === "fr" ? parisArrondissement(city.slug) : undefined;
  if (arr !== undefined) {
    for (const v of parisEntry(city.slug)?.neighbours ?? []) add(recruitCity("fr", `paris-${v}`));
    add(PARIS_CITY);
    for (const s of PARIS_ARR_SUBURBS[arr] ?? []) add(recruitCity("fr", s));
    return out;
  }
  if (city.slug === "paris") return out; // le hub Paris liste déjà ses 20 arrondissements et la couronne
  if (isGreaterParis(city)) add(PARIS_CITY);
  for (const n of nearbyCities(city.lang, city.slug, 6)) add(n);
  return out;
}

function crumbs(city: RecruitCity, mode: Mode) {
  const t = T[city.lang];
  const p = prefix(mode, city.lang);
  const items: { name: string; href: string }[] = [
    { name: t.home, href: "/" },
    { name: t.cities, href: HUB },
  ];
  if (isGreaterParis(city)) items.push({ name: PARIS_CITY.name, href: `${p}/paris` });
  items.push({ name: city.name, href: `${p}/${city.slug}` });
  return items;
}

/** Fil d'Ariane visible + BreadcrumbList (JSON-LD). À poser en haut de page. */
export function CityBreadcrumb({ city, mode }: { city: RecruitCity; mode: Mode }) {
  const t = T[city.lang];
  const items = crumbs(city, mode);
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((it, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: it.name,
      item: `${SITE}${it.href}`,
    })),
  };
  return (
    <nav aria-label={t.breadcrumb} className="text-xs font-medium text-ink-soft">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <ol className="flex flex-wrap items-center gap-x-1.5 gap-y-1">
        {items.map((it, i) => {
          const last = i === items.length - 1;
          return (
            <li key={it.href} className="flex items-center gap-x-1.5">
              {i > 0 && <span aria-hidden="true">›</span>}
              {last ? (
                <span aria-current="page" className="text-ink">{it.name}</span>
              ) : (
                <TrackedLink href={it.href} label="maillage" className="underline-offset-4 hover:text-owner-dark hover:underline">{it.name}</TrackedLink>
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}

/** Bloc « Autour de <ville> » + lien vers la page jumelle. À poser en bas de page. */
export function CityLinks({ city, mode }: { city: RecruitCity; mode: Mode }) {
  const t = T[city.lang];
  const p = prefix(mode, city.lang);
  const anchor = mode === "owner" ? t.ownerAnchor : t.recruitAnchor;
  const cities = linkedCities(city);
  const twin = mode === "owner"
    ? { href: `${RECRUIT_PATH_PREFIX[city.lang]}/${city.slug}`, text: t.toRecruit(city.name), cls: "text-sitter-dark" }
    : { href: `${OWNER_PATH_PREFIX[city.lang]}/${city.slug}`, text: t.toOwner(city.name), cls: "text-owner-dark" };
  const hover = mode === "owner" ? "hover:bg-owner-light hover:text-owner-dark" : "hover:bg-sitter-light hover:text-sitter-dark";
  return (
    <section className="mt-12 border-t border-owner/15 pt-6">
      {cities.length > 0 && (
        <nav aria-label={t.around(city.name)}>
          <h2 className="font-display text-lg font-extrabold text-ink">{t.around(city.name)}</h2>
          <ul className="mt-3 flex flex-wrap gap-2">
            {cities.map((c) => (
              <li key={c.slug}>
                <TrackedLink
                  href={`${p}/${c.slug}`}
                  label="maillage"
                  className={`inline-block rounded-full bg-bg-soft px-3.5 py-2 text-sm font-medium text-ink transition max-lg:py-3 ${hover}`}
                >
                  {anchor(c.name)}
                </TrackedLink>
              </li>
            ))}
            <li>
              <TrackedLink href={HUB} label="maillage" className={`inline-block rounded-full bg-bg-soft px-3.5 py-2 text-sm font-medium text-ink transition max-lg:py-3 ${hover}`}>
                {t.cities} →
              </TrackedLink>
            </li>
          </ul>
        </nav>
      )}
      <p className={`${cities.length ? "mt-5" : ""} text-center text-sm md:text-left`}>
        <TrackedLink href={twin.href} label="maillage" className={`font-semibold underline-offset-4 hover:underline ${twin.cls}`}>{twin.text}</TrackedLink>
      </p>
    </section>
  );
}

export default CityLinks;
