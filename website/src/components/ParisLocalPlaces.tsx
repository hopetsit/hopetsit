import Link from "@/components/SiteLink";
import PLACES from "@/lib/paris-places.json";

// v562 — SEO Paris (Search Console 17/09 : les 20 arrondissements « détectés, non
// indexés » ; 21 phrases sur 27 identiques d'une page à l'autre). Daniel : « au
// moins 80 % unique ». Sur les pages d'arrondissement, OwnerCityPage et
// RecruitCityPage n'affichent plus leurs blocs génériques : ce composant les
// remplace par le contenu RÉEL du quartier (lieux de la PawMap, horaires,
// week-end, parcs, arrondissements voisins, FAQ locale) + un seul paragraphe
// court sur HoPetSit. Données : website/src/lib/paris-places.json, produites par
// ~/hopetsit-social/paris_places_build.py et rafraîchies le 1er du mois.

type Place = { title: string; cat: string; address: string; hours: string; m: number };
export type ParisEntry = {
  n: number;
  counts: Record<string, number>;
  places: Place[];
  greens?: Place[];
  neighbours: number[];
  vetSat: number;
  vetSun: number;
  vetHours: number;
};
type Mode = "owner" | "recruit";

const DATA = PLACES as Record<string, ParisEntry>;

/** Phrase chiffrée propre à l'arrondissement : seulement ce qui existe, avec les noms.
 *  10/12 (bob) : les pages garde-animaux/paris-N et devenir-petsitter/paris-N partageaient
 *  ce paragraphe au mot près (Search Console : 5 des 6 pages clés encore non indexées sont
 *  classées « doublon, mauvaise URL canonique » — même cause que les jumelles Chicago/Fort
 *  Worth à 92 % corrigées le 10/10). Même liste de lieux réels, mais formulée différemment
 *  selon qu'on s'adresse au propriétaire ou au futur pet sitter. */
function stats(e: ParisEntry, mode: Mode): string {
  const c = e.counts;
  const bits = [
    c.vet ? nb(c.vet, "vétérinaire", "vétérinaires") : "",
    c.shop ? nb(c.shop, "animalerie", "animaleries") : "",
    c.groomer ? nb(c.groomer, "toiletteur", "toiletteurs") : "",
    c.dogpark ? nb(c.dogpark, "espace canin", "espaces canins") : "",
    c.green ? nb(c.green, "espace vert nommé", "espaces verts nommés") : "",
    c.water ? nb(c.water, "fontaine", "fontaines") : "",
  ].filter(Boolean);
  const named = e.places.slice(0, 2).map((p) => p.title);
  const tail = named.length ? `, dont ${named.join(" et ")}` : "";
  return mode === "owner"
    ? `Autour de chez vous, dans le ${ord(e.n)} : ${bits.join(", ")}${tail}.`
    : `Un pet sitter du ${ord(e.n)} travaille avec ça à proximité : ${bits.join(", ")}${tail}.`;
}
export const parisEntry = (slug: string): ParisEntry | undefined => DATA[slug];

const ord = (n: number) => (n === 1 ? "1er" : `${n}e`);
const nb = (k: number, one: string, many: string) => `${k} ${k > 1 ? many : one}`;
const DAYS: Record<string, string> = { Mo: "lun.", Tu: "mar.", We: "mer.", Th: "jeu.", Fr: "ven.", Sa: "sam.", Su: "dim.", PH: "jours fériés" };
const hours = (h: string): string => {
  const raw = h.trim();
  if (!raw) return "";
  if (raw === "24/7") return "ouvert 24 h/24";
  if (/^sunrise-sunset$/i.test(raw)) return "du lever au coucher du soleil";
  // formats saisonniers ou exceptions (mois, dates) : trop techniques pour être affichés tels quels
  if (/\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|week|closed|sunrise|sunset)\b/i.test(raw)) return "";
  return raw
    .replace(/\b(Mo|Tu|We|Th|Fr|Sa|Su|PH)\b/g, (d) => DAYS[d])
    .replace(/\boff\b/g, "fermé")
    .replace(/,(?=\d)/g, ", ")
    .replace(/;\s*/g, " · ");
};
const far = (m: number) => (m < 1000 ? `${Math.round(m / 10) * 10} m` : `${(m / 1000).toFixed(1).replace(".", ",")} km`);
const dist = (m: number) => (m < 1000 ? `à ${Math.round(m / 50) * 50} m du centre de l'arrondissement` : `à ${(m / 1000).toFixed(1).replace(".", ",")} km`);

function PlaceList({ items }: { items: Place[] }) {
  return (
    <ul className="mt-4 grid gap-3 md:grid-cols-2">
      {items.map((p) => (
        <li key={p.title + p.m} className="rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
          <p className="font-bold text-ink">{p.title}</p>
          {p.address && <p className="mt-0.5 text-sm text-ink-muted">{p.address}</p>}
          <p className="mt-0.5 text-xs text-ink-muted">
            {hours(p.hours) ? `${hours(p.hours)} · ` : ""}{far(p.m)}
          </p>
        </li>
      ))}
    </ul>
  );
}

