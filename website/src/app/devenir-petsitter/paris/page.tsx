import type { Metadata } from "next";
import Link from "next/link";

// v533 — SEO recrutement : page « devenir pet sitter à Paris » (stratégie
// supply-first : remplir Paris de sitters avant de pousser les proprios).
export const metadata: Metadata = {
  title: "Devenir pet sitter à Paris — gagnez de l'argent en gardant des animaux",
  description:
    "Fixez vos tarifs, choisissez vos services (garde, visites, promenades) et soyez payé en toute sécurité. Devenez pet sitter ou promeneur de chiens à Paris avec HoPetSit — inscription gratuite.",
  alternates: { canonical: "https://www.hopetsit.com/devenir-petsitter/paris" },
};

const STEPS = [
  {
    n: "1",
    t: "Créez votre profil gratuit",
    p: "Photo, présentation, services proposés (garde à domicile, visites, promenades) et VOS tarifs — c'est vous qui décidez.",
  },
  {
    n: "2",
    t: "Faites vérifier votre identité",
    p: "5 minutes dans l'app. Le badge ✓ rassure les propriétaires : les profils vérifiés reçoivent beaucoup plus de demandes.",
  },
  {
    n: "3",
    t: "Recevez des demandes et discutez",
    p: "Les propriétaires de votre quartier vous contactent par chat. Vous acceptez uniquement ce qui vous convient.",
  },
  {
    n: "4",
    t: "Soyez payé en toute sécurité",
    p: "Le paiement est bloqué dans l'app dès la réservation et versé sur votre compte bancaire une fois le service terminé. Zéro impayé.",
  },
];

const FAQ = [
  {
    q: "Combien peut-on gagner comme pet sitter à Paris ?",
    a: "À Paris, les gardes se facturent généralement 20 à 30 € par jour et les promenades 12 à 20 €. Avec quelques clients réguliers, un complément de 200 à 500 € par mois est réaliste — vous fixez vos propres tarifs.",
  },
  {
    q: "Faut-il un diplôme ou un statut particulier ?",
    a: "Aucun diplôme n'est requis pour commencer sur HoPetSit — il faut aimer les animaux, être fiable et avoir 18 ans ou plus. Pour une activité régulière, renseignez-vous sur le statut adapté (micro-entrepreneur et, pour la garde de chiens/chats à titre habituel, l'ACACED).",
  },
  {
    q: "L'inscription coûte-t-elle quelque chose ?",
    a: "Non, l'inscription et le profil sont gratuits. Seule la vérification d'identité (badge ✓, fortement recommandée) coûte 3 €.",
  },
  {
    q: "Comment le suivi GPS protège-t-il aussi le sitter ?",
    a: "Pendant une promenade, le suivi PawFollow prouve que le service a bien été rendu, du départ au retour. Transparence pour le propriétaire, tranquillité pour vous.",
  },
];

export default function DevenirPetsitterParisPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "Devenir pet sitter à Paris",
        inLanguage: "fr",
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
      <p className="text-sm font-semibold text-sitter-dark">Paris & Île-de-France</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Devenez pet sitter à Paris — et soyez payé pour aimer les animaux
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Étudiant, en télétravail, retraité ou simplement passionné ? Des
        centaines de milliers de Parisiens ont un chien ou un chat… et personne
        pour le garder pendant les vacances ou les journées de travail. HoPetSit
        vous met en relation avec eux — vous fixez vos tarifs, vous choisissez
        vos services, vous êtes payé en sécurité.
      </p>

      <div className="mt-8 flex flex-wrap gap-3">
        {["💶 Vos tarifs, vos règles", "📅 Vous choisissez vos horaires", "✓ Badge vérifié", "🔒 Zéro impayé"].map((b) => (
          <span key={b} className="rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-ink shadow-card">
            {b}
          </span>
        ))}
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        Comment ça marche
      </h2>
      <ol className="mt-6 space-y-4">
        {STEPS.map((s) => (
          <li key={s.n} className="flex gap-5 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <div className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-sitter-light text-lg font-extrabold text-sitter-dark">
              {s.n}
            </div>
            <div>
              <h3 className="text-base font-bold text-ink">{s.t}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">{s.p}</p>
            </div>
          </li>
        ))}
      </ol>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        Questions fréquentes
      </h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-sitter-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Les premiers arrivés prennent les meilleurs quartiers
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          HoPetSit se lance à Paris : peu de concurrence entre sitters, des
          propriétaires qui arrivent chaque semaine. C'est le meilleur moment
          pour créer votre profil.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white"
        >
          Créer mon profil gratuit
        </Link>
      </div>
    </div>
  );
}
