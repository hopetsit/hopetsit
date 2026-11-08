import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import ParisGuidesLinks from "@/components/ParisGuidesLinks";

// 2026-W45 (marketing hebdo, dimanche) — sujet suivant non cochée de
// `marketing/sujets_4poles.md` § Paris (page pilier /garde-animaux/paris#quartiers).
// Angle différent de /blog/faire-garder-son-chat-a-paris (qui détaille les prix) :
// ici, la question posée par le propriétaire d'un chat d'appartement — visite ou
// garde ailleurs — et la logistique d'accès (digicode, clés, voisin). Aucun prix
// inventé : on renvoie vers le guide existant pour les tarifs.
export const metadata: Metadata = {
  title: "Chat d'appartement à Paris : visite à domicile ou garde ailleurs ?",
  description:
    "Chat qui ne bouge pas de son appartement parisien : comment décider entre visites à domicile et garde chez un sitter, et comment organiser l'accès (digicode, clés, voisin).",
  alternates: { canonical: "https://www.hopetsit.com/blog/chat-dappartement-paris" },
};

const FAQ = [
  {
    q: "Mon chat ne sort jamais de l'appartement : faut-il vraiment le déplacer ?",
    a: "Dans la grande majorité des cas, non. Un chat d'appartement est attaché à ses repères : son griffoir, ses cachettes, les bruits de l'immeuble. Le déplacer chez un sitter ajoute un stress (transport, nouveau territoire) qui n'existe pas avec une visite à domicile.",
  },
  {
    q: "Combien de visites par jour pour un chat seul à Paris ?",
    a: "Une visite par jour suffit pour un chat adulte en bonne santé sur deux à trois jours, à condition de laisser assez d'eau et de nourriture en libre accès si besoin. Au-delà de trois jours, ou pour un chaton, deux visites quotidiennes sont plus sûres.",
  },
  {
    q: "Comment donner accès à mon appartement sans remettre mes clés à un inconnu ?",
    a: "Trois solutions courantes à Paris : le gardien ou la conciergerie de l'immeuble gardent un double, une boîte à clés sécurisée est posée sur la porte, ou un voisin de confiance fait la remise en main propre avant votre départ. Choisissez un pet sitter avec identité vérifiée et avis réels avant de trancher.",
  },
  {
    q: "Un chat peut-il rester seul tout un week-end sans visite ?",
    a: "24 à 36 heures maximum, avec eau et croquettes en libre-service, et seulement pour un chat adulte en bonne santé. Au-delà, une visite quotidienne reste nécessaire pour la litière et la surveillance.",
  },
  {
    q: "Comment savoir que la visite a vraiment eu lieu ?",
    a: "Demandez une photo ou un message à chaque passage, directement dans le chat de l'application. Sur HoPetSit, le paiement n'est débloqué qu'une fois le service terminé, ce qui évite les visites fantômes.",
  },
];

