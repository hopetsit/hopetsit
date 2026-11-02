import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 2026-W44 (weekly marketing routine, Sunday) — next unchecked topic from
// `marketing/sujets_4poles.md` § New York (pillar page /pet-sitting/new-york#districts).
// Dog run names below come from the same OpenStreetMap data already published on the
// 5 borough pages (src/lib/city-districts.json) — nothing invented. No prices, no stats.
const URL = "https://www.hopetsit.com/blog/dog-runs-in-nyc";
const TITLE = "Dog Runs in NYC: Etiquette and How to Pick One in Your Borough";
const DESCRIPTION =
  "Off-leash dog runs across New York City: the unwritten etiquette, how to tell if one is right for your dog, and real dog runs to check out in Manhattan, Brooklyn, Queens, the Bronx and Staten Island.";
const COVER_ALT = "Curly puppy on a leash, cover of the NYC dog runs guide";
const HEADLINE = "Dog runs in NYC: etiquette and how to pick one in your borough";

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
    images: [{ url: "https://www.hopetsit.com/blog/dog-runs-in-nyc.jpg", width: 1200, height: 630, alt: "Curly puppy on a leash, cover of the NYC dog runs guide" }],
  },
};

const FAQ = [
  {
    q: "Do dogs need to be leashed in New York City?",
    a: "Yes, outside of designated off-leash areas and the posted off-leash hours some parks allow early morning and late evening. Inside a fenced dog run, dogs are typically off leash once inside the gate — check the signage at the run itself, rules can vary slightly from one park to another.",
  },
  {
    q: "Is my dog ready for a dog run?",
    a: "A dog run works best for a dog that already comes back when called, isn't guarding food or toys around strangers, and enjoys other dogs rather than tolerating them. If you're not sure, watch from outside the fence for a few minutes before going in, and ask your vet if your dog's age and vaccination status are appropriate for off-leash play.",
  },
  {
    q: "What should I bring to a dog run?",
    a: "Poop bags (most runs have a dispenser, but it can run empty), water for hot days, and a leash in hand even though your dog will be off it — you'll need it to leave. Leave treats in your pocket unless you're prepared to share, since a bag of food can draw every dog in the run.",
  },
  {
    q: "Can a dog walker take my dog to a dog run?",
    a: "Many HoPetSit walkers build a dog run stop into a midday walk if your dog is social and used to it — just mention it in your request so you only hear back from walkers comfortable supervising off-leash play, and let them know how your dog behaves around others.",
  },
  {
    q: "What if my dog gets into a scuffle?",
    a: "Most dog run scuffles are loud and over in seconds. Stay calm, call your dog's name in a normal voice rather than shouting, and separate the dogs by the leash or collar rather than reaching between them. If it happens often, your dog may simply prefer calmer runs or one-on-one walks instead.",
  },
];

const BOROUGHS = [
  {
    id: "manhattan",
    name: "Manhattan",
    note: "Small apartments and long workdays mean dog runs double as the midday release valve. Tompkins Square Dog Run and the Tribeca Dog Park are two of the busiest spots to know.",
  },
  {
    id: "brooklyn",
    name: "Brooklyn",
    note: "From Prospect Park's famous off-leash hours to waterfront spots like Brooklyn Bridge Park's Pier 6 Dog Run, Brooklyn has one of the city's liveliest dog communities.",
  },
  {
    id: "queens",
    name: "Queens",
    note: "The largest borough by area spreads its runs out, from the Jackson Heights Canine Recreational Wonderland to the Rockaway Freeway Dog Park near the beach.",
  },
  {
    id: "the-bronx",
    name: "The Bronx",
    note: "Big, green and quieter: Seton Park Dog Run and Woodlawn Dog Park sit close to some of the largest park land in the city.",
  },
  {
    id: "staten-island",
    name: "Staten Island",
    note: "The most suburban borough has fewer runs, but Conference House Park Dog Run gives dogs room to move at the island's southern tip.",
  },
];

