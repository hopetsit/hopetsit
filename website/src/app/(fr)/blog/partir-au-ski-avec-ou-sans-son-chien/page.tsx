import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// 2026-W47 (marketing hebdo, dimanche) — sujet suivant non coché de
// `marketing/sujets_4poles.md` § Paris (page pilier /garde-animaux/paris#quartiers).
// Saisonnier (vacances de ski de février) mais écrit sans date précise pour
// rester utile plusieurs hivers. Aucun prix hors des fourchettes déjà
// publiées (15-30 €/jour, 25-45 €/nuit, 12-20 € la promenade — cf.
// /blog/voyager-avec-son-animal-ou-le-faire-garder) et aucune affirmation
// juridique ou fiscale.
// 23/11/2026 (GUS) — image propre 1200×630 ajoutée (og:image, JSON-LD, haut de page).
const URL = "https://www.hopetsit.com/blog/partir-au-ski-avec-ou-sans-son-chien";
const TITLE = "Partir au ski avec ou sans son chien : organiser la garde depuis Paris";
const COVER = "https://www.hopetsit.com/blog/partir-au-ski-avec-ou-sans-son-chien.jpg";
const COVER_ALT = "Un chien noir tenu en laisse en forêt, image du guide pour partir au ski avec ou sans son chien";
const DESCRIPTION =
  "Chien au chalet ou garde à Paris pendant les vacances de ski : les critères pour décider, les prix réels et comment réserver à temps avant les vacances scolaires.";

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
    images: [{ url: COVER, width: 1200, height: 630, alt: COVER_ALT }],
  },
};

const FAQ = [
  {
    q: "Peut-on emmener son chien au ski ?",
    a: "Beaucoup de chiens s'en accommodent très bien, surtout les races habituées au froid, mais tout dépend du trajet, du logement et du caractère de l'animal. Un chien anxieux en voiture ou peu habitué aux changements d'environnement est souvent plus serein en restant dans ses repères à Paris.",
  },
  {
    q: "Et pour un chat, la question se pose-t-elle vraiment ?",
    a: "Rarement. Un chat voyage mal, supporte mal le changement de territoire et n'a aucun bénéfice à partir au ski. Des visites à domicile ou une garde chez un sitter parisien restent presque toujours la meilleure option, comme on le détaille dans notre guide sur le chat d'appartement à Paris.",
  },
  {
    q: "Combien coûte la garde de son animal pendant les vacances de ski ?",
    a: "Comptez en moyenne 15 à 30 € par jour pour une garde chez un pet sitter, et 25 à 45 € pour une garde avec nuit. Une semaine complète se négocie presque toujours avec un tarif dégressif.",
  },
  {
    q: "Faut-il réserver longtemps à l'avance pour les vacances de février ?",
    a: "Oui. Les vacances scolaires de février concentrent les départs sur une période courte, et les meilleurs profils parisiens se réservent vite. Mieux vaut s'y prendre plusieurs semaines avant plutôt que la veille du départ.",
  },
  {
    q: "Que laisser au pet sitter avant de partir une semaine ?",
    a: "Les quantités exactes de nourriture pour toute la durée, les coordonnées du vétérinaire habituel, un double des clés et les habitudes de l'animal (jeux, promenades, comportement avec les autres animaux). Une rencontre préalable permet de régler ces détails calmement avant le départ.",
  },
];

