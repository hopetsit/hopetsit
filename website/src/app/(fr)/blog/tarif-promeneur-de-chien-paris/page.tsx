import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// v535 — SEO Paris : tarifs promeneur de chien (requête transactionnelle).
// 24/11/2026 (GUS) — Search Console 28 j France : 670 affichages, 3 clics, 19e place
// (« promeneur de chien paris » 169 aff. en 16e, « promeneur de chien » 90 en 12e,
// « promenade de chien » 53 en 15e). Depuis le nouveau titre du 09/11 la page est passée de la
// 21e à la 16e place ; elle restait très courte. Enrichie pour monter en première page :
// ce que fait un promeneur, déroulé d'une promenade, solo ou groupe, comment choisir,
// check-list, règles de Paris, liens, image propre 1200×630. Aucun tarif ni chiffre nouveau.
const URL = "https://www.hopetsit.com/blog/tarif-promeneur-de-chien-paris";
const COVER = "https://www.hopetsit.com/blog/tarif-promeneur-de-chien-paris.jpg";
const COVER_ALT = "Chien roux souriant devant un massif de fleurs, couverture du guide « Promeneur de chien à Paris »";
const TITLE = "Promeneur de chien à Paris : tarif d'une promenade en 2026";
const DESCRIPTION =
  "Trouver un promeneur de chien à Paris et savoir combien coûte une balade de 30 min à 1 h : forfaits à la semaine, ce qui fait varier le tarif et comment payer en sécurité.";

export const metadata: Metadata = {
  // 09/11 (GUS) — Search Console 28 j : « promeneur de chien paris » 70 affichages (21e place),
  // « promeneur(s) de chien(s) paris » 58 de plus (28e-31e), 0 clic ; le titre ne parlait que du
  // coût. Titre et H1 reprennent la requête, « tarif » (déjà 6e) gardé.
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
    images: [{ url: COVER, width: 1200, height: 630, alt: COVER_ALT }],
  },
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
  {
    q: "Promeneur de chien ou dog sitter : quelle différence ?",
    a: "Le promeneur de chien ne fait que les sorties : il vient chercher le chien, le promène et le ramène chez vous. Le dog sitter garde le chien, à la journée ou plusieurs jours, chez lui ou chez vous. Pour une journée de travail, le promeneur suffit ; pour un week-end ou des vacances, il faut un dog sitter.",
  },
  {
    q: "Faut-il confier ses clés au promeneur ?",
    a: "Seulement si vous êtes absent au moment de la promenade, et jamais avant de l'avoir rencontré. Beaucoup de maîtres font une première balade en étant présents, puis remettent un double des clés quand la confiance est là. Convenez par écrit, dans le chat de l'app, de qui garde les clés et de quand elles sont rendues.",
  },
  {
    q: "Mon chien sera-t-il tenu en laisse ?",
    a: "Dans les rues de Paris, oui : la laisse est obligatoire sur la voie publique. Dans les parcs et les bois, les règles changent d'un lieu à l'autre. Dites clairement au promeneur si vous acceptez ou non que votre chien soit lâché là où c'est permis.",
  },
];

const DEROULE = [
  "Le promeneur arrive à l'heure convenue et récupère votre chien chez vous (ou vous le lui remettez en bas de l'immeuble).",
  "Il l'équipe avec son harnais ou son collier habituel et part pour la durée prévue : tour du quartier, square ou parc ouvert aux chiens.",
  "Pendant la sortie, le chien marche, renifle, fait ses besoins ; le promeneur ramasse et lui donne à boire s'il fait chaud.",
  "Au retour, il essuie les pattes si besoin, vérifie la gamelle d'eau et referme bien la porte.",
  "Demandez-lui un mot et une photo dans le chat de l'app après chaque sortie : vous savez comment la promenade s'est passée.",
];

const CHOISIR = [
  "Rencontrez-le avant, avec votre chien : dix minutes de marche ensemble dans votre rue suffisent pour voir s'il le tient bien et si le chien le suit volontiers.",
  "Demandez-lui combien de chiens il promène en même temps, et s'il les connaît tous.",
  "Demandez où il va : un promeneur du quartier connaît les squares ouverts aux chiens et les rues calmes.",
  "Parlez du caractère de votre chien : tire en laisse, réactif avec ses congénères, peur du bruit, fugueur. Un bon promeneur pose ces questions lui-même.",
  "Lisez les avis des autres maîtres sur son profil et regardez depuis quand il est inscrit.",
  "Faites une première promenade à l'essai avant de vous engager sur un forfait à la semaine.",
];

const CHECKLIST = [
  "Un harnais ou un collier bien réglé, avec une médaille à votre numéro, et la laisse habituelle.",
  "Des sacs à déjections, et une gourde ou une gamelle pliable l'été.",
  "Les consignes écrites : durée, lâché ou non, friandises autorisées ou non, chiens à éviter.",
  "Le nom et le téléphone de votre vétérinaire, et une personne à joindre si vous ne répondez pas.",
  "Le code de l'immeuble, l'étage, et où poser les clés au retour si vous en confiez.",
];

export default function ArticleTarifPromeneurParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: TITLE,
        description: DESCRIPTION,
        inLanguage: "fr-FR",
        mainEntityOfPage: URL,
        datePublished: "2026-09-27",
        dateModified: "2026-11-24",
        image: { "@type": "ImageObject", url: COVER, width: 1200, height: 630 },
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
      <p className="text-sm font-semibold text-owner">Guide tarifs · Paris · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Promeneur de chien à Paris : combien coûte une promenade ?
      </h1>
      <Image
        src="/blog/tarif-promeneur-de-chien-paris.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Journées longues au bureau, imprévus, canicule : faire promener son
        chien à Paris est devenu un vrai service du quotidien. Voici les prix
        réellement pratiqués en 2026, et comment éviter les mauvaises
        surprises.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Un promeneur de chien, c'est quoi ?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Un promeneur de chien est une personne qui sort votre chien à votre place : il vient le
        chercher chez vous, le promène dans le quartier pendant la durée convenue, puis le ramène.
        Il ne garde pas le chien chez lui et ne dort pas chez vous : c'est le rôle du{" "}
        <Link href="/blog/dog-sitter-paris" className="font-semibold text-owner underline">
          dog sitter
        </Link>
        . À Paris, on fait surtout appel à un promeneur pour la sortie de midi, quand le chien
        reste seul en appartement pendant la journée de travail, mais aussi après une opération,
        pendant une grossesse, ou simplement les semaines trop chargées.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        La promenade de chien n'est pas qu'une pause pipi. Pour un chien de ville, c'est le moment
        où il se dépense, sent d'autres odeurs et croise du monde. Si le vôtre attend dix heures
        seul chaque jour, notre guide{" "}
        <Link href="/blog/chien-seul-toute-la-journee-paris" className="font-semibold text-owner underline">
          chien seul toute la journée à Paris
        </Link>{" "}
        explique comment organiser cette sortie.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Comment se passe une promenade
      </h2>
      <ol className="mt-4 space-y-3">
        {DEROULE.map((t, i) => (
          <li key={t} className="flex gap-3 leading-relaxed text-ink-muted">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-owner text-sm font-bold text-white">
              {i + 1}
            </span>
            <span>{t}</span>
          </li>
        ))}
      </ol>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Promenade en solo ou en groupe ?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        En promenade solo, le promeneur ne sort que votre chien : il va à son rythme et lui
        accorde toute son attention. C'est le bon choix pour un chiot, un chien âgé, craintif ou
        qui s'entend mal avec les autres. En promenade partagée, votre chien sort avec un ou
        plusieurs autres chiens : c'est moins cher, et les chiens sociables y trouvent des copains
        de jeu. Demandez toujours combien de chiens sont sortis ensemble, et faites un essai avant
        de choisir.
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
      <p className="mt-4 text-sm text-ink-muted">
        Dans le{" "}
        <Link href="/garde-animaux/paris-1" className="font-semibold text-owner underline">
          1er arrondissement
        </Link>{" "}
        (Louvre, Palais-Royal, les Tuileries), beaucoup de résidents en appartement et peu
        d'espaces verts privés font de la promenade un service très demandé. Dans le{" "}
        <Link href="/garde-animaux/paris-3" className="font-semibold text-owner underline">
          3e
        </Link>
        , entre le Marais nord et Arts-et-Métiers, familles et jeunes actifs se partagent une
        forte densité de petits chiens. Votre arrondissement n'est pas cité ? La page{" "}
        <Link href="/garde-animaux/paris" className="font-semibold text-owner underline">
          dog sitter et promeneur à Paris
        </Link>{" "}
        les liste tous.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Bien choisir son promeneur de chien à Paris
      </h2>
      <ul className="mt-4 space-y-2">
        {CHOISIR.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Pour comparer plusieurs réponses, notre guide{" "}
        <Link href="/blog/choisir-un-pet-sitter-de-confiance-a-paris" className="font-semibold text-owner underline">
          choisir un pet sitter de confiance à Paris
        </Link>{" "}
        donne les bons réflexes.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Ce qu'il faut préparer pour le promeneur
      </h2>
      <ul className="mt-4 space-y-2">
        {CHECKLIST.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-1 shrink-0 font-bold text-owner">✓</span>
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Promener un chien à Paris : les règles à connaître
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Dans les rues de Paris, un chien doit être tenu en laisse, et ramasser ses déjections est
        obligatoire. Tous les jardins ne sont pas ouverts aux chiens, et ceux qui le sont imposent
        souvent la laisse et certaines allées. Un promeneur du quartier connaît ces règles ; vous
        pouvez les vérifier dans nos guides{" "}
        <Link href="/blog/jardins-parisiens-ouverts-aux-chiens" className="font-semibold text-owner underline">
          les jardins parisiens ouverts aux chiens
        </Link>{" "}
        et{" "}
        <Link href="/blog/promener-son-chien-a-paris" className="font-semibold text-owner underline">
          promener son chien à Paris
        </Link>
        . L'été, demandez une sortie tôt le matin ou en fin de journée : le bitume brûlant et la
        chaleur sont dangereux pour un chien.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Trouver un promeneur de chien près de chez vous
      </h2>
      <ol className="mt-4 space-y-3">
        {[
          "Publiez votre demande gratuitement : le chien, les jours et l'heure de la promenade, votre arrondissement.",
          "Les promeneurs proches reçoivent votre demande et vous répondent avec leur prix.",
          "Comparez leurs profils et leurs avis, discutez dans le chat et proposez une première rencontre avec votre chien.",
          "Choisissez et payez dans l'app : le paiement est sécurisé, et vous suivez la promenade en direct sur la carte.",
        ].map((t, i) => (
          <li key={t} className="flex gap-3 leading-relaxed text-ink-muted">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-owner text-sm font-bold text-white">
              {i + 1}
            </span>
            <span>{t}</span>
          </li>
        ))}
      </ol>

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

      <ParisGuidesLinks current="/blog/tarif-promeneur-de-chien-paris" />

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
