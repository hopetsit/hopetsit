"use client";

// v23.1.147 — voir terms/page.tsx pour le détail du refactor multilingue.
// Mentions légales — société Hong Kong CARDELLI HERMANOS LIMITED qui
// exploite la marque HoPetSit.
import { LegalDocRenderer } from "@/components/LegalDocRenderer";

export default function ImprintPage() {
  return <LegalDocRenderer slug="imprint" titleKey="imprint_title" />;
}
