// 24/09/2026 — LOT B, étape 5 : titre et description propres de /pricing, servis
// par le serveur (la page elle-même est un composant client et ne peut pas
// exporter de métadonnées). Le titre traduit est posé par <PageTitle />.
import type { Metadata } from "next";
import { pageMeta } from "@/lib/seoMeta";

export const metadata: Metadata = pageMeta("page_title_pricing", "page_desc_pricing", "/pricing");

export default function Layout({ children }: { children: React.ReactNode }) {
  return children;
}
