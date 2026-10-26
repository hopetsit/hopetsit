import type { Metadata } from "next";
import Link from "@/components/SiteLink";

// 2026-W43 — SEO recruiting post for the Miami market (weekly marketing
// routine, odd ISO week = recruiting angle, city picked from the US rotation
// — the one city in the 8-city list not yet covered by any post).
export const metadata: Metadata = {
  title: "How to become a pet sitter in Miami (and what you can earn)",
  description:
    "Brickell, Wynwood, Coral Gables: realistic dog walking and pet sitting rates in Miami, how to land your first regular clients, and which status to set up.",
  alternates: {
    canonical: "https://www.hopetsit.com/blog/become-a-pet-sitter-in-miami",
  },
};

const FAQ = [
  {
    q: "Do I need a license to walk dogs or pet sit in Miami?",
    a: "No license is required for occasional dog walking or pet sitting. What matters most to owners is a clear profile, real availability, and reviews from past clients. Check your local rules if you plan to make it a full-time business.",
  },
  {
    q: "How much does pet sitting pay in Miami?",
    a: "It depends entirely on how many owners book you and how often, so there is no guaranteed amount. The rates in this guide are the usual ranges in Miami; what grows over time is the number of regular clients who book you again.",
  },
  {
    q: "Which Miami neighborhoods have the most demand?",
    a: "Condo-dense areas with frequent travelers — Brickell, Wynwood, South Beach, Coral Gables — tend to have the steadiest demand, since owners there fly out often and small dogs make up a large share of the local pet population.",
  },
  {
    q: "What about the heat?",
    a: "Most owners and sitters shift walks to early morning or evening once temperatures climb, especially in summer. Being upfront about your preferred time slots is part of being reliable here, not a weakness.",
  },
  {
    q: "How do I get my first clients?",
    a: "Be specific about the neighborhood and building types you cover — owners almost always prefer someone who already knows their block or their condo building over a generic citywide profile. Your first booking matters most: it gives you your first review.",
  },
];

export default function ArticleMiami() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "How to become a pet sitter in Miami (and what you can earn)",
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
      <p className="text-sm font-semibold text-owner">City guide · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        How to become a pet sitter in Miami
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Brickell, Wynwood, Coral Gables: Miami is a city of condos, frequent
        travelers, and small dogs that rarely get a backyard of their own.
        Owners fly out for work or for the weekend year-round, not just in
        summer, which makes pet sitting here one of the steadiest side
        activities around — here's what it realistically looks like.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        What you can charge
      </h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Service</th>
              <th className="p-4 font-bold">Typical rate</th>
              <th className="p-4 font-bold">Time spent</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Dog walk</td>
              <td className="p-4">$18 – $30</td>
              <td className="p-4">20 – 30 min</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Drop-in visit (cat)</td>
              <td className="p-4">$15 – $25</td>
              <td className="p-4">15 – 20 min</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Full-day sitting</td>
              <td className="p-4">$35 – $60</td>
              <td className="p-4">Daytime, no overnight</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        Rates run higher in condo-dense areas like Brickell and South Beach,
        a little lower further from the water. Multi-day bookings while an
        owner is traveling are usually negotiated at a slight discount.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        What makes the difference
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        What actually moves the needle isn't the rate on your profile, it's
        being the person an owner trusts with their keys or their building's
        front desk code. Two or three loyal clients who travel often beat a
        dozen one-off requests.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Getting your first clients
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Be specific about the neighborhood and the type of building you cover
        — Brickell high-rises, Wynwood lofts, Coral Gables houses. Owners
        booking a sitter on short notice, often right before a flight, pick
        someone who clearly knows their building's drop-off routine over a
        vague "Miami" profile. A real photo and an honest note about your
        experience with animals, even if it's just your own dog, goes further
        than a long list of credentials.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Your first booking matters more than any other: it's what gets you
        your first review. If you're just starting out, cat visits and short
        walks are an easy, low-risk way to build that track record before
        taking on longer sitting jobs or full vacations.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Mistakes that cost you clients
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Pricing yourself far below the going rate doesn't attract more
        bookings — it makes owners suspicious, and locks you into clients who
        negotiate everything. Skipping a short meet-and-greet before the
        first walk is another common mistake: fifteen minutes at the owner's
        place prevents almost every misunderstanding about routine or
        temperament. And taking cash with no record leaves you with no
        recourse if a dispute ever comes up — keep payments and messages in
        one place you can look back on.
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
          Start pet sitting in Miami
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Free to join, you set your own rates and availability. Secure
          in-app payments, a verified profile, and live GPS tracking on every
          walk.
        </p>
        <Link
          href="/become-a-pet-sitter/miami"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Become a pet sitter in Miami
        </Link>
        <p className="mt-3 text-xs text-ink-soft">
          New to pet sitting overall?{" "}
          <Link href="/blog/how-to-become-a-dog-walker" className="underline">
            Read the general starter guide
          </Link>
          {" · "}
          <Link href="/pet-sitting/miami" className="underline">
            Looking for a sitter instead?
          </Link>
        </p>
      </div>
    </div>
  );
}
