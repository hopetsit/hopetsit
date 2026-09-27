import type { Metadata } from "next";
import Link from "next/link";

// 2026-W37 — SEO : article de recrutement ciblé sur le 11e arrondissement,
// l'arrondissement le plus peuplé de Paris (généré par la routine marketing
// hebdomadaire, semaine ISO impaire = recrutement).
export const metadata: Metadata = {
  title: "Devenir pet sitter dans le 11e arrondissement de Paris : le guide",
  description:
    "Oberkampf, Bastille, République : pourquoi le 11e arrondissement est l'un des meilleurs points de départ pour devenir pet sitter à Paris, et comment trouver ses premiers clients.",
  alternates: {
    canonical: "https://www.hopetsit.com/blog/devenir-pet-sitter-paris-11e",
  },
};

const FAQ = [
  {
    q: "Pourquoi commencer dans le 11e arrondissement précisément ?",
    a: "C'est l'arrondissement le plus peuplé de Paris, avec une forte densité de petits chiens en appartement autour d'Oberkampf, de Bastille et de République. La demande de promenades et de gardes y est constante toute l'année, même en dehors des vacances scolaires.",
  },
  {
    q: "Faut-il habiter le 11e pour y trouver des clients ?",
    a: "Non, mais c'est un vrai avantage : les propriétaires cherchent presque toujours quelqu'un à moins de quinze minutes à pied de chez eux, pour pouvoir vous confier un double des clés en cas de besoin.",
  },
  {
    q: "Combien peut-on gagner en pet sitting dans le quartier ?",
    a: "Les tarifs pratiqués à Paris tournent autour de 12 à 20 € la promenade et 20 à 30 € la garde à la journée. Avec deux ou trois clients réguliers du quartier, on atteint rapidement plusieurs centaines d'euros par mois pour quelques heures par semaine.",
  },
  {
    q: "Quel statut choisir pour être payé légalement ?",
    a: "La plupart des pet sitters occasionnels optent pour le statut d'auto-entrepreneur, simple à créer en ligne. Pour les détails précis (cotisations, plafonds), mieux vaut se renseigner directement auprès de l'URSSAF ou d'un expert-comptable plutôt que de se fier à des approximations trouvées en ligne.",
  },
  {
    q: "Comment décrocher sa première mission dans le 11e ?",
    a: "Un profil complet avec une vraie photo et des disponibilités honnêtes suffit souvent. La première demande vient presque toujours d'un propriétaire du quartier qui a besoin de quelqu'un rapidement — soyez précis sur les rues ou stations de métro que vous couvrez.",
  },
];

export default function ArticleParis11e() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Devenir pet sitter dans le 11e arrondissement de Paris : le guide",
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
        Devenir pet sitter dans le 11e arrondissement de Paris
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Oberkampf, Bastille, République : le 11e est l'arrondissement le plus
        peuplé de Paris, avec des milliers de chiens et de chats qui vivent en
        appartement. C'est aussi l'un des meilleurs endroits pour se lancer en
        pet sitting, parce que la demande de promenades et de gardes y est
        constante, semaine après semaine.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Pourquoi ce quartier en particulier
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Peu de jardins privés, beaucoup de studios et de deux-pièces, des
        habitants jeunes et actifs qui travaillent en horaires de bureau :
        c'est la combinaison qui crée le plus de demande pour une promenade en
        milieu de journée. Autour de République et d'Oberkampf, les
        propriétaires ont aussi tendance à voyager fréquemment le week-end, ce
        qui génère des demandes de garde régulières.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Contrairement à des arrondissements plus résidentiels, le 11e a encore
        peu de pet sitters installés durablement : les premiers profils
        sérieux et réactifs prennent une longueur d'avance qui dure.
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
        Ces fourchettes correspondent à ce qui se pratique dans Paris intra-muros ;
        elles montent légèrement les soirs de semaine ou pour une garde
        réservée en dernière minute.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Combien à la fin du mois
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Trois promenades par semaine à 15 €, c'est environ 180 € par mois pour
        quelques heures de marche dans le quartier. Une garde de week-end à 25 €
        la journée, deux fois par mois, y ajoute 100 € de plus. Avec deux ou
        trois clients réguliers du 11e — souvent des propriétaires qui
        travaillent à proximité — on dépasse fréquemment 400 € par mois sans
        que cela demande une journée entière.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Comment trouver ses premiers clients dans le quartier
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Soyez précis sur les rues et les stations de métro que vous couvrez
        (Oberkampf, Voltaire, Charonne, Ledru-Rollin) : un propriétaire
        pressé choisit presque toujours quelqu'un qui connaît déjà son coin de
        rue plutôt qu'un profil générique « Paris ». Complétez votre profil
        avec une vraie photo et une présentation honnête de votre expérience
        avec les animaux, même si elle vient simplement d'un animal de famille.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Votre première mission compte double : elle vous donne votre premier
        avis, qui rassure ensuite tous les propriétaires suivants. N'hésitez
        pas à démarrer avec des visites pour chats ou de petits chiens si vous
        débutez, avant d'accepter des gardes plus longues.
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
        Passer par un cadre où le paiement est sécurisé et tracé, comme
        <Link href="/blog/devenir-pet-sitter-combien-ca-rapporte" className="font-semibold text-owner">
          {" "}notre guide sur les revenus du pet sitting
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
          Devenez pet sitter dans le 11e
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Inscription gratuite, vous fixez vos tarifs et vos disponibilités.
          Paiement sécurisé, profil vérifié et suivi GPS de chaque promenade.
        </p>
        <Link
          href="/devenir-petsitter/paris-11"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Devenir pet sitter dans le 11e
        </Link>
        <p className="mt-3 text-xs text-ink-soft">
          Vous cherchez plutôt un tarif clair par balade ?{" "}
          <Link href="/blog/tarif-promeneur-de-chien-paris" className="underline">
            Voir les prix des promeneurs à Paris
          </Link>
        </p>
      </div>
    </div>
  );
}
