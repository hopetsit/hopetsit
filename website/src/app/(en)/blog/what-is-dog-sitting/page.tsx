import type { Metadata } from "next";
import Link from "@/components/SiteLink";

// 14/10/2026 (GUS) — article de la semaine choisi sur la demande mesurée dans la Search
// Console (28 j, USA) : « dog sitting » 931 affichages / 0 clic / 16e place et « dog sitter »
// 334 affichages / 21e place, servis par des pages villes (Decatur, Cincinnati, Columbus…)
// qui ne disent pas ce qu'est une garde de chien en général. Aucune page du site ne
// répondait à la question de fond. Texte vrai, aucun chiffre inventé : les tarifs sont
// renvoyés vers l'article Dallas (chiffres déjà publiés) et au prix affiché dans l'app.
const URL = "https://www.hopetsit.com/blog/what-is-dog-sitting";
// 27/10/2026 (GUS) — Search Console 28 j USA : « dog sitting meaning » 6,8e place, « dog sitter
// meaning » 8e, « dog sitting » 7,7e — 267 affichages, 0 clic. Le titre ne disait pas « meaning » :
// titre et description répondent maintenant à la question tapée (définition en 1re phrase).
const TITLE = "Dog Sitting Meaning: What a Dog Sitter Does and How It Works";
const DESCRIPTION =
  "Dog sitting means a person cares for your dog in a home, usually yours, while you are away: drop-in visits, day sitting or overnight stays. What a dog sitter does, how it differs from boarding, and how to find one.";
const HEADLINE = "Dog sitting explained: how it works and how to find a dog sitter near you";

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
    q: "What does a dog sitter actually do?",
    a: "A dog sitter looks after your dog while you are away: feeding on schedule, fresh water, walks and play, medication if needed, and company. Depending on the format, the sitter stops by for visits, stays the day, or sleeps over at your place. Most sitters send a photo or a short note after each visit.",
  },
  {
    q: "Is dog sitting better than boarding?",
    a: "For most dogs, staying in their own home with their own routine is less stressful than a kennel, and there is no exposure to a group of unknown dogs. Boarding can make sense for a very social dog or when nobody can come to your home. Our comparison guide goes through both options in detail.",
  },
  {
    q: "How much does dog sitting cost?",
    a: "There is no single national rate: the price depends on the format (visit, day, overnight), the length of the stay, the number of dogs and the city. On HoPetSit each sitter sets their own prices, and you see the total before you confirm a booking.",
  },
  {
    q: "How do I know a dog sitter is trustworthy?",
    a: "Read reviews tied to real bookings, look for a verified profile, chat with the sitter before booking, and set up a short meet-and-greet at your home. Keep the booking and the payment in the app so there is a record if anything needs sorting out.",
  },
  {
    q: "Can I follow the walks while I am away?",
    a: "Yes. Walks booked through HoPetSit are tracked live on the map, so you can see when your dog went out, the route and how long it lasted, instead of relying on a text that says everything went fine.",
  },
];

