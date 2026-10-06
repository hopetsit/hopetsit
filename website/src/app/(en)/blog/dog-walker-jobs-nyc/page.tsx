import type { Metadata } from "next";
import Link from "next/link";

// 05/10/2026 (GUS, ordre de Daniel : recruter des prestataires à New York,
// gratuitement). Requête visée : « dog walker jobs nyc » / « how to become a
// dog walker in new york ». Relié à /become-a-pet-sitter/new-york et à
// l'article jumeau /blog/pet-sitting-jobs-new-york. Aucun chiffre d'activité
// inventé, aucune promesse de revenus : tarifs = fourchettes déjà affichées
// sur la page New York ; règle d'argent = code backend (vérifié par FLO le
// 06/10/2026) : 100 % du tarif au promeneur, propriétaire = tarif + 20 %
// (15 % badge Top), libération portefeuille à la confirmation ou 48 h après.

const URL = "https://www.hopetsit.com/blog/dog-walker-jobs-nyc";
const TITLE = "Dog Walker Jobs in NYC: How to Start in New York";
const DESCRIPTION =
  "How to become a dog walker in New York: what owners expect, the leash and park rules to know, where the work is in each borough, and how to get your first clients. Free to join.";
const HEADLINE = "Dog walker jobs in NYC: how to become a dog walker in New York";

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
    q: "Do I need a license to be a dog walker in New York City?",
    a: "HoPetSit does not ask for a certification: you need to be 18 or older, reliable and comfortable with dogs. If you turn dog walking into a full-time business, check the current New York City and New York State rules for businesses and consider liability insurance.",
  },
  {
    q: "How much do dog walkers make in NYC?",
    a: "On HoPetSit, New York walks are usually priced between $20 and $35, and you set your own rate. What you earn depends on how many walks you are booked for. Our guide to pet sitting pay in New York walks through an example week.",
  },
  {
    q: "Can I take a client's dog on the subway?",
    a: "Only if the dog fits in a carrier or bag. That is why most New York dog walkers work in the neighborhood where they live, within walking or biking distance of their clients.",
  },
  {
    q: "Can dogs be off-leash in Central Park or Prospect Park?",
    a: "Only in the areas where it is allowed and during courtesy hours, before 9 a.m. and after 9 p.m. The rest of the time dogs stay leashed. Always ask the owner first whether their dog has reliable recall.",
  },
];

const STEPS = [
  { t: "Create your free walker profile", p: "A real photo, a few honest lines about your experience with dogs (your own dog counts), the neighborhoods you cover and your price per walk." },
  { t: "Verify your identity", p: "It takes a few minutes in the app and adds the ✓ badge owners look for before handing over their keys." },
  { t: "Answer requests near you", p: "Owners close to you contact you in the chat. Meet them and their dog once before the first walk, then accept only what fits your week." },
  { t: "Walk, share, get paid", p: "The walk is shown live on the map to the owner. Payment is made in the app at booking and paid out to you after the service." },
];

