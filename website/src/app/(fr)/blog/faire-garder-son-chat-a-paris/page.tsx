import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// v535 — SEO Paris : garde de chat (audience énorme, souvent oubliée des
// contenus « chien »).
// 13/11/2026 (GUS) — Search Console 28 j France : 277 affichages, 0 clic, 19e place
// (« cat sitter », « garde chat paris »). La description promettait une check-list
// absente de la page : ajoutée (+ visite type, + lien guide chat d'appartement),
// image propre 1200×630 au lieu de l'og-image générique. Aucun chiffre nouveau.
const URL = "https://www.hopetsit.com/blog/faire-garder-son-chat-a-paris";
const COVER = "https://www.hopetsit.com/blog/faire-garder-son-chat-a-paris.jpg";
const COVER_ALT = "Chat gris dans un salon parisien, couverture du guide « Garde de chat à Paris »";
const TITLE = "Garde de chat à Paris : cat sitter à domicile et prix";
const DESC =
  "Garde de chat à domicile à Paris : un cat sitter vient nourrir, câliner et changer la litière. Visites 8-15 €, garde complète, check-list avant de partir.";

export const metadata: Metadata = {
  title: TITLE,
  description: DESC,
  alternates: { canonical: URL },
  openGraph: {
    title: TITLE,
    description: DESC,
    url: URL,
    type: "article",
    locale: "fr_FR",
    siteName: "HoPetSit",
    images: [{ url: COVER, width: 1200, height: 630, alt: COVER_ALT }],
  },
};

const CHECKLIST = [
  "Croquettes et pâtée pour toute la durée, plus deux ou trois jours de marge.",
  "Litière en réserve et sacs pour la jeter, avec l'endroit où se trouve la poubelle de l'immeuble.",
  "Les habitudes écrites noir sur blanc : heures des repas, quantités, cachettes préférées, ce qui l'effraie.",
  "Le carnet de santé, les médicaments éventuels et la façon de les donner.",
  "Le nom et le téléphone de votre vétérinaire, plus une clinique ouverte le dimanche près de chez vous.",
  "Les clés, le code de la porte, l'étage, et un voisin ou un gardien d'immeuble prévenu.",
  "Fenêtres et balcon : dites ce qui doit rester fermé. À Paris, les chutes depuis un balcon sont un vrai risque pour les chats.",
];

const FAQ = [
  {
    q: "Combien coûte une visite pour chat à Paris ?",
    a: "Comptez 8 à 15 € la visite (repas, litière, jeu et câlins). Deux visites par jour se négocient souvent en formule. Une garde complète chez un cat sitter coûte 15 à 25 € par jour.",
  },
  {
    q: "Vaut-il mieux déplacer le chat ou le laisser chez lui ?",
    a: "Dans l'immense majorité des cas : le laisser chez lui. Le chat est attaché à son territoire ; des visites quotidiennes le stressent beaucoup moins qu'un déménagement temporaire en pension.",
  },
  {
    q: "Un chat peut-il rester seul un week-end ?",
    a: "24 à 36 heures maximum avec eau et croquettes en libre-service — et encore, pour un chat adulte en bonne santé. Au-delà, il faut une visite quotidienne : litière, eau fraîche et surveillance.",
  },
  {
    q: "Comment faire confiance à un inconnu chez moi ?",
    a: "Choisissez un profil avec identité vérifiée et avis de vraies réservations, échangez par chat avant, et faites une rencontre préalable. Sur HoPetSit, le paiement n'est débloqué qu'après le service.",
  },
];

