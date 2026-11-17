import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 2026-W38 — SEO US : Austin, angle PROPRIÉTAIRES (semaine ISO paire). Ville
// en rotation (index 6/8), données reprises de lib/recruit-cities.ts (austin).
const URL = "https://www.hopetsit.com/blog/finding-a-pet-sitter-in-austin";
const TITLE = "Dog Sitting Daily Rate in Austin, TX (2026): Day & Overnight";
const DESCRIPTION =
  "Daily rate for dog sitting in Austin: $30–45 for daytime sitting, $40–55 overnight, $15–25 a walk. What a day, a night and a drop-in visit cover, and how to pay safely.";
const COVER = "https://www.hopetsit.com/blog/finding-a-pet-sitter-in-austin.jpg";
const COVER_ALT = "A puppy on a leash outdoors, cover of the guide to dog sitting rates in Austin";

export const metadata: Metadata = {
  // 01/10/2026 — GUS : 197 impressions sur « dog sitting » en position 6,7
  // et 0 clic en 28 j. Titre et description réécrits pour répondre à la
  // requête (prix, comment choisir) au lieu de l'ancien titre « Finding… ».
  // 06/11/2026 — GUS : « daily rate for dog sitting » 33 affichages en
  // position 8,5 (page 1), 0 clic ; « 24 hour pet sitting rates » 20 aff.
  // Titre + description reprennent les mots de la recherche et les chiffres
  // du tableau (jour / nuit / balade), rien d'autre ne change.
  // 16/11/2026 — GUS : Search Console 28 j USA, 657 affichages, 0 clic, 7e-13e place sur
  // « daily rate for dog sitting », « dog sitting per day », « pet sitting per day »,
  // « dog sitting overnight rates », « drop in pet sitting rates ». La page était courte
  // (un tableau de 3 lignes) : sections ajoutées (par jour / par nuit / visite / 24 h,
  // calcul d'un séjour, ce qui fait bouger le prix, questions à poser) + image propre.
  // AUCUN chiffre nouveau : seuls les tarifs déjà publiés ici sont repris. Titre inchangé.
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
    q: "What is the daily rate for dog sitting in Austin?",
    a: "Daytime dog sitting with no overnight typically runs $30 to $45 a day in Austin. If the sitter also stays the night, expect $40 to $55. A single 30-45 minute walk runs $15 to $25.",
  },
  {
    q: "How much is overnight dog sitting in Austin?",
    a: "An overnight stay typically runs $40 to $55 a night in Austin. The evening walk, the night and the morning routine are normally part of that price — confirm it with the sitter before you book.",
  },
  {
    q: "What does a drop-in visit cost?",
    a: "A drop-in is a short visit — food, water, a quick break outside — rather than a full day. It is priced per visit, and each sitter sets their own price, so ask for the per-visit amount and how long the visit lasts. As a reference point, a 30-45 minute walk in Austin runs $15 to $25.",
  },
  {
    q: "How much does a dog sitter cost in Austin?",
    a: "Expect $30 to $55 per day for in-home sitting, and $15 to $25 for a single walk. Overnight stays or multi-day bookings often come with a small discount after the first day.",
  },
  {
    q: "Should I meet the sitter before booking?",
    a: "Yes, always. A short meet-and-greet, in person or on video, lets you check that your dog is comfortable and hand over the essentials: feeding schedule, meds, and how they behave around other dogs.",
  },
  {
    q: "Is it safe to pay a pet sitter in advance?",
    a: "Only through a platform that holds the payment until the job is done. On HoPetSit, the booking is paid securely in the app, but the sitter isn't paid out until your pet is safely returned to you.",
  },
  {
    q: "How do I know my dog actually got walked?",
    a: "Live GPS tracking (PawFollow) shows the walk happening in real time on a map, with route and duration — not just a text saying 'all good'.",
  },
  {
    q: "What if I need a sitter last minute?",
    a: "Austin is growing faster than the number of sitters available, so demand spikes around SXSW, ACL and holiday weekends. Book a few days ahead when you can, and check a sitter's actual availability calendar before messaging.",
  },
];

