import type { MetadataRoute } from "next";

// v23.1.267 — SEO : robots.txt (était absent). On autorise l'indexation des
// pages vitrine et on bloque les espaces authentifiés (données privées).
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      // 11/10/2026 (BOB) — Vercel gratuit saturé par des robots : les scrapers, outils SEO payants
      // et robots d'IA sont interdits partout (et refusés 403 par le middleware s'ils insistent).
      { userAgent: ["AhrefsBot", "SemrushBot", "MJ12bot", "DotBot", "PetalBot", "Bytespider", "GPTBot", "ClaudeBot", "anthropic-ai", "CCBot", "Amazonbot", "DataForSeoBot", "BLEXBot", "MegaIndex", "SeznamBot", "serpstatbot", "Barkrowler", "ImagesiftBot", "Diffbot", "omgili", "meta-externalagent", "Applebot-Extended", "Google-Extended", "PerplexityBot", "OAI-SearchBot", "cohere-ai", "TimpiBot", "SiteAuditBot", "AwarioBot"], disallow: "/" },
      {
      userAgent: "*",
      allow: "/",
      disallow: [
        "/dashboard",
        "/chat",
        "/bookings",
        "/invoices",
        "/profile",
        "/pets",
        "/pay",
        "/walk",
        "/friends",
        "/sitter-setup",
        "/api/",
      ],
      },
    ],
    // v517 — hôte canonique = www (redirection 308 de l'apex).
    sitemap: "https://www.hopetsit.com/sitemap.xml",
    host: "https://www.hopetsit.com",
  };
}
