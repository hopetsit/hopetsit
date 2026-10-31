import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// 31/10/2026 (GUS) — consigne de Daniel du 31/10 au soir : SEO sur 4 pôles (Paris + Europe,
// New York, Séoul, Tokyo) avec un article par ville. Sujet saisonnier distinct des articles
// existants (Toussaint = garde-animaux-toussaint-paris ; vacances en général =
// faire-garder-son-chien-pendant-les-vacances) : Noël et le Nouvel An à Paris. Aucun tarif,
// aucun chiffre : chaque gardien fixe son prix dans l'app.
const URL = "https://www.hopetsit.com/blog/faire-garder-son-animal-pendant-les-fetes-a-paris";
const TITLE = "Faire garder son chien ou son chat pendant les fêtes à Paris";
const DESCRIPTION =
  "Noël, Nouvel An : quand réserver un gardien à Paris, garde chez lui ou chez vous, pétards et repas de fête, ce qu'il faut laisser au pet sitter. Le guide pour partir l'esprit tranquille.";
const HEADLINE = "Faire garder son chien ou son chat pendant les fêtes de fin d'année à Paris";

export const metadata: Metadata = {
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
    images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }],
  },
};

const FAQ = [
  {
    q: "Quand réserver un gardien pour Noël à Paris ?",
    a: "Le plus tôt possible. Les gardiens ont eux aussi des fêtes en famille, et beaucoup de propriétaires partent aux mêmes dates. Publier votre demande dès novembre vous laisse le temps de comparer les réponses et de rencontrer le gardien avec votre animal.",
  },
  {
    q: "Mon chat peut-il rester seul pendant les fêtes ?",
    a: "Un chat adulte en bonne santé supporte mieux de rester chez lui qu'un chien, mais pas sans visites : eau fraîche, repas, litière et un peu de compagnie au moins une fois par jour. Pour plus de deux jours, prévoyez des visites quotidiennes ou un gardien qui dort chez vous.",
  },
  {
    q: "Comment protéger mon chien des pétards du 31 décembre ?",
    a: "Prévenez le gardien si votre chien a peur du bruit : sortie plus tôt dans la soirée, laisse bien attachée, fenêtres fermées et un coin calme où il peut se cacher. Si votre vétérinaire a prescrit quelque chose, laissez l'ordonnance et les doses écrites.",
  },
  {
    q: "Combien coûte une garde pendant les fêtes ?",
    a: "Il n'y a pas de prix unique : il dépend de la formule (visites, garde chez le gardien, nuits chez vous), de la durée et du nombre d'animaux. Sur HoPetSit, chaque gardien fixe son tarif et vous voyez le total avant de confirmer.",
  },
  {
    q: "Et si mes plans changent ?",
    a: "Prévenez le gardien par le chat de l'app le plus tôt possible. HoPetSit prévoit une annulation gratuite jusqu'à 72 heures avant le début de la garde.",
  },
];

const FORMULES = [
  {
    t: "La garde chez le gardien",
    d: "Votre chien passe les fêtes chez un gardien du quartier. Il n'est jamais seul, garde ses promenades et profite d'une vraie maison. C'est la formule la plus simple pour une semaine d'absence.",
  },
  {
    t: "Le gardien qui dort chez vous",
    d: "Idéal pour un animal âgé ou anxieux, ou quand vous avez à la fois un chien et un chat : chacun garde ses repères, et votre appartement est occupé pendant votre absence.",
  },
  {
    t: "Les visites à domicile",
    d: "Une ou deux visites par jour pour nourrir, changer la litière, jouer et vérifier que tout va bien. C'est souvent ce qui convient le mieux à un chat.",
  },
  {
    t: "La promenade",
    d: "Si vous restez à Paris mais que les journées de fêtes sont chargées, un promeneur peut sortir votre chien à midi ou en fin d'après-midi.",
  },
];

