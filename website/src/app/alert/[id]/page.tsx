import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

// v552 — PAGE DE PARTAGE D'UN SIGNALEMENT / D'UN SOS ANIMAL.
//
// Daniel : « quand on partage un lien, selon ce qu'on partage, que ça tombe
// sur la chose précise ». Un SOS animal perdu partagé sur WhatsApp doit
// afficher l'alerte elle-même — type, lieu, photo — et pas une page d'accueil.
// Celui qui a l'app est renvoyé dessus par le lien universel ; celui qui ne
// l'a pas voit quand même l'alerte ici et peut aider.
//
// ⚠️ RÈGLE PROJET : page vue par des robots (aperçu de partage) → composant
// SERVEUR, jamais "use client".

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ??
  "https://hopetsit-backend.onrender.com/api/v1";

const SITE = "https://www.hopetsit.com";

type Report = {
  id: string;
  type: string;
  note: string;
  photoUrl: string;
  city: string;
  lat: number | null;
  lng: number | null;
  isSos: boolean;
  createdAt: string;
  expiresAt: string;
};

const TYPE_EMOJI: Record<string, string> = {
  lost_pet: "🆘",
  found_pet: "🐾",
  aggressive_dog: "⚠️",
  hazard: "⚠️",
  water_active: "💧",
  dead_animal: "💀",
  food: "🍖",
  trash: "🗑️",
  vet_open: "🏥",
};

const TYPE_LABEL: Record<string, string> = {
  lost_pet: "Animal perdu",
  found_pet: "Animal trouvé",
  aggressive_dog: "Chien agressif",
  hazard: "Danger",
  water_active: "Point d'eau",
  dead_animal: "Animal décédé",
  food: "Nourriture",
  trash: "Déchets",
  vet_open: "Vétérinaire ouvert",
};

async function getReport(id: string): Promise<Report | null> {
  try {
    const r = await fetch(`${API_BASE}/map-reports/public/${id}`, {
      // Une alerte vit 48 h et peut évoluer : cache court.
      next: { revalidate: 60 },
    });
    if (!r.ok) return null;
    return (await r.json()) as Report;
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
  const report = await getReport(id);
  if (!report) return { title: "Alerte introuvable | HoPetSit" };

  const emoji = TYPE_EMOJI[report.type] ?? "🔔";
  const label = TYPE_LABEL[report.type] ?? "Signalement";
  const where = report.city ? ` à ${report.city}` : "";
  const title = report.isSos
    ? `🆘 SOS animal perdu${where} | HoPetSit`
    : `${emoji} ${label}${where} | HoPetSit`;
  const description =
    report.note?.trim() ||
    (report.isSos
      ? `Un animal a été signalé perdu${where}. Ouvre la PawMap pour voir où et aider à le retrouver.`
      : `${label} signalé${where} par la communauté HoPetSit sur la PawMap.`);
  const image = report.photoUrl || `${SITE}/og-image.png`;
  const url = `${SITE}/alert/${report.id}`;

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
      images: [{ url: image, width: 1200, height: 630, alt: label }],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [image],
    },
  };
}

export default async function AlertPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const report = await getReport(id);
  if (!report) notFound();

  const emoji = TYPE_EMOJI[report.type] ?? "🔔";
  const label = TYPE_LABEL[report.type] ?? "Signalement";
  const expired = new Date(report.expiresAt).getTime() < Date.now();
  const mapLink =
    report.lat != null && report.lng != null
      ? `/map?lat=${report.lat}&lng=${report.lng}&z=15`
      : "/map";
  const directions =
    report.lat != null && report.lng != null
      ? `https://www.google.com/maps/search/?api=1&query=${report.lat},${report.lng}`
      : null;

  return (
    <main className="mx-auto max-w-2xl px-4 py-10">
      <div className="overflow-hidden rounded-3xl border border-black/10 bg-white shadow-sm">
        {report.photoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={report.photoUrl}
            alt={label}
            className="h-64 w-full object-cover"
          />
        ) : (
          <div
            className="flex h-40 w-full items-center justify-center text-6xl"
            style={{ background: report.isSos ? "#FBEAE8" : "#FCEDE4" }}
          >
            {emoji}
          </div>
        )}

        <div className="p-6">
          <div
            className="mb-2 inline-flex items-center gap-2 rounded-full px-3 py-1 text-sm font-semibold"
            style={
              report.isSos
                ? { background: "#FBEAE8", color: "#CE3B2C" }
                : { background: "#FCEDE4", color: "#E8551C" }
            }
          >
            <span>{emoji}</span>
            <span>{report.isSos ? "SOS animal perdu" : label}</span>
          </div>

          <h1 className="font-display text-2xl font-extrabold text-ink">
            {report.isSos ? "Un animal est perdu" : label}
            {report.city ? ` — ${report.city}` : ""}
          </h1>

          {report.note && (
            <p className="mt-4 whitespace-pre-line text-[15px] leading-relaxed text-black/80">
              {report.note}
            </p>
          )}

          <p className="mt-3 text-sm text-black/60">
            {expired
              ? "Cette alerte a expiré."
              : "Alerte active — les membres autour ont été prévenus."}
          </p>

          <div className="mt-7 flex flex-col gap-3 sm:flex-row">
            <Link
              href={mapLink}
              className="flex-1 rounded-2xl bg-owner px-5 py-3 text-center font-semibold text-white"
            >
              Voir sur la PawMap
            </Link>
            {directions && (
              <a
                href={directions}
                target="_blank"
                rel="noopener noreferrer"
                className="flex-1 rounded-2xl border border-black/15 px-5 py-3 text-center font-semibold text-ink"
              >
                Itinéraire
              </a>
            )}
          </div>

          <p className="mt-6 text-center text-sm text-black/60">
            Tu peux aider : signale-le si tu le vois —{" "}
            <Link href="/download" className="font-semibold text-owner underline">
              télécharge HoPetSit
            </Link>
          </p>
        </div>
      </div>
    </main>
  );
}
