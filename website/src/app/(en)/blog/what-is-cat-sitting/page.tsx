import type { Metadata } from "next";
import Link from "@/components/SiteLink";

// 21/10/2026 (GUS) — article de la semaine choisi sur la demande mesurée dans la Search
// Console (28 j, USA, 22/09 → 19/10) : 118 requêtes « cat sitting / cat sitter <ville> »,
// 717 affichages, 0 clic, autour de la 20e place (Arlington, Naples, Honolulu, Cincinnati,
// Irving, Indianapolis, St. Louis, Dallas…). Les pages villes n'ont qu'un court bloc chat ;
// aucune page du site n'expliquait la garde de chat elle-même (l'article « leaving a cat
// alone » répond à « combien de temps », pas à « comment ça marche / comment choisir »).
// Texte vrai, aucun chiffre inventé, aucun tarif : chaque gardien fixe son prix dans l'app.
const URL = "https://www.hopetsit.com/blog/what-is-cat-sitting";
// 27/10/2026 (GUS) — « cat sitting » 938 affichages à la 20e place, « cat sitter meaning » 8e,
// 0 clic : titre et description donnent la définition tout de suite.
const TITLE = "Cat Sitting Meaning: What a Cat Sitter Does and How It Works";
const DESCRIPTION =
  "Cat sitting means someone looks after your cat in your own home while you are away. What a cat sitter does on each visit, how many visits a day your cat needs, and how to choose a cat sitter you can trust.";
const HEADLINE = "Cat sitting explained: what a cat sitter does and how to find one near you";

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
    q: "What does a cat sitter do during a visit?",
    a: "Fresh food and water, a clean litter box, a check that your cat is eating and behaving normally, medication if needed, and some play or quiet company. Most sitters also send a photo or a short note after each visit, so you know the visit happened.",
  },
  {
    q: "How many visits a day does my cat need?",
    a: "For a healthy adult cat, one visit a day is the usual minimum and two is more comfortable, especially for a long trip. Kittens, senior cats, cats on medication or cats that eat several small meals need two visits or more. If in doubt, ask your vet.",
  },
  {
    q: "Is a cat sitter better than a cattery?",
    a: "Most cats are territorial and get stressed by a new place, a car ride and the smell of other cats. Staying home with visits keeps their routine intact. A cattery can make sense for a cat that needs constant medical supervision, which is a question for your vet.",
  },
  {
    q: "How much does cat sitting cost?",
    a: "There is no single rate: it depends on the city, the number of visits per day, their length, the number of cats and any medical care. On HoPetSit each sitter sets their own price and you see the total before you confirm.",
  },
  {
    q: "Do I have to give my keys to a stranger?",
    a: "You give them to someone you have chatted with, read the reviews of and met first. Do a short meet-and-greet at home, hand over the keys in person, and keep a backup contact with a second key in case something comes up.",
  },
];

const CITIES = [
  { slug: "new-york", name: "New York" },
  { slug: "san-francisco", name: "San Francisco" },
  { slug: "dallas", name: "Dallas" },
  { slug: "honolulu", name: "Honolulu" },
  { slug: "cincinnati", name: "Cincinnati" },
  { slug: "naples-fl", name: "Naples, FL" },
];

