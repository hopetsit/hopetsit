import Link from "next/link";
import { usGuide } from "@/components/UsLocalGuide";
import type { RecruitCity } from "@/lib/recruit-cities";

// 07/11 (GUS) — Search Console 28 j (France) : les pages /garde-animaux/<ville> hors Paris sortent
// en 13e-20e place avec 0 clic sur « garde chat <ville> » (Vitry 36 affichages, Antony 19,
// Rueil 19, Massy 17), « garde de chien <ville> » (Vitry 24, Antony 19) et « dog sitter »
// (La Rochelle 30, Annecy 22, Metz 23, Brest 19…). La page ne disait des chats et des chiens
// qu'une ligne chacun. Même remède que sur les pages US du 11-12/10 (blocs « Cat sitting in »
// / « Dog sitting in », suivis d'une hausse des clics) : deux blocs propriétaire FR, texte vrai
// (visites à domicile, nuits sur place, promenades suivies), aucun chiffre inventé ; quartiers et
// lieux de promenade pris dans le guide local quand la ville en a un, rien sinon.
export default function FrOwnerBlocks0711({ city }: { city: RecruitCity }) {
  // La page /garde-animaux/paris a son propre guide (sections du 20/10 et du 01/11) : on n'y touche pas.
  if (city.lang !== "fr" || city.slug === "paris") return null;
  const g = usGuide(city.slug, "fr");
  const name = city.name;
  const hoods = g?.hoods.slice(0, 3).join(", ");
  const walks = g?.walks.slice(0, 2).map((w) => w.name).join(" ou ");
  const Puce = ({ t }: { t: string }) => (
    <li className="flex gap-2 text-sm leading-relaxed text-ink-muted">
      <span aria-hidden="true" className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
      <span>{t}</span>
    </li>
  );
  return (
    <section className="mt-10" data-fr-blocks-0711>
      <div aria-labelledby="fr-garde-chat">
        <h2 id="fr-garde-chat" className="font-display text-2xl font-extrabold text-ink">{`Garde de chat à ${name} : visites à domicile`}</h2>
        <p className="mt-3 text-sm leading-relaxed text-ink-muted">
          {`La plupart des chats sont plus heureux chez eux qu'en pension. Un gardien de chat à ${name} passe chez toi une ou deux fois par jour : croquettes et eau fraîche, litière propre, jeu ou simple compagnie, médicaments si ton chat en a besoin, et une photo ou un petit mot après chaque visite dans l'app.`}
          {hoods ? ` Les gardiens qui proposent des visites habitent dans ces quartiers et aux alentours : ${hoods}.` : ""}
        </p>
        <ul className="mt-3 space-y-2">
          <Puce t="Publie une demande de visites pour chat avec tes dates et le nombre de passages par jour souhaité ; les gardiens près de chez toi répondent dans l'app." />
          <Puce t="Discute d'abord, réserve ensuite : le montant reste bloqué dans l'app jusqu'à la fin des visites." />
          <Puce t={`Absence plus longue ? Demande un gardien qui peut aussi dormir sur place, pour que ton chat garde ses habitudes à ${name}.`} />
        </ul>
        <p className="mt-3 text-sm leading-relaxed text-ink-muted">
          Première fois ?{" "}
          <Link href="/blog/faire-garder-son-chat-a-paris" className="font-semibold text-owner underline">
            Faire garder son chat : ce qui se passe à chaque visite et combien de passages prévoir
          </Link>
          .
        </p>
      </div>
      <div className="mt-8" aria-labelledby="fr-garde-chien">
        <h2 id="fr-garde-chien" className="font-display text-2xl font-extrabold text-ink">{`Garde de chien à ${name} : à domicile, promenades comprises`}</h2>
        <p className="mt-3 text-sm leading-relaxed text-ink-muted">
          {`Un dog sitter (c'est le nom anglais du gardien de chien) à ${name} garde ton chien chez toi, dans ses habitudes : il dort sur place ou passe plusieurs fois par jour pour les repas, le jeu et les sorties, et t'envoie une photo ou un petit mot après chaque passage. Les promenades sont suivies en direct sur la carte : tu vois quand ton chien est sorti et combien de temps.`}
          {walks ? ` Lieux de promenade à proximité : ${walks}.` : ""}
        </p>
        <ul className="mt-3 space-y-2">
          <Puce t="Week-end ou vacances ? Demande un gardien qui dort chez toi, ou des visites quotidiennes si ton chien supporte bien la nuit seul." />
          <Puce t="Journées de travail à rallonge ? Réserve une visite de midi avec promenade, à l'heure qui t'arrange." />
          <Puce t={`Publie tes dates et les besoins de ton chien ; les gardiens près de chez toi à ${name} te répondent dans l'app. Tu discutes d'abord, tu lis les avis, et le montant reste dans l'app jusqu'à la fin de la garde.`} />
        </ul>
        <p className="mt-3 text-sm leading-relaxed text-ink-muted">
          Première fois ?{" "}
          <Link href="/blog/dog-sitter-paris" className="font-semibold text-owner underline">
            Dog sitter : garde à domicile, visites ou nuits sur place, et comment choisir
          </Link>
          .
        </p>
      </div>
    </section>
  );
}
