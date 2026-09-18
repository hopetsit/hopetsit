// v565 (point 29) — `/report/:id` est l'alias historique (v552) de
// `/alert/:id` dans les liens de partage et l'AASA. Même page publique
// (composant serveur, aperçu de partage) : redirection permanente.

import { permanentRedirect } from "next/navigation";

export default function ReportAliasPage({ params }: { params: { id: string } }) {
  permanentRedirect(`/alert/${encodeURIComponent(String(params?.id || ""))}`);
}
