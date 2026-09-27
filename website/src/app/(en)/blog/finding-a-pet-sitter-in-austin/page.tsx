import type { Metadata } from "next";
import Link from "next/link";

// 2026-W38 — SEO US : Austin, angle PROPRIÉTAIRES (semaine ISO paire). Ville
// en rotation (index 6/8), données reprises de lib/recruit-cities.ts (austin).
export const metadata: Metadata = {
  title: "Finding a trusted dog sitter in Austin, TX (2026 guide)",
  description:
    "Austin dog owners: realistic pet sitting rates ($30-55/day, $15-25/walk), how to vet a sitter, and why secure in-app payment and live GPS tracking matter.",
  alternates: {
    canonical: "https://www.hopetsit.com/blog/finding-a-pet-sitter-in-austin",
  },
};

const FAQ = [
  {
    q: "How much does a dog sitter cost in Austin?",
    a: "Expect $30 to $55 per day for in-home sitting, and $15 to $25 for a single walk. Overnight stays or multi-day bookings often come with a small discount after the first day.",
  },
  {
    q: "Should I meet the sitter before booking?",
    a: "Yes, always. A short meet-and-greet, in person or on video, lets you check that your dog is comfortable and hand over the essentials: feeding schedule, meds, and how they behave around other dogs.",
  },
  {
    q: "Is it safe to pay a pet sitter in advance?",
    a: "Only through a platform that holds the payment until the job is done. On HoPetSit, the booking is paid securely in the app, but the sitter isn't paid out until your pet is safely returned to you.",
  },
  {
    q: "How do I know my dog actually got walked?",
    a: "Live GPS tracking (PawFollow) shows the walk happening in real time on a map, with route and duration — not just a text saying 'all good'.",
  },
  {
    q: "What if I need a sitter last minute?",
    a: "Austin is growing faster than the number of sitters available, so demand spikes around SXSW, ACL and holiday weekends. Book a few days ahead when you can, and check a sitter's actual availability calendar before messaging.",
  },
];

export default function ArticleFindingSitterAustin() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Finding a trusted dog sitter in Austin, TX",
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
      <p className="text-sm font-semibold text-owner">Owner's guide · Austin, TX</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Finding a trusted dog sitter in Austin, TX
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Austin is one of the most dog-friendly cities in the country — and
        one of the fastest-growing, which means the number of dogs is
        outpacing the number of reliable sitters. Here's what to actually
        check before you hand over your leash for a weekend, a workday, or a
        two-week trip.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        What a sitter costs in Austin
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
              <td className="p-4">$30 – $45</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Overnight sitting</td>
              <td className="p-4">$40 – $55</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        Prices run a bit higher close to downtown, Zilker and South Congress,
        and drop slightly further out. Multi-day bookings usually get a small
        discount past the first day — always ask upfront, not after.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        How to actually vet a sitter
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A nice profile photo tells you nothing. Look for reviews tied to
        completed bookings, not just star ratings with no context, and
        prioritize sitters close enough to your neighborhood — a 20-minute
        drive across I-35 during rush hour is not "nearby." If you're
        weighing a sitter against a boarding facility, we compared both
        options{" "}
        <Link href="/blog/dog-boarding-vs-pet-sitting" className="font-semibold text-owner underline">
          honestly, price by price
        </Link>.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Before you book, do a short meet-and-greet — in person if you can,
        video call if you can't. Hand over the real details: feeding
        schedule, any meds, how your dog reacts to other dogs at the dog
        park. It takes fifteen minutes and it's the single best predictor of
        how the actual stay will go.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Payment and proof, not just promises
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Never pay a sitter in full, in cash, before the service happens —
        it's the single easiest way to get burned. On HoPetSit, payment is
        secured in the app the moment a booking is confirmed, and it's only
        released to the sitter once your dog is back with you. Every walk
        can be tracked live on the map with PawFollow, so "he had a great
        walk" comes with an actual route and duration attached, not just a
        text.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Questions Austin owners actually ask
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
          Find a verified sitter in Austin
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Verified profiles, real reviews, secure in-app payment and live GPS
          tracking on every walk.
        </p>
        <Link
          href="/pet-sitting/austin"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          See sitters in Austin
        </Link>
      </div>
    </div>
  );
}