export default function ArticleFindingSitterAustin() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Dog sitting rates in Austin, TX: per day, overnight and per visit",
        description: DESCRIPTION,
        inLanguage: "en-US",
        mainEntityOfPage: URL,
        dateModified: "2026-11-16",
        image: { "@type": "ImageObject", url: COVER, width: 1200, height: 630 },
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
      <p className="text-sm font-semibold text-owner">Owner's guide · Austin, TX</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Dog sitting rates in Austin, TX: per day, overnight, and how to find a sitter you trust
      </h1>
      <Image
        src="/blog/finding-a-pet-sitter-in-austin.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Austin is one of the most dog-friendly cities in the country — and
        one of the fastest-growing, which means the number of dogs is
        outpacing the number of reliable sitters. Here's what to actually
        check before you hand over your leash for a weekend, a workday, or a
        two-week trip.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Daily rate for dog sitting in Austin
      </h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Service</th>
              <th className="p-4 font-bold">Typical rate</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Single walk (30-45 min)</td>
              <td className="p-4">$15 – $25</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Daytime sitting, no overnight</td>
              <td className="p-4">$30 – $45</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Overnight sitting</td>
              <td className="p-4">$40 – $55</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        Prices run a bit higher close to downtown, Zilker and South Congress,
        and drop slightly further out. Multi-day bookings usually get a small
        discount past the first day — always ask upfront, not after.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Per day, per night, per visit: which rate applies to you
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Sitters in Austin quote in three different units, and most price
        confusion comes from comparing one unit with another. Start from your
        dog's actual day, then pick the line that matches.
      </p>
      <div className="mt-5 space-y-4">
        {[
          {
            t: "You work long days and come home at night",
            d: "That is the per-day rate ($30 – $45): meals, walks and company while you are out. Your dog still sleeps at home with you, so no night is billed.",
          },
          {
            t: "You are away for a weekend or a trip",
            d: "That is the overnight rate ($40 – $55 a night): someone is with your dog in the evening, through the night and for the morning routine. Count nights, not days.",
          },
          {
            t: "Your dog only needs a break in the middle of the day",
            d: "That is a walk ($15 – $25 for 30-45 minutes) or a shorter drop-in visit, priced per visit. Two visits a day can cost as much as a full day of sitting — worth checking before you choose.",
          },
          {
            t: "Your dog cannot be left alone at all",
            d: "Puppies, seniors and dogs on a strict medication schedule may need someone there around the clock. There is no standard 24-hour rate: ask the sitter for a single total covering the whole stay.",
          },
        ].map((c) => (
          <div key={c.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{c.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{c.d}</p>
          </div>
        ))}
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Working out the cost of a whole stay
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Take a Friday-evening-to-Sunday-evening trip. That is two nights, so
        at Austin&apos;s typical overnight rate you are looking at two times
        $40 – $55, before any multi-day discount the sitter may offer. A
        Monday-to-Friday work week with no overnight is five days at the
        daytime rate instead. Writing it out this way — number of nights,
        number of days, number of extra walks — is the quickest way to see
        whether two quotes are really describing the same job.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        The same method works anywhere in Texas; for the Dallas-Fort Worth
        side, see our guide to{" "}
        <Link href="/blog/how-much-does-a-pet-sitter-cost-in-dallas" className="font-semibold text-owner underline">
          dog sitter rates in Dallas
        </Link>
        .
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        What pushes an Austin quote up or down
      </h2>
      <ul className="mt-4 space-y-2">
        {[
          "Event weeks: SXSW, ACL and holiday weekends are when sitters are booked first. Ask early and expect less room to negotiate.",
          "Summer heat: midday walks get shorter and move to early morning or evening, which can change how a sitter organizes — and prices — the day.",
          "A second pet: two dogs in the same home usually cost more than one, but less than two separate bookings.",
          "Special care: a puppy that is not house-trained yet, a senior dog, or medication on a fixed schedule all take more of the sitter's time.",
          "The drive: a sitter in your own part of town has less travel to factor in than one crossing the city at rush hour.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Five questions to ask before you agree on a price
      </h2>
      <ol className="mt-4 list-decimal space-y-2 pl-5 leading-relaxed text-ink-muted">
        <li>Is this price per day, per night or per visit — and what time does each one start and end?</li>
        <li>How many walks are included, and how long is each?</li>
        <li>Is there an extra charge for a second pet, for medication or for a holiday date?</li>
        <li>Will my dog be alone at any point, and for how long?</li>
        <li>What is the total for my exact dates?</li>
      </ol>
      <p className="mt-4 leading-relaxed text-ink-muted">
        On HoPetSit each sitter sets their own price, and you see the full
        amount before you confirm anything. New to the idea? Our guide to{" "}
        <Link href="/blog/what-is-dog-sitting" className="font-semibold text-owner underline">
          what dog sitting includes
        </Link>{" "}
        explains each format in plain English.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        How to actually vet a sitter
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A nice profile photo tells you nothing. Look for reviews tied to
        completed bookings, not just star ratings with no context, and
        prioritize sitters close enough to your neighborhood — a 20-minute
        drive across I-35 during rush hour is not "nearby." If you're
        weighing a sitter against a boarding facility, we compared both
        options{" "}
        <Link href="/blog/dog-boarding-vs-pet-sitting" className="font-semibold text-owner underline">
          honestly, price by price
        </Link>.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Before you book, do a short meet-and-greet — in person if you can,
        video call if you can't. Hand over the real details: feeding
        schedule, any meds, how your dog reacts to other dogs at the dog
        park. It takes fifteen minutes and it's the single best predictor of
        how the actual stay will go.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Payment and proof, not just promises
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Never pay a sitter in full, in cash, before the service happens —
        it's the single easiest way to get burned. On HoPetSit, payment is
        secured in the app the moment a booking is confirmed, and it's only
        released to the sitter once your dog is back with you. Every walk
        can be tracked live on the map with PawFollow, so "he had a great
        walk" comes with an actual route and duration attached, not just a
        text.
      </p>

      {/* 31/10/2026 (GUS) — « cat sitting » 1 730 affichages US en 7 j, 20e place, 0 clic : lien contextuel vers le guide cat sitting */}
      <p className="mt-4 leading-relaxed text-ink-muted">
        Looking for someone to visit a cat rather than walk a dog? Read <Link href="/blog/what-is-cat-sitting" className="font-semibold text-owner underline">what cat sitting means and how it works</Link> before you book.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Questions Austin owners actually ask
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
          Find a verified sitter in Austin
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Verified profiles, real reviews, secure in-app payment and live GPS
          tracking on every walk.
        </p>
        <Link
          href="/pet-sitting/austin"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          See sitters in Austin
        </Link>
        <p className="mt-4 text-sm text-ink-muted">
          Elsewhere in Texas?{" "}
          <Link href="/pet-sitting/dallas" className="font-semibold text-owner underline">
            Dog sitters in Dallas
          </Link>
          {" "}— Uptown, Lakewood, Plano and Frisco.
        </p>
        {/* 18/10 (GUS) — Search Console 28 j : « dog sitting » = 0 clic sur
            Los Angeles (167 aff.), San Francisco (108), New York (77), Boston
            (33), pages classées 22e-26e. Cet article, lui, est classé ~7e sur
            la même requête : il relie ces pages avec l'ancre exacte. */}
        <p className="mt-3 text-sm text-ink-muted">
          Not in Texas? HoPetSit also lists{" "}
          <Link href="/pet-sitting/los-angeles" className="font-semibold text-owner underline">dog sitting in Los Angeles</Link>,{" "}
          <Link href="/pet-sitting/san-francisco" className="font-semibold text-owner underline">San Francisco</Link>,{" "}
          <Link href="/pet-sitting/new-york" className="font-semibold text-owner underline">New York</Link> and{" "}
          <Link href="/pet-sitting/boston" className="font-semibold text-owner underline">Boston</Link>
          {" "}— and a plain-English guide to{" "}
          <Link href="/blog/what-is-dog-sitting" className="font-semibold text-owner underline">how dog sitting works</Link>
          .
        </p>
      </div>
    </div>
  );
}
