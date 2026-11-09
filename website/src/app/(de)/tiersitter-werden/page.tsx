import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import { TrackedLink } from "@/components/TrackedLink";
import { RECRUIT_CITIES, RECRUIT_PATH_PREFIX, type RecruitCity } from "@/lib/recruit-cities";

// 09/11/2026 (Bob, semaine 46) — même trou que /devenir-petsitter (FR, 26/10)
// et /become-a-pet-sitter (EN, 02/11) : /tiersitter-werden/<ville> est un
// réseau de 18 pages déjà en ligne (Allemagne, Autriche, Suisse — priorité
// n° 2 de Daniel, 20/09 : « les villes existent déjà, aucune page à créer,
// seulement à faire indexer »), mais /tiersitter-werden SANS ville 404ait :
// aucune des pages déjà indexées ne reliait vers ce réseau sauf sa propre
// page jumelle. Pas de nouvelle ville, pas de nouvelle langue — seulement le
// hub manquant pour un réseau existant (règle SEO du 20/09 : « relier
// l'existant plutôt qu'élargir »).
export const metadata: Metadata = {
  title: "Tiersitter werden — Geld verdienen mit Tierliebe | HoPetSit",
  description:
    "Lege deine eigenen Preise fest, wähle deine Leistungen (Betreuung, Kurzbesuche, Gassigehen) und werde sicher bezahlt. Werde Tiersitter oder Hundesitter mit HoPetSit — kostenlose Anmeldung, verfügbar in Deutschland, Österreich und der Schweiz.",
  alternates: { canonical: "https://www.hopetsit.com/tiersitter-werden" },
};

const STEPS = [
  {
    n: "1",
    t: "Erstelle dein kostenloses Profil",
    p: "Foto, Beschreibung, Leistungen (Betreuung zu Hause, Kurzbesuche, Gassigehen) und DEINE Preise — du entscheidest.",
  },
  {
    n: "2",
    t: "Lass deine Identität bestätigen",
    p: "5 Minuten in der App. Das ✓-Abzeichen schafft Vertrauen: verifizierte Profile erhalten deutlich mehr Anfragen.",
  },
  {
    n: "3",
    t: "Erhalte Anfragen und chatte",
    p: "Tierhalter in deiner Nähe kontaktieren dich per Chat. Du nimmst nur die Aufträge an, die zu dir passen.",
  },
  {
    n: "4",
    t: "Werde sicher bezahlt",
    p: "Die Zahlung wird bei der Buchung in der App hinterlegt und nach Abschluss der Leistung auf dein Konto überwiesen. Kein Zahlungsausfall.",
  },
];

const FAQ = [
  {
    q: "Wie viel kann man als Tiersitter verdienen?",
    a: "Das hängt von deiner Stadt und deinen eigenen Preisen ab — du behältst 100 % deines Preises, die Servicegebühr zahlt der Tierhalter.",
  },
  {
    q: "Braucht man eine Ausbildung oder einen bestimmten Status?",
    a: "Für den Start auf HoPetSit ist keine Ausbildung nötig — du musst Tiere lieben, zuverlässig sein und mindestens 18 Jahre alt sein. Für eine regelmäßige, bezahlte Tätigkeit gelten je nach Land unterschiedliche Regeln (Deutschland, Österreich, Schweiz) — informiere dich vor Ort.",
  },
  {
    q: "Kostet die Anmeldung etwas?",
    a: "Nein, Anmeldung und Profil sind kostenlos. Nur die Identitätsprüfung (✓-Abzeichen, sehr empfohlen) kostet eine kleine Gebühr.",
  },
  {
    q: "Wie schützt die GPS-Verfolgung auch den Sitter?",
    a: "Während eines Spaziergangs belegt die PawFollow-Verfolgung, dass die Leistung tatsächlich erbracht wurde — von der Abholung bis zur Rückgabe. Transparenz für den Halter, Absicherung für dich.",
  },
  {
    q: "Ist HoPetSit in meiner Stadt verfügbar?",
    a: "HoPetSit ist in Deutschland, Österreich und der Schweiz verfügbar. Die Städte unten haben eine eigene Seite, aber du kannst dein Profil erstellen, wo immer du bist.",
  },
];

const DE_CITIES = RECRUIT_CITIES.filter((c) => c.lang === "de" && c.slug !== "berlin");
const GERMANY = DE_CITIES.filter((c) => c.region.endsWith("Deutschland"));
const AUSTRIA = DE_CITIES.filter((c) => c.region.endsWith("Österreich"));
const SWITZERLAND = DE_CITIES.filter((c) => c.region.endsWith("Schweiz"));

