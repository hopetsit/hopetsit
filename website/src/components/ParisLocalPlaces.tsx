import Link from "next/link";
import PLACES from "@/lib/paris-places.json";

// v562 — SEO Paris (Search Console 17/09 : les 20 arrondissements « détectés, non
// indexés », 21 phrases sur 27 identiques d'une page à l'autre). Contenu réel et
// unique par arrondissement : les lieux animaliers de la PawMap autour du
// quartier (données `paris_places_build.py`) + liens vers les arrondissements
// voisins. Affiché sur /garde-animaux/paris-N et /devenir-petsitter/paris-N.

type Place = { title: string; cat: string; address: string; hours: string; m: number };
type Entry = { n: number; counts: Record<string, number>; places: Place[]; neighbours: number[] };

const CAT: Record<string, string> = {
  vet: "Vétérinaire", groomer: "Toiletteur", shop: "Animalerie", park: "Parc", hotel: "Hôtel pet-friendly",
  restaurant: "Restaurant pet-friendly", trainer: "Éducateur", beach: "Plage", water: "Point d'eau", other: "Lieu",
};
const ord = (n: number) => (n === 1 ? "1er" : `${n}e`);
const plural = (k: number, one: string, many: string) => `${k} ${k > 1 ? many : one}`;


// Questions-réponses construites à partir des lieux réels : un texte différent par arrondissement.
function localFaq(e: Entry, mode: "owner" | "recruit"): { q: string; a: string }[] {
  const a = ord(e.n);
  const by = (cat: string) => e.places.filter((p) => p.cat === cat);
  const fmt = (p: Place) => `${p.title}${p.address ? ` (${p.address})` : ""}${p.hours ? `, ouvert ${p.hours}` : ""}`;
  const vets = by("vet"), shops = by("shop"), groomers = by("groomer"), parks = by("park");
  const voisins = e.neighbours.map((v) => ord(v)).join(", ");
  const out: { q: string; a: string }[] = [];
  out.push({
    q: `Où trouver un vétérinaire près de Paris ${a} ?`,
    a: vets.length
      ? `Autour du ${a}, la PawMap indique notamment ${vets.slice(0, 3).map(fmt).join(" ; ")}. ${e.counts.vet && e.counts.vet > vets.length ? `Au total, ${e.counts.vet} cabinets et cliniques sont répertoriés dans le secteur.` : ""} Votre pet sitter HoPetSit peut vous y conduire en cas de besoin.`
      : `La PawMap recense ${e.counts.vet || 0} cabinet(s) vétérinaire(s) autour du ${a} ; les arrondissements voisins (${voisins}) en comptent d'autres, consultables sur la carte.`,
  });
  const shopping = [...shops, ...groomers];
  if (shopping.length)
    out.push({
      q: `Animaleries et toiletteurs dans le ${a} : lesquels sont proches ?`,
      a: `Près du ${a} : ${shopping.slice(0, 3).map(fmt).join(" ; ")}. ${mode === "owner" ? "Pratique pour confier à votre pet sitter la liste des croquettes ou un rendez-vous de toilettage pendant votre absence." : "Des adresses utiles à connaître quand on garde les animaux des voisins."}`,
    });
  out.push({
    q: `Où promener un chien autour de Paris ${a} ?`,
    a: `${parks.length ? `Espaces verts proches repérés sur la PawMap : ${parks.map((p) => p.title).join(", ")}. ` : ""}${e.counts.water ? `On compte aussi ${e.counts.water} points d'eau dans le secteur, utiles en été. ` : ""}Pour varier les balades, les arrondissements voisins (${voisins}) sont accessibles à pied${mode === "owner" ? ", et la promenade est suivie en direct dans l'app." : "."}`,
  });
  return out;
}

export default function ParisLocalPlaces({ slug, mode }: { slug: string; mode: "owner" | "recruit" }) {
  const e = (PLACES as Record<string, Entry>)[slug];
  if (!e) return null;
  const c = e.counts;
  const parts = [
    c.vet ? plural(c.vet, "vétérinaire", "vétérinaires") : "",
    c.shop ? plural(c.shop, "animalerie", "animaleries") : "",
    c.groomer ? plural(c.groomer, "toiletteur", "toiletteurs") : "",
    c.park ? plural(c.park, "parc ou square", "parcs et squares") : "",
    c.water ? plural(c.water, "point d'eau", "points d'eau") : "",
  ].filter(Boolean);
  const base = mode === "owner" ? "/garde-animaux" : "/devenir-petsitter";
  const intro =
    mode === "owner"
      ? `Autour du ${ord(e.n)} arrondissement, la PawMap HoPetSit recense ${parts.join(", ")}. Pratique pour votre pet sitter : il sait où trouver un vétérinaire ouvert ou un point d'eau pendant la promenade.`
      : `Autour du ${ord(e.n)} arrondissement, la PawMap HoPetSit recense ${parts.join(", ")} : les propriétaires du quartier ont des animaux à faire garder et promener toute l'année.`;
  return (
    <section className="mt-14">
      <h2 className="font-display text-2xl font-extrabold text-ink">
        {mode === "owner" ? `Les lieux pour animaux autour de Paris ${ord(e.n)}` : `Le quartier du ${ord(e.n)} pour un pet sitter`}
      </h2>
      <p className="mt-3 text-sm leading-relaxed text-ink-muted">{intro}</p>
      {e.places.length > 0 && (
        <ul className="mt-5 grid gap-3 md:grid-cols-2">
          {e.places.map((p) => (
            <li key={p.title} className="rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
              <p className="text-xs font-semibold uppercase tracking-wide text-owner">{CAT[p.cat] || "Lieu"}</p>
              <p className="mt-1 font-bold text-ink">{p.title}</p>
              {p.address && <p className="mt-0.5 text-sm text-ink-muted">{p.address}</p>}
              {p.hours && <p className="mt-0.5 text-xs text-ink-muted">Horaires : {p.hours}</p>}
            </li>
          ))}
        </ul>
      )}
      <p className="mt-4 text-sm">
        <Link href="/pawmap" className="font-semibold text-owner hover:underline">Voir tous les lieux sur la PawMap →</Link>
      </p>
      <div className="mt-8 space-y-4">
        {localFaq(e, mode).map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>
      <div className="mt-8">
        <p className="text-sm font-semibold text-ink">Arrondissements voisins</p>
        <ul className="mt-2 flex flex-wrap gap-2 text-sm">
          {e.neighbours.map((v) => (
            <li key={v}>
              <Link href={`${base}/paris-${v}`} className="inline-block rounded-full bg-bg-soft px-3 py-1.5 text-ink hover:bg-owner-light hover:text-owner-dark">
                {mode === "owner" ? `Pet sitter Paris ${ord(v)}` : `Devenir pet sitter Paris ${ord(v)}`}
              </Link>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
