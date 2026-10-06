import type { Metadata } from "next";
import Link from "next/link";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// 2026-W40 — SEO FR, angle PROPRIÉTAIRES (semaine ISO paire). Angle non
// encore couvert par les autres articles Paris : comment VÉRIFIER un pet
// sitter avant de lui confier son animal (identité, avis, paiement, preuve
// de la prestation), plutôt que le prix ou une occasion précise.
export const metadata: Metadata = {
  title: "Comment choisir un pet sitter de confiance à Paris : le guide",
  description:
    "Profil vérifié, avis, rencontre préalable, paiement sécurisé, suivi GPS : ce qu'il faut vérifier avant de confier son chien ou son chat à un pet sitter à Paris.",
  alternates: {
    canonical:
      "https://www.hopetsit.com/blog/choisir-un-pet-sitter-de-confiance-a-paris",
  },
};

const FAQ = [
  {
    q: "Comment savoir si un pet sitter est réellement fiable ?",
    a: "Regardez d'abord s'il a des avis laissés après des réservations réellement payées sur la plateforme, pas seulement une note affichée sans contexte. Un profil complet (présentation, tarifs clairs, disponibilités à jour) et une pièce d'identité vérifiée sont de bons signaux. Le bouche-à-oreille local compte aussi : un sitter déjà actif dans votre arrondissement a souvent des habitués.",
  },
  {
    q: "Faut-il rencontrer le pet sitter avant de réserver ?",
    a: "Oui, autant que possible. Un premier échange, en vrai ou en vidéo, permet de transmettre les informations qui comptent vraiment : alimentation, traitement en cours, comportement avec les autres animaux. Un quart d'heure suffit, et c'est souvent ce qui évite le plus de mauvaises surprises.",
  },
  {
    q: "Comment être sûr que mon chien a vraiment été promené ?",
    a: "Le suivi GPS en direct (PawFollow dans l'app HoPetSit) montre la promenade sur une carte pendant qu'elle se déroule, avec le trajet et la durée — pas seulement un message disant que tout s'est bien passé.",
  },
  {
    q: "Le paiement est-il sécurisé ?",
    a: "Ne payez jamais la totalité en espèces avant la prestation. Sur une plateforme comme HoPetSit, le paiement est bloqué dès la réservation confirmée et n'est versé au sitter qu'après la garde ou la promenade effectuée, ce qui protège les deux parties.",
  },
  {
    q: "Que faire si la garde ne s'est pas bien passée ?",
    a: "Un cadre où les échanges et le paiement sont tracés (messages dans l'app, réservation horodatée) donne de quoi contacter le service client et faire valoir la situation, ce qu'un arrangement de la main à la main ne permet pas.",
  },
];

export default function ArticleChoisirPetSitterParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Comment choisir un pet sitter de confiance à Paris : le guide",
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
        Comment choisir un pet sitter de confiance à Paris
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Confier son chien ou son chat à quelqu'un qu'on ne connaît pas, même
        pour une heure de promenade, demande un minimum de garanties. À
        Paris, l'offre grandit vite dans certains quartiers et reste rare
        dans d'autres : voici ce qu'il faut vraiment vérifier avant de
        réserver, au-delà d'une jolie photo de profil.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Un profil ne suffit pas : regardez les avis
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Une note affichée seule ne dit rien de la régularité d'un sitter.
        Cherchez des avis rattachés à de vraies réservations terminées, avec
        quelques détails concrets (ponctualité, comportement de l'animal au
        retour), plutôt qu'une simple étoile. Un sitter qui a déjà quelques
        réservations dans votre{" "}
        <Link href="/garde-animaux/paris-9" className="font-semibold text-owner underline">
          arrondissement
        </Link>{" "}
        connaît en général déjà les parcs et les trajets du quartier, ce qui
        compte autant que la note elle-même.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Vérifiez aussi que l'identité du sitter a bien été contrôlée par la
        plateforme, et pas seulement déclarée. Un profil complet — tarifs
        clairs, disponibilités à jour, présentation honnête — en dit souvent
        plus long qu'une longue liste d'étoiles sans contexte. Nous avons
        détaillé les prix réellement pratiqués dans notre guide sur le{" "}
        <Link href="/blog/tarif-promeneur-de-chien-paris" className="font-semibold text-owner underline">
          tarif d'un promeneur de chien à Paris
        </Link>
        , utile pour repérer un prix anormalement bas.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        La rencontre préalable, l'étape qu'on saute trop souvent
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Un échange avant la première garde, en vrai ou en vidéo, change tout.
        C'est le moment pour transmettre ce qui compte réellement : les
        horaires de repas, un traitement en cours, la réaction de votre
        animal face à d'autres chiens au parc ou face à un inconnu qui sonne
        à la porte. Un quart d'heure suffit, et c'est souvent ce qui évite le
        plus de malentendus — bien plus qu'un long message échangé la
        veille.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        C'est aussi l'occasion de poser des questions concrètes : que se
        passe-t-il en cas d'imprévu, le sitter accepte-t-il de garder deux
        animaux à la fois, comment se déroule une garde pendant un{" "}
        <Link
          href="/blog/faire-garder-son-chien-le-week-end-a-paris"
          className="font-semibold text-owner underline"
        >
          week-end
        </Link>{" "}
        ou une absence plus longue.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Paiement sécurisé et preuve de la prestation
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Ne payez jamais l'intégralité en espèces avant que la garde ou la
        promenade n'ait eu lieu : c'est le moyen le plus simple de se
        retrouver sans recours en cas de problème. Dans l'app HoPetSit, le
        paiement est bloqué au moment de la réservation et n'est versé au
        sitter qu'une fois l'animal rendu — jamais avant.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Pour les promenades, le suivi en direct (PawFollow) affiche le trajet
        sur une carte pendant qu'il se déroule, avec la durée réelle. « Tout
        s'est bien passé » devient une preuve plutôt qu'une simple formule,
        et c'est ce qui distingue un service encadré d'un arrangement de
        particulier à particulier sans aucune trace.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Trouver un sitter près de chez soi
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        La proximité compte plus que la note affichée : un sitter à vingt
        minutes à pied connaît mieux les habitudes de votre rue qu'un profil
        très bien noté mais situé à l'autre bout de Paris. Chaque
        arrondissement a son propre profil de demande — certains, comme le
        9e entre Pigalle et les Grands Boulevards, comptent surtout des chats
        et de petits chiens en appartement, d'autres privilégient les
        grandes promenades au bois. Cherchez d'abord dans votre quartier
        avant d'élargir.
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

      <ParisGuidesLinks current="/blog/choisir-un-pet-sitter-de-confiance-a-paris" />

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Trouvez un pet sitter vérifié près de chez vous
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Profils vérifiés, avis vérifiés, paiement sécurisé et suivi GPS de
          chaque promenade, partout à Paris et en Île-de-France.
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
