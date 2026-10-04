import type { Metadata } from "next";
import Link from "next/link";

// 2026-W40 — SEO US, owner angle (even ISO week), city rotation index 0/8
// (Dallas). Topic #1 from marketing/sujets_us.md — links into the two
// Dallas pages that Search Console still shows as unknown to Google.
export const metadata: Metadata = {
  title: "How Much Does a Pet Sitter Cost in Dallas? 2026 Rates",
  description:
    "Realistic Dallas pet sitting rates for 2026: $30-55 a day, $15-25 a walk. What changes the price, how it compares to boarding, and how to pay safely.",
  alternates: {
    canonical:
      "https://www.hopetsit.com/blog/how-much-does-a-pet-sitter-cost-in-dallas",
  },
};

const FAQ = [
  {
    q: "How much does a pet sitter cost in Dallas?",
    a: "In-home pet sitting in Dallas typically runs $30 to $55 a day, depending on the neighborhood and whether it includes an overnight stay. A single walk runs $15 to $25.",
  },
  {
    q: "What's the difference between daytime sitting and overnight sitting?",
    a: "Daytime sitting with no overnight tends to land toward the lower end of the $30-55 range, while a full overnight stay — someone actually sleeping at your place or keeping your dog overnight — lands toward the higher end.",
  },
  {
    q: "Is boarding cheaper than a pet sitter in Dallas?",
    a: "Not usually. In-home pet sitting generally runs $25-45 a night nationally, while boarding facilities charge $40-85 a night once you add fees for walks, meds or a larger kennel. A sitter also means no new environment and no other animals your pet has to adjust to.",
  },
  {
    q: "Why do rates vary so much across Dallas?",
    a: "Uptown, Lakewood, Plano and Frisco each have their own supply of sitters. A newer suburb with fewer sitters registered can mean a longer wait or a slightly higher rate than a neighborhood where HoPetSit's community already has regulars.",
  },
  {
    q: "How should I pay a pet sitter safely?",
    a: "Avoid handing over cash for the full amount before the service happens. On HoPetSit, payment is held securely in the app the moment a booking is confirmed and only released to the sitter after your pet is back with you — and every walk can be tracked live on the map with PawFollow.",
  },
];

export default function ArticlePetSitterCostDallas() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "How Much Does a Pet Sitter Cost in Dallas? 2026 Rates",
        inLanguage: "en-US",
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: {
          "@type": "Organization",
          name: "HoPetSit",
          url: "https://www.hopetsit.com",
        },
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
      <p className="text-sm font-semibold text-owner">Owner's guide · Dallas, TX</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        How much does a pet sitter cost in Dallas?
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Uptown, Lakewood, Plano, Frisco: Dallas-Fort Worth is sprawling, hot
        for half the year, and full of dogs with big yards who still need a
        midday walk. Before you book a sitter or a boarding kennel, here's
        what the service actually costs and what changes the price.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Realistic Dallas rates
      </h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Service</th>
              <th className="p-4 font-bold">Typical rate</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Single walk (30-45 min)</td>
              <td className="p-4">$15 – $25</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Daytime sitting, no overnight</td>
              <td className="p-4">$30 – $40</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Overnight sitting</td>
              <td className="p-4">$40 – $55</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        Rates run a little higher in Uptown and Lakewood, where there's more
        competition for the sitter's time, and a little lower further out in
        Plano or Frisco. Multi-day bookings are usually negotiated with a
        small discount after the first day — always ask upfront.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Pet sitter vs boarding: which costs more?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Nationally, in-home pet sitting runs $25-45 a night, while a boarding
        facility charges $40-85 a night once you add the fees for walks,
        medication or a bigger kennel — and that's before counting the stress
        of a new environment and other animals. We compared both options{" "}
        <Link
          href="/blog/how-much-does-a-dog-walker-cost"
          className="font-semibold text-owner underline"
        >
          price by price in our dog walker cost guide
        </Link>
        . In Dallas's heat, a sitter who can keep your dog on their normal
        schedule, in their own yard, is often worth the extra few dollars a
        day.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Why rates vary across DFW
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Dallas-Fort Worth isn't one market — it's a dozen suburbs stitched
        together, each with its own supply of sitters. Uptown and Lakewood
        already have a few regulars built up; a newer or fast-growing area
        can mean fewer sitters to choose from and a slightly longer wait for
        a last-minute booking. If you're close to the center, it's worth{" "}
        <Link href="/pet-sitting/dallas" className="font-semibold text-owner underline">
          browsing sitters in Dallas
        </Link>{" "}
        a few days ahead rather than the night before.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Paying safely, not just cheaply
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        The lowest price isn't always the best deal. Avoid handing over cash
        for the full amount before the service happens — it's the easiest
        way to get burned if something goes wrong. On HoPetSit, payment is
        held securely in the app the moment a booking is confirmed, and it's
        only released to the sitter once your pet is safely back with you.
        Every walk can also be tracked live on the map with PawFollow, so
        "he had a great time" comes with an actual route and duration
        attached.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Frequently asked questions
      </h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div
            key={f.q}
            className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card"
          >
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Find a verified pet sitter in Dallas
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Verified profiles, real reviews, secure in-app payment and live GPS
          tracking on every walk.
        </p>
        <Link
          href="/pet-sitting/dallas"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          See sitters in Dallas
        </Link>
        <p className="mt-4 text-sm text-ink-muted">
          Thinking about sitting instead?{" "}
          <Link
            href="/become-a-pet-sitter/dallas"
            className="font-semibold text-owner underline"
          >
            Become a pet sitter in Dallas
          </Link>
          {" "}— Uptown, Lakewood, Plano and Frisco all need more sitters.
        </p>
      </div>
    </div>
  );
}