export default function ArticleDogRunsNyc() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        mainEntityOfPage: URL,
        datePublished: "2026-11-01",
        image: { "@type": "ImageObject", url: "https://www.hopetsit.com/blog/dog-runs-in-nyc.jpg", width: 1200, height: 630 },
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com", logo: { "@type": "ImageObject", url: "https://www.hopetsit.com/logo.png" } },
      },
      { "@type": "FAQPage", mainEntity: FAQ.map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })) },
    ],
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">Practical guide · New York</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Dog runs in NYC: etiquette and how to pick one in your borough
      </h1>
      <Image
        src="/blog/dog-runs-in-nyc.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        No yard, strict leash laws almost everywhere else, and a dog that needs to actually run: that
        is exactly what New York&apos;s fenced dog runs are for. There are dozens scattered across the
        five boroughs, but not every run suits every dog, and the etiquette inside the fence is mostly
        unwritten. Here is how to pick the right one and use it well.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What a dog run actually is</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A dog run is a fenced, usually gravel or rubber-surfaced area inside a city park, built so dogs
        can be off leash legally. Most have a double-gate entry so no dog slips out while another comes
        in, a water source, and separate sections for small and large dogs in the bigger parks. They are
        free to use and open to any dog, which is exactly why the informal rules inside matter: there is
        no staff checking vaccination records or temperaments at the gate.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">The etiquette nobody writes down</h2>
      <ul className="mt-4 space-y-2">
        {[
          "Watch before you enter. A minute or two outside the fence tells you the mood of the run and whether your dog's energy will fit in.",
          "Leash off only once the gate is fully closed behind you, and leash back on before you open it to leave — that's when most dogs slip out.",
          "Pick up every time, even if your dog \"barely did anything.\" Runs with dirty ground get reported and sometimes closed.",
          "Keep an eye on your dog, not your phone. Most scuffles start small and are easy to break up early if someone's actually watching.",
          "Ask before offering another dog a treat, and don't bring food that can start a scramble among several dogs at once.",
          "If your dog is reactive, anxious, or simply happier one-on-one, a quiet street or a private yard is kinder than forcing a dog run.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Dog runs to know, borough by borough</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Each borough has its own cluster of runs, mapped from OpenStreetMap on our borough pages below.
        A few to start with:
      </p>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {BOROUGHS.map((b) => (
          <Link
            key={b.id}
            href={`/pet-sitting-new-york/${b.id}`}
            className="block rounded-2xl border border-ink/5 bg-white p-5 shadow-card transition hover:border-owner/40"
          >
            <h3 className="font-bold text-ink">{b.name}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{b.note}</p>
            <span className="mt-3 inline-block text-sm font-semibold text-owner">See pet sitters in {b.name} →</span>
          </Link>
        ))}
      </div>
      <p className="mt-6 text-xs text-ink-muted">Dog run names: © OpenStreetMap contributors (ODbL).</p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">When a dog run isn&apos;t the answer</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A puppy still building its vaccination schedule, an older dog with joint pain, or a dog that
        gets overwhelmed by a crowd of strangers is usually better off with a calm leash walk or a quiet
        stretch of park instead. If you&apos;re not sure which fits your dog, ask your vet, and consider
        a regular dog walker who already knows your dog&apos;s temperament rather than a new run every
        time. Not sure what a sitter or walker visit even looks like day to day? Our guides on{" "}
        <Link href="/blog/what-is-dog-sitting" className="font-semibold text-owner underline">dog sitting</Link>{" "}
        and{" "}
        <Link href="/blog/what-is-cat-sitting" className="font-semibold text-owner underline">cat sitting</Link>{" "}
        break down the formats.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Find a walker who knows your borough</h2>
      <ol className="mt-4 space-y-3">
        {[
          "Post your request for free: your dog, how it behaves around other dogs, and whether you'd like dog run time included.",
          "Nearby walkers and sitters reply with their price and availability.",
          "Chat in the app, ask how they handle off-leash play, and set up a meet-and-greet before the first walk.",
          "Pay in the app. Payment is secure and only released to the walker after the walk; PawFollow GPS tracking shows the route live.",
        ].map((t, i) => (
          <li key={t} className="flex gap-3 leading-relaxed text-ink-muted">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-owner text-sm font-bold text-white">{i + 1}</span>
            <span>{t}</span>
          </li>
        ))}
      </ol>
      <p className="mt-6 leading-relaxed text-ink-muted">
        See every borough, its dog runs, parks and vets, on our{" "}
        <Link href="/pet-sitting/new-york#districts" className="font-semibold text-owner underline">New York pet sitting page</Link>.
        Traveling over the holidays?{" "}
        <Link href="/blog/pet-sitting-new-york-holidays" className="font-semibold text-owner underline">Our holiday pet sitting guide</Link>{" "}
        covers that. Looking to walk dogs for a living instead?{" "}
        <Link href="/become-a-pet-sitter/new-york" className="font-semibold text-owner underline">Become a sitter in New York</Link>.
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

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">Find a walker who gets your dog outside</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">Walks, drop-ins and overnights across the five boroughs.</p>
        <Link href="/pet-sitting/new-york" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Find a dog walker in New York
        </Link>
      </div>
    </div>
  );
}