export default function ArticleGarderChatParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: TITLE,
        description: DESC,
        url: URL,
        mainEntityOfPage: URL,
        image: { "@type": "ImageObject", url: COVER, width: 1200, height: 630 },
        inLanguage: "fr",
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
      <p className="text-sm font-semibold text-owner">Guide chat · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Garde de chat à Paris : faire garder son chat sans stress
      </h1>
      <Image
        src="/blog/faire-garder-son-chat-a-paris.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Les chats détestent deux choses : les valises et les changements. Bonne
        nouvelle : à Paris, la meilleure solution de garde est aussi la plus
        simple — quelqu'un vient chez vous. Voici comment ça marche et combien
        ça coûte.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Les deux vraies options</h2>
      <div className="mt-6 space-y-4">
        <div className="rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
          <h3 className="font-bold text-ink">🔑 Les visites à domicile (recommandé)</h3>
          <p className="mt-2 text-sm leading-relaxed text-ink-muted">
            Un cat sitter passe une à deux fois par jour : repas, eau fraîche,
            litière, jeu et câlins si votre chat est d'humeur. Il reste dans son
            royaume, vous recevez photos et nouvelles à chaque passage. C'est la
            formule préférée des vétérinaires comportementalistes.
          </p>
        </div>
        <div className="rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
          <h3 className="font-bold text-ink">🏠 La garde chez un cat sitter</h3>
          <p className="mt-2 text-sm leading-relaxed text-ink-muted">
            Pour les absences très longues ou les chats très sociables : votre
            chat est accueilli chez un passionné, sans autres animaux si besoin.
            Prévoyez ses affaires (arbre, panier, litière habituelle) pour
            adoucir la transition.
          </p>
        </div>
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Comment se passe une visite de cat sitter</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Une visite ne se résume pas à remplir la gamelle. Le cat sitter vérifie
        d&apos;abord que votre chat va bien : il mange, il boit, il se montre, la
        litière a servi normalement. Ensuite viennent l&apos;eau fraîche, le repas,
        le nettoyage de la litière, puis un moment de jeu ou de câlins si votre
        chat le veut bien — un chat timide peut rester caché les premiers jours,
        c&apos;est normal. Avant de partir, il vous envoie une photo et un mot. Si
        quelque chose cloche (il ne mange plus, il vomit, il se cache sans sortir),
        il vous prévient tout de suite et appelle votre vétérinaire si besoin.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">La check-list avant de partir</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Préparez ces points avec votre cat sitter, idéalement lors d&apos;une
        rencontre chez vous quelques jours avant le départ :
      </p>
      <ul className="mt-4 space-y-2">
        {CHECKLIST.map((item) => (
          <li key={item} className="flex gap-3 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="font-bold text-owner">✓</span>
            <span>{item}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Votre chat ne sort jamais de l&apos;appartement et vous hésitez encore entre
        visites et garde ailleurs ? Le guide{" "}
        <Link href="/blog/chat-dappartement-paris" className="font-semibold text-owner underline">
          chat d&apos;appartement à Paris
        </Link>{" "}
        détaille comment décider, et comment organiser l&apos;accès (digicode, clés,
        voisin).
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Où trouver un cat sitter par quartier</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Certains arrondissements comptent déjà beaucoup de chats en appartement. Dans le{" "}
        <Link href="/garde-animaux/paris-4" className="font-semibold text-owner underline">
          4e arrondissement
        </Link>
        , entre le Marais et l'île Saint-Louis, les visites à domicile pour chats sont très
        fréquentes. Même constat dans le{" "}
        <Link href="/garde-animaux/paris-9" className="font-semibold text-owner underline">
          9e
        </Link>
        , du côté de Pigalle et des Grands Boulevards, où jeunes couples et petits chiens se
        partagent le quartier avec de nombreux chats. Pour les autres quartiers, la page{" "}
        <Link href="/garde-animaux/paris" className="font-semibold text-owner underline">
          pet sitter à Paris
        </Link>{" "}
        réunit les 20 arrondissements et les communes voisines.
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

      <ParisGuidesLinks current="/blog/faire-garder-son-chat-a-paris" />

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Des cat sitters vérifiés dans votre quartier
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Comparez les profils parisiens, lisez les vrais avis et réservez des
          visites en quelques minutes — gratuitement sur HoPetSit.
        </p>
        <Link href="/download" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Télécharger l'app HoPetSit
        </Link>
      </div>
    </div>
  );
}
