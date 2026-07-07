import type { MetadataRoute } from "next";

// v23.1.267 — SEO : robots.txt (était absent). On autorise l'indexation des
// pages vitrine et on bloque les espaces authentifiés (données privées).
export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
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
    // v517 — hôte canonique = www (redirection 308 de l'apex).
    sitemap: "https://www.hopetsit.com/sitemap.xml",
    host: "https://www.hopetsit.com",
  };
}
