import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// 2026-W44 (marketing hebdo, dimanche) — sujet suivant non coché de
// `marketing/sujets_4poles.md` § Paris (page pilier /garde-animaux/paris#quartiers).
// Semaine ISO 44 paire → angle propriétaire. Aucun chiffre, aucune affirmation
// vétérinaire précise (vaccins, âges) : on renvoie systématiquement au vétérinaire.
const URL = "https://www.hopetsit.com/blog/premier-chiot-a-paris";
const TITLE = "Premier chiot à Paris : propreté en appartement et premières sorties";
const DESCRIPTION =
  "Apprendre la propreté à un chiot dans un appartement parisien, choisir le bon moment pour ses premières sorties et bien gérer la rue, l'ascenseur et les voisins. Le guide pratique.";
const HEADLINE = "Premier chiot à Paris : propreté en appartement et premières sorties";

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
    q: "Quand peut-on sortir un chiot dans la rue à Paris ?",
    a: "Cela dépend de son protocole de vaccination, propre à chaque chiot : c'est votre vétérinaire qui vous dira à partir de quand les sorties en extérieur sont possibles. En attendant, on peut déjà le porter dans les bras quelques minutes dans la cage d'escalier ou devant l'immeuble pour l'habituer aux bruits de la rue.",
  },
  {
    q: "Combien de temps un chiot peut-il rester sans sortir faire ses besoins ?",
    a: "Un chiot a une vessie minuscule et ne se retient pas comme un adulte : les sorties doivent être fréquentes, surtout au réveil, après les repas et après le jeu. Si vous travaillez en journée, un passage de midi fait une vraie différence les premières semaines.",
  },
  {
    q: "Les accidents en appartement sont-ils normaux ?",
    a: "Oui, presque tous les chiots en ont, même avec une éducation assidue. Ce n'est pas un échec : on nettoie sans gronder, on félicite chaleureusement quand il fait ses besoins au bon endroit, et on garde le même rythme de sorties chaque jour.",
  },
  {
    q: "Comment habituer un chiot à l'ascenseur et au hall de l'immeuble ?",
    a: "Progressivement et sans le forcer : quelques trajets courts, en le portant si besoin, en le laissant renifler le hall à son rythme. Prévenez les voisins s'il aboie ou grogne au début, la plupart comprennent très bien pour un chiot.",
  },
  {
    q: "Un promeneur peut-il s'occuper d'un chiot pendant mes journées de travail ?",
    a: "Oui, à condition qu'il connaisse bien le profil du chiot (vaccins, caractère, ce qui lui fait peur) : beaucoup de gardiens et promeneurs HoPetSit acceptent les chiots pour une sortie de midi ou une garde à la journée. Indiquez-le dans votre demande pour ne recevoir que des réponses adaptées.",
  },
];

const ETAPES = [
  {
    t: "Un coin fixe et des horaires réguliers",
    d: "Choisissez un endroit dans l'appartement (ou un balcon sécurisé) où le chiot peut faire ses besoins les premiers jours, et sortez-le toujours aux mêmes moments : au réveil, après chaque repas, après une sieste et avant le coucher. La régularité compte plus que la durée des sorties.",
  },
  {
    t: "Féliciter, jamais punir",
    d: "Un accident ne se corrige pas en gueule : le chiot ne fait pas le lien. En revanche, une friandise et une voix joyeuse juste après qu'il a fait ses besoins au bon endroit l'aident à comprendre très vite ce qu'on attend de lui.",
  },
  {
    t: "La cage d'escalier comme premier terrain d'entraînement",
    d: "Avant même les premières sorties en rue, la cage d'escalier, le hall et l'ascenseur de l'immeuble sont déjà un monde à découvrir : bruits de porte, autres habitants, sol qui change. Quelques minutes par jour suffisent pour qu'il s'habitue sans être submergé.",
  },
  {
    t: "La rue, par petites doses",
    d: "Une fois le feu vert du vétérinaire obtenu, les premières sorties doivent rester courtes et calmes : un trottoir tranquille plutôt qu'un carrefour animé, pas trop de chiens à la fois, et toujours la laisse. L'idée est de construire des souvenirs rassurants, pas de tout découvrir en une fois.",
  },
];

