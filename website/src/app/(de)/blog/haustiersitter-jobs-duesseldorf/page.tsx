import type { Metadata } from "next";
import Link from "next/link";
import { RHEIN_DEMAND_END, rheinDemandOpen } from "@/components/DeRheinRecruit";
import { ExpiringNotice } from "@/components/ExpiringNotice";

// 06/10/2026 (GUS, mission de BOB, accord de Daniel : recruter des Tiersitter
// autour de Düsseldorf, gratuitement). Requête visée : « Haustiersitter Jobs
// Düsseldorf » / « Tiersitter Düsseldorf verdienen ». Relié aux 3 pages
// existantes /tiersitter-werden/duesseldorf, /koeln, /essen (et elles à lui).
// Tarifs = uniquement ceux de recruit-cities.ts. Règle d'argent = backend
// pricing.js (vérifiée par FLO le 06/10) : 100 % du tarif pour le Tiersitter,
// le Halter paie tarif + 20 % (15 % badge Top), wallet libéré à la confirmation
// ou 48 h après la fin, puis IBAN. Exemple chiffré = calcul, pas une promesse.
// La demande réelle (une seule, fêtes 2026/27) disparaît après le 07/01/2027.

const URL = "https://www.hopetsit.com/blog/haustiersitter-jobs-duesseldorf";
const TITLE = "Haustiersitter Jobs in Düsseldorf: Geld mit Tierbetreuung";
const HEADLINE = "Haustiersitter Jobs in Düsseldorf: so verdienst du Geld mit Tierbetreuung";
const DESCRIPTION =
  "Tiersitter oder Gassigeher in Düsseldorf, Köln und Essen: übliche Preise, was du wirklich behältst (100 % deines Preises), Regeln in NRW und wie du deine ersten Stammkunden findest.";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  alternates: { canonical: URL },
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    url: URL,
    type: "article",
    locale: "de_DE",
    siteName: "HoPetSit",
    images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }],
  },
};

const RATES = [
  { s: "Betreuung oder Besuche in Düsseldorf", r: "20 bis 30 € pro Tag" },
  { s: "Gassi gehen in Düsseldorf", r: "12 bis 18 € pro Spaziergang" },
  { s: "Betreuung in Köln", r: "18 bis 28 € pro Tag" },
  { s: "Gassi gehen in Köln", r: "12 bis 17 € pro Spaziergang" },
  { s: "Betreuung in Essen", r: "20 bis 30 € pro Tag" },
  { s: "Gassi gehen in Essen", r: "12 bis 18 € pro Spaziergang" },
];

function faq(): { q: string; a: string }[] {
  const list = [
    {
      q: "Wie viel verdient ein Haustiersitter in Düsseldorf?",
      a: "Auf HoPetSit verlangen Tiersitter in Düsseldorf meist 20 bis 30 € pro Tag Betreuung und 12 bis 18 € pro Spaziergang. Du legst deine Preise selbst fest. Was du am Ende verdienst, hängt nur von den Buchungen ab, die du annimmst.",
    },
    {
      q: "Was behält HoPetSit von meinem Preis?",
      a: "Nichts: Du behältst 100 % deines Preises, die Anmeldung ist kostenlos. Der Halter zahlt deinen Preis plus 20 % HoPetSit-Gebühr (15 % mit dem Top-Abzeichen). Das Geld wird in deinem Wallet freigegeben, sobald der Halter den Service bestätigt, oder 48 Stunden nach dem geplanten Ende, und du überweist es auf dein Bankkonto (IBAN).",
    },
    {
      q: "Muss ich ein Gewerbe anmelden?",
      a: "Für ein paar Betreuungen nebenbei meist nicht sofort, aber Einnahmen sind grundsätzlich steuerpflichtig. Wer regelmäßig Tiere betreut, sollte sich beim Gewerbeamt seiner Stadt und beim Finanzamt informieren, und beim Veterinäramt fragen, ob eine Erlaubnis nach § 11 Tierschutzgesetz nötig ist.",
    },
  ];
  if (rheinDemandOpen()) {
    list.push({
      q: "Gibt es gerade eine Anfrage in Düsseldorf?",
      a: "Ja. Eine Tierhalterin aus Düsseldorf sucht auf HoPetSit einen Tiersitter für Weihnachten und Neujahr 2026/27, und in der Region gibt es noch wenige Tiersitter, die antworten können.",
    });
  }
  return list;
}

const LINK = "font-semibold text-sitter-dark underline";

