import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 2026-W40 — SEO US, owner angle (even ISO week), city rotation index 0/8
// (Dallas). Topic #1 from marketing/sujets_us.md — links into the two
// Dallas pages that Search Console still shows as unknown to Google.
// 14/11/2026 (GUS) — Search Console 28 j USA (16/10 → 12/11) : 827 affichages, 0 clic, 22e place.
// Requêtes : « dog sitter rates » (29), « dog sitter cost per day », « dog boarding costs dallas / dfw »
// (14e-20e), « 24 hour pet sitting rates », « compare pet sitting and boarding prices » (7e).
// Titre sur « dog sitter rates », sections ajoutées (ce que couvre chaque tarif, pension vs garde à
// domicile, garde 24 h, ce qui fait varier le prix, comparer deux devis) et image propre.
// AUCUN chiffre nouveau : seuls les tarifs déjà publiés dans l'article sont repris.
const URL = "https://www.hopetsit.com/blog/how-much-does-a-pet-sitter-cost-in-dallas";
const TITLE = "Dog Sitter Rates in Dallas (2026): Per Day, Overnight, Boarding";
const DESCRIPTION =
  "Dog sitter rates in Dallas in 2026: $15-25 a walk, $30-40 a day, $40-55 overnight. What each price covers, sitter vs boarding costs in DFW, and how to compare two quotes.";
const COVER = "https://www.hopetsit.com/blog/how-much-does-a-pet-sitter-cost-in-dallas.jpg";
const COVER_ALT = "Dog at home, cover of the guide to dog sitter rates in Dallas";

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
    q: "How much does a pet sitter cost in Dallas?",
    a: "In-home pet sitting in Dallas typically runs $30 to $55 a day, depending on the neighborhood and whether it includes an overnight stay. A single walk runs $15 to $25.",
  },
  {
    q: "What's the difference between daytime sitting and overnight sitting?",
    a: "Daytime sitting with no overnight tends to land toward the lower end of the $30-55 range, while a full overnight stay — someone actually sleeping at your place or keeping your dog overnight — lands toward the higher end.",
  },
  {
    q: "How much is overnight dog sitting in Dallas?",
    a: "An overnight stay in Dallas typically runs $40 to $55 a night, compared with $30 to $40 for daytime sitting with no overnight. For several nights in a row, ask the sitter about a small discount after the first night.",
  },
  {
    q: "Is boarding cheaper than a pet sitter in Dallas?",
    a: "Not usually. In-home pet sitting generally runs $25-45 a night nationally, while boarding facilities charge $40-85 a night once you add fees for walks, meds or a larger kennel. A sitter also means no new environment and no other animals your pet has to adjust to.",
  },
  {
    q: "What does a 24-hour pet sitter cost in Dallas?",
    a: "There is no single 24-hour rate. A sitter who stays day and night gives up their whole day, so expect a quote above a plain overnight stay. On HoPetSit each sitter sets their own price and you see the total before you confirm.",
  },
  {
    q: "Why do rates vary so much across Dallas?",
    a: "Uptown, Lakewood, Plano and Frisco each have their own supply of sitters. A newer suburb with fewer sitters registered can mean a longer wait or a slightly higher rate than a neighborhood where HoPetSit's community already has regulars.",
  },
  {
    q: "How should I pay a pet sitter safely?",
    a: "Avoid handing over cash for the full amount before the service happens. On HoPetSit, payment is held securely in the app the moment a booking is confirmed and only released to the sitter after your pet is back with you — and every walk can be tracked live on the map with PawFollow.",
  },
];