export default function ArticlePartirAuSki() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: TITLE,
        description: DESCRIPTION,
        inLanguage: "fr",
        mainEntityOfPage: URL,
        datePublished: "2026-11-22",
        image: { "@type": "ImageObject", url: COVER, width: 1200, height: 630 },
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
        {TITLE}
      </h1>
      <Image
        src="/blog/partir-au-ski-avec-ou-sans-son-chien.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Entre le chalet qui n&apos;accepte pas les animaux, le trajet en
        voiture de plusieurs heures et le froid en altitude, partir au ski
        avec son chien ou son chat ne se décide pas à la légère. Voici de quoi
        trancher sereinement, et comment organiser la garde depuis Paris si
        vous décidez de le laisser.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Chien ou chat : la question ne se pose pas de la même façon
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Un chien habitué au froid et aux longs trajets peut très bien profiter
        d&apos;une semaine à la montagne, à condition que le logement
        l&apos;accepte et que le programme lui laisse de vraies sorties en
        laisse. Un chien anxieux en voiture, sensible aux changements de
        rythme ou peu sociable avec d&apos;autres animaux croisés en station
        est en revanche souvent plus heureux à rester dans ses repères. Pour
        un chat, la réponse est presque toujours la même : le voyage
        n&apos;apporte rien, et un animal attaché à son territoire s&apos;en
        sort nettement mieux avec des visites à domicile, comme on le détaille
        dans notre guide sur{" "}
        <Link href="/blog/chat-dappartement-paris" className="font-semibold text-owner underline">
          le chat d&apos;appartement à Paris
        </Link>
        .
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Emmener son chien au ski : ce qu&apos;il faut vérifier avant de partir
      </h2>
      <ul className="mt-4 space-y-2">
        {[
          "La politique « animaux acceptés » du chalet ou de la location, souvent avec un supplément — à confirmer par écrit avant de réserver.",
          "La durée du trajet et les pauses nécessaires si vous partez en voiture : un chien a besoin de s'arrêter régulièrement, surtout sur un long trajet vers les Alpes ou les Pyrénées.",
          "Le carnet de vaccination à jour si le logement ou un chenil local le demande en cas de garde ponctuelle sur place.",
          "Les manteaux pour chiens à poil court et un sol parfois gelé devant le chalet, qui peut être aussi glissant qu'un trottoir parisien en hiver.",
          "Les pistes et remontées mécaniques, qui n'acceptent presque jamais les chiens : prévoir à l'avance qui s'en occupe pendant que vous skiez.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Laisser son animal à Paris : les options et leur prix réel
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Si vous décidez de ne pas emmener votre animal, trois formules
        existent : des visites quotidiennes à domicile, une garde chez un pet
        sitter de votre arrondissement, ou une garde à domicile chez vous si
        quelqu&apos;un peut y loger. Comptez en moyenne 15 à 30 € par jour pour
        une garde chez un sitter, 25 à 45 € pour une garde avec nuit, et 12 à
        20 € pour une simple promenade si votre chien a surtout besoin de
        sorties régulières plutôt que d&apos;une garde complète. Une semaine
        entière se négocie presque toujours avec un tarif dégressif, comme on
        le détaille dans notre guide{" "}
        <Link href="/blog/voyager-avec-son-animal-ou-le-faire-garder" className="font-semibold text-owner underline">
          voyager avec son animal ou le faire garder
        </Link>
        . Vérifiez toujours le profil de la personne que vous choisissez —
        notre guide{" "}
        <Link href="/blog/choisir-un-pet-sitter-de-confiance-a-paris" className="font-semibold text-owner underline">
          pour choisir un pet sitter de confiance à Paris
        </Link>{" "}
        liste les points à contrôler avant de confier les clés de chez vous.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Réserver tôt : la bonne fenêtre avant les vacances scolaires
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Les vacances de ski concentrent énormément de départs parisiens sur
        une période courte, souvent la même semaine ou les deux semaines qui
        suivent selon la zone académique. Les sitters les plus demandés de
        votre quartier se réservent vite, exactement comme pour les{" "}
        <Link href="/blog/faire-garder-son-chien-pendant-les-vacances" className="font-semibold text-owner underline">
          vacances d&apos;été ou de Noël
        </Link>
        . Si vous savez déjà que vous partez, il est plus prudent de chercher
        et de rencontrer quelqu&apos;un plusieurs semaines avant le départ
        plutôt que de s&apos;y prendre la veille.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Ce qu&apos;il faut laisser au pet sitter avant de partir
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Une semaine de garde se prépare un peu différemment d&apos;un
        week-end : prévoyez la quantité exacte de nourriture pour toute la
        durée, les coordonnées du vétérinaire habituel et un numéro de contact
        joignable en cas de besoin. Une rencontre préalable, même brève, permet
        de régler les habitudes de votre animal (jeux, horaires de sortie,
        comportement avec d&apos;autres animaux) et d&apos;éviter les
        mauvaises surprises une fois sur les pistes.
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

      <ParisGuidesLinks current="/blog/partir-au-ski-avec-ou-sans-son-chien" />

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Un pet sitter vérifié près de chez vous avant de partir au ski
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Comparez les profils de votre arrondissement, lisez les vrais avis
          et réservez une garde en quelques minutes — gratuitement sur
          HoPetSit.
        </p>
        <Link href="/garde-animaux/paris#quartiers" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Trouver un pet sitter à Paris
        </Link>
      </div>
    </div>
  );
}
