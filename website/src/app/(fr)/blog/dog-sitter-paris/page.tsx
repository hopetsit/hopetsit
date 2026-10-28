import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// 28/10/2026 (GUS) — article de la semaine choisi sur la demande mesurée dans la Search
// Console (28 j, France, 29/09 → 26/10) : « dog sitter paris » 51 affichages (16e place),
// « dogsitting paris » 39 (38e), « dog sitting paris » 24 (25e) = 114 affichages, 0 clic,
// tous sur /garde-animaux/paris. Aucune page du site n'expliquait le mot « dog sitter »
// ni les formules qu'il recouvre. Texte vrai, aucun tarif inventé : chaque gardien fixe
// son prix dans l'app, et les fourchettes de prix restent dans les guides déjà en ligne.
const URL = "https://www.hopetsit.com/blog/dog-sitter-paris";
const TITLE = "Dog sitter à Paris : ce qu'il fait et comment en trouver un";
const DESCRIPTION =
  "Un dog sitter garde ou promène votre chien quand vous n'êtes pas là. Garde chez lui ou chez vous, visites, promenades : les 4 formules à Paris et comment choisir un dog sitter de confiance près de chez vous.";
const HEADLINE = "Dog sitter à Paris : ce qu'il fait, les 4 formules et comment en trouver un";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  alternates: { canonical: URL },
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    url: URL,
    type: "article",
    locale: "fr_FR",
    siteName: "HoPetSit",
    images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }],
  },
};

const FAQ = [
  {
    q: "Dog sitter, pet sitter, promeneur : quelle différence ?",
    a: "« Dog sitter » est simplement le mot anglais pour la personne qui garde un chien. Un pet sitter garde aussi les chats et les autres animaux. Un promeneur, lui, ne fait que les sorties : il vient chercher le chien, le promène et le ramène.",
  },
  {
    q: "Combien coûte un dog sitter à Paris ?",
    a: "Il n'y a pas de prix unique : il dépend de la formule (promenade, visite, journée, nuit), de la durée et du nombre d'animaux. Sur HoPetSit, chaque dog sitter fixe son tarif et vous voyez le total avant de confirmer. Nos guides des tarifs donnent les fourchettes courantes à Paris.",
  },
  {
    q: "Mon chien va-t-il dormir chez le dog sitter ?",
    a: "C'est vous qui choisissez : garde chez le dog sitter, ou garde chez vous avec un dog sitter qui vient dormir sur place. Précisez-le dans votre demande, les dog sitters qui répondent savent ce que vous attendez.",
  },
  {
    q: "Comment savoir si mon chien a bien été promené ?",
    a: "Pendant la prestation, le suivi GPS PawFollow montre la promenade en direct sur la carte, et le chat de l'app permet d'échanger des photos avec le dog sitter.",
  },
  {
    q: "Que faire si je dois annuler ?",
    a: "Prévenez le dog sitter le plus tôt possible par le chat de l'app. HoPetSit prévoit une annulation possible jusqu'à 72 heures avant le début de la garde.",
  },
];

const FORMULES = [
  {
    t: "La garde chez le dog sitter",
    d: "Votre chien vit quelques jours chez le dog sitter, dans son appartement ou sa maison. C'est la formule la plus demandée pour un week-end ou des vacances : le chien n'est jamais seul et garde un rythme de sorties normal.",
  },
  {
    t: "La garde chez vous",
    d: "Le dog sitter s'installe chez vous, souvent pour la nuit. Votre chien garde ses repères, son panier, ses horaires. Utile pour un chien âgé, anxieux, ou quand vous avez aussi un chat.",
  },
  {
    t: "Les visites à domicile",
    d: "Le dog sitter passe une ou plusieurs fois par jour : repas, eau fraîche, sortie, un peu de compagnie. Cela convient à un chien adulte calme pour une absence courte, pas à un chiot.",
  },
  {
    t: "La promenade",
    d: "Une sortie de 30 minutes à une heure, souvent à midi pendant votre journée de travail. C'est le métier du promeneur de chien, et c'est la solution quand votre chien reste seul toute la journée.",
  },
];

