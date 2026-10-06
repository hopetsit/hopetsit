import type { MetadataRoute } from "next";
import { RECRUIT_CITIES, recruitPaths, ownerPaths } from "../lib/recruit-cities";
import { fetchProviderSitemap } from "../lib/publicProvider607";

// 02/10 (607) — relu toutes les heures (pages /s des prestataires).
export const revalidate = 3600;

// v23.1.267 — SEO : sitemap des pages publiques (était absent). metadataBase
// est défini dans layout.tsx (https://hopetsit.com).
// v517 — hôte canonique = www (Vercel redirige hopetsit.com → www en 308).
// La propriété Search Console est https://www.hopetsit.com → les URLs du
// sitemap doivent être sur le MÊME hôte, sinon elles comptent « hors
// propriété » et l'indexation rame.
const BASE = "https://www.hopetsit.com";

const PUBLIC_PATHS = [
  "",
  "/how-it-works",
  "/pricing",
  "/pawmap",
  // 02/10 (607) — page publique PawPoints (priorité 0,5).
  "/pawpoints-guide",
  "/faq",
  "/contact",
  "/download",
  "/terms",
  "/privacy",
  "/refund",
  "/imprint",
  "/cgu",
  "/remboursement",
  // v531 — SEO : blog + pages villes (contenu statique indexable).
  "/blog",
  // 05/10 (GUS) — recrutement New York.
  "/blog/dog-walker-jobs-nyc",
  "/blog/pet-sitting-jobs-new-york",
  // 06/10 (GUS) — recrutement Düsseldorf / Köln / Essen.
  "/blog/haustiersitter-jobs-duesseldorf",
  // 2026-W40 — choisir un pet sitter à Paris (propriétaires) + coût d'un pet
  // sitter à Dallas (sujets_us.md #1, liens vers les pages Dallas inconnues
  // de Google).
  "/blog/choisir-un-pet-sitter-de-confiance-a-paris",
  "/blog/how-much-does-a-pet-sitter-cost-in-dallas",
  // 2026-W39 — recrutement Paris 15e + San Francisco.
  "/blog/devenir-pet-sitter-paris-15e",
  "/blog/become-a-pet-sitter-in-san-francisco",
  // 2026-W38 — garde de week-end à Paris (propriétaires) + Austin (owners).
  "/blog/faire-garder-son-chien-le-week-end-a-paris",
  "/blog/finding-a-pet-sitter-in-austin",
  "/blog/chien-seul-toute-la-journee-paris",
  "/blog/combien-coute-un-pet-sitter",
  "/blog/faire-garder-son-chien-pendant-les-vacances",
  "/blog/how-much-does-a-dog-walker-cost",
  // 2026-W37 — recrutement Paris 11e + Chicago.
  "/blog/devenir-pet-sitter-paris-11e",
  "/blog/become-a-pet-sitter-in-chicago",
  // v535 — 6 articles SEO Paris + USA.
  "/blog/promener-son-chien-a-paris",
  "/blog/tarif-promeneur-de-chien-paris",
  "/blog/faire-garder-son-chat-a-paris",
  "/blog/how-to-become-a-dog-walker",
  "/blog/dog-boarding-vs-pet-sitting",
  "/blog/leaving-cat-alone-vacation",
  // 29/09 (SAM) : /petsitter/paris et /petsitter/dallas restent en ligne mais
  // pointent (canonical) vers /garde-animaux/paris et /pet-sitting/dallas —
  // même contenu, une seule adresse pour Google, donc hors du plan du site.
  "/devenir-petsitter/paris",
  // v575 — page d'atterrissage de la pub Meta « Paris · Propriétaires » et hub
  // vers les 20 arrondissements (src/app/garde-animaux/paris/page.tsx).
  // Elle n'est pas produite par ownerPaths() : son slug n'est pas dans
  // recruit-cities (qui ne contient que paris-1…paris-20).
  "/garde-animaux/paris",
  "/petsitter/madrid",
  "/villes",
];

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  // 26/09/2026 (SAM) — plus de « date du jour » sur les 654 URL à chaque mise
  // en ligne : Google finit par ignorer un lastmod qui change sans que la page
  // change. On ne date que les pages dont on connaît la vraie dernière
  // modification (pages propriétaires Paris : cartes de gardiens le 26/09).
  const PAGES_DATEES: Array<[RegExp, Date]> = [
    [/^\/garde-animaux\//, new Date("2026-09-26T12:00:00Z")],
  ];
  const dateDe = (path: string) => PAGES_DATEES.find(([rx]) => rx.test(path))?.[1];
  // v547 — pages « devenir pet sitter à <ville> » (FR/EN/PL/KO) générées
  // depuis lib/recruit-cities.ts : une ligne de données = une URL indexable.
  // v560 — + pages « trouver un pet sitter à <ville> » (côté propriétaire).
  const all = [...PUBLIC_PATHS, ...recruitPaths(), ...ownerPaths()];
  // v562 — focus Paris + USA (Daniel, 13/09) : priorité haute aux pages FR et
  // aux villes américaines, basse aux autres langues (qui restent indexables).
  const US = new Set(RECRUIT_CITIES.filter((c) => c.lang === "en" && /USA/.test(c.region)).map((c) => c.slug));
  const prio = (path: string): number => {
    if (path === "") return 1;
    if (path === "/pawpoints-guide") return 0.5;
    if (path.startsWith("/blog") || path === "/villes" || path === "/download" || path === "/pawmap") return 0.8;
    if (path.startsWith("/devenir-petsitter/") || path.startsWith("/garde-animaux/")) return 0.8;
    const m = path.match(/^\/(become-a-pet-sitter|pet-sitting)\/([^/]+)$/);
    if (m) return US.has(m[2]) ? 0.8 : 0.4;
    return path.split("/").length > 2 ? 0.3 : 0.6;
  };
  const pages: MetadataRoute.Sitemap = all.map((path) => ({
    url: `${BASE}${path}`,
    ...(dateDe(path) ? { lastModified: dateDe(path) } : {}),
    changeFrequency: path === "" || path.startsWith("/blog") ? "weekly" : "monthly",
    priority: prio(path),
  }));
  // 02/10 (607, BOB) — pages personnelles /s/<slug> : SEULEMENT les
  // prestataires de France et des États-Unis (règle SEO du 20/09 : budget
  // d'exploration). Les autres /s restent indexables et liées depuis la carte,
  // hors sitemap. Le pays vient du serveur (champ `country`, ISO) : sans lui,
  // aucune page /s n'est ajoutée (jamais de devinette).
  const providers = await fetchProviderSitemap();
  for (const p of providers) {
    const c = String(p.country || "").toUpperCase();
    if (c !== "FR" && c !== "US") continue;
    const d = p.updatedAt ? new Date(p.updatedAt) : null;
    pages.push({ url: `${BASE}/s/${p.slug}`, ...(d && !Number.isNaN(d.getTime()) ? { lastModified: d } : {}), changeFrequency: "weekly", priority: 0.6 });
  }
  return pages;
}
