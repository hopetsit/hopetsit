"use client";

// v23.1 part 146 — Page suivi live d'une promenade.
// URL: /walk/<bookingId>
//
// L'owner ouvre cette page pendant que le sitter/walker promène son animal.
// Le sitter émet des `map:position-update` depuis l'app (rate-limited 1/3s
// côté serveur). Le backend re-émet `map:friend-position` à la user-room
// de l'owner. Cette page écoute cet event et bouge le marker sur la carte.
//
// Carte : Leaflet + OpenStreetMap (pas de Google Maps → pas de billing).

import dynamic from "next/dynamic";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  Booking,
  getBookingDetail,
  getStoredUser,
} from "@/lib/api";
import { useSocket } from "@/lib/useSocket";

// Leaflet n'aime pas le SSR → on importe le composant en dynamic.
const WalkLiveMap = dynamic(() => import("@/components/WalkLiveMap"), {
  ssr: false,
  loading: () => (
    <div className="flex h-[60vh] min-h-[400px] items-center justify-center rounded-2xl border border-ink/5 bg-bg-soft text-ink-muted">
      Chargement de la carte…
    </div>
  ),
});

export default function WalkPage() {
  const params = useParams<{ bookingId: string }>();
  const bookingId = params.bookingId;

  const { t } = useT();
  const router = useRouter();
  const [booking, setBooking] = useState<Booking | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Initialise le socket (au cas où l'user arrive direct sur /walk via URL).
  useSocket();

  useEffect(() => {
    if (!getStoredUser()) {
      router.replace("/login");
      return;
    }
    (async () => {
      try {
        const b = await getBookingDetail(bookingId);
        if (!b) {
          setError("Réservation introuvable.");
          return;
        }
        setBooking(b);
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Loading failed");
      } finally {
        setLoading(false);
      }
    })();
  }, [bookingId, router]);

  if (loading) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-24 text-center text-ink-muted">
        {t("common_loading")}
      </div>
    );
  }

  if (!booking) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-24">
        <Link href="/bookings" className="text-sm text-ink-muted hover:text-ink">
          ← Mes réservations
        </Link>
        <p className="mt-6 text-center text-ink-muted">{error || "Booking introuvable"}</p>
      </div>
    );
  }

  // Identifie le walker/sitter à suivre (peut être null sur les bookings où
  // le provider n'a pas encore commencé sa promenade).
  const walkerId = booking.walkerId || booking.sitterId;
  const walkerName = booking.walkerName || booking.sitterName || "Provider";

  return (
    <div className="mx-auto max-w-4xl px-4 py-12 md:py-16">
      <div className="mb-6">
        <Link href="/bookings" className="text-sm text-ink-muted hover:text-ink">
          ← Mes réservations
        </Link>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        Suivi en direct
      </h1>
      <p className="mt-2 text-ink-muted">
        Position de <span className="font-semibold text-ink">{walkerName}</span> en temps réel.
        Mise à jour automatique à chaque envoi GPS depuis son téléphone.
      </p>

      <div className="mt-8">
        <WalkLiveMap walkerId={walkerId} walkerName={walkerName} />
      </div>

      {/* Info box sous la carte */}
      <div className="mt-6 rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
        <div className="flex flex-wrap items-center gap-3 text-sm">
          <span className="rounded-full bg-bg-soft px-3 py-1 text-xs font-mono text-ink-muted">
            #{booking.id.slice(-6)}
          </span>
          <span className="font-semibold text-ink">{booking.serviceType || "Walk"}</span>
          {booking.serviceDate && (
            <span className="text-ink-muted">
              ·{" "}
              {new Date(booking.serviceDate).toLocaleDateString("fr-FR", {
                day: "numeric",
                month: "short",
                year: "numeric",
              })}
            </span>
          )}
          <span
            className={`ml-auto rounded-full px-2.5 py-0.5 text-xs font-semibold ${
              booking.status === "paid"
                ? "bg-green-100 text-green-800"
                : "bg-slate-100 text-slate-700"
            }`}
          >
            {booking.status}
          </span>
        </div>

        <div className="mt-4 rounded-xl bg-bg-soft px-4 py-3 text-xs text-ink-muted">
          ℹ️ Le marker bouge dès que {walkerName} envoie un nouveau point GPS
          depuis l&apos;app HoPetSit (1× toutes les 3 secondes max). Si la
          carte reste vide, c&apos;est que la promenade n&apos;a pas encore
          commencé ou que le sitter n&apos;a pas activé la géolocalisation.
        </div>
      </div>
    </div>
  );
}
