import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 2026-W45 (weekly marketing routine, Sunday) — next unchecked topic from
// `marketing/sujets_4poles.md` § New York (pillar page /pet-sitting/new-york#districts).
// No prices invented: sitters set their own rates, we point to profiles instead
// of quoting a number for a service (cat visits) with no published median.
const URL = "https://www.hopetsit.com/blog/cat-sitting-nyc-apartment";
const TITLE = "Cat Sitting in a New York Apartment: Drop-Ins, Keys and Doormen";
const DESCRIPTION =
  "Cat sitting in a NYC apartment: why most cats are better off staying home, how to solve building access (doorman, keys, lockbox), and what a drop-in visit should cover.";
const COVER = "https://www.hopetsit.com/blog/cat-sitting-nyc-apartment.jpg";
const COVER_ALT = "A dog and a cat at home by the window, cover of the guide to cat sitting in a New York apartment";
const HEADLINE = "Cat sitting in a New York apartment: drop-ins, keys and doormen";

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
    q: "Should I board my cat or get a drop-in sitter instead?",
    a: "For most apartment cats, a drop-in sitter who comes to your home is the better choice. Cats bond with their territory more than with a new place, and a car ride plus an unfamiliar apartment usually causes more stress than staying home with a familiar sitter.",
  },
  {
    q: "How many visits a day does my cat need?",
    a: "One visit a day is usually enough for a healthy adult cat over a two- to three-day trip, as long as there's enough food and water left out. For longer trips, or for a kitten or senior cat, two visits a day is safer.",
  },
  {
    q: "My building has a doorman — do I still need to set anything up?",
    a: "Yes. Add the sitter's name to your building's visitor or service list ahead of time, and tell the front desk which apartment and which days. Some buildings require ID at the desk every visit, so make sure your sitter knows that before the first stop.",
  },
  {
    q: "What if I'm in a walk-up with no doorman?",
    a: "A lockbox on the door, or a trusted neighbor who hands off a spare key before you leave, are the two most common solutions. Avoid leaving a key under a mat; pick a traceable handoff, and only with a sitter whose identity has been verified.",
  },
  {
    q: "Can my cat be left alone for a full weekend with no visit?",
    a: "24 to 36 hours at most, with food and water left out, and only for a healthy adult cat. Beyond that, a daily visit is still needed for the litter box and to check everything is fine.",
  },
];

export default function ArticleCatSittingNycApartment() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        mainEntityOfPage: URL,
        datePublished: "2026-11-08",
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
        Cat sitting in a New York apartment: drop-ins, keys and doormen
      </h1>
      <Image
        src="/blog/cat-sitting-nyc-apartment.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        No yard, no litter box in the hallway, and a cat that has never lived
        anywhere else: that is most cats in New York City apartments. Before
        you book anything for your next trip, the real question isn&apos;t
        the price — it&apos;s who moves. Your cat, or just the person who
        comes to feed it?
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Why most apartment cats are better off at home</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Unlike dogs, cats bond with a place at least as much as with a
        person. The smell of their own furniture, their favorite hiding spot
        under the bed, the familiar sounds of the building: all of that
        disappears the moment you move them somewhere new. A carrier ride, an
        unfamiliar apartment, sometimes other animals already there — boarding
        stacks up stress even with a caring sitter. That's why most cat
        behaviorists recommend keeping cats at home by default, with someone
        coming to them instead.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Doorman, keys, or a lockbox: solving access</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        In New York, the part that actually trips people up isn&apos;t the
        cat — it&apos;s the door. If your building has a doorman, add your
        sitter&apos;s name to the visitor or service list ahead of time, and
        tell the front desk the apartment number and the exact dates; some
        buildings ask for ID at every visit, so give your sitter a heads up.
        In a walk-up with no doorman, the two most common fixes are a lockbox
        mounted on the door, with the code shared only on the day, or a
        trusted neighbor who hands off a spare key before you leave. Skip
        leaving a key under the mat — pick a handoff you can trace, and only
        with a sitter whose identity has been verified first.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What a drop-in visit should actually cover</h2>
      <ul className="mt-4 space-y-2">
        {[
          "Fresh food and water, and a check that your cat is eating and acting normally.",
          "Scooping the litter box every visit — a full box is the fastest way to stress a cat that's already alone.",
          "A few minutes of play or attention if your cat is sociable, skipped if it prefers to hide.",
          "Any medication on the schedule you wrote down, not guessed from memory.",
          "A quick photo or message sent through the app so you know the visit actually happened.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">How many visits a day</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        One visit a day is usually enough for a healthy adult cat over a two-
        to three-day trip, as long as food and water are left out in enough
        quantity. For longer trips, a kitten, a senior cat, or one on
        medication, two visits a day is the safer call. If you're not sure
        which your cat needs, your regular vet knows its temperament better
        than any guide — ask before you book.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Before you leave: a short checklist</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Clean the litter box right before you go, and set out a second box if
        you have more than one cat. Write down your vet's contact info and a
        weekend clinic in case something comes up. Note your cat's habits —
        favorite hiding spots, anything that calms it down, any ongoing
        treatment — so a new sitter isn't guessing. And share your access plan
        (doorman, lockbox code, or neighbor) a few days ahead, never the
        morning you leave.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Find a sitter who knows your building type</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Doorman buildings, walk-ups, elevator buildings with strict visitor
        logs: experienced New York sitters have seen all of it. Rates are set
        by each sitter, so compare a few profiles in your neighborhood rather
        than assuming one price fits every building. See every borough on our{" "}
        <Link href="/pet-sitting/new-york#districts" className="font-semibold text-owner underline">New York pet sitting page</Link>.
        If your cat also needs a dog walked in the same home, our guide to{" "}
        <Link href="/blog/dog-runs-in-nyc" className="font-semibold text-owner underline">NYC dog runs</Link>{" "}
        covers that side. New to the idea of drop-in care altogether? Start with{" "}
        <Link href="/blog/what-is-cat-sitting" className="font-semibold text-owner underline">cat sitting explained</Link>.
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
        <h2 className="font-display text-2xl font-extrabold text-ink">Find a cat sitter who knows your building</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">Verified profiles, secure in-app payment, across all five boroughs.</p>
        <Link href="/pet-sitting/new-york" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Find a cat sitter in New York
        </Link>
      </div>
    </div>
  );
}