export default function ArticlePremierChiotParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "fr-FR",
        mainEntityOfPage: URL,
        datePublished: "2026-11-01",
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
        mainEntity: FAQ.map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })),
      },
    ],
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">Guide pratique · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Premier chiot à Paris : propreté en appartement et premières sorties
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Accueillir un chiot dans un 25 m² du 11e ou un deux-pièces en étage avec ascenseur capricieux,
        ce n'est pas tout à fait comme l'accueillir dans une maison avec jardin. Pas de panique : des
        milliers de chiots grandissent très bien dans des appartements parisiens chaque année. Voici
        comment organiser la propreté les premières semaines, et comment préparer sereinement ses
        toutes premières sorties dans la rue.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">La propreté commence avant la rue</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Beaucoup de propriétaires attendent les premières sorties pour commencer l'apprentissage de
        la propreté. En réalité, tout commence dans l'appartement, souvent plusieurs semaines avant
        que le chiot ne mette une patte sur le trottoir. L'objectif des premiers jours n'est pas la
        perfection, mais la régularité : un chiot qui sort toujours aux mêmes moments comprend plus
        vite ce qu'on attend de lui qu'un chiot qu'on sort « quand on a le temps ».
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Si vous travaillez toute la journée, c'est souvent le point le plus difficile à tenir : un
        chiot laissé seul huit heures accumule les accidents, non par bêtise mais parce que son corps
        ne peut tout simplement pas attendre aussi longtemps. Un passage à midi, par un proche ou par
        un promeneur, change beaucoup de choses les premières semaines — voir notre guide sur{" "}
        <Link href="/blog/chien-seul-toute-la-journee-paris" className="font-semibold text-owner underline">
          le chien seul toute la journée à Paris
        </Link>
        .
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Les 4 réflexes qui font la différence</h2>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {ETAPES.map((e) => (
          <div key={e.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{e.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{e.d}</p>
          </div>
        ))}
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Et le vétérinaire, dans tout ça ?</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Chaque chiot a son propre calendrier de visites et de vaccinations, et c'est votre vétérinaire
        qui décide quand les premières sorties en extérieur sont possibles sans risque. Ne vous fiez
        pas à ce qu'a fait un ami pour son propre chiot : les situations varient. En attendant le feu
        vert, vous pouvez déjà habituer votre chiot aux bruits de l'immeuble en le portant quelques
        minutes dans le hall ou la cage d'escalier.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">La vie en immeuble : ascenseur, voisins, parties communes</h2>
      <ul className="mt-4 space-y-2">
        {[
          "L'ascenseur fait peur à beaucoup de chiots au début : portez-le les premières fois, puis laissez-le monter seul à côté de vous quand il semble à l'aise.",
          "Prévenez vos voisins directs qu'un chiot vient d'arriver : un peu d'indulgence sur les premiers aboiements ou les premières nuits aide tout le monde.",
          "Dans les parties communes, gardez-le en laisse : un chiot qui détale dans le hall peut surprendre un voisin ou se blesser sur un escalier.",
          "Désignez un coin « sorties » proche de l'immeuble pour les tout premiers jours en extérieur : un trajet connu, sans surprise, rassure plus qu'une grande balade découverte.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Les premières vraies sorties</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Une fois le feu vert donné, privilégiez des trottoirs calmes plutôt qu'un carrefour animé, et
        limitez le nombre de rencontres avec d'autres chiens les premiers jours : un chiot peut vite
        se sentir dépassé par trop de nouveautés en même temps. Les squares et jardins autorisés aux
        chiens viennent ensuite, quand il tient bien sa laisse et répond à son nom — notre guide{" "}
        <Link href="/blog/promener-son-chien-a-paris" className="font-semibold text-owner underline">
          promener son chien à Paris
        </Link>{" "}
        recense les meilleurs endroits par quartier, et la carte communautaire PawMap de l'app montre
        les lieux pet-friendly près de chez vous.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Besoin d'aide pour les sorties pendant que vous êtes au bureau, ou simplement pour souffler un
        peu pendant cette période intense ? Un promeneur ou un gardien habitué aux chiots peut prendre
        le relais pour une sortie de midi ou une garde à la journée : précisez « chiot » dans votre
        demande pour ne recevoir que des réponses de prestataires à l'aise avec cet âge.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Retrouvez la page de votre arrondissement, avec ses vétérinaires et ses espaces verts, sur{" "}
        <Link href="/garde-animaux/paris#quartiers" className="font-semibold text-owner underline">
          notre page pet sitter à Paris
        </Link>
        .
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

      <ParisGuidesLinks current="/blog/premier-chiot-a-paris" />

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">Un coup de main pour les sorties de votre chiot ?</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Promeneurs et gardiens vérifiés dans les 20 arrondissements de Paris et en Île-de-France.
        </p>
        <Link href="/garde-animaux/paris" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Trouver un pet sitter à Paris
        </Link>
      </div>
    </div>
  );
}
