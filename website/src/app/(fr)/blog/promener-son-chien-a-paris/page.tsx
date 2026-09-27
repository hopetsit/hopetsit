import type { Metadata } from "next";
import Link from "next/link";

// v535 — SEO Paris : guide promenade de chien à Paris (trafic local + PawMap).
export const metadata: Metadata = {
  title: "Promener son chien à Paris : parcs, bois et bons plans (2026)",
  description:
    "Où promener son chien à Paris ? Bois de Vincennes et de Boulogne, berges, canaux, règles de laisse et astuces de la communauté — le guide pratique 2026.",
  alternates: { canonical: "https://www.hopetsit.com/blog/promener-son-chien-a-paris" },
};

const SPOTS = [
  {
    t: "🌳 Le bois de Vincennes",
    p: "Le grand classique de l'Est parisien : des kilomètres d'allées, des lacs et de vastes pelouses. Idéal pour les longues balades du week-end, accessible en métro (ligne 1, Château de Vincennes).",
  },
  {
    t: "🌲 Le bois de Boulogne",
    p: "Le pendant de l'Ouest : étangs, sous-bois et sentiers ombragés l'été. Les chiens y sont à l'aise tôt le matin, quand les coureurs sont encore rares.",
  },
  {
    t: "🚶 Les berges et canaux",
    p: "Canal de l'Ourcq, canal Saint-Martin, berges de Seine : parfaits pour les balades urbaines en laisse, avec de l'eau, de l'ombre et des terrasses pet-friendly.",
  },
  {
    t: "🏞️ Les parcs de quartier",
    p: "De plus en plus de parcs et squares parisiens acceptent les chiens tenus en laisse — la signalétique à l'entrée fait foi, et elle évolue régulièrement. Vérifiez les horaires : certains espaces ne sont ouverts aux chiens qu'à certaines heures.",
  },
];

const TIPS = [
  "La laisse est la règle générale à Paris — les espaces de liberté (caniparcs) restent rares, repérez-les près de chez vous.",
  "Évitez 12h-16h en été : le bitume brûlant abîme les coussinets. Le test : posez votre main 5 secondes au sol.",
  "Ayez toujours de l'eau et des sacs — les amendes pour déjections non ramassées sont réelles.",
  "Variez les parcours : un chien qui découvre de nouvelles odeurs se dépense deux fois plus.",
];

export default function ArticlePromenerChienParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: "Promener son chien à Paris : parcs, bois et bons plans",
    inLanguage: "fr",
    author: { "@type": "Organization", name: "HoPetSit" },
    publisher: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com" },
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">Guide local · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Promener son chien à Paris : parcs, bois et bons plans
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Promener un chien à Paris, c'est tout un art : entre les parcs qui
        acceptent les chiens, ceux qui les refusent et les horaires qui
        changent, mieux vaut connaître les bons spots. Voici le guide pratique —
        et comment la communauté parisienne les partage en temps réel.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Les meilleurs endroits pour se dépenser
      </h2>
      <div className="mt-6 space-y-4">
        {SPOTS.map((s) => (
          <div key={s.t} className="rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <h3 className="font-bold text-ink">{s.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{s.p}</p>
          </div>
        ))}
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Les règles d'or du promeneur parisien
      </h2>
      <ul className="mt-6 space-y-3">
        {TIPS.map((t, i) => (
          <li key={i} className="flex gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
            <span className="text-owner">✓</span>
            <span className="text-sm leading-relaxed text-ink-muted">{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Le secret des Parisiens : la carte communautaire
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Les règles changent, les bons coins se découvrent : c'est exactement
        pour ça que la <strong>PawMap</strong> de HoPetSit existe. Les
        propriétaires parisiens y épinglent les parcs accessibles, les cafés
        pet-friendly, les points d'eau et même les alertes (zones à tiques,
        travaux). Ouvrez la carte, et le quartier vous appartient.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Pas le temps de promener aujourd'hui ? Des{" "}
        <Link href="/petsitter/paris" className="font-semibold text-owner">
          promeneurs de chiens vérifiés à Paris
        </Link>{" "}
        prennent le relais — avec le trajet suivi en GPS depuis votre téléphone.
      </p>

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          La PawMap de Paris vous attend
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Téléchargez HoPetSit gratuitement : la carte des spots pet-friendly,
          les promeneurs de votre quartier et le suivi GPS des balades.
        </p>
        <Link href="/download" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Télécharger l'app HoPetSit
        </Link>
      </div>
    </div>
  );
}
