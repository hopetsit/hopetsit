"use client";

// Page de suivi en direct d'une réservation — /walk/<bookingId>.
//
// Le propriétaire ouvre cette page pendant que le gardien ou le promeneur
// s'occupe de son animal. L'app du prestataire envoie sa position ; le serveur
// la relaie (`map:friend-position`) et la carte la suit.
//
// 05/10/2026 (612, LEO) — même rendu que l'app : un seul tracé violet (nettoyé
// par le serveur puis lissé), la photo de la personne suivie, une lueur
// discrète ; textes dans les 9 langues du site ; couleurs pleines (zéro gris).

import dynamic from "next/dynamic";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import type { TrailPoint } from "@/lib/trail612";
import { useT } from "@/lib/i18n/LanguageProvider";
import BackLink from "@/components/BackLink";
import {
  ApiError,
  Booking,
  getBookingDetail,
  getFriendsLivePositions,
  getProviderLocation,
  getStoredUser,
  ProviderLocation,
} from "@/lib/api";
import { useSocket } from "@/lib/useSocket";

// Leaflet n'aime pas le SSR → composant chargé côté navigateur seulement.
function MapLoading() {
  const { t } = useT();
  return (
    <div className="flex h-[60vh] min-h-[400px] items-center justify-center rounded-[28px] border border-[#F1D9CC] bg-[#FFF7F2] text-sm font-semibold text-[#6E4F48]">
      {t("map_loading_map")}
    </div>
  );
}
const WalkLiveMap = dynamic(() => import("@/components/WalkLiveMap"), { ssr: false, loading: () => <MapLoading /> });

/** Tracé [lat, lng][] renvoyé par le serveur (déjà nettoyé), ou liste vide. */
function readTrail(v: unknown): TrailPoint[] {
  if (!Array.isArray(v)) return [];
  const out: TrailPoint[] = [];
  for (const q of v) {
    if (Array.isArray(q) && q.length >= 2 && Number.isFinite(Number(q[0])) && Number.isFinite(Number(q[1]))) out.push([Number(q[0]), Number(q[1])]);
  }
  return out;
}

const STATUS_STYLE: Record<string, { bg: string; ink: string }> = {
  paid: { bg: "#E9F7EE", ink: "#1F7A37" },
  completed: { bg: "#E9F7EE", ink: "#1F7A37" },
  cancelled: { bg: "#FDE7E2", ink: "#9E1F0B" },
  rejected: { bg: "#FDE7E2", ink: "#9E1F0B" },
};

