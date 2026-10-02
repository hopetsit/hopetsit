// 24/09/2026 — LOT B, étape 5 : titre et description propres de /faq, servis
// par le serveur (la page elle-même est un composant client et ne peut pas
// exporter de métadonnées). Le titre traduit est posé par <PageTitle />.
// 02/10/2026 (607, LEO) — + données structurées FAQPage (questions servies en
// français, comme le HTML du serveur), mêmes clés que la page.
import type { Metadata } from "next";
import { pageMeta } from "@/lib/seoMeta";
import { t as bundles } from "@/lib/i18n/translations";
import { FAQ_COUNT } from "@/lib/faqCount";

export const metadata: Metadata = pageMeta("page_title_faq", "page_desc_faq", "/faq");

function faqJsonLd() {
  const fr = bundles.fr;
  const mainEntity = Array.from({ length: FAQ_COUNT }, (_, i) => ({ q: fr[`faq_q${i + 1}`], a: fr[`faq_a${i + 1}`] }))
    .filter((x) => x.q && x.a)
    .map((x) => ({ "@type": "Question", name: x.q, acceptedAnswer: { "@type": "Answer", text: x.a } }));
  return { "@context": "https://schema.org", "@type": "FAQPage", mainEntity };
}

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd()).replace(/</g, "\\u003c") }} />
      {children}
    </>
  );
}
