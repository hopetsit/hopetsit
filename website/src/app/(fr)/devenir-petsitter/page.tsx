import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import { TrackedLink } from "@/components/TrackedLink";
import { RECRUIT_CITIES, RECRUIT_PATH_PREFIX, PARIS_CITY, type RecruitCity } from "@/lib/recruit-cities";

// 26/10 (Bob, semaine 44) — « devenir pet sitter » (sans ville) est la requête
// la PLUS vue de la Search Console cette semaine (46 impressions/28 j, devant
// « devenir pet sitter paris » à 44 et « devenir dog sitter paris » à 31) —
// et /devenir-petsitter (sans ville) n'existait pas : la route 404ait, Google
// n'ayant que /devenir-petsitter/paris ou l'accueil à proposer pour cette
// requête nationale. Avec l'indexation Paris + USA désormais complète
// (42/42, cf. kpi-2026-W44.md), ceci n'est pas une « nouvelle ville » ni une
// nouvelle langue (interdites tant que l'indexation ne progresse pas) : c'est
// le hub national manquant pour un réseau de pages déjà existant et déjà
// indexé — qui relie vers Paris et les 17 grandes villes françaises déjà en
// ligne, dans l'esprit du maillage (règle SEO du 20/09 : « relier l'existant
// plutôt qu'élargir »).
export const metadata: Metadata = {
  title: "Devenir pet sitter — gagnez de l'argent en gardant des animaux | HoPetSit",
  description:
    "Fixez vos tarifs, choisissez vos services (garde, visites, promenades) et soyez payé en toute sécurité. Devenez pet sitter ou dog sitter avec HoPetSit, partout en France — inscription gratuite.",
  alternates: { canonical: "https://www.hopetsit.com/devenir-petsitter" },
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
    p: "Les propriétaires près de chez vous vous contactent par chat. Vous acceptez uniquement ce qui vous convient.",
  },
  {
    n: "4",
    t: "Soyez payé en toute sécurité",
    p: "Le paiement est bloqué dans l'app dès la réservation et versé sur votre compte bancaire une fois le service terminé. Zéro impayé.",
  },
];

const FAQ = [
  {
    q: "Combien peut-on gagner comme pet sitter en France ?",
    a: "Les tarifs varient selon la ville : en général 15 à 30 € par jour pour une garde et 9 à 20 € pour une promenade. Chaque ville a sa propre fourchette (voir plus bas) et vous fixez vos propres tarifs sur votre profil.",
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
  {
    q: "HoPetSit est-il disponible dans ma ville ?",
    a: "HoPetSit est disponible partout en France. Les villes ci-dessous ont une page dédiée avec les tarifs locaux, mais vous pouvez créer votre profil où que vous soyez.",
  },
];

// France métropolitaine hors Île-de-France (déjà reliée via Paris ci-dessus).
const FRANCE_ONLY = new Set(["Île-de-France", "Belgique", "Suisse", "Luxembourg", "Monaco"]);
const CITIES = RECRUIT_CITIES.filter((c) => c.lang === "fr" && !FRANCE_ONLY.has(c.region));
// Villes francophones hors France : pages déjà en ligne, reliées à part pour
// garder le texte « partout en France » exact.
const FRANCOPHONIE = RECRUIT_CITIES.filter(
  (c) => c.lang === "fr" && ["Belgique", "Suisse", "Luxembourg", "Monaco"].includes(c.region),
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

export default function DevenirPetsitterPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "Devenir pet sitter",
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
      <nav aria-label="Fil d'Ariane" className="text-xs font-medium text-ink-soft">
        <ol className="flex flex-wrap items-center gap-x-1.5 gap-y-1">
          <li>
            <TrackedLink href="/" label="maillage" className="underline-offset-4 hover:text-owner-dark hover:underline">Accueil</TrackedLink>
          </li>
          <li aria-hidden="true">›</li>
          <li aria-current="page" className="text-ink">Devenir pet sitter</li>
        </ol>
      </nav>
      <p className="mt-3 text-sm font-semibold text-sitter-dark">France entière</p>
      <h1 className="mt-1.5 font-display text-[1.6rem] font-extrabold leading-[1.15] tracking-tight text-ink md:mt-2 md:text-4xl">
        Devenez pet sitter — et soyez payé pour aimer les animaux
      </h1>
      <p className="mt-4 flex items-start gap-2 text-sm font-semibold text-sitter-dark">
        <span aria-hidden className="mt-1.5 inline-block h-2 w-2 shrink-0 rounded-full bg-[#16A34A]" />
        Gardes 15 à 30 € par jour · promenades 9 à 20 € — vous fixez vos tarifs
      </p>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Étudiant, en télétravail, retraité ou simplement passionné ? Des millions
        de Français ont un chien ou un chat… et personne pour le garder pendant
        les vacances ou les journées de travail. HoPetSit vous met en relation
        avec eux, partout en France — vous fixez vos tarifs, vous choisissez vos
        services, vous êtes payé en sécurité.
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

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">Choisissez votre ville</h2>
      <p className="mt-2 text-sm leading-relaxed text-ink-muted">
        Chaque ville a sa page : les tarifs du quartier et ce qui est demandé localement.
      </p>
      <ul className="mt-4 flex flex-wrap gap-2">
        <li>
          <TrackedLink
            href={`${RECRUIT_PATH_PREFIX.fr}/${PARIS_CITY.slug}`}
            label="maillage"
            className="inline-block rounded-full bg-sitter px-4 py-2.5 text-sm font-bold text-white transition hover:bg-sitter-dark max-lg:py-3"
          >
            Paris & Île-de-France
          </TrackedLink>
        </li>
      </ul>
      <Chips cities={CITIES} />

      {FRANCOPHONIE.length > 0 && (
        <>
          <h3 className="mt-8 text-sm font-bold text-ink-muted">Francophonie</h3>
          <Chips cities={FRANCOPHONIE} />
        </>
      )}

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
          HoPetSit se lance en France : peu de concurrence entre sitters, des
          propriétaires qui arrivent chaque semaine. C&apos;est le meilleur
          moment pour créer votre profil.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white"
        >
          Créer mon profil gratuit
        </Link>
      </div>

      <section className="mt-12 border-t border-owner/15 pt-6">
        <p className="text-center text-sm md:text-left">
          <TrackedLink href="/garde-animaux/paris" label="maillage" className="font-semibold text-owner-dark underline-offset-4 hover:underline">
            Vous êtes propriétaire ? Trouver un pet sitter à Paris →
          </TrackedLink>
        </p>
        <p className="mt-3 text-center text-sm md:text-left">
          <TrackedLink href="/villes" label="maillage" className="font-semibold text-sitter-dark underline-offset-4 hover:underline">
            Toutes les villes →
          </TrackedLink>
        </p>
      </section>
    </div>
  );
}
