import type { Metadata } from "next";
import Link from "next/link";

// v531 — SEO : article statique « prix pet sitter » (requête à fort volume).
export const metadata: Metadata = {
  title: "Combien coûte un pet sitter en 2026 ? Tarifs garde chien & chat",
  description:
    "Garde à domicile 15-30 €/jour, promenade 10-20 €, visite 8-15 € : les vrais tarifs des pet sitters en France en 2026 et comment payer le juste prix.",
  alternates: { canonical: "https://www.hopetsit.com/blog/combien-coute-un-pet-sitter" },
};

const FAQ = [
  {
    q: "Quel est le prix moyen d'un pet sitter par jour ?",
    a: "Comptez en moyenne 15 à 30 € par jour pour une garde à domicile en France, selon la ville, la durée et le nombre d'animaux. Les tarifs sont souvent dégressifs pour les gardes longues.",
  },
  {
    q: "Combien coûte une promenade de chien ?",
    a: "Une promenade de 30 minutes à 1 heure coûte généralement entre 10 et 20 €. Beaucoup de promeneurs proposent des forfaits à la semaine plus avantageux.",
  },
  {
    q: "Le pet sitting est-il moins cher qu'une pension ?",
    a: "À prestation comparable, la garde par un particulier est souvent 30 à 50 % moins chère qu'une pension professionnelle, avec l'avantage d'un animal qui reste dans un cadre familial.",
  },
  {
    q: "Comment payer un pet sitter en toute sécurité ?",
    a: "Évitez les paiements de la main à la main sans trace. Sur HoPetSit, le paiement se fait dans l'app et n'est débloqué au pet sitter qu'une fois le service confirmé.",
  },
];

export default function ArticlePrixPetSitter() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Combien coûte un pet sitter en 2026 ?",
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
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <p className="text-sm font-semibold text-owner">Guide tarifs · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Combien coûte un pet sitter en 2026 ?
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Vous partez en week-end ou en vacances et vous cherchez quelqu'un pour
        garder votre chien ou votre chat ? Voici les fourchettes de prix
        réellement pratiquées en France, et nos conseils pour payer le juste
        tarif sans mauvaise surprise.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Les tarifs moyens en France
      </h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Service</th>
              <th className="p-4 font-bold">Fourchette</th>
              <th className="p-4 font-bold">Ce qui fait varier le prix</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Garde à domicile (jour)</td>
              <td className="p-4">15 – 30 €</td>
              <td className="p-4">Ville, nombre d'animaux, nuit incluse ou non</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Promenade (30 min – 1 h)</td>
              <td className="p-4">10 – 20 €</td>
              <td className="p-4">Durée, promenade seule ou en groupe</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Visite à domicile</td>
              <td className="p-4">8 – 15 €</td>
              <td className="p-4">Soins particuliers (médicaments, repas)</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        À Paris et dans les grandes villes, comptez plutôt le haut de la
        fourchette ; en zone rurale, le bas. Les gardes de plusieurs semaines se
        négocient presque toujours avec un tarif dégressif.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Pension, famille ou pet sitter : que choisir ?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        La pension professionnelle rassure mais coûte cher (25 à 45 €/jour) et
        change les habitudes de l'animal. La famille dépanne, mais n'est pas
        toujours disponible ni équipée. Le pet sitter combine le meilleur des
        deux : votre animal garde ses repères, vous choisissez la personne, et
        vous payez uniquement le service dont vous avez besoin.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Questions fréquentes
      </h2>
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
          Trouvez un pet sitter vérifié près de chez vous
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Profils vérifiés, avis réels, paiement sécurisé et suivi GPS de chaque
          promenade — gratuitement sur HoPetSit.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Télécharger l'app HoPetSit
        </Link>
      </div>
    </div>
  );
}
