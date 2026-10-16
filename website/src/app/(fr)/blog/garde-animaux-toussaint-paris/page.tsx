import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// 16/10/2026 (SAM) — article saisonnier PROPRIÉTAIRES : vacances de la
// Toussaint à Paris (zone C : du vendredi 17 octobre au soir au lundi
// 2 novembre 2026 au matin). Rattaché à l'existant (« améliorer et relier,
// pas multiplier ») : il renvoie vers les 3 guides vacances/chat/confiance et
// vers /garde-animaux/paris ; son appel à l'action principal est le formulaire
// de demande gratuite, avec la campagne « toussaint_paris » pour le mesurer.
// Pas d'`openGraph` ici : comme les autres articles, la page hérite de celui
// du layout (un openGraph de page REMPLACERAIT celui du layout, og:image compris).
const CANONICAL = "https://www.hopetsit.com/blog/garde-animaux-toussaint-paris";
const CTA_HREF =
  "/posts/create?city=Paris&utm_source=site&utm_medium=blog&utm_campaign=toussaint_paris";
const HEADLINE =
  "Garde de chien et de chat pendant les vacances de la Toussaint à Paris";

export const metadata: Metadata = {
  title: "Garde de chien et de chat à Paris pendant la Toussaint 2026",
  description:
    "Vacances de la Toussaint du 17 octobre au 2 novembre 2026 : gardien à domicile, pension ou famille pour votre chien ou votre chat à Paris, prix, check-list et pourquoi réserver tôt.",
  alternates: { canonical: CANONICAL },
};

const OPTIONS = [
  {
    t: "🏠 Le gardien à domicile (ou chez un particulier)",
    p: "Votre chien ou votre chat reste dans ses habitudes : ses repas, son panier, ses promenades. Un gardien vient dormir chez vous, passe une à deux fois par jour, ou accueille votre animal chez lui. C'est l'option la plus rassurante pour les animaux anxieux, et souvent la plus économique : comptez 15 à 30 € par jour pour une garde, 8 à 15 € la visite pour un chat.",
  },
  {
    t: "🏢 La pension",
    p: "Un encadrement professionnel dans des locaux dédiés, mais un environnement collectif parfois stressant, des vaccins exigés et un budget plus élevé (25 à 45 € par jour). Pendant les vacances scolaires, les places partent vite : si vous choisissez cette voie, appelez sans attendre.",
  },
  {
    t: "👨‍👩‍👧 La famille ou les amis",
    p: "Gratuit et affectif, mais pas toujours disponible à la Toussaint, où beaucoup de familles partent en même temps que vous. Et il reste difficile d'imposer vos consignes ou de demander des nouvelles chaque jour à un proche qui vous rend service.",
  },
];

const CHECKLIST = [
  "Publiez votre demande dès maintenant : dates, animal, quartier, et ce qui compte pour vous (promenades, visites, nuit sur place).",
  "Rencontrez le gardien avant le départ, en vrai ou en vidéo, et observez le contact avec votre animal.",
  "Regardez le badge « Identité vérifiée » et les avis laissés après de vraies réservations.",
  "Préparez un carnet de consignes : repas, promenades, traitements en cours, coordonnées de votre vétérinaire.",
  "Laissez croquettes, laisse, panier, litière habituelle et le jouet préféré : les repères comptent autant que les soins.",
  "Convenez du rythme des nouvelles : photos, messages dans l'app et suivi PawFollow des promenades.",
  "Payez dans l'app, jamais tout en liquide à l'avance : le montant est bloqué à la réservation et versé au gardien après le service.",
];

const FAQ = [
  {
    q: "Quelles sont les dates des vacances de la Toussaint 2026 à Paris ?",
    a: "Paris est en zone C. Les vacances de la Toussaint commencent le vendredi 17 octobre 2026 après la classe et se terminent le lundi 2 novembre 2026 au matin, avec la reprise des cours. Toutes les zones sont en vacances en même temps.",
  },
  {
    q: "Combien coûte une garde de chien ou de chat à Paris pendant la Toussaint ?",
    a: "Comptez 15 à 30 € par jour pour une garde chez un gardien ou à votre domicile, et 8 à 15 € la visite pour un chat. Une pension coûte plutôt 25 à 45 € par jour. Chaque gardien fixe ses tarifs : vous les voyez sur son profil avant de réserver.",
  },
  {
    q: "Vaut-il mieux faire garder mon chat chez moi ou le déplacer ?",
    a: "Dans l'immense majorité des cas, le laisser chez lui. Le chat est attaché à son territoire : une ou deux visites par jour (repas, eau fraîche, litière, jeu) le stressent beaucoup moins qu'un séjour en pension.",
  },
  {
    q: "Est-il trop tard pour trouver un gardien à quelques jours du départ ?",
    a: "Pas forcément, mais les gardiens disponibles sur toute la période se réservent les premiers. Publiez votre demande le plus tôt possible, même pour une partie des vacances seulement : les gardiens de votre arrondissement vous répondent et vous choisissez ensuite, sans engagement.",
  },
  {
    q: "Comment avoir des nouvelles pendant mes vacances ?",
    a: "Convenez du rythme avant le départ. Dans l'app HoPetSit, vous échangez par chat avec votre gardien et le suivi PawFollow affiche la promenade de votre chien en direct sur la carte, avec le trajet et la durée.",
  },
];

