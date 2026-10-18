import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// 2026-W42 — SEO FR, angle PROPRIÉTAIRES (semaine ISO paire). Angle suggéré
// dans le rapport de la semaine 2026-W40 (« voyager avec son animal vs le
// faire garder », non encore traité). Deux arrondissements sans AUCUN lien
// interne au 18/10 (paris-7, paris-14, vérifié par recherche dans le dépôt)
// reçoivent leur premier lien ici. Tarifs = uniquement ceux déjà publiés
// dans devenir-pet-sitter-combien-ca-rapporte (12-20 € la promenade, 15-30 €
// la garde journée, 25-45 € la garde avec nuit). Aucune affirmation
// juridique sur le transport des animaux (règles qui varient par
// compagnie/opérateur) : on renvoie se renseigner auprès du transporteur.
export const metadata: Metadata = {
  title: "Voyager avec son animal ou le faire garder à Paris : comment décider ?",
  description:
    "Emmener son chien ou son chat en voyage, ou le faire garder à Paris pendant l'absence ? Les critères concrets pour trancher, les prix réels et comment bien préparer la garde.",
  alternates: {
    canonical:
      "https://www.hopetsit.com/blog/voyager-avec-son-animal-ou-le-faire-garder",
  },
};

const FAQ = [
  {
    q: "Vaut-il mieux emmener son chien en voyage ou le faire garder ?",
    a: "Cela dépend surtout du trajet et du caractère de l'animal. Un chien calme, habitué à la voiture, s'adapte souvent bien à un déplacement court. Un trajet long, plusieurs correspondances ou un animal anxieux plaident plutôt pour une garde dans un cadre connu, chez lui ou chez un pet sitter qu'il a déjà rencontré.",
  },
  {
    q: "Les trains et les avions acceptent-ils les animaux ?",
    a: "Les règles varient selon la compagnie ou l'opérateur (poids autorisé, cage de transport, zones où l'animal doit rester dans son sac) : renseignez-vous directement auprès du transporteur avant de réserver, les conditions changent régulièrement.",
  },
  {
    q: "Combien coûte une garde à domicile à Paris pendant une absence ?",
    a: "Les tarifs courants à Paris tournent autour de 15 à 30 € pour une garde à la journée, et 25 à 45 € pour une garde avec nuit. Les promenades se négocient plutôt entre 12 et 20 € la sortie. Les séjours de plusieurs jours se discutent presque toujours avec un tarif dégressif.",
  },
  {
    q: "Et pour un chat plutôt qu'un chien ?",
    a: "Un chat voyage en général moins bien qu'un chien et s'attache fortement à son territoire. Dans la majorité des cas, le laisser chez lui avec des visites régulières d'un pet sitter est la solution la moins stressante pour lui — nous détaillons ce choix dans notre guide sur la garde de chat à Paris.",
  },
  {
    q: "Comment préparer une garde de plusieurs jours ?",
    a: "Rencontrez le sitter avant le départ, même quinze minutes, pour transmettre les habitudes de l'animal (alimentation, traitement en cours, comportement avec les autres animaux). Laissez des consignes écrites et privilégiez un paiement sécurisé dans l'app plutôt qu'un arrangement en espèces, pour garder une trace en cas de problème.",
  },
];

