import type { Metadata } from "next";
import Link from "next/link";

// 2026-W38 — SEO : article statique « garde de week-end à Paris » (angle
// PROPRIÉTAIRES, semaine ISO paire). Distinct de la garde vacances (plusieurs
// semaines) et de la promenade de midi (chien seul en semaine) déjà couvertes.
export const metadata: Metadata = {
  title: "Faire garder son chien le week-end à Paris : le mode d'emploi",
  description:
    "Un mariage, un week-end à la campagne, une envie de souffler : comment faire garder son chien 2 ou 3 jours à Paris, à quel prix, et comment choisir un pet sitter vérifié.",
  alternates: {
    canonical:
      "https://www.hopetsit.com/blog/faire-garder-son-chien-le-week-end-a-paris",
  },
};

const FAQ = [
  {
    q: "Combien coûte une garde de week-end à Paris ?",
    a: "Comptez 20 à 30 € par jour pour une garde à domicile chez le pet sitter, souvent avec un léger tarif dégressif à partir du deuxième jour. Une visite quotidienne chez vous, sans garde de nuit, revient plutôt à 8 à 15 € par passage.",
  },
  {
    q: "Faut-il rencontrer le pet sitter avant de partir ?",
    a: "Oui, c'est la règle numéro un. Un échange, même de vingt minutes, permet de vérifier que le contact passe bien avec votre chien et de transmettre ses habitudes : gamelle, laisse, traitement en cours, comportement avec les autres animaux.",
  },
  {
    q: "Le paiement se fait-il avant ou après la garde ?",
    a: "Sur HoPetSit, le paiement est sécurisé dans l'app dès la réservation acceptée, mais l'argent n'est reversé au pet sitter qu'une fois l'animal rendu. Vous n'avez jamais à régler en liquide ni à l'avance sans garantie.",
  },
  {
    q: "Comment savoir si mon chien a bien été promené ?",
    a: "Le suivi GPS PawFollow affiche l'itinéraire et la durée de chaque sortie en direct, consultable depuis votre téléphone où que vous soyez. Vous pouvez aussi échanger des photos et des messages avec le pet sitter pendant tout le week-end.",
  },
  {
    q: "Et si un imprévu survient pendant le week-end ?",
    a: "Un profil vérifié et des avis d'autres propriétaires parisiens limitent le risque, mais gardez toujours les coordonnées de votre vétérinaire habituel à portée de main et vérifiez que le pet sitter s'engage à vous prévenir immédiatement en cas de souci.",
  },
];

export default function ArticleGardeWeekEndParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Faire garder son chien le week-end à Paris : le mode d'emploi",
        inLanguage: "fr",
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: {
          "@type": "Organization",
          name: "HoPetSit",
          url: "https://www.hopetsit.com",
        },
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
      <p className="text-sm font-semibold text-owner">Guide pratique · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Faire garder son chien le week-end à Paris : le mode d'emploi
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Un mariage en province, une envie d'air pur ou simplement deux jours
        pour souffler sans emmener le chien : la garde de week-end est la
        demande la plus fréquente sur HoPetSit à Paris, bien avant les grandes
        vacances. Voici comment l'organiser sans stress, ni pour vous, ni pour
        votre chien.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Week-end, vacances, promenade : ce n'est pas la même demande
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Deux ou trois jours d'absence n'appellent pas la même solution qu'un
        départ de deux semaines l'été. Vous n'avez pas besoin d'un contrat
        long ni d'un hébergement collectif : un pet sitter du quartier qui
        accueille votre chien chez lui, ou qui vient chez vous, suffit
        largement. C'est aussi une bonne façon de tester une relation de
        confiance avant de lui confier une garde plus longue pendant les{" "}
        <Link href="/blog/faire-garder-son-chien-pendant-les-vacances" className="font-semibold text-owner underline">
          vacances d'été
        </Link>.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Combien ça coûte à Paris
      </h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Formule</th>
              <th className="p-4 font-bold">Tarif courant à Paris</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Visite quotidienne à domicile</td>
              <td className="p-4">8 – 15 € par passage</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Garde à la journée, sans nuit</td>
              <td className="p-4">20 – 30 €</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Garde avec nuit, chez le sitter ou chez vous</td>
              <td className="p-4">25 – 45 €</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        Pour un week-end classique de deux nuits, comptez entre 50 et 90 €
        tout compris. Beaucoup de pet sitters appliquent un léger tarif
        dégressif à partir du deuxième jour consécutif.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Comment choisir un pet sitter vérifié
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Ne vous arrêtez pas à la première annonce venue. Regardez d'abord les
        avis laissés par d'autres propriétaires parisiens : ils en disent
        plus long qu'une jolie photo de profil. Privilégiez ensuite quelqu'un
        de vraiment proche de chez vous — un pet sitter à quinze minutes à
        pied respecte mieux les habitudes de sortie de votre chien qu'un
        profil à l'autre bout de la ville.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Prenez le temps d'un échange avant de réserver, même court : c'est le
        moment de transmettre les consignes (repas, traitement en cours,
        comportement avec les autres chiens) et de sentir si le contact passe
        naturellement. Sur la{" "}
        <Link href="/pawmap" className="font-semibold text-owner underline">
          PawMap
        </Link>, vous voyez aussi les parcs et lieux pet-friendly autour du
        domicile du sitter, utile pour se projeter sur les sorties du
        week-end.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Pendant le week-end : suivi et paiement sécurisé
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Le vrai confort d'un week-end sans le chien, c'est de ne pas avoir à
        s'inquiéter. Le suivi GPS <strong>PawFollow</strong> affiche en
        direct chaque promenade sur la carte, et le chat intégré permet
        d'échanger des photos avec le pet sitter sans passer par un autre
        numéro. Le paiement, lui, reste sécurisé dans l'app dès l'acceptation
        de la réservation et n'est reversé au sitter qu'une fois votre chien
        récupéré — vous n'avez jamais à régler en liquide à l'avance.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Questions fréquentes
      </h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div
            key={f.q}
            className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card"
          >
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Trouvez un pet sitter vérifié près de chez vous
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Profils vérifiés, avis vérifiés, paiement sécurisé et suivi GPS de
          chaque promenade, partout à Paris et en Île-de-France.
        </p>
        <Link
          href="/garde-animaux/paris"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Trouver un pet sitter à Paris
        </Link>
      </div>
    </div>
  );
}
