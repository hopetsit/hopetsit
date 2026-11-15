import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// 2026-W46 (marketing hebdo, dimanche) — sujet suivant non coché de
// `marketing/sujets_4poles.md` § Paris (page pilier /garde-animaux/paris#quartiers).
// Angle différent de /blog/promener-son-chien-a-paris (qui couvre bois, berges et
// canaux, très permissifs) : ici, les JARDINS et squares intra-muros, où les règles
// sont plus strictes et changent d'un lieu à l'autre. Pas de citation de texte de
// loi : on renvoie systématiquement à la signalétique sur place et à paris.fr.
const URL = "https://www.hopetsit.com/blog/jardins-parisiens-ouverts-aux-chiens";

export const metadata: Metadata = {
  title: "Les jardins parisiens ouverts aux chiens : règles et bonnes pratiques",
  description:
    "Jardins, squares, bois : tous les espaces verts parisiens n'acceptent pas les chiens de la même façon. Comment savoir où ils sont admis, et les bons réflexes une fois sur place.",
  alternates: { canonical: URL },
};

const FAQ = [
  {
    q: "Est-ce que tous les jardins parisiens acceptent les chiens ?",
    a: "Non. Plusieurs grands jardins historiques intra-muros interdisent les chiens à l'intérieur des grilles, souvent pour protéger les pelouses et les massifs, alors que les bois (Vincennes, Boulogne), les berges et de nombreux squares de quartier les acceptent en laisse. La seule règle sûre est de regarder le panneau à l'entrée.",
  },
  {
    q: "Les chiens doivent-ils être tenus en laisse dans les jardins qui les acceptent ?",
    a: "Dans la grande majorité des cas, oui. Les espaces où un chien peut être lâché sans laisse restent rares à Paris intra-muros ; vérifiez la signalétique sur place plutôt que de vous fier à une habitude prise ailleurs.",
  },
  {
    q: "Le panneau à l'entrée n'est pas clair, que faire ?",
    a: "En cas de doute, mieux vaut demander à un agent du jardin ou vérifier les horaires et conditions d'accès sur paris.fr avant de vous y rendre, les règles pouvant varier d'un jardin à l'autre et évoluer dans le temps.",
  },
  {
    q: "Existe-t-il des espaces sans laisse pour chien à Paris ?",
    a: "Quelques « espaces de liberté » existent mais restent peu nombreux par rapport au nombre de jardins de la capitale. Renseignez-vous sur ceux de votre arrondissement plutôt que de supposer qu'un jardin proche en propose un.",
  },
  {
    q: "Comment trouver un promeneur qui connaît les bons jardins de mon quartier ?",
    a: "Les promeneurs HoPetSit de votre arrondissement connaissent généralement les jardins et squares qui acceptent les chiens près de chez vous, et peuvent adapter le parcours en conséquence.",
  },
];

export default function ArticleJardinsParisiensChiens() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Les jardins parisiens ouverts aux chiens : règles et bonnes pratiques",
        inLanguage: "fr",
        mainEntityOfPage: URL,
        datePublished: "2026-11-15",
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com" },
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
      <p className="text-sm font-semibold text-owner">Guide local · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Les jardins parisiens ouverts aux chiens : règles et bonnes pratiques
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Paris compte des centaines d&apos;espaces verts, mais ils ne se valent
        pas tous pour une sortie avec votre chien. Certains jardins
        l&apos;interdisent purement et simplement à l&apos;intérieur des
        grilles, d&apos;autres l&apos;acceptent en laisse sans condition.
        Avant d&apos;y aller, mieux vaut savoir où vous mettez les pattes.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Jardins, squares et bois : une différence qui change tout
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Tous les espaces verts parisiens ne suivent pas les mêmes règles.
        Plusieurs grands jardins historiques intra-muros, pensés autour de
        pelouses et de massifs fleuris, interdisent les chiens à
        l&apos;intérieur de leurs grilles — seules les allées extérieures
        restent accessibles. À l&apos;inverse, les deux grands bois de la
        capitale, les berges de Seine et les canaux fonctionnent davantage
        comme des parcs de nature et acceptent largement les chiens tenus en
        laisse ; nous détaillons ces spots-là dans notre guide{" "}
        <Link href="/blog/promener-son-chien-a-paris" className="font-semibold text-owner underline">
          promener son chien à Paris
        </Link>
        . Entre les deux, les squares de quartier varient énormément : certains
        les acceptent sans problème, d&apos;autres les interdisent
        complètement, souvent à cause d&apos;une aire de jeux pour enfants ou
        d&apos;un espace engazonné protégé.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Comment savoir si un jardin accepte les chiens
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Le seul réflexe fiable reste de regarder le panneau à l&apos;entrée :
        un pictogramme « chien interdit » (ou autorisé en laisse) y figure
        presque toujours. Si l&apos;information n&apos;est pas claire, ou si
        vous préférez vérifier avant de vous déplacer, le site paris.fr liste
        les horaires et conditions d&apos;accès de chaque jardin. Les règles
        peuvent changer d&apos;un jardin à l&apos;autre et évoluer dans le
        temps, mieux vaut donc vérifier au cas par cas plutôt que de supposer
        qu&apos;un jardin suit la même règle que son voisin.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Les bonnes pratiques une fois sur place
      </h2>
      <ul className="mt-4 space-y-2">
        {[
          "La laisse reste la règle dans la quasi-totalité des jardins qui acceptent les chiens — vérifiez sur place si une zone spécifique permet de la détacher.",
          "Ramassez systématiquement les déjections : c'est souvent la première raison invoquée quand un jardin finit par interdire les chiens.",
          "Évitez les heures d'affluence près des aires de jeux pour enfants, même dans un jardin globalement ouvert aux chiens.",
          "Un chien de catégorie doit porter sa muselière dans les lieux publics, jardins compris — renseignez-vous auprès de votre mairie si vous avez un doute sur la catégorie de votre chien.",
          "Restez à l'écart des pelouses explicitement interdites, même si le reste du jardin autorise les chiens.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Et si le jardin le plus proche de chez vous n&apos;accepte pas les chiens ?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Ce n&apos;est pas rare, et ça ne veut pas dire qu&apos;il faut
        renoncer à la sortie. Un bois, une berge ou un square voisin accepte
        peut-être les chiens sans condition particulière. C&apos;est
        justement le genre de détail que connaissent les promeneurs qui
        arpentent un quartier au quotidien : dans le{" "}
        <Link href="/garde-animaux/paris-19" className="font-semibold text-owner underline">
          19e arrondissement
        </Link>
        , autour des Buttes-Chaumont, les habitués savent par exemple quelles
        allées restent ouvertes aux chiens en laisse. Si vous préférez
        déléguer la sortie plutôt que de tester vous-même chaque panneau,
        des{" "}
        <Link href="/garde-animaux/paris" className="font-semibold text-owner underline">
          promeneurs vérifiés près de chez vous
        </Link>{" "}
        connaissent déjà les bons jardins de leur secteur.
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

      <ParisGuidesLinks current="/blog/jardins-parisiens-ouverts-aux-chiens" />

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Un promeneur qui connaît les bons jardins de votre quartier
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Comparez les profils parisiens, lisez les vrais avis et réservez une
          promenade en quelques minutes — gratuitement sur HoPetSit.
        </p>
        <Link href="/garde-animaux/paris" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Trouver un promeneur à Paris
        </Link>
      </div>
    </div>
  );
}
