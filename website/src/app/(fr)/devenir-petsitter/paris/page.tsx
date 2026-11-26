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
// 26/11 (GUS) — Search Console 28 j France : cette page reçoit 591 affichages
// pour 4 clics, en 41e place. Les recherches qui l'affichent sont générales et
// la page n'y répondait pas : « devenir pet sitter » (188 aff., 44e),
// « devenir dog sitter » (104, 51e), « devenir pet sitter à domicile » (61),
// « faire du pet sitting » (58). Ajout d'un vrai guide (ce que fait un pet
// sitter, les étapes pour commencer, à domicile, dog sitter, statut) + 3
// questions, titre qui nomme « dog sitter ». Aucune page créée, aucun chiffre
// nouveau ; la phrase « 200 à 500 € par mois » est retirée (règle : pas de
// promesse de revenus).
export const metadata: Metadata = {
  title: "Devenir pet sitter ou dog sitter à Paris : comment commencer",
  description:
    "Comment devenir pet sitter à Paris : les étapes pour commencer, garder à domicile ou chez soi, devenir dog sitter ou promeneur, le statut à connaître. Vous fixez vos tarifs — inscription gratuite sur HoPetSit.",
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
    a: "À Paris, les gardes se facturent généralement 20 à 30 € par jour et les promenades 12 à 20 €. Ce que vous gagnez dépend du nombre de demandes que vous acceptez et de vos disponibilités : HoPetSit ne garantit aucun revenu, et c'est vous qui fixez vos tarifs.",
  },
  {
    q: "Faut-il un diplôme ou un statut particulier ?",
    a: "Aucun diplôme n'est requis pour commencer sur HoPetSit — il faut aimer les animaux, être fiable et avoir 18 ans ou plus. Pour une activité régulière, renseignez-vous sur le statut adapté (micro-entrepreneur et, pour la garde de chiens/chats à titre habituel, l'ACACED).",
  },
  {
    q: "Comment devenir pet sitter à domicile ?",
    a: "Créez un profil, cochez « garde à domicile » ou « visites à domicile », indiquez vos tarifs et vos disponibilités. Vous allez chez le propriétaire : l'animal reste dans son environnement. Avant la première garde, rencontrez toujours le propriétaire et l'animal, et notez les habitudes, les repas et le numéro du vétérinaire.",
  },
  {
    q: "Quelle différence entre pet sitter et dog sitter ?",
    a: "Un pet sitter garde tous les animaux de compagnie (chats, chiens, lapins, oiseaux…). Un dog sitter ne garde que des chiens. Sur HoPetSit, vous choisissez les animaux que vous acceptez et les services que vous proposez : un même profil peut faire les deux.",
  },
  {
    q: "Peut-on faire du pet sitting en étant étudiant ou salarié ?",
    a: "Oui, beaucoup commencent ainsi : quelques visites le soir, une garde le week-end ou pendant les vacances. Vous n'acceptez que les demandes compatibles avec votre emploi du temps. Pensez à vérifier les règles de déclaration qui s'appliquent à votre situation.",
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

const GUIDE = [
  {
    t: "1. Choisissez ce que vous proposez.",
    p: "Garde chez le propriétaire, accueil chez vous, visites à domicile, promenades : commencez par ce que vous pouvez tenir sans stress.",
  },
  {
    t: "2. Soyez honnête sur votre expérience.",
    p: "Animaux que vous avez eus, races que vous connaissez, ce que vous ne faites pas (médicaments, très grands chiens…). Un profil précis rassure plus qu'un profil parfait.",
  },
  {
    t: "3. Fixez un tarif cohérent avec votre quartier.",
    p: "Regardez ce qui se pratique autour de vous, puis ajustez. Vous pouvez le modifier à tout moment.",
  },
  {
    t: "4. Rencontrez avant de garder.",
    p: "Une première rencontre avec le propriétaire et l'animal évite presque tous les malentendus : habitudes, repas, sorties, vétérinaire, personne à prévenir.",
  },
  {
    t: "5. Donnez des nouvelles.",
    p: "Une photo et un mot à chaque visite : c'est ce que les propriétaires retiennent, et ce qui fait revenir un client.",
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

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        Devenir pet sitter : par où commencer
      </h2>
      <p className="mt-3 text-base leading-relaxed text-ink-muted">
        Un pet sitter s'occupe d'un animal quand son propriétaire est absent : il le nourrit,
        le sort, joue avec lui, surveille que tout va bien et donne des nouvelles. Faire du pet
        sitting ne demande pas de diplôme pour débuter, mais du sérieux : on vous confie un
        membre de la famille, et souvent les clés du logement.
      </p>
      <ul className="mt-5 space-y-3 text-sm leading-relaxed text-ink-muted">
        {GUIDE.map((g) => (
          <li key={g.t} className="rounded-2xl bg-bg-soft p-4">
            <span className="font-bold text-ink">{g.t}</span> {g.p}
          </li>
        ))}
      </ul>

      <h3 className="mt-10 font-display text-xl font-extrabold text-ink">
        Pet sitter à domicile ou chez soi
      </h3>
      <p className="mt-3 text-base leading-relaxed text-ink-muted">
        Il y a deux façons de garder. <strong className="text-ink">À domicile</strong>, vous
        allez chez le propriétaire, pour une visite ou pour y rester : c'est la formule préférée
        pour les chats, qui supportent mal de changer de lieu. <strong className="text-ink">Chez
        vous</strong>, vous accueillez l'animal : cela convient surtout aux chiens sociables, si
        votre logement s'y prête et que votre bail ou votre copropriété ne l'interdit pas. Vous
        pouvez commencer par une seule formule et ajouter l'autre plus tard.
      </p>

      <h3 className="mt-10 font-display text-xl font-extrabold text-ink">
        Devenir dog sitter ou promeneur de chiens
      </h3>
      <p className="mt-3 text-base leading-relaxed text-ink-muted">
        Un dog sitter garde des chiens ; un promeneur les sort pendant que leur maître travaille.
        À Paris, les chiens doivent être tenus en laisse sur la voie publique et tous les jardins
        ne leur sont pas ouverts : connaître les espaces de votre quartier est un vrai atout.
        Dites clairement sur votre profil les gabarits que vous acceptez et si vous promenez un
        seul chien à la fois. Pour voir ce que les propriétaires attendent, lisez nos guides{" "}
        <Link href="/blog/dog-sitter-paris" className="font-semibold text-sitter-dark underline">
          dog sitter à Paris
        </Link>{" "}
        et{" "}
        <Link href="/blog/tarif-promeneur-de-chien-paris" className="font-semibold text-sitter-dark underline">
          promeneur de chien à Paris
        </Link>
        .
      </p>

      <h3 className="mt-10 font-display text-xl font-extrabold text-ink">
        Statut et déclaration
      </h3>
      <p className="mt-3 text-base leading-relaxed text-ink-muted">
        Les sommes gagnées en gardant des animaux sont des revenus à déclarer. Pour une activité
        régulière, le statut le plus courant est celui de micro-entrepreneur. Garder des chiens ou
        des chats chez soi à titre professionnel est une activité encadrée : une attestation de
        connaissances (ACACED) et une déclaration auprès de la direction départementale chargée
        de la protection des populations (DDPP) sont alors demandées. Renseignez-vous sur les
        sites officiels (service-public.fr, autoentrepreneur.urssaf.fr) avant de vous lancer ;
        notre article{" "}
        <Link href="/blog/devenir-pet-sitter-combien-ca-rapporte" className="font-semibold text-sitter-dark underline">
          devenir pet sitter : combien ça rapporte
        </Link>{" "}
        détaille le sujet.
      </p>

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
