// 31/10/2026 (GUS, consigne de Daniel : SEO sur 4 pôles — Paris + Europe, New York, Séoul, Tokyo).
// UNE seule liste de données pour la colonne « Nos villes » et la colonne « Blog » du pied de page,
// dans les 9 langues. Chaque ville pointe vers SA page pilier, dans SA langue, à la section quartiers.
import type { Lang } from "@/lib/i18n/langs";

export const FOOTER_CITIES = [
  { href: "/garde-animaux/paris#quartiers", name: { fr: "Paris", ko: "파리 Paris", ja: "パリ Paris" } },
  { href: "/pet-sitting/new-york#districts", name: { ko: "뉴욕 New York", ja: "ニューヨーク New York" } , def: "New York" },
  { href: "/pet-sitting-korea/seoul#districts", name: { fr: "서울 Séoul", ko: "서울 Seoul" }, def: "서울 Seoul" },
  { href: "/pet-sitting-japan/tokyo#districts", name: { ja: "東京 Tokyo" }, def: "東京 Tokyo" },
  // 08/11 (GUS, ordre de Daniel) — 5e pôle : Pays-Bas (pages en anglais, guide local sur la page).
  { href: "/pet-sitting/amsterdam#us-local-guide", name: {}, def: "Amsterdam" },
] as { href: string; name: Partial<Record<Lang, string>>; def?: string }[];

/** Derniers articles des 4 villes (titre dans la langue de l'article). À mettre à jour avec la rotation hebdo. */
export const FOOTER_POSTS = [
  { href: "/blog/partir-au-ski-avec-ou-sans-son-chien", label: "Paris : partir au ski avec ou sans son chien" },
  { href: "/blog/summer-in-nyc-with-a-dog", label: "New York: summer with a dog" },
  { href: "/blog/seoul-dog-hotel-checklist", label: "애견호텔 고르는 법 : 예약 전 체크리스트" },
  { href: "/blog/tokyo-long-trip-pet-care", label: "海外旅行・長期出張でペットを預けるには" },
  { href: "/blog/cat-sitting-amsterdam-holidays", label: "Amsterdam: cat sitting over the holidays" },
];

export const FOOTER_CITY_TXT: Record<Lang, { cities: string; all: string; blog: string; allPosts: string }> = {
  fr: { cities: "Nos villes", all: "Toutes les villes (France & Europe)", blog: "Blog", allPosts: "Tous les articles" },
  en: { cities: "Our cities", all: "All cities (France & Europe)", blog: "Blog", allPosts: "All articles" },
  es: { cities: "Nuestras ciudades", all: "Todas las ciudades (Francia y Europa)", blog: "Blog", allPosts: "Todos los artículos" },
  de: { cities: "Unsere Städte", all: "Alle Städte (Frankreich & Europa)", blog: "Blog", allPosts: "Alle Artikel" },
  it: { cities: "Le nostre città", all: "Tutte le città (Francia ed Europa)", blog: "Blog", allPosts: "Tutti gli articoli" },
  pt: { cities: "As nossas cidades", all: "Todas as cidades (França e Europa)", blog: "Blog", allPosts: "Todos os artigos" },
  pl: { cities: "Nasze miasta", all: "Wszystkie miasta (Francja i Europa)", blog: "Blog", allPosts: "Wszystkie artykuły" },
  ko: { cities: "우리 도시", all: "모든 도시 (프랑스·유럽)", blog: "블로그", allPosts: "모든 글" },
  ja: { cities: "対応都市", all: "すべての都市（フランス・ヨーロッパ）", blog: "ブログ", allPosts: "すべての記事" },
};

export function footerCityName(c: (typeof FOOTER_CITIES)[number], lang: Lang): string {
  return c.name[lang] ?? c.def ?? c.name.fr ?? "";
}