export default function ArticleFetesParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "fr-FR",
        mainEntityOfPage: URL,
        datePublished: "2026-10-31",
        image: { "@type": "ImageObject", url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630 },
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
        mainEntity: FAQ.map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })),
      },
    ],
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">Guide pratique · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Faire garder son chien ou son chat pendant les fêtes à Paris
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Noël chez les parents en province, le réveillon à l'étranger, quelques jours au ski : entre
        Noël et le Nouvel An, beaucoup de Parisiens partent en même temps. C'est aussi la période où
        trouver quelqu'un pour garder son animal devient difficile, parce que tout le monde s'y prend
        à la dernière minute. Voici comment organiser la garde de votre chien ou de votre chat
        pendant les fêtes, sans stress pour lui ni pour vous.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Pourquoi s'y prendre tôt</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Les vacances scolaires de Noël concentrent les départs sur les mêmes dates. Les gardiens
        sont des particuliers : eux aussi ont un repas de famille, un voyage, des invités. Les
        places partent donc vite, surtout pour les gardes avec nuits. Publier votre demande dès
        novembre vous donne trois avantages : plus de réponses, le temps de comparer les profils et
        les avis, et surtout le temps d'organiser une rencontre avec votre animal avant le départ.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Cette rencontre compte plus qu'on ne le croit. Un chien qui a déjà fait une promenade avec
        son gardien, un chat qui a déjà vu la personne qui viendra le nourrir, vivent beaucoup mieux
        la séparation. Profitez-en pour montrer où sont la nourriture, la laisse, la litière, et pour
        expliquer les petites habitudes de la maison.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Les 4 formules possibles</h2>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {FORMULES.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        Pour un chat, lisez aussi notre guide{" "}
        <Link href="/blog/faire-garder-son-chat-a-paris" className="font-semibold text-owner underline">
          faire garder son chat à Paris
        </Link>
        . Pour un chien, le guide{" "}
        <Link href="/blog/dog-sitter-paris" className="font-semibold text-owner underline">
          dog sitter à Paris
        </Link>{" "}
        détaille chaque formule.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Les pièges des fêtes pour un animal</h2>
      <ul className="mt-4 space-y-2">
        {[
          "Les repas de fête : chocolat, raisins secs, os de volaille cuits et plats très gras sont dangereux pour les chiens et les chats. Demandez au gardien de ne rien donner en dehors de la nourriture habituelle.",
          "Les pétards et feux d'artifice du 31 décembre : beaucoup de chiens paniquent. Sortie plus tôt dans la soirée, laisse bien attachée, harnais ajusté, fenêtres fermées.",
          "Le sapin et les décorations : guirlandes, boules et fils électriques attirent les chats. Si un gardien vient chez vous, mettez-les hors de portée avant de partir.",
          "Le froid et l'humidité : promenades plus courtes mais plus fréquentes pour un petit chien ou un chien âgé, et pattes essuyées au retour.",
          "Les horaires réduits : beaucoup de cabinets vétérinaires ferment ou réduisent leurs horaires entre Noël et le jour de l'An. Laissez au gardien le numéro de votre vétérinaire et celui d'une urgence vétérinaire ouverte la nuit.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Ce qu'il faut laisser au gardien</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Une fiche simple évite les appels pendant votre réveillon : les quantités et heures des
        repas, la nourriture en quantité suffisante (plus quelques jours de marge), les traitements
        et leurs doses, le carnet de santé, le numéro d'identification de votre animal (puce ou
        tatouage, obligatoire pour un chien en France), les coordonnées de votre vétérinaire, un
        double des clés et le code de l'immeuble. Notez aussi ce qui rassure votre animal : un jouet,
        une couverture, une habitude du soir.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Trouver un gardien dans votre arrondissement</h2>
      <ol className="mt-4 space-y-3">
        {[
          "Publiez votre demande gratuitement : l'animal, les dates exactes, la formule voulue et votre arrondissement.",
          "Les gardiens et promeneurs proches reçoivent votre demande et vous répondent avec leur prix.",
          "Comparez les profils et les avis, discutez dans le chat, et proposez une rencontre avant les fêtes.",
          "Payez dans l'app : le paiement est sécurisé et n'est reversé au gardien qu'après la garde. Pendant les promenades, le suivi GPS PawFollow vous montre le trajet en direct.",
        ].map((t, i) => (
          <li key={t} className="flex gap-3 leading-relaxed text-ink-muted">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-owner text-sm font-bold text-white">{i + 1}</span>
            <span>{t}</span>
          </li>
        ))}
      </ol>
      <p className="mt-6 leading-relaxed text-ink-muted">
        Chaque arrondissement a sa page, avec les vétérinaires, les espaces canins et les jardins du
        quartier : retrouvez la vôtre sur{" "}
        <Link href="/garde-animaux/paris#quartiers" className="font-semibold text-owner underline">
          notre page pet sitter à Paris
        </Link>
        .
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

      <ParisGuidesLinks current="/blog/faire-garder-son-animal-pendant-les-fetes-a-paris" />

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">Partez tranquille pendant les fêtes</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Garde, visites ou promenade, dans les 20 arrondissements de Paris et en Île-de-France.
        </p>
        <Link href="/garde-animaux/paris" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Trouver un gardien à Paris
        </Link>
      </div>
    </div>
  );
}
