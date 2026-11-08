import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 08/11/2026 (GUS) — ordre de Daniel : « SEO blog gratuit Hollande, j'ai des inscrits ». Premier article du
// 5e pôle (Pays-Bas), en anglais : le site n'a pas de néerlandais et les Néerlandais lisent l'anglais.
// Mesuré ce jour : 10 inscrits NL (gardiens et promeneurs, 0 propriétaire), Search Console NL 28 j :
// 5 clics / 127 affichages. Aucun prix, aucun chiffre inventé, aucune promesse de « gardiens à côté ».
// Relié aux 4 pages villes NL existantes (/pet-sitting/amsterdam, rotterdam, utrecht, the-hague).
const URL = "https://www.hopetsit.com/blog/cat-sitting-amsterdam-holidays";
const IMG = "https://www.hopetsit.com/blog/cat-sitting-amsterdam-holidays.jpg";
const TITLE = "Cat Sitting in Amsterdam Over the Holidays: Home Visits, Keys and Fireworks";
const DESCRIPTION =
  "Going away from Amsterdam for Sinterklaas, Christmas or New Year? Why a cat sitter who visits your home beats a cattery, how to handle keys in a canal-house apartment, what a visit covers, and how to get your cat through the New Year's Eve fireworks.";
const HEADLINE = "Cat sitting in Amsterdam over the holidays: home visits, keys and fireworks";
const COVER_ALT = "A cat at home, cover of the Amsterdam holiday cat sitting guide";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  alternates: { canonical: URL },
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    url: URL,
    type: "article",
    locale: "en_GB",
    siteName: "HoPetSit",
    images: [{ url: IMG, width: 1200, height: 630, alt: COVER_ALT }],
  },
};

const FAQ = [
  {
    q: "Cattery (dierenpension) or a cat sitter at home: which is better for an Amsterdam cat?",
    a: "For most indoor cats, a sitter who comes to your home. Cats bond with their territory; a carrier ride and a strange pension with other animals is more stress than staying home with a visitor once or twice a day. A pension makes sense mainly for a cat that needs constant medical supervision.",
  },
  {
    q: "How many visits a day does my cat need while I'm away?",
    a: "One visit a day is usually enough for a healthy adult cat over a long weekend, with enough food and water left out. For a trip of a week or more, a kitten, a senior cat or one on medication, ask for two visits a day.",
  },
  {
    q: "How does the sitter get into my apartment if there is no concierge?",
    a: "Hand over a spare key at a first meeting, leave it with a neighbour you trust, or use a lockbox. Agree on it in the app chat before you book, and only with a sitter whose identity has been verified.",
  },
  {
    q: "What about the fireworks on New Year's Eve?",
    a: "Ask the sitter to come in the late afternoon of 31 December: curtains closed, a radio or TV on low, the cat's favourite hiding place left free, and no open windows. A visit on the morning of 1 January to check that everything is fine is worth adding.",
  },
  {
    q: "Can I leave my cat alone for a weekend with no visit at all?",
    a: "A healthy adult cat can manage 24 to 36 hours with food and water left out, but not more. Beyond that a daily visit is needed for the litter box, the water and simply to check the cat is well.",
  },
];