export default function ArticleChatAppartementParis() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: "Chat d'appartement à Paris : visite à domicile ou garde ailleurs ?",
        inLanguage: "fr",
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com" },
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
      <p className="text-sm font-semibold text-owner">Guide chat · Paris</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        Chat d&apos;appartement à Paris : visite à domicile ou garde ailleurs ?
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        Un chat qui vit en appartement à Paris n&apos;a souvent connu que ces
        quelques pièces depuis des années. Avant de partir, la vraie question
        n&apos;est pas « combien ça coûte », mais « qui bouge » : votre chat,
        ou juste une personne qui vient chez lui ? La réponse change presque
        tout.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Pourquoi le territoire compte autant
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Contrairement au chien, le chat ne s&apos;attache pas d&apos;abord à
        une personne, mais à un lieu. Ses repères olfactifs, ses cachettes
        préférées, le bruit familier de la cage d&apos;escalier : tout ça
        disparaît dès qu&apos;on le change de maison. Un transport en cage, un
        appartement inconnu, parfois d&apos;autres animaux : la garde ailleurs
        cumule les sources de stress, même chez un sitter bienveillant. C&apos;est
        pour cette raison que la plupart des vétérinaires comportementalistes
        recommandent, par défaut, de laisser le chat chez lui.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Comment trancher entre les deux options
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        La visite à domicile reste la règle pour un chat seul, sociable avec
        les humains, dans un appartement sans danger particulier (fenêtres
        sécurisées, pas de produit toxique accessible). La garde chez un
        sitter devient pertinente dans des cas plus rares : un chat qui
        réclame une présence quasi permanente et une surveillance de santé
        rapprochée, une absence de plusieurs semaines, ou un appartement
        difficile d&apos;accès (travaux, chauffage coupé, ascenseur en panne
        pour un sitter qui doit monter du matériel). Dans le doute, posez la
        question à votre vétérinaire habituel : il connaît le tempérament de
        votre chat mieux que n&apos;importe quel guide en ligne.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        L&apos;accès à l&apos;appartement : le vrai sujet parisien
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        À Paris, la question qui bloque souvent n&apos;est pas le chat, c&apos;est
        la porte. Trois solutions reviennent le plus chez les propriétaires que
        nous accompagnons : le gardien ou la conciergerie de l&apos;immeuble
        garde un double de la clé et laisse entrer le sitter sur présentation
        d&apos;une pièce d&apos;identité ; une boîte à clés sécurisée se fixe
        sur la porte palière, avec un code transmis uniquement le jour J ; ou
        un voisin de confiance fait la remise en main propre avant votre
        départ. Évitez de laisser une clé « sous le paillasson » : préférez
        toujours une solution traçable, et choisissez un sitter dont
        l&apos;identité a été vérifiée avant de lui confier l&apos;accès à
        votre logement.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Ce qu&apos;il faut préparer avant de partir
      </h2>
      <ul className="mt-4 space-y-2">
        {[
          "Une gamelle d'eau en plus si l'absence dépasse deux jours, et des croquettes en quantité visible.",
          "La litière nettoyée juste avant le départ, avec un second bac si vous avez plusieurs chats.",
          "Les coordonnées de votre vétérinaire habituel, et celles d'une clinique ouverte le week-end si besoin.",
          "Un mot écrit sur les habitudes de votre chat : cachettes préférées, ce qui le rassure, un traitement en cours.",
          "La solution d'accès choisie (gardien, boîte à clés, voisin) communiquée au sitter avant le jour J, jamais le matin même.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        Où trouver un sitter près de chez vous
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        Certains quartiers comptent déjà beaucoup de chats en appartement.
        Dans le{" "}
        <Link href="/garde-animaux/paris-4" className="font-semibold text-owner underline">
          4e arrondissement
        </Link>
        , entre le Marais et l&apos;île Saint-Louis, les visites à domicile
        pour chats sont très fréquentes. Même constat dans le{" "}
        <Link href="/garde-animaux/paris-9" className="font-semibold text-owner underline">
          9e
        </Link>
        , du côté de Pigalle et des Grands Boulevards. Pour les tarifs réels
        des visites et de la garde, notre guide{" "}
        <Link href="/blog/faire-garder-son-chat-a-paris" className="font-semibold text-owner underline">
          faire garder son chat à Paris
        </Link>{" "}
        détaille les prix pratiqués. Pour tous les autres arrondissements et
        communes voisines, la page{" "}
        <Link href="/garde-animaux/paris" className="font-semibold text-owner underline">
          pet sitter à Paris
        </Link>{" "}
        réunit l&apos;ensemble.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">Questions fréquentes</h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <ParisGuidesLinks current="/blog/chat-dappartement-paris" />

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Des cat sitters vérifiés près de chez vous
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          Comparez les profils parisiens, lisez les vrais avis et réservez des
          visites en quelques minutes — gratuitement sur HoPetSit.
        </p>
        <Link href="/garde-animaux/paris" className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white">
          Trouver un pet sitter à Paris
        </Link>
      </div>
    </div>
  );
}