export default function ArticleDogSitterParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "fr-FR",
        mainEntityOfPage: URL,
        datePublished: "2026-10-28",
        image: { "@type": "ImageObject", url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630 },
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: {
          "@type": "Organization",
          name: "HoPetSit",
          url: "https://www.hopetsit.com",
          logo: { "@type": "ImageObject", url: "https://www.hopetsit.com/logo.png" },
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
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">Guide pratique · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Dog sitter à Paris : ce qu'il fait, les 4 formules et comment en trouver un
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        À Paris, on dit souvent « dog sitter » plutôt que « gardien de chien ». Derrière ce mot se
        cachent pourtant des services assez différents : garder votre chien plusieurs jours, venir
        le nourrir, ou simplement le sortir à midi. Voici ce que fait un dog sitter, quelle formule
        choisir selon votre situation, et comment trouver quelqu'un de confiance près de chez vous.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Un dog sitter, c'est quoi exactement ?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Un dog sitter est une personne qui s'occupe de votre chien quand vous ne pouvez pas le faire :
        un déplacement professionnel, un week-end, des vacances, ou de longues journées de travail.
        Ce n'est pas une pension : le chien est gardé par une seule personne, chez elle ou chez vous,
        souvent avec très peu d'autres animaux. Pour beaucoup de chiens de ville, habitués à leur
        quartier et à leurs habitudes, c'est nettement moins stressant qu'un chenil.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Concrètement, le dog sitter fait ce que vous feriez : les repas aux heures habituelles, l'eau
        fraîche, les sorties, le jeu, un traitement s'il y en a un, et il vous donne des nouvelles.
        Il s'engage aussi à vous prévenir tout de suite en cas de souci et à contacter votre
        vétérinaire si besoin.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Les 4 formules d'un dog sitter à Paris
      </h2>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {FORMULES.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        Pour une absence de deux ou trois jours, notre guide{" "}
        <Link href="/blog/faire-garder-son-chien-le-week-end-a-paris" className="font-semibold text-owner underline">
          faire garder son chien le week-end à Paris
        </Link>{" "}
        détaille l'organisation. Si votre chien reste seul pendant que vous travaillez, lisez plutôt{" "}
        <Link href="/blog/chien-seul-toute-la-journee-paris" className="font-semibold text-owner underline">
          la promenade de midi
        </Link>
        .
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Ce qui compte vraiment à Paris
      </h2>
      <ul className="mt-4 space-y-2">
        {[
          "La distance : un dog sitter à quelques rues de chez vous, c'est un trajet court pour déposer le chien, et des sorties dans des rues qu'il connaît déjà.",
          "Le logement : un studio au 5e sans ascenseur ne convient pas à tous les chiens. Demandez où votre chien dormira et où il sortira.",
          "Les autres animaux : y a-t-il déjà un chien ou un chat chez le dog sitter ? C'est une bonne ou une mauvaise nouvelle selon le caractère du vôtre.",
          "Les parcs et les bois : beaucoup de jardins parisiens limitent l'accès aux chiens. Un dog sitter du quartier sait où aller ; notre guide des promenades à Paris vous aide à vérifier.",
          "Les papiers : l'identification (puce ou tatouage) est obligatoire pour un chien en France. Donnez au dog sitter le carnet de santé et le numéro de votre vétérinaire.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Combien ça coûte ?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Le prix d'un dog sitter dépend de la formule, de la durée et du nombre d'animaux : une
        promenade d'une demi-heure ne se compare pas à une semaine de garde avec nuits. Sur HoPetSit,
        chaque dog sitter fixe lui-même son tarif, et vous voyez le prix total avant de confirmer. Pour
        avoir des repères, consultez{" "}
        <Link href="/blog/combien-coute-un-pet-sitter" className="font-semibold text-owner underline">
          combien coûte un pet sitter
        </Link>{" "}
        et{" "}
        <Link href="/blog/tarif-promeneur-de-chien-paris" className="font-semibold text-owner underline">
          le tarif d'un promeneur de chien à Paris
        </Link>
        .
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Trouver un dog sitter près de chez vous avec HoPetSit
      </h2>
      <ol className="mt-4 space-y-3">
        {[
          "Publiez votre demande gratuitement : le chien, les dates, la formule voulue (garde, visites ou promenade) et votre arrondissement.",
          "Les dog sitters et promeneurs proches reçoivent votre demande et vous répondent avec leur prix.",
          "Comparez leurs profils et leurs avis, discutez avec eux dans le chat, et proposez une rencontre avec votre chien avant la garde.",
          "Choisissez et payez dans l'app. Le paiement est sécurisé et n'est reversé au dog sitter qu'une fois votre chien récupéré.",
        ].map((t, i) => (
          <li key={t} className="flex gap-3 leading-relaxed text-ink-muted">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-owner text-sm font-bold text-white">
              {i + 1}
            </span>
            <span>{t}</span>
          </li>
        ))}
      </ol>
      <p className="mt-6 leading-relaxed text-ink-muted">
        Pour bien choisir entre plusieurs réponses, notre guide{" "}
        <Link href="/blog/choisir-un-pet-sitter-de-confiance-a-paris" className="font-semibold text-owner underline">
          choisir un pet sitter de confiance à Paris
        </Link>{" "}
        liste les questions à poser à la rencontre.
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

      <ParisGuidesLinks current="/blog/dog-sitter-paris" />

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Trouvez un dog sitter près de chez vous
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Garde, visites ou promenade, dans les 20 arrondissements de Paris et en Île-de-France.
        </p>
        <Link
          href="/garde-animaux/paris"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Trouver un dog sitter à Paris
        </Link>
      </div>
    </div>
  );
}
