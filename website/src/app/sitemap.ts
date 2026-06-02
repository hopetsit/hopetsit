import type { MetadataRoute } from "next";

// v23.1.267 — SEO : sitemap des pages publiques (était absent). metadataBase
// est défini dans layout.tsx (https://hopetsit.com).
const BASE = "https://hopetsit.com";

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