/** Promenades : uniquement des noms réels (espaces canins du quartier et des voisins). */
function walks(e: ParisEntry, mode: Mode): string {
  const dog = e.places.filter((p) => p.cat === "dogpark").map((p) => p.title);
  const near = e.neighbours.flatMap((v) => (DATA[`paris-${v}`]?.places || []).filter((p) => p.cat === "dogpark").map((p) => `${p.title} (${ord(v)})`));
  const lead = mode === "owner" ? "Pour vos propres sorties : " : "Pour varier les balades avec les animaux que vous gardez : ";
  const parts = [
    dog.length ? `${lead}${dog.join(", ")}.` : "",
    near.length ? `Tout près : ${near.slice(0, 4).join(", ")}.` : "",
    e.counts.water ? `${e.counts.water} fontaines.` : "",
  ].filter(Boolean);
  return parts.join(" ") || `Espaces canins les plus proches : ${e.neighbours.map((v) => `Paris ${ord(v)}`).join(", ")}.`;
}

/** FAQ construite uniquement à partir des lieux réels de l'arrondissement. */
export function parisFaq(slug: string, mode: Mode): { q: string; a: string }[] {
  const e = DATA[slug];
  if (!e) return [];
  const a = ord(e.n);
  const vets = e.places.filter((p) => p.cat === "vet");
  const shops = e.places.filter((p) => p.cat === "shop" || p.cat === "groomer");
  const parks = e.places.filter((p) => p.cat === "dogpark");
  const nearest = vets[0];
  const neighbourParks = e.neighbours.flatMap((v) => (DATA[`paris-${v}`]?.places || []).filter((p) => p.cat === "dogpark").map((p) => `${p.title} (${ord(v)})`));
  const faq: { q: string; a: string }[] = [];
  faq.push({
    q: mode === "owner" ? `Quel vétérinaire est le plus proche dans le ${a} ?` : `Vers quel vétérinaire orienter un propriétaire du ${a} en urgence ?`,
    a: nearest
      ? (mode === "owner"
          ? `D'après la PawMap, ${nearest.title}${nearest.address ? `, ${nearest.address}` : ""}, se trouve ${dist(nearest.m)}.${e.vetSat ? ` Dans le secteur, ${nb(e.vetSat, "cabinet ouvre", "cabinets ouvrent")} le samedi${e.vetSun ? ` et ${nb(e.vetSun, "le dimanche", "le dimanche")}` : ""}.` : " Aucun des cabinets dont les horaires sont connus n'ouvre le samedi : prévoyez un plan B dans un arrondissement voisin."}`
          : `Le plus proche, ${nearest.title}${nearest.address ? `, ${nearest.address}` : ""} (${dist(nearest.m)}), est à connaître avant votre première garde dans le ${a}.${e.vetSat ? ` ${nb(e.vetSat, "cabinet reste ouvert", "cabinets restent ouverts")} le samedi${e.vetSun ? ` et ${nb(e.vetSun, "le dimanche", "le dimanche")}` : ""} : utile pour une garde de week-end.` : " Aucun des cabinets répertoriés n'ouvre le samedi : prévenez le propriétaire avant un week-end de garde."}`)
      : `La PawMap ne recense pas encore de cabinet nommé autour du ${a} ; consultez ceux du ${e.neighbours.map(ord).join(", ")}.`,
  });
  faq.push({
    q: mode === "owner" ? `Où acheter croquettes et litière près de Paris ${a} ?` : `Quels commerces animaliers un pet sitter doit connaître dans le ${a} ?`,
    a: shops.length
      ? `${shops.slice(0, 3).map((p) => `${p.title}${p.address ? ` (${p.address})` : ""}`).join(", ")}${shops.length > 3 ? `, et ${nb(shops.length - 3, "autre adresse", "autres adresses")} sur la carte` : ""}.`
      : `Pas de commerce animalier nommé dans un rayon d'un kilomètre ; les plus proches sont dans le ${e.neighbours.map(ord).join(", ")}.`,
  });
  faq.push({
    q: mode === "owner" ? `Où promener mon chien dans le ${a} et autour ?` : `Où un pet sitter peut-il promener un chien dans le ${a} ?`,
    a: mode === "owner"
      ? `${parks.length ? `Sur place : ${parks.map((p) => p.title).join(", ")}. ` : "Peu d'espaces canins répertoriés sur place. "}${neighbourParks.length ? `À proximité : ${neighbourParks.slice(0, 4).join(", ")}. ` : ""}${e.counts.water ? `${nb(e.counts.water, "point d'eau est", "points d'eau sont")} cartographiés dans le secteur.` : ""}`
      : `${parks.length ? `Dans le ${a} même : ${parks.map((p) => p.title).join(", ")}. ` : "Peu d'espaces canins dans l'arrondissement même. "}${neighbourParks.length ? `En élargissant un peu : ${neighbourParks.slice(0, 4).join(", ")}. ` : ""}${e.counts.water ? `Et ${nb(e.counts.water, "point d'eau", "points d'eau")} sur le trajet, utiles en été.` : ""}`,
  });
  return faq;
}

