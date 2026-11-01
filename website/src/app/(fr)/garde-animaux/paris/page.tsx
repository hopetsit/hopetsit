import type { Metadata } from "next";
import OwnerCityPage from "@/components/OwnerCityPage";
import { TrackedLink } from "@/components/TrackedLink";
import { ParisHeroForm } from "@/components/ParisHeroForm";
// 1617 (LEO, 16/10, §B.5) — « N propriétaires cherchent un gardien à Paris cette semaine » (rien si 0).
import RequestsPulse1617 from "@/components/RequestsPulse1617";
import { RECRUIT_CITIES, OWNER_PATH_PREFIX, PARIS_CITY, type RecruitCity } from "@/lib/recruit-cities";

// v575 — PAGE D'ATTERRISSAGE DE LA PUB META « Paris · Propriétaires (FR) ».
//
// ⚠️ Cause racine du 238 clics → 98 pages affichées (41 %) : l'URL de la pub,
// https://www.hopetsit.com/garde-animaux/paris, n'existait PAS. `recruit-cities`
// ne contient que `paris-1` … `paris-20` (les arrondissements) et
// `/garde-animaux/[city]` déclare `dynamicParams = false` → la requête tombait
// dans le catch-all `/[...slug]`, une page CLIENT non mise en cache
// (`cache-control: no-store`, `x-vercel-cache: MISS`, rendue à Washington :
// ~2 s de TTFB depuis Paris) qui affiche « Ouvre dans l'app HoPetSit » et tente
// en plus d'ouvrir `hopetsit://garde-animaux/paris` — une route inconnue de
// l'app. Zéro contenu Paris, zéro bouton « Publier ma demande ».
//
// Cette page est une VRAIE route statique (segment fixe « paris », donc
// prioritaire sur `[city]` : aucun conflit avec les 117 autres villes, aucune
// URL existante modifiée). Elle joue aussi le rôle de hub : les liens vers les
// 20 arrondissements aident leur indexation (Search Console 17/09 : « détectés,
// non indexés »).
// 29/09 (SAM) — la fiche « Paris » vit dans recruit-cities.ts (PARIS_CITY),
// partagée avec /petsitter/paris et le maillage.
const PARIS: RecruitCity = PARIS_CITY;

const CANONICAL = "https://www.hopetsit.com/garde-animaux/paris";
// Le layout ajoute déjà « · HoPetSit » (metadata.title.template) : ne pas
// remettre « | HoPetSit » à la main, sinon la marque sort deux fois.
// 24/10 (GUS) — Search Console 28 j : « pet sitter paris » / « petsitter paris »
// 264 affichages, « garde animaux paris » 88, « dogsitting / dog sitting / dog
// sitter paris » 94 → 0 clic, cette page 20e-42e, et ce sont les arrondissements
// (H1 « Pet sitter Paris 15e ») qui sortent 60e-90e sur « petsitter paris ».
// Titre, description et H1 reprennent les mots tapés, « pet sitter » en tête.
const TITLE = "Pet sitter à Paris : garde d'animaux, dog sitting et promenades";
// 02/10 (SAM) — « vérifié » retiré : 1 seul profil parisien avec photo a
// l'identité vérifiée (/supply/city/faces) ; tutoiement aligné sur « vous ».
const DESCRIPTION =
  "Trouvez un pet sitter à Paris, arrondissement par arrondissement : garde de chien et de chat à domicile, dog sitting, visites et promenades. Paiement sécurisé, annulation gratuite 72 h.";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  alternates: { canonical: CANONICAL },
  // v577 — og:image explicite : sans lui cette page, cible de la publicite
  // Paris, se partage sans aucune vignette (un `openGraph` de page remplace
  // celui du layout au lieu de le completer).
  openGraph: { title: TITLE, description: DESCRIPTION, url: CANONICAL, type: "website", siteName: "HoPetSit", images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }] },
};

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
            href={`${OWNER_PATH_PREFIX.fr}/${c.slug}`}
            label="maillage"
            className="inline-block rounded-full bg-bg-soft px-3.5 py-2 text-sm font-medium text-ink transition hover:bg-owner-light hover:text-owner-dark max-lg:py-3"
          >
            {c.name}
          </TrackedLink>
        </li>
      ))}
    </ul>
  );
}

