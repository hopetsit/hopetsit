import Link from "next/link";
import { TrackedLink } from "@/components/TrackedLink";

// 05/10/2026 (GUS, ordre de Daniel : « plus de prestataires à New York », gratuit).
// Règle SEO du 20/09 respectée : AUCUNE page nouvelle côté villes, on enrichit
// /become-a-pet-sitter/new-york (seule page de recrutement NY) et on la relie
// aux 2 articles du blog. Composant serveur, aucun hook. Aucun nom, aucune
// adresse, aucun chiffre d'activité inventé : la demande ouverte à Queens est
// celle relevée par BOB le 05/10 (rapport BOB), formulée sans donnée perso.

const SIGNUP_SITTER = "/signup?role=sitter&city=New%20York";
const SIGNUP_WALKER = "/signup?role=walker&city=New%20York";

export const NYC_H1 = "Earn as a pet sitter or dog walker in New York — free to join";

export const NYC_META = {
  title: "Dog Walker & Pet Sitter Jobs in New York City",
  description:
    "Free to join: walk dogs or pet sit in Manhattan, Brooklyn, Queens, the Bronx or Staten Island. You set your rates and hours, payment is secured in the app.",
};

/** Bandeau « vraie demande » du premier écran. Daté, à retirer s'il n'est plus vrai. */
export function NycDemandNotice() {
  return (
    <p className="mt-4 rounded-2xl border border-sitter/25 bg-sitter-light/70 px-4 py-3 text-sm leading-snug text-ink">
      <strong className="font-bold">October 2026:</strong> a New York owner in Queens has an
      open pet sitting request on HoPetSit right now, and very few sitters live nearby to answer
      it.
    </p>
  );
}

/** Les 2 boutons d'inscription (gardien / promeneur), ville déjà remplie. */
export function NycSignupButtons({ place }: { place: "top" | "bottom" }) {
  return (
    <div className={place === "top" ? "mt-5 grid gap-2.5 md:grid-cols-2" : "mt-5 grid gap-2.5 md:mx-auto md:max-w-lg md:grid-cols-2"}>
      <TrackedLink
        href={SIGNUP_SITTER}
        label={`recruit_nyc_sitter_${place}`}
        className="block w-full rounded-full bg-sitter px-6 py-3.5 text-center text-base font-bold text-white transition hover:bg-sitter-dark"
      >
        Join as a pet sitter
      </TrackedLink>
      <TrackedLink
        href={SIGNUP_WALKER}
        label={`recruit_nyc_walker_${place}`}
        className="block w-full rounded-full border-2 border-sitter bg-white px-6 py-3 text-center text-base font-bold text-sitter-dark transition hover:bg-sitter-light"
      >
        Join as a dog walker
      </TrackedLink>
    </div>
  );
}

const BOROUGHS: { name: string; note: string }[] = [
  { name: "Manhattan", note: "Apartment buildings and long office days: midday walks on weekdays are the core of the work. Central Park, Riverside Park and Hudson River Park are the classic routes." },
  { name: "Brooklyn", note: "Park Slope, Williamsburg, Greenpoint and Bay Ridge: families with dogs, and Prospect Park's Long Meadow for early-morning off-leash hours." },
  { name: "Queens", note: "Astoria, Long Island City, Forest Hills and Flushing: more houses with small yards, owners who travel and need home sitting or drop-in visits. A request is open here now." },
  { name: "The Bronx", note: "Riverdale, Pelham Bay and the neighborhoods around Van Cortlandt Park: big parks, longer walks, and few sitters offering their services." },
  { name: "Staten Island", note: "Quieter streets, more cars and yards: overnight stays and visits while owners travel, best for sitters who live on the island." },
];

const PAY_ROWS: { s: string; r: string; n: string }[] = [
  { s: "Dog walk", r: "$20 – $35", n: "per walk, usually 30 minutes" },
  { s: "Day sitting / visits", r: "$40 – $70", n: "per day" },
  { s: "Overnight stay", r: "Your price", n: "you set your own day and week rates" },
];

