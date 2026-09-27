"use client";

// v23.1.345 — même fix que /cgu : cette page restait sur l'ancien contenu
// français codé en dur. Elle devient un alias multilingue de /refund
// (LegalDocRenderer + lib/legalContent.ts, 6 langues) pour que les anciens
// liens restent valides.
import { LegalDocRenderer } from "@/components/LegalDocRenderer";

export default function RemboursementPage() {
  return <LegalDocRenderer slug="refund" titleKey="refund_title" />;
}
