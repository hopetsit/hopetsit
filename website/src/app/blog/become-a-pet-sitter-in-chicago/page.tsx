import type { Metadata } from "next";
import Link from "next/link";

// 2026-W37 — SEO recruiting post for the Chicago market (weekly marketing
// routine, odd ISO week = recruiting angle, city picked from the US rotation).
export const metadata: Metadata = {
  title: "How to become a pet sitter in Chicago (and what you can earn)",
  description:
    "Lincoln Park, Wicker Park, the lakefront trail: realistic dog walking and pet sitting rates in Chicago, how to land your first regular clients, and which status to set up.",
  alternates: {
    canonical: "https://www.hopetsit.com/blog/become-a-pet-sitter-in-chicago",
  },
};

const FAQ = [
  {
    q: "Do I need a license to walk dogs or pet sit in Chicago?",
    a: "No license is required for occasional dog walking or pet sitting. What matters most to owners is a clear profile, real availability, and reviews from past clients. Check your local rules if you plan to make it a full-time business.",
  },
  {
    q: "How much can a pet sitter actually earn in Chicago?",
    a: "A few walks a week as a side activity typically brings in a few hundred dollars a month. With regular clients around Lincoln Park, Wicker Park, or the lakefront and the occasional overnight stay, many sitters clear well over that.",
  },
  {
    q: "Which Chicago neighborhoods have the most demand?",
    a: "Dense, dog-owning neighborhoods along the lakefront trail — Lincoln Park, Wicker Park, Lakeview — tend to have the steadiest demand for midday walks, since owners there commute downtown and can't get home at lunch.",
  },
  {
    q: "How do I get my first clients?",
    a: "Be specific about the streets or the El stops you cover — owners almost always prefer someone who already knows their block over a generic citywide profile. Your first booking matters most: it gives you your first review.",
  },
  {
    q: "Should I worry about taxes or business status?",
    a: "It depends on how much you earn and how regularly. Rules vary by state and change over time, so check your local and state requirements or talk to a tax professional rather than relying on a rule of thumb.",
  },
];

export default function ArticleChicago() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "How to become a pet sitter in Chicago (and what you can earn)",
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
        How to become a pet sitter in Chicago
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Lincoln Park, Wicker Park, the lakefront trail: Chicago has one of the
        most walkable, most dog-dense downtowns in the country, and a lot of
        owners who commute long hours and can't make it home at lunch. That
        gap is exactly where pet sitting and dog walking pay off — here's what
        it realistically looks like.
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
        Rates run higher downtown and along the lakefront, lower in quieter
        neighborhoods further from the Loop. Multi-day bookings over holidays
        or long weekends are usually negotiated at a slight discount.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Doing the monthly math
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Three walks a week at $22 comes out to roughly $260 a month for a few
        hours of walking. Add two weekend sitting days at $45 and that's
        another $180. A handful of regular clients — the kind who book you
        every week rather than once — routinely pushes sitters past $500 a
        month without turning it into a full-time job.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        What actually moves the needle isn't the rate on your profile, it's
        consistency. An owner who works downtown needs the same walker at the
        same time most days — two or three loyal clients beat a dozen
        one-off requests.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Getting your first clients
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Be specific about the neighborhoods and the El stops you cover —
        Lincoln Park, Wicker Park, Lakeview, the lakefront trail. Owners
        booking a walker on short notice pick someone who clearly knows their
        block over a vague "Chicago" profile. A real photo and an honest note
        about your experience with animals, even if it's just your own dog,
        goes further than a long list of credentials.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Your first booking matters more than any other: it's what gets you
        your first review. If you're just starting out, cat visits and short
        walks are an easy, low-risk way to build that track record before
        taking on longer sitting jobs.
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
          Start walking dogs in Chicago
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Free to join, you set your own rates and availability. Secure
          in-app payments, a verified profile, and live GPS tracking on every
          walk.
        </p>
        <Link
          href="/become-a-pet-sitter/chicago"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Become a pet sitter in Chicago
        </Link>
        <p className="mt-3 text-xs text-ink-soft">
          New to pet sitting overall?{" "}
          <Link href="/blog/how-to-become-a-dog-walker" className="underline">
            Read the general starter guide
          </Link>
        </p>
      </div>
    </div>
  );
}
