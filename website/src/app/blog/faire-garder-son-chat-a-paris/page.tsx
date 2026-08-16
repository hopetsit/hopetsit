import type { Metadata } from "next";
import Link from "next/link";

// v535 — SEO Paris : garde de chat (audience énorme, souvent oubliée des
// contenus « chien »).
export const metadata: Metadata = {
  title: "Faire garder son chat à Paris : visites à domicile ou pension ?",
  description:
    "Votre chat déteste bouger ? Visites à domicile 8-15 €, garde chez un cat sitter parisien : les options comparées, les prix et la check-list avant de partir.",
  alternates: { canonical: "https://www.hopetsit.com/blog/faire-garder-son-chat-a-paris" },
};

const FAQ = [
  {
    q: "Combien coûte une visite pour chat à Paris ?",
    a: "Comptez 8 à 15 € la visite (repas, litière, jeu et câlins). Deux visites par jour se négocient souvent en formule. Une garde complète chez un cat sitter coûte 15 à 25 € par jour.",
  },
  {
    q: "Vaut-il mieux déplacer le chat ou le laisser chez lui ?",
    a: "Dans l'immense majorité des cas : le laisser chez lui. Le chat est attaché à son territoire ; des visites quotidiennes le stressent beaucoup moins qu'un déménagement temporaire en pension.",
  },
  {
    q: "Un chat peut-il rester seul un week-end ?",
    a: "24 à 36 heures maximum avec eau et croquettes en libre-service — et encore, pour un chat adulte en bonne santé. Au-delà, il faut une visite quotidienne : litière, eau fraîche et surveillance.",
  },
  {
    q: "Comment faire confiance à un inconnu chez moi ?",
    a: "Choisissez un profil avec identité vérifiée et avis de vraies réservations, échangez par chat avant, et faites une rencontre préalable. Sur HoPetSit, le paiement n'est débloqué qu'après le service.",
  },
];

export default function ArticleGarderChatParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Faire garder son chat à Paris : visites à domicile ou pension ?",
        inLanguage: "fr",
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com" },
      },
      {
        "@type": "FAQPage",
        mainEntity: FAQ.map((f) => ({
          "@type": "Question",
          name: f.q,
          acceptedAnswer: { "@type": "Answer", text: f.a },
        })),
      },
    ],
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">Guide chat · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Faire garder son chat à Paris : le guide sans stress
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Les chats détestent deux choses : les valises et les changements. Bonne
        nouvelle : à Paris, la meilleure solution de garde est aussi la plus
        simple — quelqu'un vient chez vous. Voici comment ça marche et combien
        ça coûte.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Les deux vraies options</h2>
      <div className="mt-6 space-y-4">
        <div className="rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
          <h3 className="font-bold text-ink">🔑 Les visites à domicile (recommandé)</h3>
          <p className="mt-2 text-sm leading-relaxed text-ink-muted">
            Un cat sitter passe une à deux fois par jour : repas, eau fraîche,
            litière, jeu et câlins si votre chat est d'humeur. Il reste dans son
            royaume, vous recevez photos et nouvelles à chaque passage. C'est la
            formule préférée des vétérinaires comportementalistes.
          </p>
        </div>
        <div className="rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
          <h3 className="font-bold text-ink">🏠 La garde chez un cat sitter</h3>
          <p className="mt-2 text-sm leading-relaxed text-ink-muted">
            Pour les absences très longues ou les chats très sociables : votre
            chat est accueilli chez un passionné, sans autres animaux si besoin.
            Prévoyez ses affaires (arbre, panier, litière habituelle) pour
            adoucir la transition.
          </p>
        </div>
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Questions fréquentes</h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Des cat sitters vérifiés dans votre quartier
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Comparez les profils parisiens, lisez les vrais avis et réservez des
          visites en quelques minutes — gratuitement sur HoPetSit.
        </p>
        <Link href="/download" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Télécharger l'app HoPetSit
        </Link>
      </div>
    </div>
  );
}
