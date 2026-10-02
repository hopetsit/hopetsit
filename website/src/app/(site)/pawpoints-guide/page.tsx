// 02/10/2026 (607, LEO) — page PUBLIQUE et indexable des PawPoints (la page
// membre /pawpoints reste privée, noindex par le middleware). Catalogue lu
// côté serveur et revalidé toutes les heures ; métadonnées par pageMeta
// (openGraph complet : piège du 21/09).
import type { Metadata } from "next";
import { pageMeta } from "@/lib/seoMeta";
import { PawPointsGuide } from "@/components/PawPointsGuide";
import type { PawCatalog607 } from "@/lib/api";

export const revalidate = 3600;
export const metadata: Metadata = pageMeta("page_title_ppg", "page_desc_ppg", "/pawpoints-guide");

const API = process.env.NEXT_PUBLIC_API_BASE ?? "https://hopetsit-backend.onrender.com/api/v1";

async function catalog(): Promise<PawCatalog607 | null> {
  try {
    const r = await fetch(`${API}/pawpoints/catalog`, { next: { revalidate: 3600 } });
    if (!r.ok) return null;
    const d = (await r.json()) as { catalog607?: PawCatalog607 };
    return d.catalog607 && Array.isArray(d.catalog607.earn) ? d.catalog607 : null;
  } catch {
    return null;
  }
}

export default async function Page() {
  return <PawPointsGuide initial={await catalog()} />;
}
