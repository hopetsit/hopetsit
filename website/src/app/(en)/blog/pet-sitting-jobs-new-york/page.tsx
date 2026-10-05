import type { Metadata } from "next";
import Link from "next/link";

// 05/10/2026 (GUS, ordre de Daniel : recruter des prestataires à New York,
// gratuitement). Requête visée : « pet sitting jobs new york » / « how much
// do pet sitters make in nyc ». Relié à /become-a-pet-sitter/new-york et à
// /blog/dog-walker-jobs-nyc. Tarifs = fourchettes déjà publiées sur la page
// New York ; commission et délai de versement = CGU. L'exemple de semaine est
// un calcul présenté comme tel, pas une promesse de revenus.

const URL = "https://www.hopetsit.com/blog/pet-sitting-jobs-new-york";
const TITLE = "Pet Sitting Jobs in New York: How Much Can You Earn?";
const DESCRIPTION =
  "Pet sitting and dog walking pay in New York: usual rates, what changes the price, what you keep after the commission, taxes, and how sitters build regular clients.";
const HEADLINE = "Pet sitting jobs in New York: how much can you earn?";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  alternates: { canonical: URL },
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    url: URL,
    type: "article",
    locale: "en_US",
    siteName: "HoPetSit",
    images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }],
  },
};

const FAQ = [
  {
    q: "How much do pet sitters charge in New York?",
    a: "On HoPetSit, New York sitters usually charge $40 to $70 per day of sitting or visits and $20 to $35 per walk. You set your own prices, including for overnight stays.",
  },
  {
    q: "What does HoPetSit take from my earnings?",
    a: "Joining is free. On bookings paid through the app, HoPetSit keeps a 20% platform commission and pays out the remaining 80% 24 hours after the service ends.",
  },
  {
    q: "Do I have to pay taxes on pet sitting income?",
    a: "Pet sitting income is generally taxable. Keep a record of what you earn and check the IRS and New York State rules, or ask a tax professional about your situation.",
  },
  {
    q: "Is pet sitting in New York a full-time job?",
    a: "For most people it starts as a side activity around school, remote work or retirement. Whether it grows depends on how many regular clients you build in your neighborhood.",
  },
];

const RATES = [
  { s: "Dog walk (about 30 min)", r: "$20 – $35" },
  { s: "Day sitting or drop-in visits", r: "$40 – $70 per day" },
  { s: "Overnight or multi-day stay", r: "Your own day and week rates" },
];

export default function ArticlePetSittingJobsNewYork() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        datePublished: "2026-10-05",
        dateModified: "2026-10-05",
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
      <p className="text-sm font-semibold text-sitter-dark">New York · Pay guide · October 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">{HEADLINE}</h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        New York is expensive for everyone, including dog and cat owners — and that is exactly why a reliable
        sitter is worth paying for. Owners who work long hours or travel need someone they trust to walk the
        dog, feed the cat or stay over. Here is what pet sitting really pays in the city, what you keep, and
        what makes the difference between a few bookings and a steady side income.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">The usual rates in New York</h2>
      <div className="mt-5 overflow-hidden rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-3 font-bold md:p-4">Service</th>
              <th className="p-3 font-bold md:p-4">Usual price</th>
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
        These are the ranges shown to New York owners on our{" "}
        <Link href="/become-a-pet-sitter/new-york" className="font-semibold text-sitter-dark underline">
          New York sitter page
        </Link>
        . On HoPetSit you write your own prices in your profile — nobody sets them for you.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What changes the price</h2>
      <ul className="mt-4 space-y-3 text-ink-muted">
        <li className="leading-relaxed"><strong className="text-ink">Time.</strong> A 60-minute walk or a long visit is worth more than a quick 30-minute loop.</li>
        <li className="leading-relaxed"><strong className="text-ink">Number of pets.</strong> Two dogs, or a dog plus cats, means more work; many sitters add a rate per extra pet.</li>
        <li className="leading-relaxed"><strong className="text-ink">Special care.</strong> Puppies, senior dogs, medication or a dog that pulls hard justify a higher price.</li>
        <li className="leading-relaxed"><strong className="text-ink">Dates.</strong> Holiday weekends, Thanksgiving and the end of December are when owners travel most and sitters are hardest to find.</li>
        <li className="leading-relaxed"><strong className="text-ink">Overnights.</strong> Staying at the owner&apos;s home means giving up your evening and night — price it as a full day, not as a visit.</li>
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What you actually keep: an example week</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        This is simple arithmetic, not a promise — what you earn depends entirely on the bookings you accept.
        Say you charge $25 per walk and walk one dog twice each weekday: that is 10 walks, or $250 paid by the
        owner. HoPetSit keeps its 20% commission, so $200 is paid out to you, 24 hours after each service. Add
        one weekend of day sitting at $50 a day and the owner pays $100, of which you receive $80.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Signing up costs nothing, and the commission rule is the same for everyone, as set out in our{" "}
        <Link href="/terms" className="font-semibold text-sitter-dark underline">terms</Link>. Remember to put
        some money aside: pet sitting income is generally taxable, so keep records and check the IRS and New
        York State rules for your situation. If you do it regularly, liability insurance for pet care is worth
        looking into.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">How New York sitters build regular income</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        The sitters who do well are rarely the cheapest. They are the ones owners book again. A regular client
        who needs a walk every weekday, or a sitter every time they fly home for the holidays, is worth far more
        than ten one-off requests. Three habits make that happen:
      </p>
      <ul className="mt-4 space-y-3 text-ink-muted">
        <li className="leading-relaxed"><strong className="text-ink">Stay local.</strong> Cover the blocks you can reach on foot. Dogs only ride the subway in a carrier, and owners prefer someone close by who can step in at short notice.</li>
        <li className="leading-relaxed"><strong className="text-ink">Send updates.</strong> A photo and two lines after each visit is what owners remember. On HoPetSit the walk is also shown live on the map.</li>
        <li className="leading-relaxed"><strong className="text-ink">Collect reviews early.</strong> Short walks and cat visits are an easy way to get your first reviews before taking on week-long stays.</li>
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Is there demand right now?</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Yes. In October 2026, New York owners — including one in Queens — have open sitting requests on
        HoPetSit, and only a handful of sitters live close enough to answer them. HoPetSit is new in New York,
        so there is little competition between sitters: the people who join now are the first ones owners see
        in their neighborhood. If you mostly want to walk dogs, start with our guide{" "}
        <Link href="/blog/dog-walker-jobs-nyc" className="font-semibold text-sitter-dark underline">
          Dog walker jobs in NYC: how to become a dog walker in New York
        </Link>
        . To see things from the owner&apos;s side, read{" "}
        <Link href="/pet-sitting/new-york" className="font-semibold text-sitter-dark underline">
          pet sitting in New York for owners
        </Link>
        .
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Frequently asked questions</h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-sitter-light p-6 text-center md:p-8">
        <h2 className="font-display text-2xl font-extrabold text-ink">Pet sit in New York</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Free to join. Your rates, your hours, owners in your own neighborhood.
        </p>
        <Link href="/signup?role=sitter&city=New%20York" className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white">
          Join as a pet sitter
        </Link>
        <p className="mt-3 text-xs text-ink-soft">
          <Link href="/become-a-pet-sitter/new-york" className="underline">Everything about sitting and walking in New York</Link>
        </p>
      </div>
    </div>
  );
}
