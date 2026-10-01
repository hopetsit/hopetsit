// 01/10/2026 (SAM) — push USA gratuit (Daniel : « pousser San Francisco, Dallas
// et New York gratuitement »). Règle SEO du 20/09 : aucune page nouvelle, on
// rend UNIQUES les pages qui existent déjà (/pet-sitting/<ville> et
// /become-a-pet-sitter/<ville>) avec du contenu local réel : quartiers, parcs
// où l'on promène, contraintes locales. Aucun chiffre d'activité, aucune
// promesse de revenus. Composant serveur, aucun hook.

type Mode = "owner" | "recruit";
type Guide = {
  hoods: string[];
  walks: { name: string; note: string }[];
  tips: string[];
  faq: Record<Mode, { q: string; a: string }[]>;
};

const GUIDES: Record<string, Guide> = {
  "new-york": {
    hoods: ["Upper West Side", "Upper East Side", "Harlem", "Park Slope", "Williamsburg", "Astoria", "Long Island City", "the East Village"],
    walks: [
      { name: "Central Park", note: "off-leash courtesy hours before 9 a.m. and after 9 p.m. — the rest of the day dogs stay leashed" },
      { name: "Prospect Park", note: "Long Meadow is Brooklyn's favorite early-morning off-leash spot" },
      { name: "Tompkins Square Park dog run", note: "the East Village run, busy every evening" },
      { name: "Hudson River Park", note: "dog runs along the West Side, handy for Chelsea and the West Village" },
    ],
    tips: [
      "Most New York dogs live in apartments without a yard, so a midday walk on workdays matters more than anywhere else.",
      "Doorman buildings usually need the sitter's name in advance — add it to your request so the key handover is smooth.",
      "Summer pavement and winter de-icing salt are both hard on paws: ask your sitter to keep walks short at noon in July and to wipe paws in winter.",
    ],
    faq: {
      owner: [
        { q: "Can my dog walker take my dog off-leash in Central Park?", a: "Only during the park's courtesy hours (before 9 a.m. and after 9 p.m.) and only in the areas where it is allowed. Tell your walker in the request whether your dog has reliable recall." },
        { q: "How does key handover work in a doorman building?", a: "Give your doorman the sitter's first name before the first visit, or meet the sitter once in person. You chat with the sitter in the app before you book, so you can arrange it there." },
      ],
      recruit: [
        { q: "Where do New York dog walkers find regular clients?", a: "Mostly in apartment neighborhoods where owners work long days: the Upper West Side, Park Slope, Astoria or Long Island City. Set your service area around the blocks you can reach on foot." },
        { q: "What do New York owners expect from a walker?", a: "Punctual midday walks, respect for building rules and leash laws, and a short update after each walk. HoPetSit shares the walk live on the map so the owner sees it." },
      ],
    },
  },
  "san-francisco": {
    hoods: ["the Mission", "Noe Valley", "Bernal Heights", "the Marina", "Pacific Heights", "the Inner Richmond", "the Sunset", "SoMa"],
    walks: [
      { name: "Fort Funston", note: "ocean bluffs and off-leash trails, a classic weekend walk" },
      { name: "Crissy Field", note: "flat beach walk with the Golden Gate in view" },
      { name: "Bernal Heights Park", note: "hilltop loop where many local dogs run every morning" },
      { name: "Golden Gate Park", note: "large park with dedicated dog play areas" },
      { name: "Mission Dolores Park", note: "the neighborhood meeting point for Mission and Noe Valley dogs" },
    ],
    tips: [
      "Many San Francisco owners commute down the Peninsula or travel for work: overnight sitting and drop-in visits for cats are common requests.",
      "Microclimates are real — fog on the west side, sun in the Mission — so pack a towel for beach walks at Fort Funston or Crissy Field.",
      "Parking is hard in most neighborhoods: mention in your request whether the sitter can walk or bike to you.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog run off-leash in San Francisco?", a: "Popular spots include Fort Funston, parts of Crissy Field and the dog play areas of Golden Gate Park. Rules vary by area and season, so tell your sitter which places your dog already knows." },
        { q: "Can a sitter look after my cat while I travel?", a: "Yes. Post a request for drop-in visits: the sitter comes to feed, play and clean the litter box, and you get updates in the app." },
      ],
      recruit: [
        { q: "Which San Francisco neighborhoods are best for a new pet sitter?", a: "Start with the neighborhood you live in. Owners prefer someone close by, and walking or biking between clients is much easier than driving and parking." },
        { q: "Do I need a car to pet sit in San Francisco?", a: "No. Most walks happen within a few blocks of the owner's home. Set your service area to what you can reach on foot, by bike or by Muni." },
      ],
    },
  },
  dallas: {
    hoods: ["Uptown", "Lakewood", "Lower Greenville", "the M Streets", "Oak Cliff and Bishop Arts", "Lake Highlands", "Deep Ellum", "Preston Hollow"],
    walks: [
      { name: "White Rock Lake", note: "the lake loop and its dog park, the east side's favorite walk" },
      { name: "Katy Trail", note: "shaded trail through Uptown, busy at sunrise and after work" },
      { name: "Klyde Warren Park", note: "downtown deck park with a small dog area" },
      { name: "Bark Park Central", note: "Deep Ellum dog park under the freeway, shaded in summer" },
    ],
    tips: [
      "Texas summers are hot: from June to September, good sitters walk dogs early in the morning or after sunset and keep midday outings short.",
      "Many Dallas homes have a yard — say in your request whether the sitter should walk your dog or just do yard time and play.",
      "Plano, Frisco, Richardson and Irving are covered too: set the exact address in your request so nearby sitters see it.",
    ],
    faq: {
      owner: [
        { q: "How do sitters handle the Dallas summer heat?", a: "Walks move to early morning and evening, with water and shade. Tell your sitter in the request if your dog is a short-nosed breed or older — they need even shorter outings in the heat." },
        { q: "Is my suburb covered, like Plano or Frisco?", a: "Yes. Your request is shown to sitters around your address, not only in Dallas proper." },
      ],
      recruit: [
        { q: "When are Dallas pet sitters most in demand?", a: "Weekends, holidays and summer trips for overnight sitting, and workdays for midday walks in Uptown, Lakewood and the M Streets." },
        { q: "Do I need a car to pet sit in Dallas?", a: "It helps, because distances are long. Many sitters focus on a few neighborhoods close to home to keep travel short." },
      ],
    },
  },
};

