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
    sitemap: "https://hopetsit.com/sitemap.xml",
    host: "https://hopetsit.com",
  };
}
