import type { Metadata } from "next";
import Link from "next/link";

// v548 — SEO Paris, angle PROPRIÉTAIRE (semaine paire) : le chien seul toute
// la journée pendant que son maître travaille — la promenade de midi.
export const metadata: Metadata = {
  title: "Chien seul toute la journée à Paris : la solution de la promenade de midi",
  description:
    "Votre chien reste seul pendant vos journées de bureau ? La promenade de midi à 12-20 € résout la plupart des problèmes de comportement. Comment bien choisir son promeneur à Paris.",
  alternates: {
    canonical: "https://www.hopetsit.com/blog/chien-seul-toute-la-journee-paris",
  },
};

const FAQ = [
  {
    q: "Combien de temps un chien peut-il rester seul dans la journée ?",
    a: "4 à 6 heures maximum pour un chien adulte en bonne santé, moins pour un chiot ou un chien âgé. Au-delà, le risque de mal-être, d'accidents propreté et de destruction augmente nettement.",
  },
  {
    q: "Combien coûte une promenade de midi à Paris ?",
    a: "Comptez 12 à 20 € pour une sortie de 30 minutes à 1 heure, selon l'arrondissement et la durée. Beaucoup de propriétaires réservent le même promeneur plusieurs fois par semaine, à horaire fixe.",
  },
  {
    q: "Comment vérifier qu'un promeneur inconnu est fiable ?",
    a: "Regardez son profil (identité vérifiée, avis d'autres propriétaires), échangez par message avant de réserver, et proposez une courte rencontre avant la première sortie. Un bon promeneur accepte toujours ce temps d'échange.",
  },
  {
    q: "Peut-on suivre la promenade en direct ?",
    a: "Oui, c'est justement ce qui rassure le plus les propriétaires qui travaillent : un suivi GPS en direct montre le trajet parcouru et confirme que la sortie a bien eu lieu, sans avoir à appeler ou à rentrer plus tôt.",
  },
  {
    q: "Faut-il réserver le même promeneur chaque semaine ?",
    a: "Ce n'est pas obligatoire mais c'est ce qui fonctionne le mieux. Un chien s'habitue vite à un visage familier et à un horaire régulier, et le promeneur connaît ses habitudes, ses peurs et son itinéraire préféré.",
  },
];

export default function ArticleChienSeulJourneeParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline:
          "Chien seul toute la journée à Paris : la solution de la promenade de midi",
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
      <p className="text-sm font-semibold text-owner">Guide propriétaire · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Chien seul toute la journée à Paris : la solution de la promenade de midi
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        8 h de bureau, un trajet dans chaque sens, et un chien seul dans un
        appartement parisien depuis le matin : c'est le quotidien de la
        majorité des propriétaires de la capitale. La bonne nouvelle, c'est
        qu'il existe une solution simple et déjà largement utilisée — la
        promenade de midi.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Le vrai problème n'est pas l'absence, c'est sa durée
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Un chien adulte en bonne santé supporte sans difficulté quelques
        heures seul. Le problème apparaît quand cette durée dépasse 6 à 8
        heures d'affilée, sans coupure : besoins naturels retenus trop
        longtemps, ennui, aboiements qui dérangent les voisins, parfois de la
        destruction. Ce ne sont pas des « caprices » — c'est une journée trop
        longue sans sortie.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Casser la journée en deux, plutôt que de tout changer
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Pas besoin de changer de rythme de vie ou de culpabiliser : une seule
        sortie au milieu de la journée suffit, la plupart du temps, à
        transformer une longue absence en deux demi-journées largement
        supportables. Un promeneur passe chez vous — vous n'avez pas besoin
        d'être présent — sort votre chien 30 minutes à 1 heure, lui laisse de
        l'eau fraîche, et repart. Vous retrouvez un chien fatigué et détendu
        le soir, plutôt qu'un chien en manque de sortie.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        C'est aujourd'hui l'un des services les plus demandés à Paris, en
        particulier dans les arrondissements où les appartements sont petits
        et les trajets domicile-travail longs — voir{" "}
        <Link href="/blog/tarif-promeneur-de-chien-paris" className="font-semibold text-owner underline">
          les tarifs pratiqués par les promeneurs parisiens
        </Link>
        .
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Bien choisir son promeneur, sans y passer la journée
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Trois réflexes suffisent. D'abord, un profil complet : identité
        vérifiée, avis laissés par d'autres propriétaires, description
        honnête de son expérience avec les chiens. Ensuite, un échange avant
        la première réservation — quelques messages suffisent pour sentir si
        le courant passe. Enfin, une courte rencontre avant la toute première
        sortie, pour présenter votre chien, ses habitudes et son parcours
        habituel. Pour trouver un coin où promener sereinement en dehors des
        horaires de bureau,{" "}
        <Link href="/blog/promener-son-chien-a-paris" className="font-semibold text-owner underline">
          notre guide des meilleurs endroits pour promener son chien à Paris
        </Link>{" "}
        reste utile même pour un promeneur professionnel.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Combien ça coûte réellement
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Une promenade de 30 minutes à 1 heure coûte généralement 12 à 20 €
        à Paris, selon l'arrondissement et la durée choisie. La plupart des
        propriétaires réservent 2 à 3 sorties par semaine, aux mêmes jours et
        aux mêmes heures : le budget mensuel tourne alors autour de 100 à
        200 €, pour un chien qui ne passe plus jamais 8 heures d'affilée sans
        sortir.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Savoir que la sortie a vraiment eu lieu
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        C'est souvent la vraie inquiétude derrière la question du prix :
        confier son chien à quelqu'un qu'on ne peut pas superviser depuis le
        bureau. Un suivi GPS en direct pendant la promenade règle ce
        problème simplement — vous voyez le trajet parcouru en temps réel, et
        vous recevez une confirmation dès que la sortie est terminée, sans
        avoir à appeler ni à écourter une réunion.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Et si vous avez vous-même un peu de temps libre en journée — étudiant,
        télétravail partiel, horaires flexibles — c'est exactement le service
        que d'autres propriétaires de votre quartier recherchent :{" "}
        <Link href="/devenir-petsitter/paris-11" className="font-semibold text-owner underline">
          voir comment devenir promeneur à Paris
        </Link>
        .
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
          Trouvez un promeneur vérifié près de chez vous
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Profils vérifiés, avis réels, paiement sécurisé et suivi GPS en
          direct de chaque promenade — gratuit à l'inscription sur HoPetSit.
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
