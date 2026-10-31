import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "@/components/SiteLink";
import { OwnerSignupCta } from "@/components/OwnerSignupCta";
import DATA from "@/lib/city-districts.json";

// 31/10/2026 (GUS, décision BOB sur la mesure : arrondissements de Paris indexés à 68 % ≥ 40 %) —
// une page par borough de New York, sur le modèle des arrondissements de Paris : contenu RÉEL
// (OpenStreetMap par frontière du borough, ~/hopetsit-social/city_districts_build.py) + un texte
// local écrit à la main pour chaque borough. Contrôle d'unicité ≥ 80 % (uniq_paris.py) avant publication.
// Reliées depuis la section « Quartiers » de /pet-sitting/new-york (déjà indexée).
type D = { id: string; name: string; en: string; counts: { vet: number; shop: number; groomer: number; dogpark: number }; dogparks: string[]; parks: string[]; hoods: string[]; near: string[] };
const LIST = (DATA as Record<string, D[]>)["new-york"] ?? [];

const LOCAL: Record<string, { lead: string; life: string; walk: string }> = {
  manhattan: {
    lead: "Small apartments, long workdays and doormen at the front desk: in Manhattan most dogs spend the day indoors while their owners are at the office, and many cats live their whole life above the tenth floor.",
    life: "That is why midday walks and drop-in visits are the everyday need here, and why key handovers matter. Tell your sitter how your building works: front desk, key fob, service elevator, and whether the super needs to know who is coming in.",
    walk: "Central Park and Riverside Park allow dogs off leash in designated areas early in the morning and late at night only; the rest of the day, leashes stay on. Dog runs are the place for a midday play session.",
  },
  brooklyn: {
    lead: "Brownstones, walk-ups and new towers along the waterfront: Brooklyn mixes families with backyards and young couples in one-bedrooms, and its dog community is one of the busiest in the city.",
    life: "Weekend trips upstate and holiday visits to family are the classic reasons Brooklyn owners book overnight sitting. If you live in a walk-up, mention the stairs: an older dog or a heavy breed needs a sitter who knows what that means.",
    walk: "Prospect Park's Long Meadow is famous for its early-morning off-leash hours, and the waterfront parks from Williamsburg to Brooklyn Bridge Park have their own dog runs. Ask your sitter which park your dog already knows.",
  },
  queens: {
    lead: "Queens is the largest borough by area, and it feels like several cities at once: apartment buildings in Astoria and Long Island City, detached houses with yards further east.",
    life: "A yard changes the brief. Tell your sitter whether your dog can be left in the yard, how the gate closes, and whether neighbors' dogs bark through the fence. In apartment neighborhoods, the routine looks more like Manhattan.",
    walk: "Flushing Meadows Corona Park, Forest Park and Astoria Park offer long walks, and the borough has dog runs scattered from the waterfront to the eastern neighborhoods. Distances are longer here, so a sitter close to your block saves time.",
  },
  "the-bronx": {
    lead: "The Bronx is the greenest borough to walk a dog in: Pelham Bay Park, the largest park in New York City, Van Cortlandt Park and Bronx Park along the river give big, quiet spaces close to home.",
    life: "Many Bronx owners commute into Manhattan, so the request we see most is the long-day walk: someone who comes at lunchtime, takes the dog out properly and sends a photo. Overnight care is the other need, for trips and family visits.",
    walk: "Trails in the big parks are great in spring and fall; in summer, plan walks early or late. Keep your dog leashed outside designated dog runs and off-leash hours, and check ticks after woodland walks.",
  },
  "staten-island": {
    lead: "Staten Island is the most suburban of the five boroughs: houses, driveways, yards and a car for most trips. Pet care here looks different from the rest of the city.",
    life: "Sitters often drive to you, and overnight stays at your home are common because pets have space and a garden. Leave clear instructions for the yard, the gate and any alarm, and say whether the sitter can park in your driveway. If you ride the ferry to Manhattan every day, a lunchtime visit keeps your dog's day from feeling endless.",
    walk: "The Greenbelt, Clove Lakes Park, Silver Lake Park and Willowbrook Park give long walks on real trails. Off the trails, keep the leash on and watch for traffic on roads without sidewalks.",
  },
};

export const dynamicParams = false;
export function generateStaticParams() {
  return LIST.map((d) => ({ borough: d.id }));
}

function entry(id: string) {
  return LIST.find((d) => d.id === id);
}