/** Bloc détaillé : quartiers, tarifs, paiement, guides. Rendu après le guide local. */
export default function NycRecruitDetails() {
  return (
    <section className="mt-12" aria-labelledby="nyc-boroughs">
      <h2 id="nyc-boroughs" className="font-display text-2xl font-extrabold text-ink">
        Which borough? All five
      </h2>
      <p className="mt-3 text-sm leading-relaxed text-ink-muted">
        Owners see sitters and walkers close to their home. Set your service area around the blocks
        you can reach on foot, by bike or by subway — remember that dogs ride the subway only in a
        carrier, so most walks start at the owner&apos;s door.
      </p>
      <ul className="mt-5 space-y-3">
        {BOROUGHS.map((b) => (
          <li key={b.name} className="rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
            <span className="block text-sm font-bold text-ink">{b.name}</span>
            <span className="mt-1 block text-sm leading-relaxed text-ink-muted">{b.note}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Rates in New York</h2>
      <p className="mt-3 text-sm leading-relaxed text-ink-muted">
        You choose your own prices in your profile. These are the usual ranges we show New York owners:
      </p>
      <div className="mt-4 overflow-hidden rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <tbody className="text-ink-muted">
            {PAY_ROWS.map((row, i) => (
              <tr key={row.s} className={i < PAY_ROWS.length - 1 ? "border-b border-ink/5" : ""}>
                <td className="p-3 font-semibold text-ink md:p-4">{row.s}</td>
                <td className="whitespace-nowrap p-3 font-bold text-sitter-dark md:p-4">{row.r}</td>
                <td className="p-3 md:p-4">{row.n}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-3 text-sm leading-relaxed text-ink-muted">
        How you get paid: the owner pays in the app when booking. HoPetSit keeps a 20% platform
        commission and pays out the other 80% 24 hours after the service ends, as written in our{" "}
        <Link href="/terms" className="font-semibold text-sitter-dark underline">terms</Link>. No cash
        to chase, and joining costs nothing.
      </p>

      <div className="mt-10 rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
        <h2 className="text-base font-bold text-ink">New York guides for sitters and walkers</h2>
        <ul className="mt-3 space-y-2 text-sm">
          <li>
            <Link href="/blog/dog-walker-jobs-nyc" className="font-semibold text-sitter-dark underline">
              Dog walker jobs in NYC: how to become a dog walker in New York
            </Link>
          </li>
          <li>
            <Link href="/blog/pet-sitting-jobs-new-york" className="font-semibold text-sitter-dark underline">
              Pet sitting jobs in New York: how much can you earn?
            </Link>
          </li>
          <li>
            <Link href="/pet-sitting/new-york" className="font-semibold text-sitter-dark underline">
              What New York owners look for in a sitter
            </Link>
          </li>
        </ul>
      </div>
    </section>
  );
}

/** FAQ propre à New York (affichée + JSON-LD FAQPage). */
export const NYC_FAQ: { q: string; a: string }[] = [
  {
    q: "How much do pet sitters and dog walkers charge in New York?",
    a: "Typical New York ranges are $20–35 per walk and $40–70 per day of sitting or visits. You set your own rates in your profile, and overnight stays are priced by you.",
  },
  {
    q: "Is it free to join HoPetSit as a sitter or walker in New York?",
    a: "Yes. Creating your profile is free. When an owner books and pays through the app, HoPetSit keeps a 20% platform commission and pays you the remaining 80% 24 hours after the service ends.",
  },
  {
    q: "Is there an owner looking for a sitter in New York right now?",
    a: "Yes. In October 2026 an owner in Queens has an open pet sitting request on HoPetSit, and few sitters live close enough to answer. Sitters who join now are the first ones New York owners see.",
  },
  {
    q: "Can I be both a pet sitter and a dog walker?",
    a: "Pick the role that fits you best when you sign up: pet sitter for home sitting, overnight stays and visits, dog walker for walks. Your profile lists the services and rates you choose.",
  },
];
