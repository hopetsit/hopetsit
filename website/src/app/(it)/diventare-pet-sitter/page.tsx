import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import { TrackedLink } from "@/components/TrackedLink";
import { RECRUIT_CITIES, RECRUIT_PATH_PREFIX, OWNER_PATH_PREFIX } from "@/lib/recruit-cities";

// 16/11/2026 (Bob, semaine 47) — même trou que /devenir-petsitter (FR, 26/10),
// /become-a-pet-sitter (EN, 02/11) et /tiersitter-werden + /ser-cuidador-de-mascotas
// (DE/ES, 09/11) : priorité n° 3 de Daniel (20/09) = « Italie
// (/diventare-pet-sitter, /custodia-animali) et Royaume-Uni ». Les 12 villes
// italiennes sont déjà en ligne, mais /diventare-pet-sitter SANS ville
// 404ait : aucune des pages déjà indexées ne reliait vers ce réseau sauf sa
// propre page jumelle. Pas de nouvelle ville, pas de nouvelle langue —
// seulement le hub manquant pour un réseau existant.
export const metadata: Metadata = {
  title: "Diventare pet sitter — farsi pagare per amare gli animali | HoPetSit",
  description:
    "Fissi le tue tariffe, scegli i tuoi servizi (custodia a domicilio, visite, passeggiate) e vieni pagato in sicurezza. Diventa pet sitter o dog sitter con HoPetSit — iscrizione gratuita, disponibile in Italia.",
  alternates: { canonical: "https://www.hopetsit.com/diventare-pet-sitter" },
};

const STEPS = [
  {
    n: "1",
    t: "Crea il tuo profilo gratuito",
    p: "Foto, presentazione, servizi (custodia a domicilio, visite, passeggiate) e LE TUE tariffe: decidi tu.",
  },
  {
    n: "2",
    t: "Verifica la tua identità",
    p: "5 minuti nell'app. Il badge ✓ rassicura i proprietari: i profili verificati ricevono molte più richieste.",
  },
  {
    n: "3",
    t: "Ricevi richieste e chatta",
    p: "I proprietari del tuo quartiere ti contattano in chat. Accetti solo ciò che ti va.",
  },
  {
    n: "4",
    t: "Vieni pagato in sicurezza",
    p: "Il pagamento è bloccato nell'app dalla prenotazione e versato sul tuo conto a servizio concluso.",
  },
];

const FAQ = [
  {
    q: "Quanto si guadagna come pet sitter in Italia?",
    a: "Decidi tu le tariffe e tieni il 100% del tuo prezzo: la commissione di servizio la paga il proprietario. Il guadagno dipende dalla città e dalle prenotazioni che accetti.",
  },
  {
    q: "Serve un diploma o una posizione particolare?",
    a: "Nessun diploma è richiesto per iniziare su HoPetSit: basta amare gli animali, essere affidabili e avere almeno 18 anni. Per un'attività regolare e pagata, informati sull'apertura di una partita IVA prima di accettare molte prenotazioni.",
  },
  {
    q: "L'iscrizione costa qualcosa?",
    a: "No, iscrizione e profilo sono gratuiti. Solo la verifica dell'identità (badge ✓, fortemente consigliata) costa una piccola somma.",
  },
  {
    q: "In che modo il monitoraggio GPS protegge anche il sitter?",
    a: "Durante una passeggiata, il monitoraggio PawFollow prova che il servizio è stato reso, dalla partenza al rientro. Trasparenza per il proprietario, protezione per te.",
  },
  {
    q: "HoPetSit è disponibile nella mia città?",
    a: "HoPetSit è disponibile in tutta Italia. Le città qui sotto hanno una pagina dedicata, ma puoi creare il tuo profilo ovunque tu sia.",
  },
];

const IT_CITIES = RECRUIT_CITIES.filter((c) => c.lang === "it");

export default function DiventarePetSitterPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      { "@type": "WebPage", name: "Diventare pet sitter", inLanguage: "it" },
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
      <nav aria-label="Percorso" className="text-xs font-medium text-ink-soft">
        <ol className="flex flex-wrap items-center gap-x-1.5 gap-y-1">
          <li>
            <TrackedLink href="/" label="maillage" className="underline-offset-4 hover:text-owner-dark hover:underline">Home</TrackedLink>
          </li>
          <li aria-hidden="true">›</li>
          <li aria-current="page" className="text-ink">Diventare pet sitter</li>
        </ol>
      </nav>
      <p className="mt-3 text-sm font-semibold text-sitter-dark">Italia</p>
      <h1 className="mt-1.5 font-display text-[1.6rem] font-extrabold leading-[1.15] tracking-tight text-ink md:mt-2 md:text-4xl">
        Diventa pet sitter — fatti pagare per il tuo amore per gli animali
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Studente, in smart working, in pensione o semplicemente appassionato?
        In tutta Italia, proprietari di cani e gatti cercano una persona di
        fiducia a cui affidarli durante il lavoro o le vacanze. HoPetSit vi
        mette in contatto: fissi le tue tariffe, scegli i tuoi servizi e vieni
        pagato in sicurezza.
      </p>

      <div className="mt-8 flex flex-wrap gap-3">
        {["💶 Le tue tariffe, le tue regole", "📅 Scegli tu gli orari", "✓ Badge verificato", "🔒 Zero insoluti"].map((b) => (
          <span key={b} className="rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-ink shadow-card">
            {b}
          </span>
        ))}
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        Come funziona
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

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">Scegli la tua città</h2>
      <p className="mt-2 text-sm leading-relaxed text-ink-muted">
        Ogni città ha la sua pagina con quello che i proprietari del posto
        cercano davvero.
      </p>
      <ul className="mt-4 flex flex-wrap gap-2">
        {IT_CITIES.map((c) => (
          <li key={c.slug}>
            <TrackedLink
              href={`${RECRUIT_PATH_PREFIX.it}/${c.slug}`}
              label="maillage"
              className="inline-block rounded-full bg-bg-soft px-3.5 py-2 text-sm font-medium text-ink transition hover:bg-sitter-light hover:text-sitter-dark max-lg:py-3"
            >
              {c.name}
            </TrackedLink>
          </li>
        ))}
      </ul>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        Domande frequenti
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
          I primi sitter si prendono i quartieri migliori
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          HoPetSit arriva ora in molte di queste città: poca concorrenza tra
          sitter, nuovi proprietari ogni settimana. È il momento migliore per
          creare il tuo profilo.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white"
        >
          Crea il mio profilo gratuito
        </Link>
      </div>

      <section className="mt-12 border-t border-owner/15 pt-6">
        <p className="text-center text-sm md:text-left">
          <TrackedLink href={`${OWNER_PATH_PREFIX.it}/roma`} label="maillage" className="font-semibold text-owner-dark underline-offset-4 hover:underline">
            Cerchi un pet sitter? Trovane uno a Roma →
          </TrackedLink>
        </p>
        <p className="mt-3 text-center text-sm md:text-left">
          <TrackedLink href="/villes" label="maillage" className="font-semibold text-sitter-dark underline-offset-4 hover:underline">
            Tutte le città →
          </TrackedLink>
        </p>
      </section>
    </div>
  );
}
