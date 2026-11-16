import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import { TrackedLink } from "@/components/TrackedLink";
import { RECRUIT_CITIES, RECRUIT_PATH_PREFIX, OWNER_PATH_PREFIX } from "@/lib/recruit-cities";

// 16/11/2026 (Bob, semaine 47) — pendant côté propriétaire de
// /diventare-pet-sitter (même commit) : même trou, même cause, même
// correctif. Priorité n° 3 de Daniel (20/09) = Italie, aucune ville/langue
// nouvelle, seulement le hub manquant pour un réseau de 12 pages déjà en
// ligne (/custodia-animali/<città>).
export const metadata: Metadata = {
  title: "Pet sitter in Italia — custodia di cani, gatti e passeggiate | HoPetSit",
  description:
    "Pet sitter e dog walker vicino a te in tutta Italia. Pubblichi la richiesta, scegli e paghi solo quando prenoti. Pagamento sicuro, annullamento gratuito 72 h.",
  alternates: { canonical: "https://www.hopetsit.com/custodia-animali" },
};

const SERVICES = [
  { icon: "🏠", t: "Custodia a domicilio", p: "Il tuo animale resta a casa sua, con le sue abitudini. Il sitter dorme lì o passa più volte al giorno." },
  { icon: "🐾", t: "Visite per gatti", p: "Cibo, lettiera, coccole e una foto a ogni visita: perfetto per i gatti che odiano spostarsi." },
  { icon: "🚶", t: "Passeggiate per cani", p: "Un'uscita in settimana all'ora che preferisci, seguita in diretta sulla mappa da porta a porta." },
];

const WHY = [
  { icon: "✓", t: "Profili trasparenti", p: "Foto, tariffe e recensioni su ogni profilo. Il badge «Identità verificata» indica i sitter la cui identità è stata controllata." },
  { icon: "🔒", t: "Pagamento sicuro", p: "Il denaro resta bloccato nell'app e va al sitter solo a servizio concluso." },
  { icon: "📍", t: "Monitoraggio live", p: "PawFollow ti mostra la passeggiata in tempo reale. Sai sempre dov'è il tuo cane." },
  { icon: "🗺️", t: "PawMap", p: "I membri vicino a te, i luoghi pet-friendly, i loro orari e il percorso per arrivarci." },
];

const FAQ = [
  {
    q: "Come trovare un pet sitter affidabile in Italia?",
    a: "Pubblica la tua richiesta: i sitter vicino a te rispondono con il loro prezzo. Leggi le recensioni, chatta e prenota solo quando ti senti tranquillo.",
  },
  {
    q: "Il pagamento è davvero sicuro?",
    a: "Sì. L'importo è bloccato nell'app alla prenotazione e versato al sitter dopo il servizio. In caso di problemi, il nostro supporto interviene prima di qualsiasi pagamento.",
  },
  {
    q: "Posso seguire la passeggiata del mio cane?",
    a: "Sì, con PawFollow: il percorso appare in diretta sulla mappa, dall'inizio alla fine, con distanza e durata.",
  },
  {
    q: "Quanto costa iscriversi?",
    a: "Niente. Pubblicare una richiesta e chattare con i sitter è gratis. Paghi solo la custodia che prenoti.",
  },
  {
    q: "HoPetSit è disponibile nella mia città?",
    a: "HoPetSit è disponibile in tutta Italia. Le città qui sotto hanno una pagina dedicata, ma puoi pubblicare la tua richiesta ovunque tu sia.",
  },
];

const IT_CITIES = RECRUIT_CITIES.filter((c) => c.lang === "it");

export default function CustodiaAnimaliPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      { "@type": "WebPage", name: "Custodia animali", inLanguage: "it" },
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
          <li aria-current="page" className="text-ink">Custodia animali</li>
        </ol>
      </nav>
      <p className="mt-3 text-sm font-semibold text-owner-dark">Italia</p>
      <h1 className="mt-1.5 font-display text-[1.6rem] font-extrabold leading-[1.15] tracking-tight text-ink md:mt-2 md:text-4xl">
        Pet sitter in Italia: custodia di cani, gatti e passeggiate
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Weekend, vacanze, giornate di lavoro infinite: in tutta Italia,
        HoPetSit ti mette in contatto con pet sitter e dog walker vicino a te.
        Pubblichi la richiesta gratis, confronti i profili, chatti e paghi
        solo se prenoti.
      </p>

      <div className="mt-8 flex flex-wrap gap-3">
        {["🔒 Pagamento sicuro", "✓ Chat prima di prenotare", "🗓 Cancellazione gratis 72 h"].map((b) => (
          <span key={b} className="rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-ink shadow-card">
            {b}
          </span>
        ))}
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        I servizi vicino a te
      </h2>
      <ol className="mt-6 space-y-4">
        {SERVICES.map((s) => (
          <li key={s.t} className="flex gap-5 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <div className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-owner-light text-lg">
              {s.icon}
            </div>
            <div>
              <h3 className="text-base font-bold text-ink">{s.t}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">{s.p}</p>
            </div>
          </li>
        ))}
      </ol>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">Perché HoPetSit</h2>
      <ol className="mt-6 space-y-4">
        {WHY.map((s) => (
          <li key={s.t} className="flex gap-5 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <div className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-owner-light text-lg">
              {s.icon}
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
        Ogni città ha la sua pagina con i sitter disponibili vicino a te.
      </p>
      <ul className="mt-4 flex flex-wrap gap-2">
        {IT_CITIES.map((c) => (
          <li key={c.slug}>
            <TrackedLink
              href={`${OWNER_PATH_PREFIX.it}/${c.slug}`}
              label="maillage"
              className="inline-block rounded-full bg-bg-soft px-3.5 py-2 text-sm font-medium text-ink transition hover:bg-owner-light hover:text-owner-dark max-lg:py-3"
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

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Trova il tuo pet sitter vicino a te
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Pubblica la richiesta in un minuto e ricevi le risposte dei sitter
          vicino a te, con il loro prezzo.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Pubblicare la mia richiesta gratuita
        </Link>
      </div>

      <section className="mt-12 border-t border-sitter/15 pt-6">
        <p className="text-center text-sm md:text-left">
          <TrackedLink href={`${RECRUIT_PATH_PREFIX.it}/roma`} label="maillage" className="font-semibold text-sitter-dark underline-offset-4 hover:underline">
            Ami gli animali? Diventa pet sitter a Roma →
          </TrackedLink>
        </p>
        <p className="mt-3 text-center text-sm md:text-left">
          <TrackedLink href="/villes" label="maillage" className="font-semibold text-owner-dark underline-offset-4 hover:underline">
            Tutte le città →
          </TrackedLink>
        </p>
      </section>
    </div>
  );
}