export default function ArticleVoyagerOuFaireGarder() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline:
          "Voyager avec son animal ou le faire garder à Paris : comment décider ?",
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
      <p className="text-sm font-semibold text-owner">Guide propriétaires · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Voyager avec son animal ou le faire garder à Paris : comment décider ?
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Un week-end prolongé, des vacances d'été ou un déplacement
        professionnel : la question revient à chaque départ. Emmener son
        chien ou son chat, ou le confier à quelqu'un de confiance pendant
        l'absence ? Il n'y a pas de bonne réponse universelle, mais des
        critères concrets pour trancher selon votre situation.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Emmener son animal : ce que ça implique vraiment
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Voyager avec un animal rassure souvent plus le propriétaire que
        l'animal lui-même. Un trajet en voiture de deux heures se passe
        généralement bien pour un chien habitué ; un vol, plusieurs
        correspondances ou une longue attente en gare sont une autre
        histoire. Les règles de transport (poids autorisé, cage, zones où
        l'animal doit rester en sac) varient selon la compagnie ou
        l'opérateur et changent régulièrement : mieux vaut les vérifier
        directement auprès du transporteur avant de réserver quoi que ce
        soit.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Il faut aussi compter le logement : tous les hébergements
        n'acceptent pas les animaux, et ceux qui le font appliquent souvent
        un supplément. Un animal âgé, malade ou simplement anxieux dans les
        environnements inconnus supporte rarement bien le changement de
        rythme d'un voyage, même court.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Le faire garder à Paris : ce que ça change
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Laisser son animal chez lui, dans son environnement habituel, avec
        ses odeurs, son panier et ses horaires de repas, est souvent ce qui
        le perturbe le moins. Dans le{" "}
        <Link href="/garde-animaux/paris-14" className="font-semibold text-owner underline">
          14e arrondissement
        </Link>{" "}
        (Montparnasse, Alésia, parc Montsouris), beaucoup de familles
        choisissent justement la garde à domicile plutôt que le déplacement
        de l'animal, pour cette raison. Les tarifs courants à Paris tournent
        autour de 15 à 30 € pour une garde à la journée et 25 à 45 € pour une
        garde avec nuit ; les promenades se négocient plutôt entre 12 et
        20 € la sortie.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Pour une absence plus longue avec des visites régulières plutôt
        qu'une présence continue — le cas typique d'un départ professionnel
        depuis le{" "}
        <Link href="/garde-animaux/paris-7" className="font-semibold text-owner underline">
          7e arrondissement
        </Link>{" "}
        (Invalides, Champ-de-Mars), où les gardes de nuit régulières sont
        fréquentes — les tarifs se discutent presque toujours à la baisse
        au-delà de quelques jours.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Les critères qui doivent vraiment trancher
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Le tempérament de l'animal compte plus que la destination. Un chien
        sociable et déjà habitué aux déplacements voyage sans trop de
        difficulté ; un chat, lui, s'attache fortement à son territoire et
        supporte très mal le changement de lieu dans la grande majorité des
        cas. La durée joue aussi : un aller-retour de deux jours se prête
        mieux au transport qu'un séjour de deux semaines, où la garde à
        domicile évite d'imposer un dépaysement prolongé.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Le type de destination compte enfin : un week-end chez des proches
        qui acceptent les animaux n'a rien à voir avec un city-trip en
        avion. Dans le doute, la garde à domicile reste la solution la plus
        simple à organiser et la moins risquée pour le bien-être de
        l'animal.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Si vous choisissez la garde : comment bien la préparer
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Rencontrez le pet sitter avant le départ, même pour un quart
        d'heure : c'est le moment pour transmettre l'alimentation, un
        traitement en cours, le comportement de l'animal face à d'autres
        animaux ou à un inconnu qui sonne à la porte. Laissez des consignes
        écrites, surtout pour un séjour de plusieurs jours.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Passez par un paiement sécurisé plutôt que des espèces versées
        d'avance : dans l'app HoPetSit, l'argent est bloqué à la réservation
        et versé au sitter seulement après la garde effectuée, et chaque
        promenade peut être suivie en direct sur une carte. Nous détaillons
        tous les points à vérifier avant de confier son animal dans notre
        guide pour{" "}
        <Link
          href="/blog/choisir-un-pet-sitter-de-confiance-a-paris"
          className="font-semibold text-owner underline"
        >
          choisir un pet sitter de confiance à Paris
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

      <ParisGuidesLinks current="/blog/voyager-avec-son-animal-ou-le-faire-garder" />

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Trouvez un pet sitter vérifié près de chez vous
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Profils vérifiés, paiement sécurisé et suivi GPS de chaque
          promenade, partout à Paris et en Île-de-France.
        </p>
        <Link
          href="/garde-animaux/paris"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Trouver un pet sitter à Paris
        </Link>
      </div>
    </div>
  );
}
