// 02/10/2026 (607, LEO) — page PUBLIQUE et indexable des PawPoints (la page
// membre /pawpoints reste privée, noindex par le middleware). Catalogue lu
// côté serveur et revalidé toutes les heures ; métadonnées par pageMeta
// (openGraph complet : piège du 21/09).
import type { Metadata } from "next";
import { pageMeta } from "@/lib/seoMeta";
import { PawPointsGuide } from "@/components/PawPointsGuide";
import type { PawCatalog607 } from "@/lib/api";
import { parseRanksCatalog611 } from "@/lib/ranks611";

export const revalidate = 3600;
export const metadata: Metadata = pageMeta("page_title_ppg", "page_desc_ppg", "/pawpoints-guide");

const API = process.env.NEXT_PUBLIC_API_BASE ?? "https://hopetsit-backend.onrender.com/api/v1";

async function catalog(): Promise<PawCatalog607 | null> {
  try {
    const r = await fetch(`${API}/pawpoints/catalog`, { next: { revalidate: 3600 } });
    if (!r.ok) return null;
    const d = (await r.json()) as { catalog607?: PawCatalog607; ranks611?: unknown };
    // 611 — les 5 rangs viennent du même GET (absents sur un ancien serveur → null).
    return d.catalog607 && Array.isArray(d.catalog607.earn) ? { ...d.catalog607, ranks611: parseRanksCatalog611(d.ranks611) } : null;
  } catch {
    return null;
  }
}

// 02/10 (609) — données VideoObject de la vidéo « attraper une peluche » (page servie en français).
const VIDEO_LD = {
  "@context": "https://schema.org",
  "@type": "VideoObject",
  name: "Attraper une peluche pendant une Balade — HoPetSit",
  description: "Capture de l'app HoPetSit : le rappel des peluches sur la PawMap, on lance une Balade, on s'approche à 30 m et on gagne +20 PawPoints.",
  thumbnailUrl: ["https://www.hopetsit.com/video/peluche_fr_poster.webp"],
  uploadDate: "2026-10-02T17:00:00+02:00",
  duration: "PT23S",
  contentUrl: "https://www.hopetsit.com/video/peluche_fr.mp4",
  embedUrl: "https://www.hopetsit.com/pawpoints-guide",
  inLanguage: "fr",
  publisher: { "@type": "Organization", name: "HoPetSit", logo: { "@type": "ImageObject", url: "https://hopetsit.com/logo.png" } },
};

export default async function Page() {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(VIDEO_LD).replace(/</g, "\\u003c") }} />
      <PawPointsGuide initial={await catalog()} />
    </>
  );
}
