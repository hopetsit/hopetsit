import type { Metadata } from "next";
import Link from "@/components/SiteLink";

// v531 — SEO : index du blog (pages 100% statiques côté serveur pour que
// Google indexe le texte — contrairement aux pages app qui sont client-side).
export const metadata: Metadata = {
  // v577 — `absolute` : sans lui le layout ajoute « · HoPetSit » a un titre
  // qui contient deja la marque, et Google coupe la fin du titre pour rien.
  title: { absolute: "Le blog HoPetSit — conseils garde & promenade d'animaux" },
  description:
    "Tarifs des pet sitters, conseils pour faire garder votre chien ou chat, promenades : les guides pratiques de l'équipe HoPetSit.",
  alternates: { canonical: "https://www.hopetsit.com/blog" },
};

const POSTS = [
  // 2026-W42 — marketing hebdo : Paris (voyager ou faire garder) + Houston (propriétaires).
  {
    slug: "voyager-avec-son-animal-ou-le-faire-garder",
    lang: "🇫🇷",
    title: "Voyager avec son animal ou le faire garder à Paris : comment décider ?",
    excerpt:
      "Emmener son chien ou son chat en voyage, ou le faire garder à Paris ? Les critères concrets pour trancher, les prix réels et comment bien préparer la garde.",
  },
  {
    slug: "finding-a-pet-sitter-in-houston",
    lang: "🇺🇸",
    title: "Finding a Pet Sitter in Houston: What It Costs and How to Choose (2026)",
    excerpt:
      "What pet sitting and dog walking cost in Houston, why midday heat changes the walk schedule, and how to check a sitter is trustworthy before you book.",
  },
  // 16/10 (SAM) — saisonnier : vacances de la Toussaint à Paris (17/10 → 2/11/2026).
  {
    slug: "garde-animaux-toussaint-paris",
    lang: "🇫🇷",
    title: "Garde de chien et de chat pendant les vacances de la Toussaint à Paris",
    excerpt:
      "Du 17 octobre au 2 novembre 2026 : gardien à domicile, pension ou famille, prix réels, check-list et pourquoi réserver tôt.",
  },
  // 21/10 (GUS) — « cat sitting / cat sitter <ville> » 717 affichages / 0 clic (USA, 28 j).
  {
    slug: "what-is-cat-sitting",
    lang: "🇺🇸",
    title: "Cat sitting explained: what a cat sitter does and how to find one near you",
    excerpt:
      "What happens during a visit, how many visits a day your cat needs, cat sitter or cattery, and how to choose someone you can trust with your keys.",
  },
  // 14/10 (GUS) — « dog sitting » 931 affichages / 0 clic (USA, 28 j) : guide propriétaire général.
  {
    slug: "what-is-dog-sitting",
    lang: "🇺🇸",
    title: "Dog sitting explained: how it works and how to find a dog sitter near you",
    excerpt:
      "Drop-in visits, day sitting or overnight stays: what each format involves, how it differs from boarding, what drives the price, and how to pick a sitter you can trust.",
  },
  // 2026-W41 — recrutement Paris 18e + Los Angeles (routine marketing hebdo).
  {
    slug: "devenir-pet-sitter-paris-18e",
    lang: "🇫🇷",
    title: "Devenir pet sitter dans le 18e arrondissement de Paris : le guide",
    excerpt:
      "Montmartre, Jules-Joffrin, la Goutte-d'Or : un quartier de voisinage où le bouche-à-oreille fait vite le plein — comment y trouver ses premiers clients.",
  },
  {
    slug: "become-a-pet-sitter-in-los-angeles",
    lang: "🇺🇸",
    title: "How to become a pet sitter in Los Angeles (and what you can earn)",
    excerpt:
      "Silver Lake, Santa Monica, the Eastside: realistic LA rates ($40-65/day, $20-30/walk) and how to land your first regular clients.",
  },
  // 06/10 (GUS) — recrutement Düsseldorf / Köln / Essen (mission de BOB, accord de Daniel).
  {
    slug: "haustiersitter-jobs-duesseldorf",
    lang: "🇩🇪",
    title: "Haustiersitter Jobs in Düsseldorf: so verdienst du Geld mit Tierbetreuung",
    excerpt:
      "Übliche Preise in Düsseldorf, Köln und Essen, was du wirklich behältst (100 % deines Preises) und die Regeln in NRW.",
  },
  // 05/10 (GUS) — recrutement New York (ordre de Daniel : plus de prestataires à NY).
  {
    slug: "dog-walker-jobs-nyc",
    lang: "🇺🇸",
    title: "Dog walker jobs in NYC: how to become a dog walker in New York",
    excerpt:
      "Leash and park rules, where the work is in each borough, and how to land your first regular clients. Free to join.",
  },
  {
    slug: "pet-sitting-jobs-new-york",
    lang: "🇺🇸",
    title: "Pet sitting jobs in New York: how much can you earn?",
    excerpt:
      "Usual New York rates ($20-35 a walk, $40-70 a day), what changes the price and what you keep after the commission.",
  },
  {
    slug: "choisir-un-pet-sitter-de-confiance-a-paris",
    lang: "🇫🇷",
    title: "Comment choisir un pet sitter de confiance à Paris : le guide",
    excerpt:
      "Profil vérifié, avis, rencontre préalable, paiement sécurisé, suivi GPS : ce qu'il faut vérifier avant de confier son animal à Paris.",
  },
  {
    slug: "how-much-does-a-pet-sitter-cost-in-dallas",
    lang: "🇺🇸",
    title: "How Much Does a Pet Sitter Cost in Dallas? 2026 Rates",
    excerpt:
      "Realistic Dallas rates ($30-55/day, $15-25/walk), how sitting compares to boarding, and how to pay safely.",
  },
  {
    slug: "devenir-pet-sitter-paris-15e",
    lang: "🇫🇷",
    title: "Devenir pet sitter dans le 15e arrondissement de Paris : le guide",
    excerpt:
      "Vaugirard, Convention, parc André-Citroën : le plus grand arrondissement de Paris manque de pet sitters — comment y trouver ses premiers clients.",
  },
  {
    slug: "become-a-pet-sitter-in-san-francisco",
    lang: "🇺🇸",
    title: "How to become a pet sitter in San Francisco (and what you can earn)",
    excerpt:
      "The Mission, Noe Valley, Golden Gate Park: realistic SF rates ($45-75/day, $25-40/walk) and how to land your first regular clients.",
  },
  {
    slug: "faire-garder-son-chien-le-week-end-a-paris",
    lang: "🇫🇷",
    title: "Faire garder son chien le week-end à Paris : le mode d'emploi",
    excerpt:
      "Un mariage, un week-end à la campagne : comment faire garder son chien 2-3 jours à Paris, à quel prix, et comment choisir un pet sitter vérifié.",
  },
  {
    slug: "finding-a-pet-sitter-in-austin",
    lang: "🇺🇸",
    title: "Finding a trusted dog sitter in Austin, TX (2026 guide)",
    excerpt:
      "Realistic Austin rates ($30-55/day, $15-25/walk), how to vet a sitter, and why secure in-app payment and live GPS tracking matter.",
  },
  {
    slug: "become-a-pet-sitter-in-chicago",
    lang: "🇺🇸",
    title: "How to become a pet sitter in Chicago (and what you can earn)",
    excerpt:
      "Lincoln Park, Wicker Park, the lakefront trail: realistic rates, how to land your first regular clients, and where to start.",
  },
  {
    slug: "devenir-pet-sitter-paris-11e",
    lang: "🇫🇷",
    title: "Devenir pet sitter dans le 11e arrondissement de Paris : le guide",
    excerpt:
      "Oberkampf, Bastille, République : pourquoi c'est l'un des meilleurs quartiers pour se lancer, et comment trouver ses premiers clients.",
  },
  {
    slug: "chien-seul-toute-la-journee-paris",
    lang: "🇫🇷",
    title: "Chien seul toute la journée à Paris : la solution de la promenade de midi",
    excerpt:
      "8 h de bureau, un chien seul à la maison : la promenade de midi à 12-20 € et comment bien choisir son promeneur à Paris.",
  },
  {
    slug: "devenir-pet-sitter-combien-ca-rapporte",
    lang: "🇫🇷",
    title: "Devenir pet sitter : combien ça rapporte vraiment ?",
    excerpt:
      "12 à 20 € la balade, 25 à 45 € la garde avec nuit : les revenus réels, le statut à choisir et par où commencer.",
  },
  {
    slug: "promener-son-chien-a-paris",
    lang: "🇫🇷",
    title: "Promener son chien à Paris : parcs, bois et bons plans",
    excerpt:
      "Bois de Vincennes, berges, parcs autorisés : où promener son chien à Paris — et la carte communautaire qui change tout.",
  },
  {
    slug: "tarif-promeneur-de-chien-paris",
    lang: "🇫🇷",
    title: "Combien coûte un promeneur de chien à Paris en 2026 ?",
    excerpt:
      "12 à 20 € la balade, forfaits dégressifs : les prix réels à Paris et comment vérifier que la balade a vraiment eu lieu.",
  },
  {
    slug: "faire-garder-son-chat-a-paris",
    lang: "🇫🇷",
    title: "Faire garder son chat à Paris : visites à domicile ou pension ?",
    excerpt:
      "Votre chat déteste bouger — et il a raison. Visites à domicile, prix et check-list pour partir l'esprit tranquille.",
  },
  {
    slug: "how-to-become-a-dog-walker",
    lang: "🇺🇸",
    title: "How to become a dog walker in 2026 (and what you can earn)",
    excerpt:
      "No degree, no boss: set your rates, choose your hours, get paid securely. The honest guide to starting in the US.",
  },
  {
    slug: "dog-boarding-vs-pet-sitting",
    lang: "🇺🇸",
    title: "Dog boarding vs pet sitting: which is best for your dog?",
    excerpt:
      "Prices, stress levels and safety compared — kennel or in-home sitter, decide in five minutes.",
  },
  {
    slug: "leaving-cat-alone-vacation",
    lang: "🇺🇸",
    title: "How long can you leave a cat alone? Vacation guide",
    excerpt:
      "24-36 hours max — and that's pushing it. What vets recommend and how drop-in visits solve everything.",
  },
  {
    slug: "combien-coute-un-pet-sitter",
    lang: "🇫🇷",
    title: "Combien coûte un pet sitter en 2026 ? Tarifs garde chien & chat",
    excerpt:
      "Garde à domicile, visites, promenades : les fourchettes de prix réelles en France et comment payer le juste tarif.",
  },
  {
    slug: "faire-garder-son-chien-pendant-les-vacances",
    lang: "🇫🇷",
    title: "Faire garder son chien pendant les vacances : le guide complet",
    excerpt:
      "Pension, famille, pet sitter à domicile : les options comparées, les pièges à éviter et notre check-list avant le départ.",
  },
  {
    slug: "how-much-does-a-dog-walker-cost",
    lang: "🇬🇧",
    title: "How much does a dog walker cost in 2026?",
    excerpt:
      "Typical dog walking rates, what changes the price, and how to find a trusted walker near you.",
  },
];

export default function BlogIndexPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-4xl font-extrabold tracking-tight text-ink md:text-5xl">
        Le blog HoPetSit
      </h1>
      <p className="mx-auto mt-4 max-w-xl text-center text-lg text-ink-muted">
        Conseils pratiques pour faire garder et promener vos animaux en toute
        confiance.
      </p>
      <div className="mt-14 space-y-6">
        {POSTS.map((p) => (
          <Link
            key={p.slug}
            href={`/blog/${p.slug}`}
            className="block rounded-2xl border border-ink/5 bg-white p-6 shadow-card transition hover:border-owner/40"
          >
            <div className="text-xs text-ink-soft">{p.lang}</div>
            <h2 className="mt-1 text-lg font-bold text-ink">{p.title}</h2>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{p.excerpt}</p>
            <span className="mt-3 inline-block text-sm font-semibold text-owner">
              Lire l'article →
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}
