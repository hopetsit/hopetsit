import type { Metadata } from "next";
import Link from "next/link";

// v535 — SEO US : "how long can you leave a cat alone" (très gros volume).
export const metadata: Metadata = {
  title: "How long can you leave a cat alone? Vacation guide (2026)",
  description:
    "24-36 hours max for a healthy adult cat — and that's pushing it. What really happens when cats stay alone, and how drop-in visits ($10-$20) solve everything.",
  alternates: { canonical: "https://www.hopetsit.com/blog/leaving-cat-alone-vacation" },
};

const TABLE = [
  ["One work day (8-10 h)", "Fine for healthy adults", "Water + clean litter before leaving"],
  ["24-36 hours", "The absolute maximum", "Extra water bowls, food dispenser"],
  ["2-3 days", "Not alone — daily visits needed", "1-2 drop-in visits per day"],
  ["A week or more", "Never alone", "Daily visits or in-home cat sitter"],
];

const FAQ = [
  {
    q: "Can I leave my cat alone for a weekend with extra food?",
    a: "It's risky. Beyond 36 hours, water fouls, litter overflows, and a blocked urinary tract or a vomiting episode can turn deadly with nobody there. A single daily drop-in visit removes all of that risk.",
  },
  {
    q: "How much does a cat drop-in visit cost in the US?",
    a: "Typically $10-$20 per visit: fresh water, food, litter scoop, playtime and a photo update. Twice-daily bundles usually get a discount.",
  },
  {
    q: "Do cats really get lonely?",
    a: "Yes — despite the independent reputation, most cats show stress behaviors (over-grooming, refusing food, accidents) when alone too long. Kittens and seniors are the most sensitive.",
  },
  {
    q: "Cat sitter vs asking a neighbor?",
    a: "A neighbor is fine for one day. For longer, a verified cat sitter with real reviews, in-app updates and secure payment is the difference between hoping and knowing your cat is okay.",
  },
];

export default function ArticleLeavingCatAlone() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "How long can you leave a cat alone? The vacation guide",
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
      <p className="text-sm font-semibold text-owner">Cat care guide · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        How long can you leave a cat alone?
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        "Cats are independent, they'll be fine" — until the water bowl tips
        over on day one of your week away. Here's what vets actually recommend,
        and the simple, cheap way to travel with peace of mind.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">The honest timeline</h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Time away</th>
              <th className="p-4 font-bold">Verdict</th>
              <th className="p-4 font-bold">What your cat needs</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            {TABLE.map((r) => (
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
          Book drop-in visits in minutes
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Verified cat sitters near you, photo updates at every visit, secure
          in-app payment — free on HoPetSit.
        </p>
        <Link href="/download" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Download the HoPetSit app
        </Link>
      </div>
    </div>
  );
}
