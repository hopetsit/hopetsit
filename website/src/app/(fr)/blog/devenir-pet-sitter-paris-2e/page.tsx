import type { Metadata } from "next";
import Link from "@/components/SiteLink";

// 2026-W43 — SEO : article de recrutement ciblé sur le 2e arrondissement
// (Sentier, Bourse, les passages couverts), généré par la routine marketing
// hebdomadaire (semaine ISO impaire = recrutement). Choisi d'après le rapport
// de la semaine 42 : le 2e est le seul arrondissement encore sans aucun lien
// interne entrant au 18/10.
export const metadata: Metadata = {
  title: "Devenir pet sitter dans le 2e arrondissement de Paris : le guide",
  description:
    "Sentier, Bourse, les passages couverts : un quartier de bureaux où les chiens attendent toute la journée. Comment y trouver ses premiers clients en pet sitting.",
  alternates: {
    canonical: "https://www.hopetsit.com/blog/devenir-pet-sitter-paris-2e",
  },
};

const FAQ = [
  {
    q: "Le 2e arrondissement, c'est surtout des bureaux : y a-t-il vraiment des clients ?",
    a: "Oui, et c'est justement ce qui crée la demande : autour du Sentier et de la Bourse, de nombreux actifs travaillent toute la journée dans le quartier ou juste à côté et ne peuvent pas rentrer rompre la journée de leur chien. La promenade de midi y est une vraie habitude, pas une exception.",
  },
  {
    q: "Faut-il habiter le 2e pour y trouver des clients ?",
    a: "Non, mais être disponible à l'heure du déjeuner et connaître les rues autour du Sentier, de la Bourse ou des passages couverts rassure un propriétaire pressé qui a besoin d'une promenade fiable entre midi et deux.",
  },
  {
    q: "Combien peut-on gagner en pet sitting dans le quartier ?",
    a: "Les tarifs pratiqués à Paris tournent autour de 12 à 20 € la promenade et 20 à 30 € la garde à la journée. Deux ou trois promenades de midi régulières dans la semaine suffisent déjà à générer un revenu d'appoint stable.",
  },
  {
    q: "Quel statut choisir pour être payé légalement ?",
    a: "La plupart des pet sitters occasionnels optent pour le statut d'auto-entrepreneur, simple à créer en ligne. Pour les questions précises de cotisations ou de plafonds, mieux vaut se renseigner directement auprès de l'URSSAF ou d'un expert-comptable plutôt que de se fier à une estimation approximative.",
  },
  {
    q: "Comment décrocher sa première mission dans le 2e ?",
    a: "Un profil complet, une vraie photo et des disponibilités précises sur l'heure du déjeuner suffisent souvent à se démarquer. Mentionnez les rues que vous couvrez (Montorgueil, Réaumur, le Sentier, les Panoramas) : un propriétaire qui travaille à deux pas choisit presque toujours quelqu'un qui connaît déjà son secteur.",
  },
];

export default function ArticleParis2e() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Devenir pet sitter dans le 2e arrondissement de Paris : le guide",
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
      <p className="text-sm font-semibold text-owner">Guide par quartier · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Devenir pet sitter dans le 2e arrondissement de Paris
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Sentier, Bourse, les passages couverts : le 2e est le plus petit
        arrondissement de Paris par sa population, mais l'un des plus denses en
        bureaux. Des milliers d'actifs y travaillent chaque jour sans pouvoir
        rentrer chez eux à midi — et leur chien, lui, attend. C'est une niche
        précise, mais une niche qui revient chaque semaine, toute l'année.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Pourquoi ce quartier en particulier
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Autour du Sentier, d'anciens ateliers de confection sont devenus des
        bureaux de start-up ; vers la Bourse, ce sont des sièges d'entreprise.
        Dans les deux cas, les journées sont longues et la pause de midi est
        courte : un chien laissé seul le matin a besoin d'une promenade bien
        avant 19 h. C'est exactement ce créneau, régulier et prévisible, qui
        manque le plus de pet sitters.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        C'est aussi un arrondissement résidentiel plus discret qu'il n'y
        paraît, avec de vrais foyers autour des passages couverts et de la rue
        Montorgueil. Peu de pet sitters s'y sont encore installés : un profil
        précis sur ce secteur se fait remarquer vite.
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
              <td className="p-4 font-semibold text-ink">Promenade de midi</td>
              <td className="p-4">12 – 20 €</td>
              <td className="p-4">30 min à 1 h</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Visite à domicile (chat)</td>
              <td className="p-4">8 – 15 €</td>
              <td className="p-4">20 à 30 min</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Garde à la journée</td>
              <td className="p-4">20 – 30 €</td>
              <td className="p-4">Journée, sans nuit</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        La promenade de midi se négocie en général au même tarif qu'une
        promenade classique : ce qui change, c'est la régularité du créneau,
        pas le prix.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Combien à la fin du mois
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Deux promenades de midi par jour à 15 €, trois jours par semaine, c'est
        déjà 90 € par semaine pour un peu plus d'une heure sur la pause
        déjeuner — soit près de 360 € par mois sans toucher à vos soirées ni à
        vos week-ends. Avec trois ou quatre clients réguliers du quartier, qui
        réservent le même créneau chaque semaine, ce chiffre grimpe vite.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Ce qui compte ici n'est pas le nombre de clients, mais la régularité
        du rendez-vous : un actif qui travaille au Sentier a besoin de vous à
        la même heure, presque tous les jours de la semaine.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Comment trouver ses premiers clients dans le quartier
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Soyez précis sur les rues que vous couvrez (Montorgueil, Réaumur, le
        Sentier, les Panoramas) et sur votre disponibilité entre midi et deux :
        c'est exactement ce que cherche un propriétaire qui travaille à côté.
        Complétez votre profil avec une vraie photo et une présentation
        honnête de votre expérience avec les animaux.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Votre première mission compte double : elle vous donne votre premier
        avis, qui rassure ensuite tous les propriétaires suivants. Démarrez
        avec des visites pour chats ou de petits chiens si vous débutez, avant
        d'accepter des gardes plus longues.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Quel statut pour être payé légalement
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        La plupart des pet sitters occasionnels choisissent le statut
        d'auto-entrepreneur, qui se crée gratuitement en ligne et se cumule
        facilement avec un emploi salarié ou des études. Pour les questions
        précises de cotisations ou de plafonds, renseignez-vous directement
        auprès de l'URSSAF ou d'un expert-comptable : les règles évoluent et
        méritent une réponse à jour plutôt qu'une estimation approximative.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Passer par un cadre où le paiement est sécurisé et tracé, comme{" "}
        <Link
          href="/blog/devenir-pet-sitter-combien-ca-rapporte"
          className="font-semibold text-owner"
        >
          notre guide sur les revenus du pet sitting
        </Link>{" "}
        le détaille, évite aussi les malentendus avec des paiements de la main
        à la main.
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
          Devenez pet sitter dans le 2e
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Inscription gratuite, vous fixez vos tarifs et vos disponibilités.
          Paiement sécurisé, profil vérifié et suivi GPS de chaque promenade.
        </p>
        <Link
          href="/devenir-petsitter/paris-2"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Devenir pet sitter dans le 2e
        </Link>
        <p className="mt-3 text-xs text-ink-soft">
          Vous voulez connaître les tarifs ailleurs à Paris ?{" "}
          <Link href="/blog/tarif-promeneur-de-chien-paris" className="underline">
            Voir les prix des promeneurs à Paris
          </Link>
        </p>
      </div>
    </div>
  );
}
