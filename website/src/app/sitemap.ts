import type { MetadataRoute } from "next";

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
  "/petsitter/paris",
  "/devenir-petsitter/paris",
  "/petsitter/madrid",
  "/petsitter/dallas",
];

export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date();
  return PUBLIC_PATHS.map((path) => ({
    url: `${BASE}${path}`,
    lastModified,
    changeFrequency: path === "" ? "weekly" : "monthly",
    priority: path === "" ? 1 : 0.7,
  }));
}
