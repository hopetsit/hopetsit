import Link from "next/link";

// 06/10/2026 (GUS) — maillage des guides Paris côté PROPRIÉTAIRES.
// Search Console (inspection du 06/10) : 4 des 7 guides Paris n'étaient pas
// indexés (« détectée, non indexée » : chat, promenade ; « Google ne reconnaît
// pas cette URL » : chien seul, tarif promeneur) alors que les guides indexés
// (choisir un sitter, week-end, vacances, combien coûte) ne pointaient presque
// pas vers eux. Ce bloc relie les 7 guides entre eux depuis chaque article.
// Ne pas y ajouter de nouvelle page : uniquement des articles déjà en ligne.
const GUIDES = [
  { href: "/blog/faire-garder-son-chat-a-paris", t: "Faire garder son chat à Paris : visites à domicile ou pension ?" },
  { href: "/blog/promener-son-chien-a-paris", t: "Promener son chien à Paris : parcs, bois et bons plans" },
  { href: "/blog/chien-seul-toute-la-journee-paris", t: "Chien seul toute la journée à Paris : la promenade de midi" },
  { href: "/blog/tarif-promeneur-de-chien-paris", t: "Combien coûte un promeneur de chien à Paris ?" },
  { href: "/blog/choisir-un-pet-sitter-de-confiance-a-paris", t: "Comment choisir un pet sitter de confiance à Paris" },
  { href: "/blog/faire-garder-son-chien-le-week-end-a-paris", t: "Faire garder son chien le week-end à Paris" },
  { href: "/blog/faire-garder-son-chien-pendant-les-vacances", t: "Faire garder son chien pendant les vacances" },
  { href: "/blog/combien-coute-un-pet-sitter", t: "Combien coûte un pet sitter ? Tarifs garde chien et chat" },
];

export default function ParisGuidesLinks({ current }: { current: string }) {
  const items = GUIDES.filter((g) => g.href !== current);
  return (
    <section className="mt-14">
      <h2 className="font-display text-2xl font-extrabold text-ink">
        À lire aussi : nos guides pour les propriétaires à Paris
      </h2>
      <ul className="mt-5 grid gap-3 md:grid-cols-2">
        {items.map((g) => (
          <li key={g.href}>
            <Link
              href={g.href}
              className="flex min-h-[44px] items-center rounded-2xl border border-ink/5 bg-white px-4 py-3 text-sm font-semibold leading-snug text-ink shadow-card transition hover:text-owner-dark"
            >
              {g.t}
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}