export default function ArticleWhatIsCatSitting() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        mainEntityOfPage: URL,
        datePublished: "2026-10-21",
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
      <p className="text-sm font-semibold text-owner">Owner guide · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Cat sitting explained: what a cat sitter does and how to find one near you
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Cats have a reputation for being independent, and many owners assume a
        full bowl and a clean litter box are enough for a few days away. They
        rarely are. A cat sitter keeps your cat fed, clean and checked on while
        it stays where it feels safest: at home. Here is what cat sitting
        involves, how many visits your cat really needs, and how to choose
        someone you can trust with your keys.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What cat sitting means</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Cat sitting is care for your cat in your own home by a person who comes
        to you. Instead of being driven to a cattery, your cat keeps its
        territory, its hiding spots, its window and its routine. The sitter
        drops in at agreed times — or, for longer trips, stays over — and does
        what you would normally do.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        This matters more for cats than for most dogs. Cats are territorial:
        a new place, a car ride and the smell of other cats are a lot to take
        in at once, and some cats stop eating when they are stressed. Staying
        home removes all of that.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What happens during a visit</h2>
      <ul className="mt-4 space-y-2">
        {[
          "Fresh food at the usual times, measured the way you do it, and clean water.",
          "Litter box scooped every visit — a dirty box is one of the first reasons a cat goes elsewhere.",
          "A quick health check: is your cat eating, drinking, using the box, moving normally?",
          "Medication or special food if your cat needs it, given exactly as written.",
          "Play or quiet company, depending on your cat. Shy cats are left alone if that is what they prefer.",
          "Small house tasks that come with being there: plants, mail, curtains, lights.",
          "A photo or a short note in the app after each visit, so you know it happened.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">How many visits a day?</h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Your cat</th>
              <th className="p-4 font-bold">Usual choice</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Healthy adult, calm, short trip</td>
              <td className="p-4">One visit a day at a fixed time.</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Longer trip, or a cat that eats small meals</td>
              <td className="p-4">Two visits a day, morning and evening.</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Kitten, senior cat, cat on medication</td>
              <td className="p-4">Two visits or more, timed around the doses — ask your vet.</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Very anxious cat, or several pets</td>
              <td className="p-4">A sitter who sleeps over, so someone is there day and night.</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Wondering how long a cat can safely stay alone between visits? Our{" "}
        <Link href="/blog/leaving-cat-alone-vacation" className="font-semibold text-owner underline">
          guide to leaving a cat alone during a vacation
        </Link>{" "}
        goes through it day by day.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Cat sitter or cattery?</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        For most cats, home visits are the calmer option: no transport, no
        unfamiliar room, no neighbors through the bars. A cattery mainly makes
        sense when a cat needs medical supervision around the clock, and that
        is a decision to take with your vet. If you also have a dog, a single
        sitter can usually look after both — see how{" "}
        <Link href="/blog/what-is-dog-sitting" className="font-semibold text-owner underline">
          dog sitting works
        </Link>{" "}
        for the dog side of the routine.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What drives the price</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        There is no single cat sitting rate. The price depends on your city,
        the number of visits per day, how long each visit lasts, the number of
        cats, any medication, holiday dates, and whether the sitter sleeps
        over. On HoPetSit every sitter sets their own price, and you see the
        full amount before you confirm — nothing is added afterwards. A price
        far below everyone else's usually means a sitter with no reviews yet,
        or one who squeezes in too many visits to do each one properly.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">How to choose a cat sitter</h2>
      <ol className="mt-4 list-decimal space-y-3 pl-5 leading-relaxed text-ink-muted">
        <li>
          <span className="font-semibold text-ink">Post your dates and your cat's needs.</span>{" "}
          Number of visits, feeding, medication, temperament. Sitters near you
          reply in the app.
        </li>
        <li>
          <span className="font-semibold text-ink">Pick someone close by.</span>{" "}
          A sitter who lives a few blocks away keeps visit times steady and can
          come back quickly if something looks wrong.
        </li>
        <li>
          <span className="font-semibold text-ink">Read reviews and chat.</span>{" "}
          Look for reviews tied to real bookings and a sitter who asks
          questions about your cat: hiding spots, what it eats, what is normal
          for it.
        </li>
        <li>
          <span className="font-semibold text-ink">Meet at home before you leave.</span>{" "}
          Show where everything is, let your cat see the sitter, hand over the
          keys in person.
        </li>
        <li>
          <span className="font-semibold text-ink">Book and pay in the app.</span>{" "}
          The amount stays in the app until the visits are done, and every
          message is on record if anything needs sorting out.
        </li>
      </ol>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Before you leave: a short checklist</h2>
      <ul className="mt-4 space-y-2">
        {[
          "Food portioned per meal, with feeding times written down.",
          "Spare litter and bags, and where the box is (and any second box).",
          "Medication with clear doses, plus your vet's name, phone and address.",
          "The carrier left out, in case the sitter has to take your cat to the vet.",
          "Your cat's hiding places, so the sitter can check on a shy cat without panicking.",
          "A backup contact with a spare key.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Find a cat sitter in your city</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        HoPetSit sitters are listed city by city, with the neighborhoods they
        cover. Start with yours:
      </p>
      <div className="mt-4 flex flex-wrap gap-2">
        {CITIES.map((c) => (
          <Link
            key={c.slug}
            href={`/pet-sitting/${c.slug}`}
            className="rounded-full border border-owner/30 bg-white px-4 py-2 text-sm font-semibold text-owner"
          >
            Cat sitters in {c.name}
          </Link>
        ))}
      </div>

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
        <h2 className="font-display text-2xl font-extrabold text-ink">Need a cat sitter?</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Post your dates for free, compare sitters near you and chat before
          you book. Verified profiles and secure in-app payment.
        </p>
        <Link
          href="/pet-sitting/new-york"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Find a cat sitter near me
        </Link>
      </div>
    </div>
  );
}
