"use client";

// v23.1.147 — Daniel : "la page terme et conditions est mal traduite ;
// refait toutes les langues". Avant : tout le contenu était hardcodé en
// anglais. Maintenant : le contenu est dans `lib/legalContent.ts` sous
// forme structurée (h2/p/ul) avec une version par langue. Le composant
// `LegalDocRenderer` sélectionne la bonne version via useT().
//
// Versions officielles : EN + FR (relues par Daniel).
// Versions auto-traduites : ES / DE / IT / PT → disclaimer affiché en haut.

import { LegalDocRenderer } from "@/components/LegalDocRenderer";

export default function TermsPage() {
  return <LegalDocRenderer slug="terms" titleKey="terms_title" />;
}
