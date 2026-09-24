// 24/09/2026 — LOT B, étape 5 : métadonnées SERVEUR d'une page vitrine.
// Un seul endroit, pour ne pas retomber dans le piège du 21/09 : un
// `openGraph` déclaré dans une page REMPLACE celui du layout (images et
// siteName perdus en silence). On répète donc images + siteName ici, et le
// titre passe par le template du layout (« %s · HoPetSit »), jamais écrit à la
// main avec la marque.

import type { Metadata } from "next";
import { t as bundles } from "@/lib/i18n/translations";

const SITE = "https://www.hopetsit.com";
const OG_IMAGE = { url: `${SITE}/og-image.png`, width: 1200, height: 630, alt: "HoPetSit — pet sitting & dog walking" };

/**
 * @param titleKey clé i18n du titre (valeur anglaise servie au serveur)
 * @param descKey  clé i18n de la description
 * @param path     chemin canonique (« /pricing »)
 */
export function pageMeta(titleKey: string, descKey: string, path: string): Metadata {
  const en = bundles.en;
  const title = en[titleKey] || "HoPetSit";
  const description = en[descKey] || "";
  const url = `${SITE}${path}`;
  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: {
      type: "website",
      siteName: "HoPetSit",
      url,
      title: `${title} · HoPetSit`,
      description,
      images: [OG_IMAGE],
    },
    twitter: { card: "summary_large_image", title: `${title} · HoPetSit`, description, images: [OG_IMAGE.url] },
  };
}
