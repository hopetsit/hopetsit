import type { Metadata } from "next";
import Link from "@/components/SiteLink";

// 2026-W42 — SEO US, owner angle (even ISO week). City rotation: the
// mechanical index (2/8) would have landed on Los Angeles again, already
// covered the previous week (2026-W41, "become-a-pet-sitter-in-los-angeles")
// — moved to the next city, Houston (index 3/8), per the W41 report's own
// note. Rates and neighborhood detail = only what's already in
// src/lib/recruit-cities.ts ($30-55/day, $15-25/walk). No invented numbers,
// no tax/legal claims. Links into the Houston city pages and one existing
// EN article (the Dallas cost guide, same state) per the usual
// internal-linking rule.
const URL = "https://www.hopetsit.com/blog/finding-a-pet-sitter-in-houston";
const TITLE = "Finding a Pet Sitter in Houston: What It Costs and How to Choose (2026)";
const DESCRIPTION =
  "What pet sitting and dog walking cost in Houston in 2026, why the summer heat changes the walk schedule, and how to check a sitter is trustworthy before you hand over your keys.";
const HEADLINE = "Finding a pet sitter in Houston: what to check before you book";

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
    q: "How much does a pet sitter cost in Houston?",
    a: "In-home pet sitting in Houston typically runs $30 to $55 a day, and a single walk usually costs $15 to $25. Rates vary a bit by neighborhood and whether the booking includes an overnight stay.",
  },
  {
    q: "Why does the Houston heat matter for dog walks?",
    a: "Hot pavement and high humidity for much of the year make a midday walk uncomfortable, and sometimes unsafe, for a dog's paws. Most Houston owners and sitters shift walks to early morning or evening instead.",
  },
  {
    q: "How do I know a sitter is actually trustworthy?",
    a: "Look for reviews tied to completed, paid bookings rather than a bare star rating, and check that the sitter's identity has been verified on the platform. A short meet-and-greet before the first booking settles the rest — routine, any medication, how your dog reacts to other dogs in the yard.",
  },
  {
    q: "Should I pay a sitter in cash?",
    a: "Avoid paying the full amount in cash before the service happens. On HoPetSit, payment is held in the app the moment a booking is confirmed and only released to the sitter once your pet is back with you, which gives both sides a record if anything goes wrong.",
  },
  {
    q: "Can I see proof that the walk actually happened?",
    a: "Yes. Live GPS tracking (PawFollow) shows the route on a map while the walk is happening, with the real duration, so you get more than a one-line \"all good\" message.",
  },
];

export default function ArticleFindingPetSitterHouston() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        datePublished: "2026-10-18",
        dateModified: "2026-10-18",
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
      <p className="text-sm font-semibold text-owner">Houston · Owner guide · October 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">{HEADLINE}</h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Big yards, sprawling neighborhoods and a long, hot summer: Houston pet care has its own rhythm. Whether
        you need a midday walk, overnight sitting while you travel, or regular visits for a cat, here&apos;s
        what it actually costs right now and what to check before you hand someone your keys.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What it actually costs</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        In-home pet sitting in Houston usually runs <strong className="text-ink">$30 to $55 a day</strong>,
        and a single walk typically costs <strong className="text-ink">$15 to $25</strong>. Expect the higher
        end for an overnight stay or a larger property, and the lower end for a short daytime visit. Multi-day
        bookings are almost always negotiated at a lower daily rate the longer they run.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Why the Houston heat changes the schedule</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        For much of the year, Houston pavement gets hot enough by midday to hurt a dog&apos;s paws, and the
        humidity makes exercise harder on them too. Most owners and sitters here shift walks to early morning
        or evening instead of the classic lunchtime slot, and keep them shorter when a heat advisory is in
        effect. If you&apos;re booking a walker, it&apos;s worth agreeing on a time window rather than a fixed
        midday hour.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">A profile alone isn&apos;t enough</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A star rating by itself doesn&apos;t say much about reliability. Look for reviews attached to real,
        completed bookings, with a bit of detail (on time, how the dog seemed afterward) rather than a bare
        number, and check that the sitter&apos;s identity has been verified by the platform, not just typed
        into a bio. A sitter who already has bookings in your part of Houston usually knows the nearby parks
        and the quieter streets for an evening walk, which matters as much as the rating itself.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Meet before the first booking</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A short meet-and-greet, in person or over video, before the first walk or stay changes everything.
        It&apos;s the moment to pass along what actually matters: feeding routine, any medication, how your
        dog reacts to other animals in the yard or to a stranger at the gate. Fifteen minutes up front avoids
        most misunderstandings later.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Pay securely, and get proof the walk happened</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Avoid handing over the full amount in cash before the service happens — it&apos;s the easiest way to
        be left with no recourse if something goes wrong. In the HoPetSit app, payment is held the moment a
        booking is confirmed and only released to the sitter once your pet is back with you, never before.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        For walks, live tracking (PawFollow) shows the route on a map while it&apos;s happening, with the real
        duration — so &quot;it went well&quot; becomes something you can actually see. HoPetSit&apos;s
        community map, PawMap, also shows pet-friendly places nearby and which sitters already work your area.
        If you&apos;re still deciding between a sitter and boarding for a longer trip, our Texas-focused guide
        on{" "}
        <Link href="/blog/how-much-does-a-pet-sitter-cost-in-dallas" className="font-semibold text-owner-dark underline">
          what a pet sitter costs in Dallas
        </Link>
        {" "}walks through the same math.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Finding a sitter near you</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Proximity matters more than the star count in a spread-out city like Houston: a sitter fifteen minutes
        away can actually make an evening walk work, where one across town in traffic can&apos;t. See the full
        picture of sitting and dog walking in Houston — rates, how booking works and how sitters get paid — on
        our{" "}
        <Link href="/pet-sitting/houston" className="font-semibold text-owner-dark underline">
          Houston pet sitting page
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

      <div className="mt-14 rounded-3xl bg-owner-light p-6 text-center md:p-8">
        <h2 className="font-display text-2xl font-extrabold text-ink">Book a verified sitter in Houston</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Verified profiles, secure in-app payment and live GPS tracking of every walk.
        </p>
        <Link href="/pet-sitting/houston" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Find a pet sitter in Houston
        </Link>
        <p className="mt-3 text-xs text-ink-soft">
          Are you a sitter or dog walker?{" "}
          <Link href="/become-a-pet-sitter/houston" className="underline">Join HoPetSit in Houston</Link>
        </p>
      </div>
    </div>
  );
}
