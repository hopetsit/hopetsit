import type { Metadata } from "next";
import Link from "next/link";

// v531 — SEO : index du blog (pages 100% statiques côté serveur pour que
// Google indexe le texte — contrairement aux pages app qui sont client-side).
export const metadata: Metadata = {
  title: "Le blog HoPetSit — conseils garde & promenade d'animaux",
  description:
    "Tarifs des pet sitters, conseils pour faire garder votre chien ou chat, promenades : les guides pratiques de l'équipe HoPetSit.",
  alternates: { canonical: "https://www.hopetsit.com/blog" },
};

const POSTS = [
  {
    slug: "combien-coute-un-pet-sitter",
    lang: "🇫🇷",
    title: "Combien coûte un pet sitter en 2026 ? Tarifs garde chien & chat",
    excerpt:
      "Garde à domicile, visites, promenades : les fourchettes de prix réelles en France et comment payer le juste tarif.",
  },
  {
    slug: "faire-garder-son-chien-pendant-les-vacances",
    lang: "🇫🇷",
    title: "Faire garder son chien pendant les vacances : le guide complet",
    excerpt:
      "Pension, famille, pet sitter à domicile : les options comparées, les pièges à éviter et notre check-list avant le départ.",
  },
  {
    slug: "how-much-does-a-dog-walker-cost",
    lang: "🇬🇧",
    title: "How much does a dog walker cost in 2026?",
    excerpt:
      "Typical dog walking rates, what changes the price, and how to find a trusted walker near you.",
  },
];

export default function BlogIndexPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight text-ink md:text-5xl">
        Le blog HoPetSit
      </h1>
      <p className="mx-auto mt-4 max-w-xl text-center text-lg text-ink-muted">
        Conseils pratiques pour faire garder et promener vos animaux en toute
        confiance.
      </p>
      <div className="mt-14 space-y-6">
        {POSTS.map((p) => (
          <Link
            key={p.slug}
            href={`/blog/${p.slug}`}
            className="block rounded-2xl border border-ink/5 bg-white p-6 shadow-card transition hover:border-owner/40"
          >
            <div className="text-xs text-ink-soft">{p.lang}</div>
            <h2 className="mt-1 text-lg font-bold text-ink">{p.title}</h2>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{p.excerpt}</p>
            <span className="mt-3 inline-block text-sm font-semibold text-owner">
              Lire l'article →
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}
