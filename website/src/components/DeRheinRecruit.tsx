import Link from "next/link";
import { TrackedLink } from "@/components/TrackedLink";
import { ExpiringNotice } from "@/components/ExpiringNotice";
import type { RecruitCity } from "@/lib/recruit-cities";

// 06/10/2026 (GUS, mission de BOB, accord de Daniel) : recruter des
// Tiersitter autour de Düsseldorf, gratuitement. Une vraie Halterin aus
// Düsseldorf a publié une demande de garde pour les fêtes (19/12/2026 →
// 07/01/2027), un seul prestataire à moins de 100 km. Règle SEO du 20/09 :
// AUCUNE page ville nouvelle, on enrichit les 3 pages existantes
// /tiersitter-werden/duesseldorf, /koeln, /essen et on les relie à l'article
// /blog/haustiersitter-jobs-duesseldorf. Aucun nom, aucune adresse, aucun
// chiffre d'activité inventé. Une seule demande : tout est au singulier.
// Commission = backend/src/utils/pricing.js (vérifié par FLO le 06/10) :
// le Tiersitter garde 100 % de son tarif, le Halter paie tarif + 20 %
// (15 % badge Top), argent libéré dans le portefeuille à la confirmation du
// Halter ou 48 h après la fin prévue, puis virement sur l'IBAN.
// Tarifs affichés = uniquement ceux de recruit-cities.ts.

export const RHEIN_SLUGS = ["duesseldorf", "koeln", "essen"] as const;

/** Fin de la demande (dernier jour de la garde). Après : bandeau et FAQ retirés. */
export const RHEIN_DEMAND_END = "2027-01-07T23:59:59+01:00";

export function isRheinCity(c: RecruitCity): boolean {
  return c.lang === "de" && (RHEIN_SLUGS as readonly string[]).includes(c.slug);
}

/** Vrai au moment du build tant que la demande court (le bandeau client se masque seul ensuite). */
export function rheinDemandOpen(now = Date.now()): boolean {
  return now <= Date.parse(RHEIN_DEMAND_END);
}

export const RHEIN_ARTICLE = {
  href: "/blog/haustiersitter-jobs-duesseldorf",
  title: "Haustiersitter Jobs in Düsseldorf: so verdienst du Geld mit Tierbetreuung",
};

export function rheinH1(c: RecruitCity): string {
  return `Tiersitter werden in ${c.name}: kostenlos anmelden, Tiere betreuen, sicher bezahlt werden`;
}

export function rheinMeta(c: RecruitCity): { title: string; description: string } {
  return {
    title: `Tiersitter Jobs in ${c.name}: kostenlos anmelden`,
    description: `Tiersitter oder Gassigeher in ${c.name}: kostenlos anmelden, Preise selbst festlegen (meist ${c.dayRate} pro Tag), 100 % deines Preises behalten, sicher in der App bezahlt.`,
  };
}

function signupHref(role: "sitter" | "walker", c: RecruitCity): string {
  return `/signup?role=${role}&city=${encodeURIComponent(c.name)}&lang=de`;
}

/** Bandeau « vraie demande » du premier écran : aucune donnée personnelle, singulier. */
export function RheinDemandNotice() {
  if (!rheinDemandOpen()) return null;
  return (
    <ExpiringNotice until={RHEIN_DEMAND_END}>
      <p className="mt-4 rounded-2xl border border-sitter/25 bg-sitter-light/70 px-4 py-3 text-sm leading-snug text-ink">
        <strong className="font-bold">Weihnachten und Neujahr 2026/27:</strong> Eine Tierhalterin aus
        Düsseldorf sucht auf HoPetSit einen Tiersitter für die Feiertage, und in der Region gibt es noch
        wenige Tiersitter, die antworten können.
      </p>
    </ExpiringNotice>
  );
}

/** Les 2 boutons d'inscription (Tiersitter / Gassigeher), rôle + ville pré-remplis, en allemand. */
export function RheinSignupButtons({ city, place }: { city: RecruitCity; place: "top" | "bottom" }) {
  return (
    <div className={place === "top" ? "mt-5 grid gap-2.5 md:grid-cols-2" : "mt-5 grid gap-2.5 md:mx-auto md:max-w-lg md:grid-cols-2"}>
      <TrackedLink
        href={signupHref("sitter", city)}
        label={`recruit_${city.slug}_sitter_${place}`}
        className="block w-full rounded-full bg-sitter px-6 py-3.5 text-center text-base font-bold text-white transition hover:bg-sitter-dark"
      >
        Als Tiersitter anmelden
      </TrackedLink>
      <TrackedLink
        href={signupHref("walker", city)}
        label={`recruit_${city.slug}_walker_${place}`}
        className="block w-full rounded-full border-2 border-sitter bg-white px-6 py-3 text-center text-base font-bold text-sitter-dark transition hover:bg-sitter-light"
      >
        Als Gassigeher anmelden
      </TrackedLink>
    </div>
  );
}

