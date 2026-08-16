import type { Metadata } from "next";
import Link from "next/link";

// v535 — SEO US : recrutement de l'offre (dog walkers) via requête à fort
// volume "how to become a dog walker".
export const metadata: Metadata = {
  title: "How to become a dog walker in 2026 (and what you can earn)",
  description:
    "No degree needed: set your rates ($15-$30/walk), choose your hours and get paid securely. How to start dog walking in the US and build a loyal client base.",
  alternates: { canonical: "https://www.hopetsit.com/blog/how-to-become-a-dog-walker" },
};

const STEPS = [
  {
    n: "1",
    t: "Create your free profile",
    p: "A friendly photo, a few lines about your experience with dogs, the services you offer (walks, drop-in visits, sitting) and YOUR rates. No CV, no interview.",
  },
  {
    n: "2",
    t: "Get your verified badge",
    p: "Identity verification takes 5 minutes in the app and adds a ✓ badge to your profile. Owners book verified walkers far more often — it's the single best investment you can make.",
  },
  {
    n: "3",
    t: "Accept only what suits you",
    p: "Owners nearby contact you through the built-in chat. You pick the dogs, the times and the neighborhoods. Students walk between classes; remote workers at lunch.",
  },
  {
    n: "4",
    t: "Get paid — guaranteed",
    p: "Payment is secured in the app when the owner books and lands in your bank account after the service. No chasing cash, no awkward conversations, no unpaid walks.",
  },
];

const FAQ = [
  {
    q: "How much do dog walkers earn in the US?",
    a: "Typical rates are $15-$25 per 30-minute walk and $25-$40 per hour. With 2 walks a day on weekdays, that's roughly $600-$1,000 per month as a side income — more in big cities.",
  },
  {
    q: "Do I need a license or certification?",
    a: "In most US cities, no license is required for occasional dog walking. Reliability, dog sense and good reviews matter far more. For a full-time business, check your city's rules and consider liability insurance.",
  },
  {
    q: "How do I get my first clients?",
    a: "Be early on a growing platform: complete profile, verified badge, honest description and fair launch pricing. Your first 3 reviews are the hardest — after that, momentum builds.",
  },
  {
    q: "What makes owners trust a new walker?",
    a: "Transparency. On HoPetSit, owners literally watch the walk live on GPS and receive the pet with a photo + code confirmation. New walkers start with the same trust tools as veterans.",
  },
];

export default function ArticleBecomeDogWalker() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "How to become a dog walker in 2026 (and what you can earn)",
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
      <p className="text-sm font-semibold text-sitter-dark">Career guide · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        How to become a dog walker (and actually get paid for it)
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Love dogs? Have a few free hours? Dog walking is one of the rare side
        gigs that's good for your health, your mood and your bank account. Here's
        how to start in the US — no degree, no boss, no upfront cost.
      </p>

      <div className="mt-8 flex flex-wrap gap-3">
        {["💵 $15-$30 per walk", "📅 Your hours", "✓ Verified badge", "🔒 Guaranteed payment"].map((b) => (
          <span key={b} className="rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-ink shadow-card">
            {b}
          </span>
        ))}
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">How it works</h2>
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

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">FAQ</h2>
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
          Early walkers get the best neighborhoods
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          HoPetSit is growing in the US — little competition between walkers,
          new owners arriving every week. Create your free profile today.
        </p>
        <Link href="/download" className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white">
          Download HoPetSit — it's free
        </Link>
      </div>
    </div>
  );
}
