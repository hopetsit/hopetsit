// 31/10/2026 (LEO, étape 3 — plan validé par BOB) — enveloppe des articles de blog (en) : les textes des
// articles ne bougent pas ; un encart « Publier ma demande » est ajouté EN FIN d'article (BlogPublishCta3110).
// Aucune nouvelle page : ce layout ne concerne que les articles déjà existants de ce dossier.
import { BlogPublishCta3110 } from "@/components/BlogPublishCta3110";

export default function BlogArticleLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      {children}
      <BlogPublishCta3110 lang="en" />
    </>
  );
}