export default function ArticleDogWalkerJobsNyc() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        datePublished: "2026-10-05",
        dateModified: "2026-10-05",
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
      <p className="text-sm font-semibold text-sitter-dark">New York · Career guide · October 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">{HEADLINE}</h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Most New York dogs live in apartments, and most of their owners work long days or travel. A dog
        cannot wait nine hours for a walk, so the midday walker is a real part of city life — from the Upper
        West Side to Astoria. If you like dogs, live in the city and have a few free hours on weekdays, here
        is how to start, what owners expect and how to land your first regular clients.
      </p>

      <div className="mt-6 rounded-2xl border border-sitter/25 bg-sitter-light/70 p-4 text-sm leading-relaxed text-ink">
        <strong>Right now:</strong> an owner in Queens has an open pet sitting request on
        HoPetSit and few sitters or walkers live nearby.{" "}
        <Link href="/become-a-pet-sitter/new-york" className="font-semibold text-sitter-dark underline">
          See the New York sitter page
        </Link>
        .
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What the job really is</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A typical New York booking is a 30-minute walk in the middle of a workday: you pick up the dog at the
        owner&apos;s building, walk the usual route, give water, and send a short update. Some owners want the
        same walk every weekday; others need a few walks while they are away for a weekend. Many walkers also
        offer drop-in visits for cats, or day sitting, which fills the gaps in their week.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Reliability matters more than anything else. An owner who finds the same walker at the same time every
        day keeps that walker for months. Being late twice is usually enough to lose a client.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">New York rules every walker should know</h2>
      <ul className="mt-4 space-y-3 text-ink-muted">
        <li className="leading-relaxed"><strong className="text-ink">Leash.</strong> Dogs in New York City must be on a leash in public, and the leash cannot be longer than six feet.</li>
        <li className="leading-relaxed"><strong className="text-ink">Clean up.</strong> Picking up after the dog is the law, and fines apply. Always carry bags — more than you think you need.</li>
        <li className="leading-relaxed"><strong className="text-ink">Off-leash hours.</strong> In many city parks, dogs can be off-leash in designated areas only before 9 a.m. and after 9 p.m. Outside those hours and areas, they stay leashed. Dog runs are the other option during the day.</li>
        <li className="leading-relaxed"><strong className="text-ink">Subway.</strong> Dogs ride the subway only in a carrier or bag, so plan to walk or bike between clients.</li>
        <li className="leading-relaxed"><strong className="text-ink">Weather.</strong> Hot pavement in summer and de-icing salt in winter are hard on paws. Keep noon walks short in July and wipe paws after winter walks.</li>
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Where the work is, borough by borough</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        <strong className="text-ink">Manhattan</strong> is the classic market: doorman buildings, long office
        days, walks in Central Park, Riverside Park or along the Hudson. <strong className="text-ink">Brooklyn</strong>{" "}
        has many dog-owning families in Park Slope, Williamsburg, Greenpoint and Bay Ridge, with Prospect Park
        for early-morning walks. <strong className="text-ink">Queens</strong> — Astoria, Long Island City, Forest
        Hills, Flushing — mixes apartments and houses, and owners there travel and need home sitting as well as
        walks. <strong className="text-ink">The Bronx</strong> has some of the biggest parks in the city, like
        Van Cortlandt and Pelham Bay, and few walkers offering their services. <strong className="text-ink">Staten Island</strong>{" "}
        suits walkers and sitters who live on the island, since most owners there drive.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        The best rule: start where you live. Owners pick the walker who is ten minutes away over someone who
        has to cross two boroughs.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">How to start on HoPetSit</h2>
      <ol className="mt-6 space-y-4">
        {STEPS.map((s, i) => (
          <li key={s.t} className="flex gap-4 rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <div className="grid h-10 w-10 shrink-0 place-items-center rounded-2xl bg-sitter-light text-base font-extrabold text-sitter-dark">{i + 1}</div>
            <div>
              <h3 className="text-base font-bold text-ink">{s.t}</h3>
              <p className="mt-1 text-sm leading-relaxed text-ink-muted">{s.p}</p>
            </div>
          </li>
        ))}
      </ol>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Joining is free and you keep 100% of your rate. When an owner books in the app, they pay your rate plus
        a 20% HoPetSit fee (15% once you have the Top badge): a $20 walk means the owner pays $24 and you
        receive $20. The money is released to your wallet when the owner confirms the walk, or 48 hours after
        its scheduled end, and you then withdraw it to your bank account, as set out in our{" "}
        <Link href="/terms" className="font-semibold text-sitter-dark underline">terms</Link>.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Getting your first clients</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Keep your service area tight and name the streets or parks you know. Write a profile that sounds like
        you: which dogs you are comfortable with, whether you can handle a strong puller, whether you are free
        at lunch every day. Offer a short meet-and-greet before the first walk — fifteen minutes with the owner
        avoids nearly every misunderstanding about routine, keys or the dog&apos;s habits.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        In doorman buildings, the owner usually has to give your name to the front desk before your first
        visit. Settle the key handover in the chat before the booking starts. Your first completed walk is the
        one that matters most: it brings your first review, and owners read reviews before anything else.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Want the numbers? Read{" "}
        <Link href="/blog/pet-sitting-jobs-new-york" className="font-semibold text-sitter-dark underline">
          Pet sitting jobs in New York: how much can you earn?
        </Link>{" "}
        For a general, non-NYC starter guide, see{" "}
        <Link href="/blog/how-to-become-a-dog-walker" className="font-semibold text-sitter-dark underline">
          how to become a dog walker
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

      <div className="mt-14 rounded-3xl bg-sitter-light p-6 text-center md:p-8">
        <h2 className="font-display text-2xl font-extrabold text-ink">Walk dogs in New York</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Free to join. You set your rates, your hours and your neighborhood.
        </p>
        <Link href="/signup?role=walker&city=New%20York" className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white">
          Join as a dog walker
        </Link>
        <p className="mt-3 text-xs text-ink-soft">
          <Link href="/become-a-pet-sitter/new-york" className="underline">Everything about sitting and walking in New York</Link>
        </p>
      </div>
    </div>
  );
}
