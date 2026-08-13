import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

// v532 — PAGE DE PARTAGE D'UN PAWSPOT (auto-promotion).
//
// Daniel : « améliore le partage de la carte entre amis sur WhatsApp, Insta
// etc. pour faire de l'auto-pub ». Un lien ne fait de la publicité que s'il
// s'affiche avec un VRAI aperçu — photo, titre, description — dans la
// conversation. Or le reste du site est rendu côté client (i18n dynamique) :
// WhatsApp, Instagram, Messenger et Google n'y voient rien.
//
// Cette page est donc un COMPOSANT SERVEUR STATIQUE, avec `generateMetadata`
// qui produit les balises Open Graph à partir des données réelles du spot.
// Résultat : le lien partagé affiche la photo du lieu, son nom et sa ville,
// puis propose de télécharger l'app. C'est le mécanisme d'acquisition.
//
// ⚠️ RÈGLE PROJET : toute page pensée pour être vue par un robot (partage ou
// SEO) DOIT rester un composant serveur — ne pas ajouter "use client" ici.

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ??
  "https://hopetsit-backend.onrender.com/api/v1";

const SITE = "https://www.hopetsit.com";

type Spot = {
  id: string;
  type: string;
  name: string;
  description: string;
  photoUrl: string;
  city: string;
  lat: number | null;
  lng: number | null;
  likesCount: number;
  validationsCount: number;
  communityValidated: boolean;
  creatorName: string;
};

// Emoji par catégorie — mêmes que sur la carte de l'app.
const TYPE_EMOJI: Record<string, string> = {
  vet: "🩺",
  shop: "🛒",
  groomer: "✂️",
  park: "🌳",
  beach: "🏖️",
  water: "💧",
  trainer: "🎓",
  hotel: "🏨",
  restaurant: "🍽️",
};

const TYPE_LABEL: Record<string, string> = {
  vet: "Vétérinaire",
  shop: "Animalerie",
  groomer: "Toiletteur",
  park: "Parc",
  beach: "Plage",
  water: "Point d'eau",
  trainer: "Éducateur",
  hotel: "Hôtel pet-friendly",
  restaurant: "Restaurant pet-friendly",
};

async function getSpot(id: string): Promise<Spot | null> {
  try {
    const r = await fetch(`${API_BASE}/pawspots/public/${id}`, {
      // Un spot bouge peu : on met en cache 5 min pour ne pas marteler le
      // backend quand un lien devient viral.
      next: { revalidate: 300 },
    });
    if (!r.ok) return null;
    return (await r.json()) as Spot;
  } catch {
    return null;
  }
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const spot = await getSpot(id);
  if (!spot) {
    return { title: "Spot introuvable | HoPetSit" };
  }
  const emoji = TYPE_EMOJI[spot.type] ?? "🐾";
  const label = TYPE_LABEL[spot.type] ?? "Spot";
  const title = spot.city
    ? `${emoji} ${spot.name} — ${label} à ${spot.city} | HoPetSit`
    : `${emoji} ${spot.name} — ${label} | HoPetSit`;
  const description =
    spot.description?.trim() ||
    `${label} recommandé par la communauté HoPetSit${
      spot.city ? ` à ${spot.city}` : ""
    }. Découvre tous les lieux pet-friendly autour de toi sur la PawMap.`;
  // Photo du spot si elle existe, sinon la bannière de partage du site.
  const image = spot.photoUrl || `${SITE}/og-image.png`;
  const url = `${SITE}/spot/${spot.id}`;

  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: {
      type: "article",
      url,
      title,
      description,
      siteName: "HoPetSit",
      images: [{ url: image, width: 1200, height: 630, alt: spot.name }],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [image],
    },
  };
}

export default async function SpotPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const spot = await getSpot(id);
  if (!spot) notFound();

  const emoji = TYPE_EMOJI[spot.type] ?? "🐾";
  const label = TYPE_LABEL[spot.type] ?? "Spot";
  const maps =
    spot.lat != null && spot.lng != null
      ? `https://www.google.com/maps/search/?api=1&query=${spot.lat},${spot.lng}`
      : null;

  return (
    <main className="mx-auto max-w-2xl px-4 py-10">
      <div className="overflow-hidden rounded-3xl border border-black/10 bg-white shadow-sm">
        {spot.photoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={spot.photoUrl}
            alt={spot.name}
            className="h-64 w-full object-cover"
          />
        ) : (
          <div className="flex h-40 w-full items-center justify-center bg-owner-light text-6xl">
            {emoji}
          </div>
        )}

        <div className="p-6">
          <div className="mb-2 inline-flex items-center gap-2 rounded-full bg-amber-50 px-3 py-1 text-sm font-semibold text-amber-700">
            <span>{emoji}</span>
            <span>{label}</span>
            {spot.communityValidated && <span title="Validé par la communauté">🐾</span>}
          </div>

          <h1 className="font-display text-2xl font-extrabold text-ink">
            {spot.name}
          </h1>
          {spot.city && (
            <p className="mt-1 text-sm text-black/60">📍 {spot.city}</p>
          )}

          {spot.description && (
            <p className="mt-4 whitespace-pre-line text-[15px] leading-relaxed text-black/80">
              {spot.description}
            </p>
          )}

          <div className="mt-4 flex flex-wrap gap-4 text-sm text-black/60">
            <span>❤️ {spot.likesCount} j&apos;aime</span>
            <span>✅ {spot.validationsCount} validations</span>
            {spot.creatorName && <span>Ajouté par {spot.creatorName}</span>}
          </div>

          <div className="mt-7 flex flex-col gap-3 sm:flex-row">
            <Link
              href="/download"
              className="flex-1 rounded-2xl bg-owner px-5 py-3 text-center font-semibold text-white"
            >
              Ouvrir dans l&apos;app HoPetSit
            </Link>
            {maps && (
              <a
                href={maps}
                target="_blank"
                rel="noopener noreferrer"
                className="flex-1 rounded-2xl border border-black/15 px-5 py-3 text-center font-semibold text-ink"
              >
                Itinéraire
              </a>
            )}
          </div>

          <p className="mt-6 text-center text-sm text-black/60">
            Des milliers de lieux pet-friendly autour de toi —{" "}
            <Link href="/pawmap" className="font-semibold text-owner underline">
              découvre la PawMap
            </Link>
          </p>
        </div>
      </div>
    </main>
  );
}