export function generateMetadata({ params }: { params: { borough: string } }): Metadata {
  const d = entry(params.borough);
  if (!d) return {};
  const url = `https://www.hopetsit.com/pet-sitting-new-york/${d.id}`;
  const title = `Pet Sitters in ${d.en}, New York: Dog Walking & Cat Sitting`;
  const description = `Find a dog sitter, dog walker or cat sitter in ${d.en}${d.hoods.length ? ` (${d.hoods.slice(0, 3).join(", ")}…)` : ""}: dog runs, parks and local tips. Post your request for free.`;
  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: { title, description, url, type: "website", siteName: "HoPetSit", images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }] },
  };
}

export default function BoroughPage({ params }: { params: { borough: string } }) {
  const d = entry(params.borough);
  const t = d && LOCAL[d.id];
  if (!d || !t) notFound();
  const byId = Object.fromEntries(LIST.map((x) => [x.id, x]));
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Service",
        name: `Pet sitting in ${d.en}, New York`,
        serviceType: "Pet sitting, cat visits and dog walking",
        provider: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com" },
        areaServed: { "@type": "Place", name: `${d.en}, New York` },
        image: "https://www.hopetsit.com/og-image.png",
        inLanguage: "en-US",
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "New York", item: "https://www.hopetsit.com/pet-sitting/new-york" },
          { "@type": "ListItem", position: 2, name: d.en, item: `https://www.hopetsit.com/pet-sitting-new-york/${d.id}` },
        ],
      },
    ],
  };
  return (
    <div className="mx-auto max-w-3xl px-4 pb-16 pt-7 md:pb-24 md:pt-16">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">
        <Link href="/pet-sitting/new-york#districts" className="underline-offset-2 hover:underline">New York</Link> › {d.en}
      </p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">Pet sitters in {d.en}</h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">{t.lead}</p>
      <OwnerSignupCta label="Post my request" city={`${d.en}, New York`} className="mt-6 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white" />

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Pet care in {d.en}</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">{t.life}</p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Walking a dog in {d.en}</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">{t.walk}</p>
      {d.dogparks.length > 0 && (
        <>
          <h3 className="mt-6 font-bold text-ink">Dog runs mapped in {d.en}</h3>
          <ul className="mt-2 flex flex-wrap gap-2">
            {d.dogparks.map((p) => <li key={p} className="rounded-full bg-owner-light px-3 py-1.5 text-sm font-semibold text-owner-dark">{p}</li>)}
          </ul>
        </>
      )}
      {d.parks.length > 0 && (
        <>
          <h3 className="mt-6 font-bold text-ink">Parks in {d.en}</h3>
          <p className="mt-2 text-sm leading-relaxed text-ink-muted">{d.parks.join(" · ")}</p>
        </>
      )}
      {d.hoods.length > 0 && (
        <>
          <h3 className="mt-6 font-bold text-ink">Neighborhoods of {d.en}</h3>
          <p className="mt-2 text-sm leading-relaxed text-ink-muted">{d.hoods.join(" · ")}</p>
        </>
      )}
      {d.counts.vet >= 10 && (
        <p className="mt-6 rounded-2xl border border-ink/5 bg-white p-5 text-sm leading-relaxed text-ink-muted shadow-card">
          OpenStreetMap lists {d.counts.vet} veterinary clinics, {d.counts.shop} pet shops and {d.counts.groomer} groomers inside {d.en}&apos;s borough limits. Leave your vet&apos;s details and the nearest 24-hour animal hospital with your sitter.
        </p>
      )}
      <p className="mt-3 text-xs text-ink-muted">Places: © OpenStreetMap contributors (ODbL).</p>

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">Find a sitter in {d.en}</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">Free request, replies with prices, secure payment released after the sitting, free cancellation up to 72 h before.</p>
        <OwnerSignupCta label="Post my request" city={`${d.en}, New York`} className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white" />
      </div>

      <nav className="mt-10 text-sm">
        <p className="font-bold text-ink">Nearby boroughs</p>
        <p className="mt-2 flex flex-wrap gap-x-4 gap-y-2">
          {d.near.map((n) => byId[n] && <Link key={n} href={`/pet-sitting-new-york/${n}`} className="font-semibold text-owner-dark underline-offset-2 hover:underline">{byId[n].en}</Link>)}
          <Link href="/pet-sitting/new-york" className="font-semibold text-owner-dark underline-offset-2 hover:underline">All of New York</Link>
          <Link href="/blog/pet-sitting-new-york-holidays" className="font-semibold text-owner-dark underline-offset-2 hover:underline">Holiday pet sitting guide</Link>
        </p>
      </nav>
    </div>
  );
}
