import type { Metadata } from "next";
import Link from "next/link";

// v535 — SEO US : comparatif boarding vs sitting (requête décisionnelle).
export const metadata: Metadata = {
  title: "Dog boarding vs pet sitting: which is best for your dog? (2026)",
  description:
    "Kennel, boarding facility or in-home pet sitter? Compare prices ($25-$85/night), stress levels and safety to pick the right care for your dog while you travel.",
  alternates: { canonical: "https://www.hopetsit.com/blog/dog-boarding-vs-pet-sitting" },
};

const FAQ = [
  {
    q: "Is pet sitting cheaper than boarding?",
    a: "Usually yes. In-home pet sitting typically runs $25-$45 per night in the US, while boarding facilities charge $40-$85 per night — and add fees for walks, meds or 'premium suites'.",
  },
  {
    q: "Which option is less stressful for the dog?",
    a: "For most dogs, staying in a familiar home (theirs or the sitter's) beats a kennel environment: no barking hall, no cage time, a routine close to normal. Anxious, senior and puppy dogs benefit the most.",
  },
  {
    q: "When is boarding the better choice?",
    a: "Highly social dogs who love group play can thrive in good daycare-style boarding. It's also a fallback during peak holidays when sitters are fully booked — book either option well in advance.",
  },
  {
    q: "How do I check a pet sitter is legit?",
    a: "Look for identity verification, reviews tied to real bookings, and a secure payment flow. On HoPetSit, payment is only released after the service, and every walk can be tracked live on GPS.",
  },
];

const ROWS = [
  ["Price per night", "$25 – $45", "$40 – $85"],
  ["Environment", "A real home — theirs or the sitter's", "Facility with kennels/runs"],
  ["Routine", "Kept (walks, meals, couch time)", "Facility schedule"],
  ["Stress level", "Low for most dogs", "Varies; hard for anxious dogs"],
  ["Updates", "Photos, chat, live GPS on walks", "Depends on facility"],
  ["Best for", "Most dogs, seniors, puppies", "Very social, high-energy dogs"],
];

export default function ArticleBoardingVsSitting() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Dog boarding vs pet sitting: which is best for your dog?",
        inLanguage: "en",
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com" },
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
      <p className="text-sm font-semibold text-owner">Comparison guide · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Dog boarding vs pet sitting: which should you choose?
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Trip coming up? You have two real options: a boarding facility, or a
        pet sitter who cares for your dog in a real home. Here's the honest
        comparison — prices, stress and safety — so you can decide in five
        minutes.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Side by side</h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold"></th>
              <th className="p-4 font-bold">🏠 Pet sitting</th>
              <th className="p-4 font-bold">🏢 Boarding</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            {ROWS.map((r) => (
              <tr key={r[0]} className="border-b border-ink/5 last:border-0">
                <td className="p-4 font-semibold text-ink">{r[0]}</td>
                <td className="p-4">{r[1]}</td>
                <td className="p-4">{r[2]}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">FAQ</h2>
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
          Find a trusted pet sitter near you
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Verified profiles, real reviews, secure payment and live GPS tracking
          — free on HoPetSit, across the US.
        </p>
        <Link href="/download" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Download the HoPetSit app
        </Link>
      </div>
    </div>
  );
}