export default function ArticleWhatIsDogSitting() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "en-US",
        mainEntityOfPage: URL,
        datePublished: "2026-10-14",
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

  const CITIES = [
    { slug: "new-york", name: "New York" },
    { slug: "los-angeles", name: "Los Angeles" },
    // 18/10 (GUS) — San Francisco (108 aff. « dog sitting », 25e) et Boston
    // (33 aff., 23e) ajoutées : 0 clic en 28 j, pages déjà indexées.
    { slug: "san-francisco", name: "San Francisco" },
    { slug: "boston", name: "Boston" },
    { slug: "dallas", name: "Dallas" },
    { slug: "columbus", name: "Columbus" },
    { slug: "decatur-ga", name: "Decatur, GA" },
    { slug: "honolulu", name: "Honolulu" },
  ];

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">Owner guide · 2026</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Dog sitting explained: how it works and how to find a dog sitter near you
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        A trip, a long week at the office, a family emergency: at some point
        every dog owner needs someone to look after their dog. "Dog sitting"
        covers several very different services, and the right one depends on
        your dog, your schedule and how long you'll be gone. Here is what each
        option really involves, what makes the price go up or down, and how to
        pick a sitter you can trust.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What dog sitting means</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Dog sitting is care for your dog in a home — usually yours — by a
        person, not a facility. Your dog keeps its bed, its smells, its
        feeding times and its usual walks. The sitter takes over what you
        normally do: food and water on schedule, walks, play, medication if
        your dog needs it, and simply being around. That is the main
        difference with a kennel, where your dog is moved to a new place with
        other dogs and a staff rotation.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        It is also different from dog walking. A walker comes for the walk and
        leaves; a sitter stays, or comes back several times a day, and takes
        responsibility for the whole routine while you are away.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">The three formats</h2>
      <div className="mt-5 overflow-x-auto rounded-2xl border border-ink/5 bg-white shadow-card">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-ink/10 text-ink">
              <th className="p-4 font-bold">Format</th>
              <th className="p-4 font-bold">What happens</th>
              <th className="p-4 font-bold">Best for</th>
            </tr>
          </thead>
          <tbody className="text-ink-muted">
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Drop-in visits</td>
              <td className="p-4">The sitter comes once or several times a day for feeding, a walk and some company.</td>
              <td className="p-4">Dogs that are fine alone at night; long workdays.</td>
            </tr>
            <tr className="border-b border-ink/5">
              <td className="p-4 font-semibold text-ink">Day sitting</td>
              <td className="p-4">The sitter stays with your dog during the day, at your place or theirs.</td>
              <td className="p-4">Puppies, anxious dogs, dogs that can't be left alone.</td>
            </tr>
            <tr>
              <td className="p-4 font-semibold text-ink">Overnight / house sitting</td>
              <td className="p-4">The sitter sleeps at your home and keeps the full routine going, day and night.</td>
              <td className="p-4">Weekends away and vacations.</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-sm text-ink-muted">
        Some sitters also host dogs at their own home. It works well for a
        sociable dog and a sitter with a quiet place, but ask who else lives
        there (other pets, children) before booking.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Dog sitting or boarding?</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        For most dogs, staying home is the calmer option: no new place to get
        used to, no group of unknown dogs, no kennel noise at night. Boarding
        makes more sense when your dog genuinely enjoys a crowd, or when nobody
        can get to your home. If you are hesitating, read our{" "}
        <Link href="/blog/dog-boarding-vs-pet-sitting" className="font-semibold text-owner underline">
          dog boarding vs pet sitting comparison
        </Link>{" "}
        — it goes through stress, safety and price side by side.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">What drives the price</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        There is no single "dog sitting rate" in the United States. The price
        depends on the format (a visit costs less than an overnight), the
        length of the stay, the number of dogs, any medical care, holiday
        dates, and above all the city. On HoPetSit, every sitter sets their own
        prices and you see the full amount before confirming — nothing is
        added afterwards. For a concrete local example, see{" "}
        <Link href="/blog/how-much-does-a-pet-sitter-cost-in-dallas" className="font-semibold text-owner underline">
          what a pet sitter costs in Dallas
        </Link>
        .
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        A price far below everyone else's is a warning sign more than a
        bargain: it often means a sitter with no reviews yet, or one who takes
        on more dogs than they can handle at the same time.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">How to find a dog sitter near you</h2>
      <ol className="mt-4 list-decimal space-y-3 pl-5 leading-relaxed text-ink-muted">
        <li>
          <span className="font-semibold text-ink">Post your dates and your dog's needs.</span>{" "}
          Breed, age, energy level, medication, how long your dog can stay
          alone. Sitters near you reply in the app; you don't have to chase
          anyone.
        </li>
        <li>
          <span className="font-semibold text-ink">Read the profile, not just the photo.</span>{" "}
          Look for reviews tied to real bookings, a verified profile, and a
          sitter who covers your neighborhood — someone a few blocks away is
          far more likely to show up on time, every time.
        </li>
        <li>
          <span className="font-semibold text-ink">Chat, then meet.</span> A
          fifteen-minute meet-and-greet at your home tells you more than any
          message: how your dog reacts, whether the sitter asks the right
          questions about routine and temperament.
        </li>
        <li>
          <span className="font-semibold text-ink">Book and pay in the app.</span>{" "}
          The amount stays in the app until the sitting is done, and every
          message and booking is on record. Cash with no trace leaves you with
          nothing to fall back on if there is a problem.
        </li>
        <li>
          <span className="font-semibold text-ink">Follow along.</span> Walks
          booked through HoPetSit are tracked live on the map, and sitters send
          a photo or a short note after each visit.
        </li>
      </ol>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Before you leave: a short checklist</h2>
      <ul className="mt-4 space-y-2">
        {[
          "Food measured out per meal, with the feeding times written down.",
          "Medication with clear doses, and your vet's name and phone number.",
          "Leash, harness, poop bags, towels — where they are and where the dog usually walks.",
          "What is off limits: table scraps, the couch, the dog park if your dog doesn't do well there.",
          "A backup contact who has a key, in case something comes up on either side.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Find a dog sitter in your city</h2>
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
            Dog sitters in {c.name}
          </Link>
        ))}
      </div>

      {/* 31/10/2026 (GUS) — « cat sitting » 1 730 affichages US en 7 j, 20e place, 0 clic : lien contextuel vers le guide cat sitting */}
      <p className="mt-4 leading-relaxed text-ink-muted">
        Have a cat too? Cat sitting works differently: visits at your home instead of walks, and the number of visits a day matters more than their length. We explain it in <Link href="/blog/what-is-cat-sitting" className="font-semibold text-owner underline">cat sitting meaning: what a cat sitter does</Link>.
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
        <h2 className="font-display text-2xl font-extrabold text-ink">Need a dog sitter?</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Post your dates for free, compare sitters near you, chat before you
          book. Verified profiles, secure in-app payment and live GPS tracking
          on every walk.
        </p>
        <Link
          href="/pet-sitting/dallas"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          Find a dog sitter near me
        </Link>
      </div>
    </div>
  );
}
