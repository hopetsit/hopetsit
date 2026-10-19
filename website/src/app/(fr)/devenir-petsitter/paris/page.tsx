import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import { TrackedLink } from "@/components/TrackedLink";
import { CityBreadcrumb, CityLinks } from "@/components/CityLinks";
import { PARIS_CITY, RECRUIT_CITIES, RECRUIT_PATH_PREFIX, type RecruitCity } from "@/lib/recruit-cities";

// v533 — SEO recrutement : page « devenir pet sitter à Paris » (stratégie
// supply-first : remplir Paris de sitters avant de pousser les proprios).
//
// 19/10 (Bob, semaine 43) — cette page est la 2e plus vue du site (175
// impressions / 28 j dans Search Console, juste derrière l'accueil) mais ne
// liait vers AUCUNE des 20 pages d'arrondissement : son équivalent côté
// propriétaire (/garde-animaux/paris) les lie toutes via des puces, celle-ci
// non — contrairement au commentaire de CityLinks (« le hub Paris liste déjà
// ses 20 arrondissements »), vrai seulement côté propriétaire. Or une page
// n'a de chance d'être indexée que si des pages déjà indexées pointent vers
// elle (règle SEO du 20/09) : la page la plus vue de Paris côté recrutement
// n'envoyait donc aucun lien à ses propres sous-pages, dont les 3 encore non
// indexées (paris-11, paris-13, paris-20). Ajout des mêmes puces que côté
// propriétaire, adaptées au recrutement, aucune page créée.
export const metadata: Metadata = {
  title: "Devenir pet sitter à Paris — gagnez de l'argent en gardant des animaux",
  description:
    "Fixez vos tarifs, choisissez vos services (garde, visites, promenades) et soyez payé en toute sécurité. Devenez pet sitter ou promeneur de chiens à Paris avec HoPetSit — inscription gratuite.",
  alternates: { canonical: "https://www.hopetsit.com/devenir-petsitter/paris" },
};

const STEPS = [
  {
    n: "1",
    t: "Créez votre profil gratuit",
    p: "Photo, présentation, services proposés (garde à domicile, visites, promenades) et VOS tarifs — c'est vous qui décidez.",
  },
  {
    n: "2",
    t: "Faites vérifier votre identité",
    p: "5 minutes dans l'app. Le badge ✓ rassure les propriétaires : les profils vérifiés reçoivent beaucoup plus de demandes.",
  },
  {
    n: "3",
    t: "Recevez des demandes et discutez",
    p: "Les propriétaires de votre quartier vous contactent par chat. Vous acceptez uniquement ce qui vous convient.",
  },
  {
    n: "4",
    t: "Soyez payé en toute sécurité",
    p: "Le paiement est bloqué dans l'app dès la réservation et versé sur votre compte bancaire une fois le service terminé. Zéro impayé.",
  },
];

const FAQ = [
  {
    q: "Combien peut-on gagner comme pet sitter à Paris ?",
    a: "À Paris, les gardes se facturent généralement 20 à 30 € par jour et les promenades 12 à 20 €. Avec quelques clients réguliers, un complément de 200 à 500 € par mois est réaliste — vous fixez vos propres tarifs.",
  },
  {
    q: "Faut-il un diplôme ou un statut particulier ?",
    a: "Aucun diplôme n'est requis pour commencer sur HoPetSit — il faut aimer les animaux, être fiable et avoir 18 ans ou plus. Pour une activité régulière, renseignez-vous sur le statut adapté (micro-entrepreneur et, pour la garde de chiens/chats à titre habituel, l'ACACED).",
  },
  {
    q: "L'inscription coûte-t-elle quelque chose ?",
    a: "Non, l'inscription et le profil sont gratuits. Seule la vérification d'identité (badge ✓, fortement recommandée) coûte 3 €.",
  },
  {
    q: "Comment le suivi GPS protège-t-il aussi le sitter ?",
    a: "Pendant une promenade, le suivi PawFollow prouve que le service a bien été rendu, du départ au retour. Transparence pour le propriétaire, tranquillité pour vous.",
  },
];