export default function ArticleToussaintParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        inLanguage: "fr",
        datePublished: "2026-10-16",
        mainEntityOfPage: CANONICAL,
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
      <p className="text-sm font-semibold text-owner">Guide propriétaires · Paris · Toussaint 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        {HEADLINE}
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Du vendredi 17 octobre au soir au lundi 2 novembre 2026 au matin, Paris
        (zone C) est en vacances. Si vous partez, une question se pose avant
        les valises : qui s&apos;occupe de votre chien ou de votre chat ? Voici
        les trois options qui existent vraiment, leurs prix, et la check-list
        pour partir l&apos;esprit tranquille.
      </p>

      <Link
        href={CTA_HREF}
        className="mt-6 block w-full rounded-full bg-owner px-6 py-3.5 text-center text-base font-bold text-white shadow-card md:mx-auto md:w-auto md:min-w-[18rem]"
      >
        Publier ma demande gratuite
      </Link>
      <p className="mt-2.5 text-center text-xs text-ink-soft">
        Gratuit · sans compte pour commencer · les gardiens de Paris vous répondent
      </p>
      <p className="mt-2 text-center text-sm">
        <Link
          href="/garde-animaux/paris"
          className="font-semibold text-owner-dark underline-offset-4 hover:underline"
        >
          Voir la garde d&apos;animaux à Paris, arrondissement par arrondissement →
        </Link>
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Les 3 options pour la Toussaint
      </h2>
      <div className="mt-6 space-y-4">
        {OPTIONS.map((o) => (
          <div key={o.t} className="rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <h3 className="font-bold text-ink">{o.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{o.p}</p>
          </div>
        ))}
      </div>
      <p className="mt-4 text-sm leading-relaxed text-ink-muted">
        Pour aller plus loin selon votre animal : notre guide pour{" "}
        <Link
          href="/blog/faire-garder-son-chien-pendant-les-vacances"
          className="font-semibold text-owner underline"
        >
          faire garder son chien pendant les vacances
        </Link>{" "}
        et celui pour{" "}
        <Link href="/blog/faire-garder-son-chat-a-paris" className="font-semibold text-owner underline">
          faire garder son chat à Paris
        </Link>
        .
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Pourquoi réserver tôt pour la Toussaint
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Les vacances de la Toussaint ont une particularité : toutes les zones
        partent en même temps, pendant deux semaines. À Paris, cela veut dire
        que beaucoup de propriétaires cherchent un gardien pour les mêmes
        dates, et que les gardiens disponibles sur toute la période, ou sur le
        week-end du 1<sup>er</sup> novembre, sont les premiers réservés.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Réserver tôt ne sert pas seulement à trouver quelqu&apos;un. C&apos;est
        aussi ce qui laisse le temps d&apos;une rencontre préalable, d&apos;un
        échange par chat sur les habitudes de votre animal et, pour un chat,
        d&apos;une première visite pendant que vous êtes encore là. Nous avons
        détaillé ce qu&apos;il faut vérifier avant de confier son animal dans
        notre guide pour{" "}
        <Link
          href="/blog/choisir-un-pet-sitter-de-confiance-a-paris"
          className="font-semibold text-owner underline"
        >
          choisir un pet sitter de confiance à Paris
        </Link>
        .
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Et si vos dates changent ? Sur HoPetSit, l&apos;annulation est gratuite
        jusqu&apos;à 72 heures avant le début de la garde : publier votre
        demande maintenant ne vous engage à rien.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        La check-list avant le départ
      </h2>
      <ul className="mt-6 space-y-3">
        {CHECKLIST.map((c, i) => (
          <li key={i} className="flex gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
            <span className="text-owner">✓</span>
            <span className="text-sm leading-relaxed text-ink-muted">{c}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Un gardien près de chez vous, dans votre arrondissement
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        La proximité compte autant que la note affichée : un gardien à vingt
        minutes à pied connaît les parcs et les trajets de votre quartier.
        Chaque arrondissement a sa page sur{" "}
        <Link href="/garde-animaux/paris" className="font-semibold text-owner underline">
          la garde d&apos;animaux à Paris
        </Link>
        , avec les vétérinaires ouverts le week-end, les espaces canins et les
        gardiens HoPetSit du secteur. Près des gares, dans le{" "}
        <Link href="/garde-animaux/paris-10" className="font-semibold text-owner underline">
          10e
        </Link>
        , les gardes autour d&apos;un départ sont une habitude ; dans le{" "}
        <Link href="/garde-animaux/paris-15" className="font-semibold text-owner underline">
          15e
        </Link>
        , le plus grand arrondissement, la demande est forte à chaque période
        de vacances.
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

      <ParisGuidesLinks current="/blog/garde-animaux-toussaint-paris" />

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Trouvez votre gardien à Paris pour la Toussaint
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Publiez votre demande en deux minutes : les gardiens et promeneurs de
          votre arrondissement vous répondent, vous comparez les profils et
          vous ne payez que si vous réservez.
        </p>
        <Link
          href={CTA_HREF}
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Publier ma demande gratuite
        </Link>
        <p className="mt-3 text-sm">
          <Link
            href="/garde-animaux/paris"
            className="font-semibold text-owner-dark underline-offset-4 hover:underline"
          >
            Garde d&apos;animaux à Paris →
          </Link>
        </p>
      </div>
    </div>
  );
}