export default function ParisLocalPlaces({ slug, mode }: { slug: string; mode: Mode }) {
  const e = DATA[slug];
  if (!e) return null;
  const a = ord(e.n);
  const c = e.counts;
  const vets = e.places.filter((p) => p.cat === "vet");
  const shops = e.places.filter((p) => p.cat === "shop" || p.cat === "groomer");
  const others = e.places.filter((p) => p.cat === "dogpark");
  const greens = e.greens || [];
  const base = mode === "owner" ? "/garde-animaux" : "/devenir-petsitter";
  const faq = parisFaq(slug, mode);

  return (
    <>
      <section className="mt-12">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          {mode === "owner" ? `Paris ${a} en chiffres` : `Paris ${a} côté pet sitter`}
        </h2>
        <p className="mt-3 text-sm leading-relaxed text-ink-muted">{stats(e, mode)}</p>
      </section>

      {vets.length > 0 && (
        <section className="mt-10">
          <h2 className="font-display text-xl font-extrabold text-ink">
            Vétérinaires du {a}
            {e.vetHours ? <span className="ml-2 text-sm font-semibold text-ink-muted">(ouverts : {e.vetSat} le sam., {e.vetSun} le dim.)</span> : null}
          </h2>
          <p className="mt-2 text-sm text-ink-muted">
            {mode === "owner" ? "En cas de besoin, les plus proches de chez vous." : "À connaître avant une première garde dans le quartier."}
          </p>
          <PlaceList items={vets} />
        </section>
      )}

      {shops.length > 0 && (
        <section className="mt-10">
          <h2 className="font-display text-xl font-extrabold text-ink">Commerces animaliers du {a}</h2>
          <p className="mt-2 text-sm text-ink-muted">
            {mode === "owner" ? "Pour les croquettes, la litière ou un accessoire de dernière minute." : "Des adresses utiles si un client vous en parle."}
          </p>
          <PlaceList items={shops} />
        </section>
      )}

      {others.length > 0 && (
        <section className="mt-10">
          <h2 className="font-display text-xl font-extrabold text-ink">Espaces canins du {a}</h2>
          <p className="mt-2 text-sm text-ink-muted">
            {mode === "owner" ? "Les sorties habituelles du quartier." : "De bons points de rendez-vous avec vos premiers clients."}
          </p>
          <PlaceList items={others} />
        </section>
      )}

      {greens.length > 0 && (
        <section className="mt-10">
          <h2 className="font-display text-xl font-extrabold text-ink">Jardins du {a}</h2>
          <p className="mt-2 text-sm text-ink-muted">
            {mode === "owner" ? "Pour une promenade calme près de chez vous." : "De quoi varier les balades, garde après garde."}
          </p>
          <ul className="mt-3 flex flex-wrap gap-2 text-sm">
            {greens.map((g) => (
              <li key={g.title} className="rounded-full bg-bg-soft px-3 py-1.5 text-ink">
                {g.title}
                {hours(g.hours) ? <span className="text-xs text-ink-muted"> · {hours(g.hours)}</span> : null}
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="mt-10">
        <h2 className="font-display text-xl font-extrabold text-ink">Balades canines, {a}</h2>
        <p className="mt-3 text-sm leading-relaxed text-ink-muted">{walks(e, mode)}</p>
      </section>

      {/* 29/09 (SAM) — l'ancien bloc « Voisins du Ne » + lien Paris vit
          maintenant dans CityLinks (voisins, Paris, petite couronne, page
          jumelle), posé par OwnerCityPage / RecruitCityPage : pas de doublon. */}

      {faq.length > 0 && (
        <section className="mt-10">
          <h2 className="font-display text-xl font-extrabold text-ink">Questions fréquentes, Paris {a}</h2>
          <div className="mt-4 space-y-4">
            {faq.map((f) => (
              <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
                <h3 className="font-bold text-ink">{f.q}</h3>
                <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
              </div>
            ))}
          </div>
        </section>
      )}

      <p className="mt-10 rounded-2xl bg-bg-soft p-5 text-sm leading-relaxed text-ink-muted">
        <Link href="/pawmap" className="font-semibold text-owner hover:underline">Paris {a} sur la PawMap →</Link>
      </p>
    </>
  );
}
