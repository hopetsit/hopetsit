import type { MetadataRoute } from "next";
import { recruitPaths } from "../lib/recruit-cities";

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
  "/login",
  "/signup",
  // v531 — SEO : blog + pages villes (contenu statique indexable).
  "/blog",
  "/blog/combien-coute-un-pet-sitter",
  "/blog/faire-garder-son-chien-pendant-les-vacances",
  "/blog/how-much-does-a-dog-walker-cost",
  // v535 — 6 articles SEO Paris + USA.
  "/blog/promener-son-chien-a-paris",
  "/blog/tarif-promeneur-de-chien-paris",
  "/blog/faire-garder-son-chat-a-paris",
  "/blog/how-to-become-a-dog-walker",
  "/blog/dog-boarding-vs-pet-sitting",
  "/blog/leaving-cat-alone-vacation",
  "/petsitter/paris",
  "/devenir-petsitter/paris",
  "/petsitter/madrid",
  "/petsitter/dallas",
];

export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date();
  // v547 — pages « devenir pet sitter à <ville> » (FR/EN/PL/KO) générées
  // depuis lib/recruit-cities.ts : une ligne de données = une URL indexable.
  const all = [...PUBLIC_PATHS, ...recruitPaths()];
  return all.map((path) => ({
    url: `${BASE}${path}`,
    lastModified,
    changeFrequency: path === "" ? "weekly" : "monthly",
    priority: path === "" ? 1 : 0.7,
  }));
}
