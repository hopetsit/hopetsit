"use client";

// 31/10/2026 (LEO, étape 3 — plan validé par BOB) — encart « Publier ma demande » en FIN D'ARTICLE de blog
// (fr/en), posé par le layout des articles : aucune nouvelle page, aucun texte d'article modifié.
// Un seul bouton → le formulaire 1 étape de l'accueil ; ligne secondaire « Devenir gardien ».
// Zéro gris : encres brunes de la charte, orange #C92A12, bleu gardien. Repères blog_publier / blog_gardien.

import Link from "@/components/SiteLink";
import { AppIcon } from "@/components/AppIcon";
import { trackSiteEvent } from "@/components/SiteAnalytics";

const TXT = {
  fr: {
    title: "Tu cherches un gardien près de chez toi ?",
    body: "Publie ta demande en 1 minute, sans compte : des gardiens vérifiés te répondent par e-mail avec leur prix. Tu choisis, tu paies, annulation gratuite jusqu'à 72 h avant.",
    cta: "Publier ma demande",
    sitter: "Tu gardes des animaux ? Deviens gardien →",
    sitterHref: "/devenir-petsitter",
  },
  en: {
    title: "Looking for a sitter near you?",
    body: "Post your request in 1 minute, no account: trusted sitters reply by email with their price. You choose, you pay, free cancellation up to 72 h before.",
    cta: "Post my request",
    sitter: "You look after pets? Become a sitter →",
    sitterHref: "/become-a-pet-sitter/new-york",
  },
};

export function BlogPublishCta3110({ lang }: { lang: "fr" | "en" }) {
  const t = TXT[lang];
  return (
    <aside className="mx-auto mt-12 max-w-3xl px-4" data-blog-cta-3110={lang}>
      <div className="rounded-3xl p-5 md:p-7" style={{ background: "#FFF6F2", boxShadow: "inset 0 0 0 1.5px #F6D9CF" }}>
        <p className="flex items-start gap-2 font-display text-[20px] font-extrabold leading-snug md:text-2xl" style={{ color: "#231715" }}>
          <AppIcon name="paw" size={22} color="#C92A12" />
          <span>{t.title}</span>
        </p>
        <p className="mt-2 text-[14px] leading-relaxed md:text-base" style={{ color: "#6E4F48" }}>{t.body}</p>
        <Link
          href="/#publier"
          onClick={() => trackSiteEvent("cta_click", { label: "blog_publier" })}
          className="mt-4 block w-full rounded-full px-6 py-4 text-center text-[17px] font-extrabold text-white shadow-card md:inline-block md:w-auto md:px-8"
          style={{ background: "linear-gradient(135deg,#C92A12,#9E1F0B)" }}
        >
          {t.cta}
        </Link>
        <p className="mt-3 text-[13px] font-bold">
          <Link href={t.sitterHref} className="underline-offset-2 hover:underline" style={{ color: "#1E4FB0" }} onClick={() => trackSiteEvent("cta_click", { label: "blog_gardien" })}>
            {t.sitter}
          </Link>
        </p>
      </div>
    </aside>
  );
}

export default BlogPublishCta3110;