export default function ArticleHaustiersitterJobsDuesseldorf() {
  const FAQ = faq();
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "de-DE",
        datePublished: "2026-10-06",
        dateModified: "2026-10-06",
        mainEntityOfPage: URL,
        image: { "@type": "ImageObject", url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630 },
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com", logo: { "@type": "ImageObject", url: "https://www.hopetsit.com/logo.png" } },
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
      <p className="text-sm font-semibold text-sitter-dark">Düsseldorf · Köln · Essen · Oktober 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">{HEADLINE}</h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Lange Arbeitstage, Pendeln nach Köln oder ins Ruhrgebiet, Urlaub über die Feiertage: Viele Hunde- und
        Katzenhalter in Düsseldorf brauchen jemanden, dem sie ihr Tier anvertrauen können. Wenn du Tiere magst
        und zuverlässig bist, kannst du daraus einen Nebenverdienst machen. Hier erfährst du, was Tierbetreuung
        in Düsseldorf und Umgebung kostet, was du davon behältst und wie du deine ersten Stammkunden findest.
      </p>

      {rheinDemandOpen() && (
        <ExpiringNotice until={RHEIN_DEMAND_END}>
          <p className="mt-6 rounded-2xl border border-sitter/25 bg-sitter-light/70 px-4 py-3 text-sm leading-snug text-ink">
            <strong className="font-bold">Weihnachten und Neujahr 2026/27:</strong> Eine Tierhalterin aus
            Düsseldorf sucht auf HoPetSit einen Tiersitter für die Feiertage, und in der Region gibt es noch
            wenige Tiersitter, die antworten können.
          </p>
        </ExpiringNotice>
      )}

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Welche Jobs gibt es in der Tierbetreuung?</h2>
      <ul className="mt-4 space-y-3 text-ink-muted">
        <li className="leading-relaxed"><strong className="text-ink">Gassi gehen.</strong> Ein Spaziergang von 30 bis 60 Minuten, oft mittags, während der Halter arbeitet. Das ist der einfachste Einstieg und eignet sich gut neben Studium, Homeoffice oder Rente.</li>
        <li className="leading-relaxed"><strong className="text-ink">Besuche zu Hause.</strong> Füttern, Katzenklo, Streicheleinheiten: Katzen bleiben am liebsten in ihrer Wohnung, deshalb sind Besuche während des Urlaubs sehr gefragt.</li>
        <li className="leading-relaxed"><strong className="text-ink">Betreuung über mehrere Tage.</strong> Du kümmerst dich tagsüber um das Tier oder übernachtest beim Halter. Das ist mehr Verantwortung, aber auch der Service, den Halter vor Reisen am dringendsten suchen.</li>
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Die üblichen Preise in Düsseldorf, Köln und Essen</h2>
      <div className="mt-5 overflow-hidden rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-3 font-bold md:p-4">Leistung</th>
              <th className="p-3 font-bold md:p-4">Üblicher Preis</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            {RATES.map((r, i) => (
              <tr key={r.s} className={i < RATES.length - 1 ? "border-b border-ink/5" : ""}>
                <td className="p-3 font-semibold text-ink md:p-4">{r.s}</td>
                <td className="p-3 md:p-4">{r.r}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Das sind die Spannen, die wir Haltern auf unseren Seiten für{" "}
        <Link href="/tiersitter-werden/duesseldorf" className={LINK}>Düsseldorf</Link>,{" "}
        <Link href="/tiersitter-werden/koeln" className={LINK}>Köln</Link> und{" "}
        <Link href="/tiersitter-werden/essen" className={LINK}>Essen</Link> zeigen. Auf HoPetSit schreibst du
        deine Preise selbst in dein Profil, niemand legt sie für dich fest. Mehr Zeit, mehrere Tiere, ein
        Welpe, ein älterer Hund mit Medikamenten oder Termine an Feiertagen rechtfertigen einen höheren Preis.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Was du wirklich behältst: ein Rechenbeispiel</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Das ist eine einfache Rechnung, kein Versprechen: Was du verdienst, hängt nur von den Buchungen ab, die
        du annimmst. Nehmen wir an, du verlangst 25 € pro Tag und betreust einen Hund an 5 Tagen. Das sind
        125 € für dich. Der Halter zahlt 150 €, also deine 125 € plus 20 % HoPetSit-Gebühr, und du bekommst
        die vollen 125 €. Mit dem Top-Abzeichen sinkt die Gebühr für den Halter auf 15 %, dein Anteil bleibt
        gleich: 100 % deines Preises.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Bezahlt wird bei der Buchung in der App, du musst keinem Bargeld hinterherlaufen. Das Geld wird in
        deinem Wallet freigegeben, sobald der Halter den Service bestätigt, oder 48 Stunden nach dem geplanten
        Ende. Danach überweist du es auf dein Bankkonto (IBAN). Die Regeln stehen in unseren{" "}
        <Link href="/terms" className={LINK}>Nutzungsbedingungen</Link>. Die Anmeldung kostet nichts; nur die
        freiwillige Identitätsprüfung für das ✓-Abzeichen kostet einmalig 3 €.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Regeln, die du in NRW kennen solltest</h2>
      <ul className="mt-4 space-y-3 text-ink-muted">
        <li className="leading-relaxed"><strong className="text-ink">Landeshundegesetz NRW.</strong> Für große Hunde und bestimmte Rassen gelten in Nordrhein-Westfalen besondere Pflichten, zum Beispiel beim Anleinen. Frag den Halter vor dem ersten Spaziergang, was für seinen Hund gilt.</li>
        <li className="leading-relaxed"><strong className="text-ink">Steuern.</strong> Einnahmen aus Tierbetreuung sind grundsätzlich steuerpflichtig. Notiere, was du einnimmst, und informiere dich beim Finanzamt.</li>
        <li className="leading-relaxed"><strong className="text-ink">Gewerbe und Erlaubnis.</strong> Wer regelmäßig und gewerblich Tiere betreut, sollte sich beim Gewerbeamt und beim Veterinäramt erkundigen, ob eine Anmeldung oder eine Erlaubnis nach § 11 Tierschutzgesetz nötig ist.</li>
        <li className="leading-relaxed"><strong className="text-ink">Versicherung.</strong> Kläre mit dem Halter, ob seine Hundehaftpflicht auch Schäden abdeckt, wenn jemand anderes den Hund ausführt. Wer oft betreut, kann über eine eigene Tierhüter-Haftpflicht nachdenken.</li>
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">So findest du deine ersten Stammkunden</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Erfolgreiche Tiersitter sind selten die billigsten, sondern die, die wieder gebucht werden. Ein Halter,
        der jeden Werktag einen Spaziergang braucht oder jedes Jahr über Weihnachten verreist, ist mehr wert als
        zehn einmalige Anfragen. Drei Gewohnheiten helfen dabei:
      </p>
      <ul className="mt-4 space-y-3 text-ink-muted">
        <li className="leading-relaxed"><strong className="text-ink">Bleib in deinem Viertel.</strong> Ob Oberkassel, Flingern oder Bilk: Halter wählen lieber jemanden aus der Nähe, der auch kurzfristig einspringen kann.</li>
        <li className="leading-relaxed"><strong className="text-ink">Schick kurze Updates.</strong> Ein Foto und zwei Sätze nach jedem Besuch bleiben in Erinnerung. Auf HoPetSit sieht der Halter den Spaziergang außerdem live auf der Karte.</li>
        <li className="leading-relaxed"><strong className="text-ink">Sammle früh Bewertungen.</strong> Kurze Spaziergänge und Katzenbesuche sind ein guter Weg zu den ersten Bewertungen, bevor du längere Betreuungen übernimmst.</li>
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Plane die Feiertage früh ein: Rund um Weihnachten, Neujahr und die Schulferien verreisen viele Halter
        gleichzeitig, und dann ist ein freier Tiersitter am schwersten zu finden. Wenn du in Köln oder Essen
        wohnst, lohnt sich ein Profil genauso: HoPetSit ist im Rheinland und im Ruhrgebiet noch neu, die
        Konkurrenz unter Tiersittern ist klein, und wer sich jetzt anmeldet, gehört zu den ersten, die Halter in
        der Nähe sehen.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Häufige Fragen</h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-sitter-light p-6 text-center md:p-8">
        <h2 className="font-display text-2xl font-extrabold text-ink">Tiersitter in Düsseldorf werden</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Kostenlos anmelden. Deine Preise, deine Zeiten, Halter in deinem eigenen Viertel.
        </p>
        <Link href="/signup?role=sitter&city=D%C3%BCsseldorf&lang=de" className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white">
          Als Tiersitter anmelden
        </Link>
        <p className="mt-3 text-xs text-ink-soft">
          <Link href="/tiersitter-werden/duesseldorf" className="underline">Alles über Tierbetreuung in Düsseldorf</Link>
        </p>
      </div>
    </div>
  );
}
