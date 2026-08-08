import type { Metadata } from "next";
import Link from "next/link";

// v531 — SEO : article statique « faire garder son chien vacances ».
export const metadata: Metadata = {
  title: "Faire garder son chien pendant les vacances : le guide complet 2026",
  description:
    "Pension, famille ou pet sitter à domicile ? Options comparées, prix, pièges à éviter et check-list avant le départ pour des vacances l'esprit tranquille.",
  alternates: {
    canonical: "https://www.hopetsit.com/blog/faire-garder-son-chien-pendant-les-vacances",
  },
};

const OPTIONS = [
  {
    t: "🏠 Le pet sitter à domicile",
    p: "Votre chien reste chez vous ou est accueilli chez un particulier passionné. Il garde ses habitudes, sa gamelle, ses promenades. C'est l'option la plus rassurante pour les animaux anxieux — et souvent la plus économique (15 à 30 €/jour).",
  },
  {
    t: "🏢 La pension canine",
    p: "Encadrement professionnel et locaux dédiés, mais environnement collectif parfois stressant, vaccins exigés et budget plus élevé (25 à 45 €/jour). À réserver longtemps à l'avance pour l'été.",
  },
  {
    t: "👨‍👩‍👧 La famille ou les amis",
    p: "Gratuit et affectif, mais pas toujours disponible, ni équipé, ni assuré. Et difficile d'oser demander un compte-rendu quotidien ou d'imposer vos consignes.",
  },
];

const CHECKLIST = [
  "Rencontrez le pet sitter avant le départ (ou faites une visio) et observez le contact avec votre chien.",
  "Vérifiez l'identité et les avis : privilégiez les profils vérifiés avec de vraies réservations.",
  "Préparez un carnet de consignes : rythme des repas, promenades, traitements, véto habituel.",
  "Laissez croquettes, laisse, panier et jouet préféré — les repères comptent autant que les soins.",
  "Convenez du rythme des nouvelles : photos, messages, et idéalement suivi GPS des promenades.",
  "Payez de façon traçable et sécurisée, jamais tout en liquide à l'avance.",
];

export default function ArticleGarderChienVacances() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: "Faire garder son chien pendant les vacances : le guide complet",
    inLanguage: "fr",
    author: { "@type": "Organization", name: "HoPetSit" },
    publisher: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com" },
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <p className="text-sm font-semibold text-owner">Guide pratique</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Faire garder son chien pendant les vacances : le guide complet
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Chaque été, des millions de propriétaires se posent la même question :
        qui va s'occuper du chien ? Voici les trois options qui existent
        vraiment, leurs prix, et la check-list pour partir l'esprit tranquille.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Les 3 options comparées
      </h2>
      <div className="mt-6 space-y-4">
        {OPTIONS.map((o) => (
          <div key={o.t} className="rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <h3 className="font-bold text-ink">{o.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{o.p}</p>
          </div>
        ))}
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        La check-list avant le départ
      </h2>
      <ul className="mt-6 space-y-3">
        {CHECKLIST.map((c, i) => (
          <li key={i} className="flex gap-3 rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
            <span className="text-owner">✓</span>
            <span className="text-sm leading-relaxed text-ink-muted">{c}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Le piège à éviter : partir sans nouvelles
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Le stress des vacances ne vient pas de la garde elle-même, mais de
        l'absence de nouvelles. Exigez un canal de communication clair. C'est
        exactement pour ça que HoPetSit intègre le chat avec votre pet sitter et
        le suivi GPS <strong>PawFollow</strong> : vous voyez la promenade de
        votre chien en direct sur la carte, depuis la plage.
      </p>

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Des pet sitters vérifiés, partout
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Comparez les profils près de chez vous, lisez les vrais avis et
          réservez en quelques minutes.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Télécharger l'app HoPetSit
        </Link>
      </div>
    </div>
  );
}
