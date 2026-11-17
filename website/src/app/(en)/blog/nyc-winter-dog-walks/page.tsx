import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 2026-W46 (weekly marketing routine, Sunday) — next unchecked topic from
// `marketing/sujets_4poles.md` § New York (pillar page /pet-sitting/new-york#districts).
// No invented thresholds (e.g. a precise "too cold" temperature) and no legal
// claims: general, widely-agreed winter care practices only.
const URL = "https://www.hopetsit.com/blog/nyc-winter-dog-walks";
const TITLE = "Walking Your Dog in an NYC Winter: Salt, Cold and Short Walks";
const DESCRIPTION =
  "NYC winter dog walks: why sidewalk salt is harder on paws than people think, how to tell a walk is too cold, and why shorter, more frequent walks beat one long one.";
const COVER = "https://www.hopetsit.com/blog/nyc-winter-dog-walks.jpg";
const COVER_ALT = "A small dog on a leash during a walk, cover of the guide to walking your dog in an NYC winter";
const HEADLINE = "Walking your dog in an NYC winter: salt, cold and short walks";

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
    images: [{ url: COVER, width: 1200, height: 630, alt: COVER_ALT }],
  },
};

const FAQ = [
  {
    q: "Do dogs need boots for NYC winters?",
    a: "They're not mandatory, but booties help a lot for short-haired breeds and anyone walking on heavily salted sidewalks. If your dog won't tolerate boots, a paw balm applied before the walk and a quick wipe-down after work almost as well.",
  },
  {
    q: "How do I clean my dog's paws after a winter walk?",
    a: "A damp towel kept by the door is usually enough — wipe each paw and check between the pads for small ice balls or salt crystals, which can be uncomfortable if left in place. A quick rinse in the sink works too if your dog tolerates it.",
  },
  {
    q: "Is sidewalk salt actually dangerous for dogs?",
    a: "Rock salt and ice-melt chemicals can irritate or dry out paw pads, and licking a lot of it off can upset a dog's stomach. It's rarely an emergency, but it's easy to avoid by wiping paws after every walk and choosing cleared sidewalks when you can.",
  },
  {
    q: "How short should winter walks be?",
    a: "There's no single number that fits every dog — it depends on size, coat and the actual temperature that day. Watch your dog instead of the thermometer: lifting paws, shivering or reluctance to keep walking means it's time to head home, even if the walk was short.",
  },
  {
    q: "Can I hire someone to walk my dog on the coldest days?",
    a: "Yes. A verified walker can take care of a quick midday walk on the days you'd rather not go out yourself, with the route logged in the app so you know it happened.",
  },
];

export default function ArticleNycWinterDogWalks() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        mainEntityOfPage: URL,
        datePublished: "2026-11-15",
        image: { "@type": "ImageObject", url: COVER, width: 1200, height: 630 },
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com" },
      },
      { "@type": "FAQPage", mainEntity: FAQ.map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })) },
    ],
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">Practical guide · New York</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Walking your dog in an NYC winter: salt, cold and short walks
      </h1>
      <Image
        src="/blog/nyc-winter-dog-walks.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        A New York winter is harder on a dog's paws than most owners expect —
        not just the cold, but what's spread on the sidewalk underneath it.
        A few habits make the difference between a dog that dreads the walk
        and one that's genuinely fine with it.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Why sidewalk salt is harder on paws than it looks</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Rock salt and ice-melt chemicals are everywhere on NYC sidewalks from
        the first freeze onward, and they sit directly on the surface a dog's
        paw pads touch with every step. Over a winter, that can dry out or
        crack the pads, and a dog that licks its paws afterward can end up
        with an upset stomach from the salt itself. The fix is simple: wipe
        paws with a damp towel after every walk, check between the pads for
        small ice balls, and apply a paw balm before heading out if your dog
        tolerates it.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">How cold is too cold</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        There's no single temperature that applies to every dog — a small,
        short-haired or senior dog feels the cold much faster than a large,
        double-coated breed, and wind chill between buildings can make a
        walk feel colder than the number on your phone suggests. Watch your
        dog instead of the forecast: lifting a paw off the ground, shivering,
        or suddenly refusing to keep walking are the real signs it's time to
        turn back, whatever the thermometer says.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Shorter, more frequent walks beat one long one</h2>
      <ul className="mt-4 space-y-2">
        {[
          "Split one long winter walk into two or three shorter outings instead, especially on the coldest days.",
          "A sweater or coat genuinely helps short-haired and small breeds stay out comfortably for longer.",
          "Stick to cleared sidewalks when you can, and avoid frozen puddles or visible black ice.",
          "Keep the leash a bit shorter near icy patches so you can control the pace if your dog starts to slip.",
          "Bring your dog in to warm up between walks rather than leaving it in a cold hallway or on a fire escape.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Handling ice and frozen sidewalks safely</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Corners and curb cuts tend to collect the most ice, since meltwater
        refreezes there overnight. Slow down on these spots rather than
        letting your dog pull ahead, and give wide berth to anything that
        looks like black ice rather than testing it. If your dog has slipped
        before on a particular stretch, it's worth rerouting even if it adds
        a block or two to the walk.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">When a dog walker can help on the coldest days</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Not every owner wants to brave a freezing midday walk between meetings,
        and that's exactly where a verified walker helps — a quick, logged
        walk at the time your dog actually needs it, whatever the weather.
        See every borough on our{" "}
        <Link href="/pet-sitting/new-york#districts" className="font-semibold text-owner underline">New York pet sitting page</Link>.
        If you're weighing a dog walker against a daycare for the winter months,
        our guide to{" "}
        <Link href="/blog/dog-boarding-vs-pet-sitting" className="font-semibold text-owner underline">dog boarding vs. pet sitting</Link>{" "}
        breaks down the difference. Curious what the job looks like from a walker's side?
        Start with{" "}
        <Link href="/blog/dog-walker-jobs-nyc" className="font-semibold text-owner underline">dog walker jobs in NYC</Link>.
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
        <h2 className="font-display text-2xl font-extrabold text-ink">Find a dog walker for the coldest days</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">Verified profiles, secure in-app payment, across all five boroughs.</p>
        <Link href="/pet-sitting/new-york" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Find a dog walker in New York
        </Link>
      </div>
    </div>
  );
}
