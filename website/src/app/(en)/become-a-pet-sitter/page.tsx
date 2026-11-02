import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import { TrackedLink } from "@/components/TrackedLink";
import { RECRUIT_CITIES, RECRUIT_PATH_PREFIX, cityMedian, type RecruitCity } from "@/lib/recruit-cities";

// 02/11/2026 (Bob, week 45) — mirrors the French national hub shipped last
// week (/devenir-petsitter, commit 0651914). Same gap, English side:
// /become-a-pet-sitter/<city> is a real, already-indexed page network, but
// /become-a-pet-sitter (no city) 404ed — Google had nothing to offer for the
// bare "become a pet sitter" query, and none of the 113 already-indexed
// EN/USA pages linked down into this network except their own twin page.
// No new city, no new language (rule of 20/09/2026) — only the missing hub
// for USA (top priority) + United Kingdom (priority #3, already served by
// these same EN pages) + the rest of English Europe, already online.
export const metadata: Metadata = {
  title: "Become a pet sitter — get paid to love animals | HoPetSit",
  description:
    "Set your own rates, choose your services (sitting, drop-in visits, walks) and get paid securely. Become a pet sitter or dog walker with HoPetSit — free sign-up, available across the US, the UK and Europe.",
  alternates: { canonical: "https://www.hopetsit.com/become-a-pet-sitter" },
};

const STEPS = [
  {
    n: "1",
    t: "Create your free profile",
    p: "Photo, bio, services (home sitting, drop-in visits, walks) and YOUR rates — you decide.",
  },
  {
    n: "2",
    t: "Get your identity verified",
    p: "5 minutes in the app. The ✓ badge reassures owners: verified profiles get far more requests.",
  },
  {
    n: "3",
    t: "Receive requests and chat",
    p: "Owners near you contact you by chat. You only accept the bookings that suit you.",
  },
  {
    n: "4",
    t: "Get paid securely",
    p: "Payment is held in the app at booking and released to your bank account once the service is done. No unpaid jobs.",
  },
];

const nyMedian = cityMedian({ lang: "en", slug: "new-york" });

const FAQ = [
  {
    q: "How much can a pet sitter earn?",
    a: nyMedian
      ? `It depends on your city and your own rates — you keep 100% of your price, the service fee is paid by the owner. The only real figure we have today: the median first rate among HoPetSit sitters in New York is ${nyMedian.day} a day and ${nyMedian.walk} a walk (${nyMedian.dayN} and ${nyMedian.walkN} profiles, as of ${nyMedian.asOf}) — too small a sample to call it a national average, but it's a real one, not a guess.`
      : "It depends on your city and your own rates — you keep 100% of your price, the service fee is paid by the owner.",
  },
  {
    q: "Do I need a license or certification?",
    a: "No certification is required to start on HoPetSit — you need to love animals, be reliable and be 18 or older. Requirements for running it as a regular paid activity vary by country and state; check your local rules.",
  },
  {
    q: "Is signing up free?",
    a: "Yes, sign-up and your profile are free. Only identity verification (the ✓ badge, strongly recommended) has a small fee.",
  },
  {
    q: "How does GPS tracking protect the sitter too?",
    a: "During a walk, PawFollow tracking proves the service really happened, from pickup to drop-off — transparency for the owner, protection for you.",
  },
  {
    q: "Is HoPetSit available in my city?",
    a: "HoPetSit is available across the United States, the United Kingdom and Europe. The cities below have a dedicated page, but you can create your profile wherever you are.",
  },
];

const EN_CITIES = RECRUIT_CITIES.filter((c) => c.lang === "en");
const USA = EN_CITIES.filter((c) => c.region.endsWith("USA") && c.slug !== "new-york" && c.slug !== "dallas");
const UK = EN_CITIES.filter((c) => c.region === "United Kingdom");
const EUROPE = EN_CITIES.filter((c) => !c.region.endsWith("USA") && c.region !== "United Kingdom");

function Chips({ cities }: { cities: RecruitCity[] }) {
  return (
    <ul className="mt-4 flex flex-wrap gap-2">
      {cities.map((c) => (
        <li key={`${c.lang}-${c.slug}`}>
          <TrackedLink
            href={`${RECRUIT_PATH_PREFIX.en}/${c.slug}`}
            label="maillage"
            className="inline-block rounded-full bg-bg-soft px-3.5 py-2 text-sm font-medium text-ink transition hover:bg-sitter-light hover:text-sitter-dark max-lg:py-3"
          >
            {c.name}
          </TrackedLink>
        </li>
      ))}
    </ul>
  );
}