export default function ArticleCatSittingAmsterdamHolidays() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en",
        mainEntityOfPage: URL,
        image: { "@type": "ImageObject", url: IMG, width: 1200, height: 630 },
        datePublished: "2026-11-08",
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: {
          "@type": "Organization",
          name: "HoPetSit",
          url: "https://www.hopetsit.com",
          logo: { "@type": "ImageObject", url: "https://www.hopetsit.com/logo.png" },
        },
      },
      { "@type": "FAQPage", mainEntity: FAQ.map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })) },
    ],
  };

  const Bullet = ({ t }: { t: string }) => (
    <li className="flex gap-2 leading-relaxed text-ink-muted">
      <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
      <span>{t}</span>
    </li>
  );

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">Practical guide · Amsterdam · Netherlands</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Cat sitting in Amsterdam over the holidays: home visits, keys and fireworks
      </h1>
      <Image
        src="/blog/cat-sitting-amsterdam-holidays.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Sinterklaas with the family in Brabant, Christmas abroad, a week of skiing in
        February: the Dutch holiday calendar is generous, and the cat does not come
        along. If you live in Amsterdam, the question is not so much where your cat
        goes, but who comes to it. This guide is for owners who want the cat to stay
        home, and need the practical side sorted: visits, keys, stairs, and the one
        night of the year every cat in the Netherlands dreads.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Why most Amsterdam cats should stay home</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A cat is attached to its territory at least as much as to its people. The
        smell of its own sofa, the hiding spot under the bed, the view from the
        windowsill onto the canal or the courtyard: all of that disappears in a
        dierenpension, however caring the staff. Add the carrier ride and the other
        animals, and the pension is usually more stressful than a few days alone with
        a visitor. That is why the default, for a healthy indoor cat, is a cat sitter
        who comes to your home once or twice a day. The pension remains the right
        choice for a cat that needs constant medical supervision.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Keys, stairs and the neighbour: access in an Amsterdam apartment</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Very few Amsterdam buildings have a concierge. Most of us live up a steep
        staircase in a canal house in the Jordaan or De Pijp, in a portiekwoning in
        Oud-West or Oost, or in a newer block in Noord or on the Zuidas with an
        intercom and a fob. The sitter needs a way in, and you need to be able to
        trace it. Three solutions work: a spare key handed over at a first meeting
        (the chance to show the cat&apos;s habits too), a neighbour you trust who hands
        the key over on the day, or a lockbox fixed inside the entrance or on the
        door. Skip the key under the mat. Agree on the method in the app chat before
        you book, and only share access with a sitter whose identity has been
        verified. If your building has a shared front door and a second door
        upstairs, say so: two keys, two locks, and a sitter who finds out on the
        first evening is a sitter who cannot feed your cat.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What a good visit covers</h2>
      <ul className="mt-4 space-y-2">
        <Bullet t="Fresh water and the usual food, and a check that the cat is eating and behaving normally." />
        <Bullet t="The litter box scooped at every visit; a full box is the fastest way to upset a cat that is already alone." />
        <Bullet t="Play or a quiet sit nearby if the cat is sociable, left in peace if it prefers to hide the first days." />
        <Bullet t="Medication on the written schedule you left, never from memory." />
        <Bullet t="Windows and the balcony door checked, especially in a canal house where a tilted window is a cat-sized gap." />
        <Bullet t="A photo or a short message in the app after each visit, so you know it happened." />
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">How many visits, and for how long</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        For a long weekend, one visit a day is enough for a healthy adult cat, with a
        full water bowl and dry food left out. For the Christmas holidays, when many
        of us are away a week or two, ask for two visits a day, or at least a longer
        single visit; the same for a kitten, a senior cat or one on medication. Two
        cats are easier than one: they keep each other company, but they need a
        second litter box. If in doubt, your own vet knows your cat&apos;s temperament
        better than any guide.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">New Year&apos;s Eve: the fireworks plan</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Fireworks are loud across the Netherlands on 31 December, even in cities that
        have restricted them, and they start in the afternoon. If you are away that
        night, plan a visit for the late afternoon: curtains closed, a radio or TV on
        low to cover the bangs, the cat&apos;s favourite hiding place left free (do not
        shut the wardrobe), food and water close to it, and every window locked. A
        cat that panics does not need to be comforted at all costs: it needs a dark,
        quiet corner it can reach. A short visit on the morning of 1 January to check
        that all is well, and to clean up if the cat was sick from stress, is worth
        adding to the request. Tell the sitter in advance how your cat reacted last
        year.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Before you leave: a short checklist</h2>
      <ul className="mt-4 space-y-2">
        <Bullet t="Litter box cleaned the morning you leave, a second box if you have two cats or are away more than a week." />
        <Bullet t="Your vet's details and the nearest emergency clinic written down where the sitter will see them." />
        <Bullet t="A note with your cat's habits: hiding spots, what calms it, any treatment, what it must not eat." />
        <Bullet t="Heating set to a steady low temperature; an old Amsterdam apartment gets cold fast in January." />
        <Bullet t="The access plan agreed a few days ahead, never the morning you leave." />
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Finding a cat sitter in Amsterdam, Rotterdam, Utrecht or The Hague</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        HoPetSit is a Europe-wide app, available in the Netherlands in English: you
        post a request with your dates and the number of visits you want, sitters who
        offer cat visits reply, you chat first, read the profile and the reviews, and
        the amount stays in the app until the visits are done. Each sitter sets their
        own rate, so compare a few profiles rather than assuming one price. HoPetSit
        is new in the Netherlands and the number of sitters varies from one
        neighbourhood to the next, so post your request early for the Christmas
        holidays. Start from the city page:{" "}
        <Link href="/pet-sitting/amsterdam" className="font-semibold text-owner underline">pet sitting in Amsterdam</Link>,{" "}
        <Link href="/pet-sitting/rotterdam" className="font-semibold text-owner underline">Rotterdam</Link>,{" "}
        <Link href="/pet-sitting/utrecht" className="font-semibold text-owner underline">Utrecht</Link> or{" "}
        <Link href="/pet-sitting/the-hague" className="font-semibold text-owner underline">The Hague</Link>.
        New to the idea? Read{" "}
        <Link href="/blog/what-is-cat-sitting" className="font-semibold text-owner underline">cat sitting explained</Link>.
        And if you are the one who loves cats and has time over the holidays, you can{" "}
        <Link href="/become-a-pet-sitter/amsterdam" className="font-semibold text-owner underline">become a cat sitter in Amsterdam</Link>.
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
        <h2 className="font-display text-2xl font-extrabold text-ink">Your cat stays home for the holidays</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">Post your dates for free, chat with sitters who do home visits in Amsterdam, and pay in the app only when you book.</p>
        <Link href="/pet-sitting/amsterdam" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Find a cat sitter in Amsterdam
        </Link>
      </div>
    </div>
  );
}
