"use client";

// v23.1.345 — Daniel : "dans CGV et politique de confidentialité c'est pas
// traduit dans toutes les langues". CAUSE : cette page /cgu était restée sur
// l'ANCIEN contenu français codé en dur (pré-refactor v147), alors que /terms
// rend déjà le même document en 6 langues via LegalDocRenderer +
// lib/legalContent.ts. On aligne : /cgu devient un alias multilingue de
// /terms (même slug), pour que tous les anciens liens restent valides.
import { LegalDocRenderer } from "@/components/LegalDocRenderer";

export default function CguPage() {
  return <LegalDocRenderer slug="terms" titleKey="terms_title" />;
}
