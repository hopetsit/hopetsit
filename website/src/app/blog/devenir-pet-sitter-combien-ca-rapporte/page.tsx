import type { Metadata } from "next";
import Link from "next/link";

// v546 — SEO : article statique « devenir pet sitter / revenus ». Cible le
// RECRUTEMENT de prestataires (le vrai goulot : une ville sans sitters ne
// convertit aucun propriétaire). Requêtes visées : « devenir pet sitter »,
// « gagner de l'argent avec les animaux », « salaire pet sitter ».
export const metadata: Metadata = {
  title: "Devenir pet sitter en 2026 : combien ça rapporte vraiment ?",
  description:
    "Revenus réels d'un pet sitter en France : 15-30 € la garde, 12-20 € la promenade. Comment démarrer sans diplôme, quel statut choisir et combien espérer par mois.",
  alternates: {
    canonical:
      "https://www.hopetsit.com/blog/devenir-pet-sitter-combien-ca-rapporte",
  },
};

const FAQ = [
  {
    q: "Faut-il un diplôme pour devenir pet sitter ?",
    a: "Non. Aucun diplôme n'est exigé pour garder ou promener des animaux de compagnie à titre occasionnel. Ce qui compte, c'est votre sérieux, vos disponibilités et les avis que vous accumulez. Une formation type ACACED devient utile si vous en faites votre activité principale.",
  },
  {
    q: "Combien peut-on gagner par mois comme pet sitter ?",
    a: "Une activité d'appoint de quelques heures par semaine rapporte généralement 150 à 400 € par mois. En y consacrant plusieurs demi-journées, avec des gardes de nuit et des clients réguliers, on dépasse souvent 800 € mensuels.",
  },
  {
    q: "Quel statut choisir pour être payé légalement ?",
    a: "Le statut d'auto-entrepreneur est le plus simple : création gratuite en ligne, cotisations proportionnelles au chiffre d'affaires, et aucune charge si vous ne gagnez rien un mois donné. Vous pouvez le cumuler avec un emploi salarié ou des études.",
  },
  {
    q: "Comment trouver ses premiers clients ?",
    a: "Créez un profil complet avec une vraie photo, une présentation honnête et des tarifs clairs. Les premières demandes viennent presque toujours de votre quartier : les propriétaires cherchent en priorité quelqu'un à moins de quinze minutes de chez eux.",
  },
  {
    q: "Est-ce risqué de garder l'animal de quelqu'un ?",
    a: "Le principal risque est le malentendu : habitudes alimentaires, traitement en cours, comportement avec les autres chiens. Une rencontre préalable et des consignes écrites règlent l'essentiel. Passez toujours par un cadre où le paiement et les échanges sont tracés.",
  },
];

export default function ArticleDevenirPetSitter() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Devenir pet sitter en 2026 : combien ça rapporte vraiment ?",
        inLanguage: "fr",
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: {
          "@type": "Organization",
          name: "HoPetSit",
          url: "https://www.hopetsit.com",
        },
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
      <p className="text-sm font-semibold text-owner">Guide revenus · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Devenir pet sitter : combien ça rapporte vraiment ?
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Garder un chat le temps d'un week-end, sortir un chien pendant que son
        maître travaille : le pet sitting est l'un des rares revenus d'appoint
        qui demande zéro investissement et zéro diplôme. Voici les montants
        réellement pratiqués en France, et ce qu'il faut savoir avant de
        commencer.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Ce que vous pouvez facturer
      </h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Prestation</th>
              <th className="p-4 font-bold">Tarif courant</th>
              <th className="p-4 font-bold">Temps passé</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Promenade de chien</td>
              <td className="p-4">12 – 20 €</td>
              <td className="p-4">30 min à 1 h</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Visite à domicile</td>
              <td className="p-4">8 – 15 €</td>
              <td className="p-4">20 à 30 min</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Garde à la journée</td>
              <td className="p-4">15 – 30 €</td>
              <td className="p-4">Journée, sans nuit</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Garde avec nuit</td>
              <td className="p-4">25 – 45 €</td>
              <td className="p-4">24 h</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        À Paris, Lyon ou Bordeaux, comptez le haut de la fourchette. En zone
        moins dense, le bas. Les gardes de plusieurs semaines se négocient
        presque toujours avec un tarif dégressif.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Combien à la fin du mois ?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Le calcul est simple et rarement présenté honnêtement, alors soyons
        concrets. Trois promenades par semaine à 15 €, c'est environ 180 € par
        mois pour six heures de marche. Deux gardes de week-end à 30 € la
        journée y ajoutent près de 240 €. Un sitter régulier, avec quelques
        clients fidèles dans son quartier, tourne autour de 400 à 600 € par
        mois — sans jamais y consacrer une journée entière.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Ce qui fait la différence n'est pas le tarif affiché, mais la
        régularité. Un propriétaire qui travaille a besoin de vous chaque
        semaine, parfois chaque jour. Deux ou trois clients réguliers valent
        mieux que vingt demandes ponctuelles.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Par où commencer
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Commencez par les animaux que vous connaissez vraiment. Si vous n'avez
        jamais tenu un grand chien en laisse, ne vous lancez pas sur des races
        puissantes : acceptez d'abord des chats, des visites à domicile ou des
        petits chiens. Votre première mission compte double, parce qu'elle vous
        donne votre premier avis.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Soignez ensuite trois choses : une photo de vous nette et souriante,
        une présentation qui dit pourquoi on peut vous confier un animal, et
        des disponibilités honnêtes. Un profil vide n'obtient jamais de
        demande, même avec des tarifs bas.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Enfin, déclarez votre activité. Le statut d'auto-entrepreneur se crée
        en ligne gratuitement et vous ne payez de cotisations que sur ce que
        vous encaissez réellement. C'est aussi ce qui rassure les propriétaires
        et vous permet d'être couvert en cas de problème.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Les erreurs qui coûtent cher
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        La première est de fixer ses prix trop bas en pensant attirer plus de
        monde. Un tarif anormalement faible inquiète plus qu'il ne rassure, et
        vous enferme ensuite dans des clients qui négocient tout. La deuxième
        est de sauter la rencontre préalable : quinze minutes chez le
        propriétaire évitent la quasi-totalité des mauvaises surprises. La
        troisième est d'accepter des paiements de la main à la main sans trace,
        qui vous laissent sans recours en cas de litige.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Questions fréquentes
      </h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div
            key={f.q}
            className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card"
          >
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Proposez vos services près de chez vous
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Inscription gratuite, vous fixez vos tarifs et vos disponibilités.
          Paiement sécurisé, profil vérifié et suivi GPS de chaque promenade.
        </p>
        <Link
          href="/devenir-petsitter/paris"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Devenir pet sitter
        </Link>
      </div>
    </div>
  );
}
