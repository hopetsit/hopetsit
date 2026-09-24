"use client";

// 24/09/2026 — LOT B, étape 5 : titres de pages PROPRES et TRADUITS.
// Les pages vitrine sont des composants client (« use client ») et ne peuvent
// pas exporter de `metadata` : le titre servi par le serveur (anglais, SEO)
// vient des `layout.tsx` de chaque dossier (lib/seoMeta.ts), et CE composant
// remplace le titre et la description dans la langue choisie par le visiteur,
// à chaque changement de langue. « · HoPetSit » est ajouté une seule fois.

import { useEffect } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";

export function PageTitle({ titleKey, descKey }: { titleKey: string; descKey?: string }) {
  const { t, lang } = useT();
  useEffect(() => {
    const title = t(titleKey);
    if (title && title !== titleKey) {
      document.title = /hopetsit/i.test(title) ? title : `${title} · HoPetSit`;
    }
    if (descKey) {
      const desc = t(descKey);
      if (desc && desc !== descKey) {
        let meta = document.querySelector<HTMLMetaElement>('meta[name="description"]');
        if (!meta) {
          meta = document.createElement("meta");
          meta.name = "description";
          document.head.appendChild(meta);
        }
        meta.content = desc;
      }
    }
  }, [t, lang, titleKey, descKey]);
  return null;
}

export default PageTitle;