export default function WalkPage() {
  const params = useParams<{ bookingId: string }>();
  const bookingId = params.bookingId;

  const { t, lang } = useT();
  const router = useRouter();
  const [booking, setBooking] = useState<Booking | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  // v23.1 part 240 — Daniel : "fix le sur le site web aussi". Avant : la
  // carte s'ouvrait centree sur Paris jusqu'a recevoir un event socket
  // du walker. Maintenant : on fetch sa derniere position connue via
  // /bookings/:id/provider-location au load, et on passe initialPosition
  // a WalkLiveMap → la carte ouvre directement sur la geoloc du sitter/
  // walker, et le halo couleur correspond au role.
  const [providerLoc, setProviderLoc] = useState<ProviderLocation | null>(null);
  // 612 — tracé de la balade déjà nettoyé par le serveur (sauts GPS retirés).
  const [serverTrail, setServerTrail] = useState<TrailPoint[]>([]);

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
          setError("not_found");
          return;
        }
        setBooking(b);
        // v240 — fetch provider's last known position (en parallele,
        // best-effort : si 204/402/409 on continue, la carte s'affichera
        // vide jusqu'au 1er event socket).
        try {
          const loc = await getProviderLocation(bookingId);
          if (loc) setProviderLoc(loc);
        } catch (_) {/* defensive — silently fail */}
        // 612 — le direct du prestataire EN SERVICE pour moi (amis ou non) :
        // la même route que la PawMap, avec son tracé nettoyé par le serveur.
        try {
          const live = await getFriendsLivePositions();
          const pid = b.walkerId || b.sitterId;
          const mine = live.find((p) => (p as { bookingId?: string }).bookingId === bookingId)
            || live.find((p) => !!pid && (p.userId === pid || ((p as { personIds?: string[] }).personIds || []).includes(pid)));
          if (mine) setServerTrail(readTrail((mine as { trail?: unknown }).trail));
        } catch (_) {/* tracé indisponible : il se dessinera avec les points reçus */}
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }
        setError(e instanceof Error && e.message ? e.message : "error");
      } finally {
        setLoading(false);
      }
    })();
  }, [bookingId, router]);

  if (loading) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-24 text-center font-semibold text-[#6E4F48]">
        {t("common_loading")}
      </div>
    );
  }

  if (!booking) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-24" data-walk-error={error || ""}>
        <BackLink href="/bookings" label={t("dash_card_bookings_title")} />
        <p className="mt-6 text-center font-semibold text-[#6E4F48]">{t("common_error_generic")}</p>
      </div>
    );
  }

  // La personne à suivre (le prestataire de la réservation).
  const walkerId = booking.walkerId || booking.sitterId;
  const walkerName = providerLoc?.providerName || booking.walkerName || booking.sitterName || t("common_member");
  const walkerRole: "walker" | "sitter" = providerLoc?.providerRole || (booking.walkerId ? "walker" : "sitter");
  const statusKey = `booking_status_${booking.status}`;
  const statusLabel = t(statusKey) === statusKey ? "" : t(statusKey);
  const statusStyle = STATUS_STYLE[booking.status] || { bg: "#FCEDE4", ink: "#9E1F0B" };
  let dateLabel = "";
  if (booking.serviceDate) {
    try { dateLabel = new Date(booking.serviceDate).toLocaleDateString(lang, { day: "numeric", month: "short", year: "numeric" }); } catch { dateLabel = ""; }
  }

  return (
    <div className="mx-auto max-w-4xl px-4 py-10 md:py-16">
      <div className="mb-6">
        <BackLink href="/bookings" label={t("dash_card_bookings_title")} />
      </div>

      <h1 className="break-words font-display text-[26px] font-extrabold leading-tight tracking-[-0.02em] text-[#231715] md:text-4xl">
        {t("map_following").replace("{name}", walkerName)}
      </h1>
      <p className="mt-2 text-[15px] leading-snug text-[#3B2A26]">{t("hiw_track_body")}</p>

      <div className="mt-6">
        <WalkLiveMap
          walkerId={walkerId}
          walkerName={walkerName}
          walkerRole={walkerRole}
          walkerAvatar={providerLoc?.providerAvatar}
          initialTrail={serverTrail}
          initialPosition={
            providerLoc?.coordinates
              ? { lat: providerLoc.coordinates.lat, lng: providerLoc.coordinates.lng, at: providerLoc.updatedAt || undefined }
              : undefined
          }
        />
      </div>

      <div className="mt-5 flex flex-wrap items-center gap-2.5 rounded-[22px] border border-[#F1D9CC] bg-white px-4 py-3.5 text-sm shadow-[0_14px_30px_-24px_rgba(201,42,18,0.55)]">
        <span className="rounded-full bg-[#FFF7F2] px-3 py-1 font-mono text-xs font-semibold text-[#6E4F48]">#{booking.id.slice(-6)}</span>
        <span className="min-w-0 break-words font-bold text-[#231715]">{walkerName}</span>
        {dateLabel && <span className="font-semibold text-[#6E4F48]">· {dateLabel}</span>}
        {statusLabel && (
          <span className="ml-auto rounded-full px-3 py-1 text-xs font-extrabold" style={{ background: statusStyle.bg, color: statusStyle.ink }}>{statusLabel}</span>
        )}
      </div>
    </div>
  );
}