export function usGuide(slug: string, lang: string): Guide | null {
  return lang === "en" ? GUIDES[slug] ?? null : null;
}

export function usFaq(slug: string, lang: string, mode: Mode): { q: string; a: string }[] {
  return usGuide(slug, lang)?.faq[mode] ?? [];
}

export default function UsLocalGuide({ slug, lang, name, mode }: { slug: string; lang: string; name: string; mode: Mode }) {
  const g = usGuide(slug, lang);
  if (!g) return null;
  return (
    <section className="mt-10" aria-labelledby="us-local-guide">
      <h2 id="us-local-guide" className="font-display text-2xl font-extrabold text-ink">
        {mode === "owner" ? `Pet care in ${name}: the local guide` : `Pet sitting in ${name}: what to know`}
      </h2>
      <p className="mt-3 text-sm leading-relaxed text-ink-muted">
        {mode === "owner" ? "Neighborhoods where owners post requests: " : "Neighborhoods to start in: "}
        {g.hoods.join(", ")}.
      </p>
      <h3 className="mt-6 text-base font-bold text-ink">
        {mode === "owner" ? "Where local sitters walk dogs" : "Where you will walk"}
      </h3>
      <ul className="mt-3 grid gap-3 md:grid-cols-2">
        {g.walks.map((w) => (
          <li key={w.name} className="rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
            <span className="block text-sm font-bold text-ink">{w.name}</span>
            <span className="mt-1 block text-sm leading-relaxed text-ink-muted">{w.note}</span>
          </li>
        ))}
      </ul>
      <h3 className="mt-6 text-base font-bold text-ink">{`Good to know in ${name}`}</h3>
      <ul className="mt-3 space-y-2">
        {g.tips.map((t) => (
          <li key={t} className="flex gap-2 text-sm leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