const ARRONDISSEMENTS = RECRUIT_CITIES.filter(
  (c) => c.lang === "fr" && /^paris-\d+$/.test(c.slug),
);
const COMMUNES = RECRUIT_CITIES.filter(
  (c) => c.lang === "fr" && c.region === "Île-de-France",
);

function Chips({ cities }: { cities: RecruitCity[] }) {
  return (
    <ul className="mt-4 flex flex-wrap gap-2">
      {cities.map((c) => (
        <li key={c.slug}>
          <TrackedLink
            href={`${RECRUIT_PATH_PREFIX.fr}/${c.slug}`}
            label="maillage"
            className="inline-block rounded-full bg-bg-soft px-3.5 py-2 text-sm font-medium text-ink transition hover:bg-sitter-light hover:text-sitter-dark max-lg:py-3"
          >
            {c.name}
          </TrackedLink>
        </li>
      ))}
    </ul>
  );
}

export default function DevenirPetsitterParisPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "Devenir pet sitter à Paris",
        inLanguage: "fr",
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
      {/* 29/09 (SAM) — fil d'Ariane + maillage, comme les autres pages villes. */}
      <CityBreadcrumb city={PARIS_CITY} mode="recruit" />
      <p className="mt-3 text-sm font-semibold text-sitter-dark">Paris & Île-de-France</p>
      <h1 className="mt-1.5 font-display text-[1.6rem] font-extrabold leading-[1.15] tracking-tight text-ink md:mt-2 md:text-4xl">
        Devenez pet sitter à Paris — et soyez payé pour aimer les animaux
      </h1>
      <p className="mt-4 flex items-start gap-2 text-sm font-semibold text-sitter-dark">
        <span aria-hidden className="mt-1.5 inline-block h-2 w-2 shrink-0 rounded-full bg-[#16A34A]" />
        Gardes 20 à 30 € par jour · promenades 12 à 20 € — vous fixez vos tarifs
      </p>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Étudiant, en télétravail, retraité ou simplement passionné ? Des
        centaines de milliers de Parisiens ont un chien ou un chat… et personne
        pour le garder pendant les vacances ou les journées de travail. HoPetSit
        vous met en relation avec eux — vous fixez vos tarifs, vous choisissez
        vos services, vous êtes payé en sécurité.
      </p>

      <div className="mt-8 flex flex-wrap gap-3">
        {["💶 Vos tarifs, vos règles", "📅 Vous choisissez vos horaires", "✓ Badge vérifié", "🔒 Zéro impayé"].map((b) => (
          <span key={b} className="rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-ink shadow-card">
            {b}
          </span>
        ))}
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        Comment ça marche
      </h2>
      <ol className="mt-6 space-y-4">
        {STEPS.map((s) => (
          <li key={s.n} className="flex gap-5 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <div className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-sitter-light text-lg font-extrabold text-sitter-dark">
              {s.n}
            </div>
            <div>
              <h3 className="text-base font-bold text-ink">{s.t}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">{s.p}</p>
            </div>
          </li>
        ))}
      </ol>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">Votre arrondissement</h2>
      <p className="mt-2 text-sm leading-relaxed text-ink-muted">
        Chaque arrondissement a sa page : les vétérinaires ouverts le week-end, les animaleries,
        les espaces canins et ce qu'un pet sitter doit savoir avant une première garde sur place.
      </p>
      <Chips cities={ARRONDISSEMENTS} />

      <h2 className="mt-10 font-display text-2xl font-extrabold text-ink">Autour de Paris</h2>
      <Chips cities={COMMUNES} />

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
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

      <div className="mt-14 rounded-3xl bg-sitter-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Les premiers arrivés prennent les meilleurs quartiers
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          HoPetSit se lance à Paris : peu de concurrence entre sitters, des
          propriétaires qui arrivent chaque semaine. C'est le meilleur moment
          pour créer votre profil.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white"
        >
          Créer mon profil gratuit
        </Link>
      </div>
      <CityLinks city={PARIS_CITY} mode="recruit" />
    </div>
  );
}