export default function BecomeAPetSitterPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "Become a pet sitter",
        inLanguage: "en",
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
      <nav aria-label="Breadcrumb" className="text-xs font-medium text-ink-soft">
        <ol className="flex flex-wrap items-center gap-x-1.5 gap-y-1">
          <li>
            <TrackedLink href="/" label="maillage" className="underline-offset-4 hover:text-owner-dark hover:underline">Home</TrackedLink>
          </li>
          <li aria-hidden="true">›</li>
          <li aria-current="page" className="text-ink">Become a pet sitter</li>
        </ol>
      </nav>
      <p className="mt-3 text-sm font-semibold text-sitter-dark">United States · United Kingdom · Europe</p>
      <h1 className="mt-1.5 font-display text-[1.6rem] font-extrabold leading-[1.15] tracking-tight text-ink md:mt-2 md:text-4xl">
        Become a pet sitter — and get paid to love animals
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Student, remote worker, retiree or simply an animal lover? Dog and cat
        owners near you are looking for someone they can trust while they
        work or travel. HoPetSit connects you with them — you set your rates,
        you choose your services, you get paid securely.
      </p>

      <div className="mt-8 flex flex-wrap gap-3">
        {["💵 Your rates, your rules", "📅 You choose your hours", "✓ Verified badge", "🔒 Guaranteed payment"].map((b) => (
          <span key={b} className="rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-ink shadow-card">
            {b}
          </span>
        ))}
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        How it works
      </h2>
      <ol className="mt-6 space-y-4">
        {STEPS.map((s) => (
          <li key={s.n} className="flex gap-5 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <div className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-sitter-light text-lg font-extrabold text-sitter-dark">
              {s.n}
            </div>
            <div>
              <h3 className="text-base font-bold text-ink">{s.t}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">{s.p}</p>
            </div>
          </li>
        ))}
      </ol>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">Choose your city</h2>
      <p className="mt-2 text-sm leading-relaxed text-ink-muted">
        Every city has its own page with what local owners are asking for.
      </p>
      <ul className="mt-4 flex flex-wrap gap-2">
        <li>
          <TrackedLink
            href={`${RECRUIT_PATH_PREFIX.en}/new-york`}
            label="maillage"
            className="inline-block rounded-full bg-sitter px-4 py-2.5 text-sm font-bold text-white transition hover:bg-sitter-dark max-lg:py-3"
          >
            New York
          </TrackedLink>
        </li>
        <li>
          <TrackedLink
            href={`${RECRUIT_PATH_PREFIX.en}/dallas`}
            label="maillage"
            className="inline-block rounded-full bg-sitter px-4 py-2.5 text-sm font-bold text-white transition hover:bg-sitter-dark max-lg:py-3"
          >
            Dallas
          </TrackedLink>
        </li>
      </ul>

      <h3 className="mt-8 text-sm font-bold text-ink-muted">United States</h3>
      <Chips cities={USA} />

      {UK.length > 0 && (
        <>
          <h3 className="mt-8 text-sm font-bold text-ink-muted">United Kingdom</h3>
          <Chips cities={UK} />
        </>
      )}

      {EUROPE.length > 0 && (
        <>
          <h3 className="mt-8 text-sm font-bold text-ink-muted">Europe</h3>
          <Chips cities={EUROPE} />
        </>
      )}

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        Frequently asked questions
      </h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-sitter-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Early sitters get the best neighborhoods
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          HoPetSit is still growing in most of these cities: little competition
          between sitters, and new owners arriving every week. This is the
          best time to create your profile.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white"
        >
          Create my free profile
        </Link>
      </div>

      <section className="mt-12 border-t border-owner/15 pt-6">
        <p className="text-center text-sm md:text-left">
          <TrackedLink href="/pet-sitting/new-york" label="maillage" className="font-semibold text-owner-dark underline-offset-4 hover:underline">
            Looking for a pet sitter instead? Find one in New York →
          </TrackedLink>
        </p>
        <p className="mt-3 text-center text-sm md:text-left">
          <TrackedLink href="/villes" label="maillage" className="font-semibold text-sitter-dark underline-offset-4 hover:underline">
            All cities →
          </TrackedLink>
        </p>
      </section>
    </div>
  );
}