const NEIGHBORS: Record<string, { slug: string; name: string }[]> = {
  duesseldorf: [{ slug: "koeln", name: "Köln" }, { slug: "essen", name: "Essen" }],
  koeln: [{ slug: "duesseldorf", name: "Düsseldorf" }, { slug: "essen", name: "Essen" }],
  essen: [{ slug: "duesseldorf", name: "Düsseldorf" }, { slug: "koeln", name: "Köln" }],
};

/** Bloc détaillé : tarifs, paiement exact, liens vers l'article et les 2 villes voisines. */
export default function RheinRecruitDetails({ city }: { city: RecruitCity }) {
  const rows = [
    { s: "Betreuung / Besuche", r: city.dayRate, n: "pro Tag" },
    { s: "Gassi gehen", r: city.walkRate, n: "pro Spaziergang" },
    { s: "Übernachtung beim Halter", r: "Dein Preis", n: "du legst Tages- und Wochenpreise selbst fest" },
  ];
  return (
    <section className="mt-12" aria-labelledby="rhein-preise">
      <h2 id="rhein-preise" className="font-display text-2xl font-extrabold text-ink">
        Preise in {city.name}
      </h2>
      <p className="mt-3 text-sm leading-relaxed text-ink-muted">
        Deine Preise legst du selbst in deinem Profil fest. Das sind die üblichen Spannen, die wir Haltern
        in {city.name} zeigen:
      </p>
      <div className="mt-4 overflow-hidden rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <tbody className="text-ink-muted">
            {rows.map((row, i) => (
              <tr key={row.s} className={i < rows.length - 1 ? "border-b border-ink/5" : ""}>
                <td className="p-3 font-semibold text-ink md:p-4">{row.s}</td>
                <td className="whitespace-nowrap p-3 font-bold text-sitter-dark md:p-4">{row.r}</td>
                <td className="p-3 md:p-4">{row.n}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-3 text-sm leading-relaxed text-ink-muted">
        So wirst du bezahlt: Du behältst 100 % deines Preises. Der Halter zahlt bei der Buchung in der App
        deinen Preis plus 20 % HoPetSit-Gebühr (15 %, sobald du das Top-Abzeichen hast). Beispiel: Bei einem
        Preis von 12 € zahlt der Halter 14,40 € und du bekommst 12 €. Das Geld wird in deinem Wallet in der
        App freigegeben, sobald der Halter den Service bestätigt, oder 48 Stunden nach dem geplanten Ende.
        Danach überweist du es auf dein Bankkonto (IBAN), wie in unseren{" "}
        <Link href="/terms" className="font-semibold text-sitter-dark underline">Nutzungsbedingungen</Link>{" "}
        beschrieben. Die Anmeldung ist kostenlos.
      </p>

      <div className="mt-10 rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
        <h2 className="text-base font-bold text-ink">Tierbetreuung im Rheinland und Ruhrgebiet</h2>
        <ul className="mt-3 space-y-2 text-sm">
          <li>
            <Link href={RHEIN_ARTICLE.href} className="font-semibold text-sitter-dark underline">
              {RHEIN_ARTICLE.title}
            </Link>
          </li>
          {(NEIGHBORS[city.slug] || []).map((n) => (
            <li key={n.slug}>
              <Link href={`/tiersitter-werden/${n.slug}`} className="font-semibold text-sitter-dark underline">
                Tiersitter werden in {n.name}
              </Link>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

/** FAQ propre aux 3 villes (affichée + JSON-LD FAQPage). */
export function rheinFaq(city: RecruitCity): { q: string; a: string }[] {
  const faq = [
    {
      q: `Wie viel verlangen Tiersitter in ${city.name}?`,
      a: `In ${city.name} kostet eine Betreuung meist ${city.dayRate} pro Tag und ein Spaziergang ${city.walkRate}. Du legst deine Preise selbst fest, auch für Übernachtungen. Was du verdienst, hängt nur von den Buchungen ab, die du annimmst.`,
    },
    {
      q: "Was behält HoPetSit von meinem Preis?",
      a: "Nichts: Du behältst 100 % deines Preises, und die Anmeldung ist kostenlos. Der Halter zahlt deinen Preis plus 20 % HoPetSit-Gebühr (15 % mit dem Top-Abzeichen): Bei 12 € zahlt der Halter 14,40 € und du bekommst 12 €. Das Geld wird in deinem Wallet freigegeben, sobald der Halter den Service bestätigt, oder 48 Stunden nach dem geplanten Ende, und du überweist es dann auf dein Bankkonto (IBAN).",
    },
  ];
  if (rheinDemandOpen()) {
    faq.push({
      q: "Sucht gerade jemand in der Region einen Tiersitter?",
      a: "Ja. Eine Tierhalterin aus Düsseldorf sucht auf HoPetSit einen Tiersitter für Weihnachten und Neujahr 2026/27, und in der Region gibt es noch wenige Tiersitter. Wer sich jetzt anmeldet, gehört zu den ersten, die Halter in der Nähe sehen.",
    });
  }
  return faq;
}
