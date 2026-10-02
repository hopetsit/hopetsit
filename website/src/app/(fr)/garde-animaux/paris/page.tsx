import type { Metadata } from "next";
import OwnerCityPage from "@/components/OwnerCityPage";
import { TrackedLink } from "@/components/TrackedLink";
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
const TITLE = "Garde d'animaux à Paris — pet sitter, visites chats & promenades";
// 02/10 (SAM) — « vérifié » retiré : 1 seul profil parisien avec photo a
// l'identité vérifiée (/supply/city/faces) ; tutoiement aligné sur « vous ».
const DESCRIPTION =
  "Garde d'animaux à Paris : des gardiens et promeneurs près de chez vous, arrondissement par arrondissement. Paiement sécurisé, chat avant de réserver, annulation gratuite 72 h.";

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
    <OwnerCityPage city={PARIS} h1="Garde d'animaux à Paris : pet-sitter, chat et promenade de chien">
      <section className="mt-12">
        <h2 className="font-display text-2xl font-extrabold text-ink">Ton arrondissement</h2>
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
