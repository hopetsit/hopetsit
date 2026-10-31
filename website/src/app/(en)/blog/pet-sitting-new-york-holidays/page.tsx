import type { Metadata } from "next";
import Link from "@/components/SiteLink";

// 31/10/2026 (GUS) — Daniel's 31/10 brief: SEO on 4 hubs (Paris + Europe, New York, Seoul,
// Tokyo), one article per city. Seasonal owner guide for New York (Thanksgiving 26/11/2026,
// Christmas, New Year), distinct from the two NYC recruiting articles. No prices, no stats:
// each sitter sets their own rate in the app.
const URL = "https://www.hopetsit.com/blog/pet-sitting-new-york-holidays";
const TITLE = "Pet Sitting in New York over Thanksgiving & the Holidays";
const DESCRIPTION =
  "Leaving NYC for Thanksgiving, Christmas or New Year's? When to book a pet sitter, drop-ins vs overnight stays, winter walks, rock salt and fireworks, and what to leave your sitter.";
const HEADLINE = "Pet sitting in New York over Thanksgiving, Christmas and New Year's: a practical guide";

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
    q: "When should I book a pet sitter for Thanksgiving in NYC?",
    a: "As early as you can. Thanksgiving falls on Thursday, November 26 in 2026, and a lot of New Yorkers leave the city the same Wednesday. Posting your request in early November gives you more replies and time for a meet-and-greet with your pet.",
  },
  {
    q: "Drop-in visits or an overnight sitter?",
    a: "Most dogs need someone overnight or a stay at the sitter's home: they can't hold it for long and they don't like being alone at night. An adult cat often does well with one or two drop-in visits a day, as long as the trip is short.",
  },
  {
    q: "How much does holiday pet sitting cost in New York?",
    a: "There is no single price: it depends on the format (walks, drop-ins, day care, overnights), the length of your trip and the number of pets. On HoPetSit each sitter sets their own rate and you see the total before you confirm.",
  },
  {
    q: "Does my dog need a license in New York City?",
    a: "Yes. NYC requires dogs to be licensed with the Health Department and to wear their license tag in public. Leave a copy of the license and vaccination records with your sitter.",
  },
  {
    q: "What if my plans change?",
    a: "Message your sitter through the app as soon as you know. HoPetSit offers free cancellation up to 72 hours before the sitting starts.",
  },
];

const OPTIONS = [
  { t: "Overnight at your place", d: "The sitter stays in your apartment. Your dog keeps its routine and its bed, your cat keeps its territory, and someone is home if the radiator acts up." },
  { t: "Stay at the sitter's home", d: "Your dog spends the holidays with a sitter in your neighborhood. Never alone, regular walks, and a real home rather than a kennel." },
  { t: "Drop-in visits", d: "One or two visits a day to feed, refresh water, clean the litter box and play. Usually the right fit for a cat on a short trip." },
  { t: "Dog walks", d: "Staying in town but out all day for family dinners? A walker can take your dog out at midday or in the late afternoon." },
];

export default function ArticleNycHolidays() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        mainEntityOfPage: URL,
        datePublished: "2026-10-31",
        image: { "@type": "ImageObject", url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630 },
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
        Pet sitting in New York over Thanksgiving, Christmas and New Year&apos;s
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Between Thanksgiving and New Year&apos;s, half of New York seems to be on a train, a plane or
        the Turnpike. If you share an apartment with a dog or a cat, the question comes back every
        year: who looks after them while you&apos;re away? Here is how to plan holiday pet sitting in
        the city, from booking early to the small winter details that make a difference.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Book early, then meet</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Holiday dates are the same for everyone, and sitters have families and trips too. Overnight
        stays go first. Posting your request a few weeks ahead means more replies, time to read
        profiles and reviews, and time for the step that matters most: a meet-and-greet. A short walk
        together in your neighborhood tells you more about a sitter than any profile, and your dog
        will already know the person who comes to pick it up.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        In a city of doormen, key fobs and buzzers, sort out access during that meeting too: who
        holds the keys, whether the front desk needs the sitter&apos;s name, and how the package
        room or the elevator works in your building.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Four ways to cover the holidays</h2>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {OPTIONS.map((o) => (
          <div key={o.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{o.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{o.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        Not sure which one fits? Our guides on{" "}
        <Link href="/blog/what-is-dog-sitting" className="font-semibold text-owner underline">dog sitting</Link>{" "}
        and{" "}
        <Link href="/blog/what-is-cat-sitting" className="font-semibold text-owner underline">cat sitting</Link>{" "}
        explain each format in detail.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">New York winter details your sitter should know</h2>
      <ul className="mt-4 space-y-2">
        {[
          "Rock salt and de-icer: sidewalks are salted after every snowfall and it stings paws. Ask your sitter to wipe your dog's paws after each walk, or leave booties or paw balm if your dog uses them.",
          "Shorter, more frequent walks in the cold, especially for small, short-haired or older dogs. A coat by the door saves time.",
          "Park rules: dogs must be leashed in NYC, except during the off-leash hours some parks allow early in the morning and late at night in designated areas. Tell your sitter which spots your dog knows.",
          "Holiday food: chocolate, grapes and raisins, cooked bones and fatty leftovers are dangerous for dogs and cats. Nothing outside the usual food.",
          "Fireworks on New Year's Eve: many dogs panic. An earlier evening walk, a well-fitted harness, closed windows and a quiet corner help.",
          "Decorations: tinsel, ornaments and light cords attract cats. Put them out of reach if a sitter will be staying at your place.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What to leave your sitter</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A one-page note avoids calls during dinner: feeding amounts and times, enough food for the
        whole trip plus a few extra days, medication and doses, your vet&apos;s number and the
        nearest 24-hour animal hospital, a copy of your dog&apos;s NYC license and vaccination
        records, building access details, and the little things that calm your pet down at night.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Find a sitter in your borough with HoPetSit</h2>
      <ol className="mt-4 space-y-3">
        {[
          "Post your request for free: your pet, the exact dates, the format you want and your neighborhood.",
          "Nearby sitters and walkers get your request and reply with their price.",
          "Compare profiles and reviews, chat in the app, and set up a meet-and-greet before you leave.",
          "Pay in the app. Payment is secure and only released to the sitter after the sitting; during walks, PawFollow GPS tracking shows the route live.",
        ].map((t, i) => (
          <li key={t} className="flex gap-3 leading-relaxed text-ink-muted">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-owner text-sm font-bold text-white">{i + 1}</span>
            <span>{t}</span>
          </li>
        ))}
      </ol>
      <p className="mt-6 leading-relaxed text-ink-muted">
        Manhattan, Brooklyn, Queens, the Bronx or Staten Island: see the parks, dog runs and vets of
        your borough on our{" "}
        <Link href="/pet-sitting/new-york#districts" className="font-semibold text-owner underline">New York pet sitting page</Link>.
        Looking after pets yourself over the holidays?{" "}
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
        <h2 className="font-display text-2xl font-extrabold text-ink">Travel with peace of mind this holiday season</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">Overnights, drop-ins and walks across the five boroughs.</p>
        <Link href="/pet-sitting/new-york" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Find a pet sitter in New York
        </Link>
      </div>
    </div>
  );
}