export default function GardeAnimauxParisPage() {
  return (
    <OwnerCityPage
      city={PARIS}
      h1="Pet sitter à Paris : garde, visites et promenades"
      // 08/10 (SAM) — le menu « Vous habitez où ? » (06-07/10) : 17 visiteurs
      // de la pub restés 3 s le 07/10 → 0 choix, 0 « Publier ». Remplacé par
      // une phrase + UN bouton qui ouvre directement le formulaire (le quartier
      // se précise dans son 1er champ, pré-rempli « Paris »).
      // 12/10 (SAM) — changement d'approche : 956 arrivées pub en 7 j → 8 clics
      // sur le bouton. Le premier écran EST désormais le formulaire court
      // (service, dates, une phrase, « Continuer » → étape 2 du formulaire).
      // Retour arrière : remettre <ParisHeroCta> (composant conservé).
      heroCta={
        <>
          <ParisHeroForm
            city={PARIS.name}
            lead="Des gardiens vérifiés près de chez toi te répondent avec leur prix. Sans compte, tout de suite."
            note="Gratuit · sans compte · tu choisis et tu paies ensuite, annulation gratuite jusqu'à 72 h avant"
            lang="fr"
            country="FR"
            campaign="paris_owners"
            page="/garde-animaux/paris"
          />
          {/* 1617 — preuve sociale réelle (demandes ouvertes de vrais propriétaires) ; absente si 0. */}
          <RequestsPulse1617 city="Paris" lang="fr" className="mt-3" />
        </>
      }
      stickyWatchId="hero-publier"
      seasonalBanner={false}
    >
      <section className="mt-12">
        {/* 01/11 (GUS) — Search Console 28 j France : « dog sitter paris » 85 affichages
            (14e), « dogsitting paris » 49, « dog sitting paris » 25 → 0 clic sur cette page.
            Section « Dog sitter à Paris » sous la ligne de flottaison (le premier écran /
            formulaire est mesuré : rien n'y est ajouté) + liens vers les 4 guides Paris.
            Remplace le lien saisonnier Toussaint (vacances finies le 01/11) par celui des fêtes. */}
        <h2 id="dog-sitter" className="scroll-mt-24 font-display text-2xl font-extrabold text-ink">Dog sitter à Paris</h2>
        <p className="mt-2 text-sm leading-relaxed text-ink-muted">
          Un dog sitter garde ton chien chez toi, le promène pendant ta journée de travail ou
          l&apos;accueille le temps d&apos;un week-end ou de tes vacances. Sur HoPetSit, tu publies ta
          demande (dates, quartier, habitudes de ton chien) et les dog sitters de ton arrondissement
          te répondent avec leur prix. Tu choisis, tu paies dans l&apos;app, et l&apos;annulation est
          gratuite jusqu&apos;à 72 h avant. Même chose pour un chat : visites à domicile plutôt que pension.
        </p>
        <ul className="mt-3 space-y-2 text-sm font-semibold">
          {[
            ["/blog/dog-sitter-paris", "Dog sitter à Paris : ce qu'il fait et comment en trouver un"],
            ["/blog/tarif-promeneur-de-chien-paris", "Combien coûte un promeneur de chien à Paris ?"],
            ["/blog/faire-garder-son-chat-a-paris", "Faire garder son chat à Paris : visites ou pension ?"],
            ["/blog/faire-garder-son-animal-pendant-les-fetes-a-paris", "🎄 Noël et jour de l'an : faire garder son chien ou son chat"],
          ].map(([href, label]) => (
            <li key={href}>
              <TrackedLink
                href={href}
                label="maillage"
                className="text-owner-dark underline-offset-4 hover:underline max-lg:inline-block max-lg:py-1"
              >
                {label}{" →"}
              </TrackedLink>
            </li>
          ))}
        </ul>
        <h2 id="quartiers" className="mt-8 scroll-mt-24 font-display text-2xl font-extrabold text-ink">Ton arrondissement</h2>
        <p className="mt-2 text-sm leading-relaxed text-ink-muted">
          Chaque arrondissement a sa page : les vétérinaires ouverts le week-end, les animaleries,
          les espaces canins et les gardiens HoPetSit du quartier.
        </p>
        <Chips cities={ARRONDISSEMENTS} />

        <h2 className="mt-10 font-display text-2xl font-extrabold text-ink">Autour de Paris</h2>
        <Chips cities={COMMUNES} />
      </section>
    </OwnerCityPage>
  );
}
