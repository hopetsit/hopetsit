import type { Metadata } from "next";
import Link from "next/link";

// v535 — SEO Paris : tarifs promeneur de chien (requête transactionnelle).
export const metadata: Metadata = {
  title: "Combien coûte un promeneur de chien à Paris en 2026 ?",
  description:
    "Promenade de chien à Paris : 12 à 20 € la balade de 30 min à 1 h, forfaits dégressifs à la semaine. Ce qui fait varier les prix et comment payer en sécurité.",
  alternates: { canonical: "https://www.hopetsit.com/blog/tarif-promeneur-de-chien-paris" },
};

const FAQ = [
  {
    q: "Quel est le prix d'une promenade de chien à Paris ?",
    a: "Comptez 12 à 20 € pour une balade de 30 minutes à 1 heure dans Paris intra-muros. Les promenades en solo (votre chien uniquement) se situent en haut de fourchette, les balades partagées en bas.",
  },
  {
    q: "Existe-t-il des forfaits à la semaine ?",
    a: "Oui — la plupart des promeneurs proposent des forfaits 3 ou 5 balades par semaine, avec 20 à 30 % de réduction par balade. C'est la formule des maîtres qui travaillent en présentiel.",
  },
  {
    q: "Le promeneur vient-il chercher le chien chez moi ?",
    a: "Oui, c'est l'usage : le promeneur récupère votre chien à domicile et le ramène après la balade. Sur HoPetSit, la remise se confirme par photo et code — vous savez exactement quand votre chien part et revient.",
  },
  {
    q: "Comment savoir si la balade a vraiment eu lieu ?",
    a: "C'est LA bonne question. Avec le suivi PawFollow de HoPetSit, vous voyez le trajet en direct sur la carte, du départ au retour. Plus besoin de faire confiance à l'aveugle.",
  },
];

export default function ArticleTarifPromeneurParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Combien coûte un promeneur de chien à Paris en 2026 ?",
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
      <p className="text-sm font-semibold text-owner">Guide tarifs · Paris · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Combien coûte un promeneur de chien à Paris ?
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Journées longues au bureau, imprévus, canicule : faire promener son
        chien à Paris est devenu un vrai service du quotidien. Voici les prix
        réellement pratiqués en 2026, et comment éviter les mauvaises
        surprises.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Les tarifs parisiens</h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Formule</th>
              <th className="p-4 font-bold">Prix constaté</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Balade partagée (30-45 min)</td>
              <td className="p-4">12 – 15 €</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Balade solo (30 min – 1 h)</td>
              <td className="p-4">15 – 20 €</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Forfait 5 balades/semaine</td>
              <td className="p-4">−20 à −30 % par balade</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        Sur HoPetSit, chaque promeneur fixe librement son tarif — vous comparez
        les profils de votre quartier, leurs avis et leurs prix avant de
        réserver.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Questions fréquentes</h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <p className="mt-10 leading-relaxed text-ink-muted">
        Envie d'arrondir vos fins de mois plutôt que de payer ? Paris manque de
        promeneurs :{" "}
        <Link href="/devenir-petsitter/paris" className="font-semibold text-owner">
          devenez promeneur de chiens sur HoPetSit
        </Link>{" "}
        — vous fixez vos tarifs et vos horaires.
      </p>

      <div className="mt-10 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Trouvez votre promeneur à Paris
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Profils vérifiés, avis réels, paiement sécurisé et balade suivie en
          GPS — gratuitement sur HoPetSit.
        </p>
        <Link href="/download" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Télécharger l'app HoPetSit
        </Link>
      </div>
    </div>
  );
}
