import type { Metadata } from "next";
import Link from "next/link";

// v531 — SEO: static English article targeting "dog walker cost" queries.
export const metadata: Metadata = {
  title: "How much does a dog walker cost in 2026? Real rates & tips",
  description:
    "Dog walking costs $15-$30 (or 10-20 €) per walk in 2026. See what changes the price, weekly package deals, and how to find a trusted walker near you.",
  alternates: {
    canonical: "https://www.hopetsit.com/blog/how-much-does-a-dog-walker-cost",
  },
};

const FAQ = [
  {
    q: "How much is a 30-minute dog walk?",
    a: "Most walkers charge $15-$25 (or 10-20 €) for a 30-minute solo walk. Group walks are usually cheaper, and weekly packages can cut the per-walk price by 20-30%.",
  },
  {
    q: "Do dog walkers charge more for two dogs?",
    a: "Yes — expect a surcharge of roughly 50% for a second dog from the same household, rather than double the price.",
  },
  {
    q: "How do I know my dog was actually walked?",
    a: "Choose a walker who shares live GPS tracking. On HoPetSit, the PawFollow feature lets you watch the whole walk on the map in real time.",
  },
  {
    q: "How should I pay a dog walker?",
    a: "Avoid untraceable cash arrangements. In HoPetSit, payment is held securely in the app and only released to the walker after the service is confirmed.",
  },
];

export default function ArticleDogWalkerCost() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "How much does a dog walker cost in 2026?",
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
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <p className="text-sm font-semibold text-owner">Pricing guide · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        How much does a dog walker cost in 2026?
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Whether you're stuck at the office or travelling, a dog walker keeps
        your pup happy and healthy. Here's what dog walking really costs, what
        makes the price move, and how to pick someone you can trust.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Typical rates</h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Service</th>
              <th className="p-4 font-bold">Typical price</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">30-minute walk</td>
              <td className="p-4">$15 – $25 · 10 – 20 €</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">1-hour walk</td>
              <td className="p-4">$25 – $40 · 18 – 30 €</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Weekly package (5 walks)</td>
              <td className="p-4">Often 20-30% cheaper per walk</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        Big cities sit at the top of the range; smaller towns at the bottom.
        Solo walks, weekends, holidays and puppies who need extra attention all
        push the price up.
      </p>

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
          Find a trusted dog walker near you
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Verified profiles, real reviews, secure in-app payment and live GPS
          tracking of every walk — free on HoPetSit.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Download the HoPetSit app
        </Link>
      </div>
    </div>
  );
}