function Chips({ cities }: { cities: RecruitCity[] }) {
  return (
    <ul className="mt-4 flex flex-wrap gap-2">
      {cities.map((c) => (
        <li key={c.slug}>
          <TrackedLink
            href={`${RECRUIT_PATH_PREFIX.de}/${c.slug}`}
            label="maillage"
            className="inline-block rounded-full bg-bg-soft px-3.5 py-2 text-sm font-medium text-ink transition hover:bg-sitter-light hover:text-sitter-dark max-lg:py-3"
          >
            {c.name}
          </TrackedLink>
        </li>
      ))}
    </ul>
  );
}

export default function TiersitterWerdenPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      { "@type": "WebPage", name: "Tiersitter werden", inLanguage: "de" },
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
      <nav aria-label="Brotkrumen" className="text-xs font-medium text-ink-soft">
        <ol className="flex flex-wrap items-center gap-x-1.5 gap-y-1">
          <li>
            <TrackedLink href="/" label="maillage" className="underline-offset-4 hover:text-owner-dark hover:underline">Start</TrackedLink>
          </li>
          <li aria-hidden="true">›</li>
          <li aria-current="page" className="text-ink">Tiersitter werden</li>
        </ol>
      </nav>
      <p className="mt-3 text-sm font-semibold text-sitter-dark">Deutschland · Österreich · Schweiz</p>
      <h1 className="mt-1.5 font-display text-[1.6rem] font-extrabold leading-[1.15] tracking-tight text-ink md:mt-2 md:text-4xl">
        Werde Tiersitter — und werde bezahlt, weil du Tiere liebst
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Student, im Homeoffice, Rentner oder einfach Tierliebhaber? Hunde- und
        Katzenhalter in deiner Nähe suchen jemanden, dem sie vertrauen können,
        während sie arbeiten oder reisen. HoPetSit bringt euch zusammen — du
        legst deine Preise fest, du wählst deine Leistungen, du wirst sicher
        bezahlt.
      </p>

      <div className="mt-8 flex flex-wrap gap-3">
        {["💶 Deine Preise, deine Regeln", "📅 Du wählst deine Zeiten", "✓ Verifiziertes Abzeichen", "🔒 Garantierte Zahlung"].map((b) => (
          <span key={b} className="rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-ink shadow-card">
            {b}
          </span>
        ))}
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        So funktioniert es
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

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">Wähle deine Stadt</h2>
      <p className="mt-2 text-sm leading-relaxed text-ink-muted">
        Jede Stadt hat ihre eigene Seite mit dem, was Halter dort vor Ort suchen.
      </p>
      <ul className="mt-4 flex flex-wrap gap-2">
        <li>
          <TrackedLink
            href={`${RECRUIT_PATH_PREFIX.de}/berlin`}
            label="maillage"
            className="inline-block rounded-full bg-sitter px-4 py-2.5 text-sm font-bold text-white transition hover:bg-sitter-dark max-lg:py-3"
          >
            Berlin
          </TrackedLink>
        </li>
      </ul>

      <h3 className="mt-8 text-sm font-bold text-ink-muted">Deutschland</h3>
      <Chips cities={GERMANY} />

      {AUSTRIA.length > 0 && (
        <>
          <h3 className="mt-8 text-sm font-bold text-ink-muted">Österreich</h3>
          <Chips cities={AUSTRIA} />
        </>
      )}

      {SWITZERLAND.length > 0 && (
        <>
          <h3 className="mt-8 text-sm font-bold text-ink-muted">Schweiz</h3>
          <Chips cities={SWITZERLAND} />
        </>
      )}

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        Häufig gestellte Fragen
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
          Die ersten Sitter bekommen die besten Viertel
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          HoPetSit wächst in den meisten dieser Städte noch: wenig Konkurrenz
          zwischen Sittern, und jede Woche kommen neue Halter dazu. Jetzt ist
          der beste Moment, dein Profil zu erstellen.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white"
        >
          Mein kostenloses Profil erstellen
        </Link>
      </div>

      <section className="mt-12 border-t border-owner/15 pt-6">
        <p className="text-center text-sm md:text-left">
          <TrackedLink href="/tierbetreuung/berlin" label="maillage" className="font-semibold text-owner-dark underline-offset-4 hover:underline">
            Suchst du einen Tiersitter? Finde einen in Berlin →
          </TrackedLink>
        </p>
        <p className="mt-3 text-center text-sm md:text-left">
          <TrackedLink href="/villes" label="maillage" className="font-semibold text-sitter-dark underline-offset-4 hover:underline">
            Alle Städte →
          </TrackedLink>
        </p>
      </section>
    </div>
  );
}
