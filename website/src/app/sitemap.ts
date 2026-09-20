import type { MetadataRoute } from "next";
import { RECRUIT_CITIES, recruitPaths, ownerPaths } from "../lib/recruit-cities";

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
  "/petsitter/paris",
  "/devenir-petsitter/paris",
  // v575 — page d'atterrissage de la pub Meta « Paris · Propriétaires » et hub
  // vers les 20 arrondissements (src/app/garde-animaux/paris/page.tsx).
  // Elle n'est pas produite par ownerPaths() : son slug n'est pas dans
  // recruit-cities (qui ne contient que paris-1…paris-20).
  "/garde-animaux/paris",
  "/petsitter/madrid",
  "/petsitter/dallas",
  "/villes",
];

export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date();
  // v547 — pages « devenir pet sitter à <ville> » (FR/EN/PL/KO) générées
  // depuis lib/recruit-cities.ts : une ligne de données = une URL indexable.
  // v560 — + pages « trouver un pet sitter à <ville> » (côté propriétaire).
  const all = [...PUBLIC_PATHS, ...recruitPaths(), ...ownerPaths()];
  // v562 — focus Paris + USA (Daniel, 13/09) : priorité haute aux pages FR et
  // aux villes américaines, basse aux autres langues (qui restent indexables).
  const US = new Set(RECRUIT_CITIES.filter((c) => c.lang === "en" && /USA/.test(c.region)).map((c) => c.slug));
  const prio = (path: string): number => {
    if (path === "") return 1;
    if (path.startsWith("/blog") || path === "/villes" || path === "/download" || path === "/pawmap") return 0.8;
    if (path.startsWith("/devenir-petsitter/") || path.startsWith("/garde-animaux/")) return 0.8;
    const m = path.match(/^\/(become-a-pet-sitter|pet-sitting)\/([^/]+)$/);
    if (m) return US.has(m[2]) ? 0.8 : 0.4;
    return path.split("/").length > 2 ? 0.3 : 0.6;
  };
  return all.map((path) => ({
    url: `${BASE}${path}`,
    lastModified,
    changeFrequency: path === "" || path.startsWith("/blog") ? "weekly" : "monthly",
    priority: prio(path),
  }));
}
