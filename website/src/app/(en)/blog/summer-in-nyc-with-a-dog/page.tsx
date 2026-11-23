import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 2026-W47 (weekly marketing routine, Sunday) — next unchecked topic from
// `marketing/sujets_4poles.md` § New York (pillar page /pet-sitting/new-york#districts).
// Published ahead of the season on purpose (as planned in the W46 report) so
// it has time to rank before summer actually arrives. Mirrors the structure
// of /blog/nyc-winter-dog-walks (same pillar, opposite season) without
// repeating its content. No invented numbers (no made-up "safe" temperature)
// — only the widely known hand-on-pavement test, and no legal claims.
const URL = "https://www.hopetsit.com/blog/summer-in-nyc-with-a-dog";
const TITLE = "Summer in NYC with a Dog: Heat, Hot Pavement and Midday Walks";
const COVER = "https://www.hopetsit.com/blog/summer-in-nyc-with-a-dog.jpg";
const COVER_ALT = "A small curly-haired dog on a leash outdoors, cover of the guide to summer in NYC with a dog";
const DESCRIPTION =
  "Why NYC sidewalks get hotter than the air temperature, how to tell a walk is too hot, and why midday is the wrong time for a city dog walk in summer.";
const HEADLINE = "Summer in NYC with a dog: heat, hot pavement and midday walks";

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
    q: "How do I know if the pavement is too hot for my dog's paws?",
    a: "Press the back of your hand flat on the sidewalk and hold it there. If it's too hot for your hand after five seconds, it's too hot for your dog's paws. Asphalt and dark pavement get hottest, so grass or shaded concrete are safer options when it's available.",
  },
  {
    q: "What time of day is safest for summer walks in the city?",
    a: "Early morning and after sunset are almost always cooler than midday, both for the air and for the pavement itself, which keeps absorbing heat for hours after direct sun hits it. A short walk at 7 a.m. beats a long one at 1 p.m. on a hot day.",
  },
  {
    q: "Which dogs struggle most with NYC summer heat?",
    a: "Flat-faced breeds (pugs, bulldogs, Boston terriers), senior dogs, overweight dogs and dark-coated dogs tend to overheat faster than others. For these dogs, shorter and more frequent outings are safer than one long midday walk.",
  },
  {
    q: "Are dog booties worth it for summer walks?",
    a: "They help on the hottest stretches of pavement, but many dogs resist wearing them. If yours won't tolerate booties, routing around grass, shaded sidewalks and recently hosed-down areas gets you most of the same protection.",
  },
  {
    q: "Can a dog walker help on the hottest days?",
    a: "Yes. A verified walker can take an early-morning or evening walk at the time your dog actually needs it, logged in the app, on the days a midday walk between meetings isn't realistic.",
  },
];

export default function ArticleSummerInNycWithADog() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        mainEntityOfPage: URL,
        datePublished: "2026-11-22",
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
        {HEADLINE}
      </h1>
      <Image
        src="/blog/summer-in-nyc-with-a-dog.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        A New York summer is hard on a city dog in ways that have nothing to
        do with the air temperature on your phone. The sidewalk itself, the
        lack of shade between buildings, and the timing of the walk make most
        of the difference — and all three are easy to get wrong without
        realizing it.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Why hot pavement is the real danger, not just the heat</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Dark asphalt and concrete absorb sun all day and can get far hotter
        than the air above them, especially between buildings where there's
        little shade and heat reflects off glass and brick. A dog's paw pads
        touch that surface with every step, and a burn can happen faster than
        most owners expect. The simple test: press the back of your hand flat
        on the sidewalk for five seconds. If it's too hot for you, it's too
        hot for your dog — route toward grass, shade or recently hosed-down
        pavement instead.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Why midday is the wrong time for a city walk</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Pavement doesn't cool down the moment the sun moves — it keeps
        radiating heat for hours after peak exposure, which is exactly why a
        4 p.m. sidewalk can still be dangerously hot even as the air
        temperature starts dropping. Early morning and after sunset are
        almost always the safer windows, both for the ground and for your
        dog's energy. If a midday walk is unavoidable, keep it short and stick
        to shaded blocks rather than the sunniest, most direct route.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Signs your dog needs to stop and cool down</h2>
      <ul className="mt-4 space-y-2">
        {[
          "Heavy panting that doesn't ease up once you slow down or stop walking.",
          "Lifting paws off the ground, hesitating to keep walking, or trying to pull toward shade.",
          "Excessive drooling, bright red gums or tongue, or sudden lethargy.",
          "Flat-faced breeds, seniors, overweight dogs and dark coats overheat faster than others — watch them more closely.",
          "When in doubt, head indoors or into shade and offer water rather than pushing to finish the walk.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Making the walk itself easier on a hot day</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A collapsible water bowl and a bottle of water make a real difference
        on anything longer than a quick relief break. Favor the shaded side of
        the street, parks with tree cover, and blocks you know have grass
        strips over wide-open, treeless avenues. If your dog tolerates
        booties, they help on the hottest stretches of pavement — if not,
        routing around the worst of it gets you most of the same protection.
        Opposite problem in January? Our guide to{" "}
        <Link href="/blog/nyc-winter-dog-walks" className="font-semibold text-owner underline">
          walking your dog in an NYC winter
        </Link>{" "}
        covers rock salt and icy sidewalks the same way.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">When a dog walker can help on the hottest days</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Not every owner can step out for an early-morning or evening walk
        between work and commuting, and that's exactly where a verified
        walker helps — a cooler, well-timed walk logged in the app instead of
        a rushed midday one in the heat of the day. See every borough on our{" "}
        <Link href="/pet-sitting/new-york#districts" className="font-semibold text-owner underline">New York pet sitting page</Link>.
        Curious what the job looks like from a walker's side? Start with{" "}
        <Link href="/blog/dog-walker-jobs-nyc" className="font-semibold text-owner underline">dog walker jobs in NYC</Link>, or see
        typical rates in our guide to{" "}
        <Link href="/blog/pet-sitting-jobs-new-york" className="font-semibold text-owner underline">pet sitting jobs in New York</Link>.
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
        <h2 className="font-display text-2xl font-extrabold text-ink">Find a dog walker for the hottest days</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">Verified profiles, secure in-app payment, across all five boroughs.</p>
        <Link href="/pet-sitting/new-york" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Find a dog walker in New York
        </Link>
      </div>
    </div>
  );
}