export default function ArticlePetSitterCostDallas() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: TITLE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        mainEntityOfPage: URL,
        datePublished: "2026-10-04",
        dateModified: "2026-11-14",
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
      <p className="text-sm font-semibold text-owner">Owner's guide · Dallas, TX</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Dog sitter rates in Dallas: what a pet sitter costs per day and overnight
      </h1>
      <Image
        src="/blog/how-much-does-a-pet-sitter-cost-in-dallas.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Uptown, Lakewood, Plano, Frisco: Dallas-Fort Worth is sprawling, hot
        for half the year, and full of dogs with big yards who still need a
        midday walk. Before you book a sitter or a boarding kennel, here's
        what the service actually costs and what changes the price.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Realistic Dallas rates
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
              <td className="p-4">$30 – $40</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Overnight sitting</td>
              <td className="p-4">$40 – $55</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        Rates run a little higher in Uptown and Lakewood, where there's more
        competition for the sitter's time, and a little lower further out in
        Plano or Frisco. Multi-day bookings are usually negotiated with a
        small discount after the first day — always ask upfront.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        What a day rate and an overnight rate actually cover
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Two quotes with the same dollar amount can describe very different
        services. Before comparing prices, check what is inside each one.
      </p>
      <ul className="mt-4 space-y-2">
        {[
          "Per walk: one outing of 30 to 45 minutes, water refilled, a quick note afterwards. Nothing else is implied.",
          "Per day, no overnight: several check-ins or a long daytime stay — meals, walks, play, medication if needed — and your dog sleeps alone at night.",
          "Overnight: the sitter sleeps at your place, or your dog sleeps at theirs. The evening walk, the night and the morning routine are part of the price.",
          "24-hour sitting: someone is there day and night. It is the most demanding format for a sitter, so it is quoted above a plain overnight — ask for one total for the whole stay instead of adding up hours.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Not sure which format your dog needs? Our guide to{" "}
        <Link href="/blog/what-is-dog-sitting" className="font-semibold text-owner underline">
          what dog sitting includes
        </Link>{" "}
        walks through each one.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Pet sitter vs boarding: which costs more?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Nationally, in-home pet sitting runs $25-45 a night, while a boarding
        facility charges $40-85 a night once you add the fees for walks,
        medication or a bigger kennel — and that's before counting the stress
        of a new environment and other animals. We compared both options{" "}
        <Link
          href="/blog/how-much-does-a-dog-walker-cost"
          className="font-semibold text-owner underline"
        >
          price by price in our dog walker cost guide
        </Link>
        . In Dallas's heat, a sitter who can keep your dog on their normal
        schedule, in their own yard, is often worth the extra few dollars a
        day.
      </p>

      <h3 className="mt-8 font-display text-xl font-extrabold text-ink">
        Dog boarding costs vs in-home sitting in DFW: what each price covers
      </h3>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">&nbsp;</th>
              <th className="p-4 font-bold">In-home sitter</th>
              <th className="p-4 font-bold">Boarding kennel</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Where your dog sleeps</td>
              <td className="p-4">At home, or in the sitter's home.</td>
              <td className="p-4">In a kennel or a shared room.</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Walks and playtime</td>
              <td className="p-4">Agreed with the sitter and part of the quote.</td>
              <td className="p-4">Often billed as an add-on.</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Medication</td>
              <td className="p-4">Agreed upfront with the sitter.</td>
              <td className="p-4">Often a separate fee.</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Other animals</td>
              <td className="p-4">None, unless you agree to it.</td>
              <td className="p-4">Other dogs nearby day and night.</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Drop-off and pick-up</td>
              <td className="p-4">None when the sitter comes to you.</td>
              <td className="p-4">Two drives, within opening hours.</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        When you compare a boarding price with a sitter's price, add the
        kennel's extras first — that is the number to put next to the
        sitter's quote.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        What moves a dog sitter's rate up or down
      </h2>
      <ul className="mt-4 space-y-2">
        {[
          "Number of pets: a second dog or a cat in the same home usually adds to the price, but less than a second booking would.",
          "Dates: Thanksgiving, Christmas, spring break and summer weekends fill up first, and sitters price them accordingly.",
          "Your dog: puppies, seniors, large or very energetic dogs, and dogs on medication take more time.",
          "Notice: a request posted the night before leaves you fewer sitters to choose from.",
          "Length of stay: for several days in a row, many sitters agree to a small discount after the first day.",
          "Distance: a sitter a few minutes away has less driving to price in than one crossing DFW.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        How to compare two quotes
      </h2>
      <ol className="mt-4 list-decimal space-y-3 pl-5 leading-relaxed text-ink-muted">
        <li>
          <span className="font-semibold text-ink">Ask for one total for the whole stay.</span>{" "}
          Dates, number of walks, overnight or not — all in one figure, so
          nothing is added later.
        </li>
        <li>
          <span className="font-semibold text-ink">Check what is included.</span>{" "}
          Walks, feeding, medication, photo updates: the cheaper quote is not
          cheaper if half of it is missing.
        </li>
        <li>
          <span className="font-semibold text-ink">Read the reviews, not just the price.</span>{" "}
          A rate far below everyone else's often means a sitter with no
          reviews yet.
        </li>
        <li>
          <span className="font-semibold text-ink">Meet before you book.</span>{" "}
          A short meet-and-greet tells you more than any profile.
        </li>
      </ol>
      <p className="mt-4 leading-relaxed text-ink-muted">
        On HoPetSit you post your dates once, sitters near you answer with
        their own price, and you see the full amount before you confirm.
        Outside Dallas proper, start with{" "}
        <Link href="/pet-sitting/fort-worth" className="font-semibold text-owner underline">
          sitters in Fort Worth
        </Link>
        ,{" "}
        <Link href="/pet-sitting/plano" className="font-semibold text-owner underline">
          Plano
        </Link>{" "}
        or{" "}
        <Link href="/pet-sitting/frisco" className="font-semibold text-owner underline">
          Frisco
        </Link>
        .
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Why rates vary across DFW
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Dallas-Fort Worth isn't one market — it's a dozen suburbs stitched
        together, each with its own supply of sitters. Uptown and Lakewood
        already have a few regulars built up; a newer or fast-growing area
        can mean fewer sitters to choose from and a slightly longer wait for
        a last-minute booking. If you're close to the center, it's worth{" "}
        <Link href="/pet-sitting/dallas" className="font-semibold text-owner underline">
          browsing sitters in Dallas
        </Link>{" "}
        a few days ahead rather than the night before.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Paying safely, not just cheaply
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        The lowest price isn't always the best deal. Avoid handing over cash
        for the full amount before the service happens — it's the easiest
        way to get burned if something goes wrong. On HoPetSit, payment is
        held securely in the app the moment a booking is confirmed, and it's
        only released to the sitter once your pet is safely back with you.
        Every walk can also be tracked live on the map with PawFollow, so
        "he had a great time" comes with an actual route and duration
        attached.
      </p>

      {/* 31/10/2026 (GUS) — « cat sitting » 1 730 affichages US en 7 j, 20e place, 0 clic : lien contextuel vers le guide cat sitting */}
      <p className="mt-4 leading-relaxed text-ink-muted">
        For a cat, the visit format and what drives the price (visits a day, length, medication) are explained in our guide to <Link href="/blog/what-is-cat-sitting" className="font-semibold text-owner underline">cat sitting</Link>.
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
          Find a verified pet sitter in Dallas
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Verified profiles, real reviews, secure in-app payment and live GPS
          tracking on every walk.
        </p>
        {/* 16/10 (SAM, §B.6) — bouton principal = publier la demande (gratuit,
            sans compte), ville pré-remplie ; voir les gardiens en second. */}
        <div className="mt-5 flex flex-col items-center gap-3 sm:flex-row sm:justify-center">
          <Link
            href="/posts/create?city=Dallas&utm_source=blog&utm_medium=article&utm_campaign=dallas_free"
            className="inline-flex min-h-[48px] items-center justify-center rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
          >
            Post your free request
          </Link>
          <Link
            href="/pet-sitting/dallas"
            className="inline-flex min-h-[48px] items-center justify-center rounded-full border-2 border-owner bg-white px-7 py-3 text-sm font-bold text-owner"
          >
            See sitters in Dallas
          </Link>
        </div>
        <p className="mt-4 text-sm text-ink-muted">
          Thinking about sitting instead?{" "}
          <Link
            href="/become-a-pet-sitter/dallas"
            className="font-semibold text-owner underline"
          >
            Become a pet sitter in Dallas
          </Link>
          {" "}— Uptown, Lakewood, Plano and Frisco all need more sitters.
        </p>
      </div>
    </div>
  );
}
