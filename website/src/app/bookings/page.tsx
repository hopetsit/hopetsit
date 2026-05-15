"use client";

// v23.1 part 146 — Page "Mes réservations".
// Owner voit ses bookings créés. Sitter/Walker voit les bookings où il est
// service provider. Actions accept/decline disponibles pour les sitter/walker
// quand le booking est en `pending`. Refresh temps réel via socket events
// `booking:accepted` / `booking:paid`.

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  ApiError,
  AuthUser,
  Booking,
  BookingStatus,
  getMyBookings,
  getStoredUser,
  respondToBooking,
} from "@/lib/api";
import { useSocketEvent } from "@/lib/useSocket";

const STATUS_LABELS: Record<BookingStatus, { label: string; color: string }> = {
  pending: { label: "En attente", color: "bg-amber-100 text-amber-800" },
  accepted: { label: "Acceptée", color: "bg-blue-100 text-blue-800" },
  agreed: { label: "Confirmée", color: "bg-blue-100 text-blue-800" },
  paid: { label: "Payée", color: "bg-green-100 text-green-800" },
  completed: { label: "Terminée", color: "bg-slate-100 text-slate-700" },
  cancelled: { label: "Annulée", color: "bg-red-100 text-red-700" },
  rejected: { label: "Refusée", color: "bg-red-100 text-red-700" },
  refunded: { label: "Remboursée", color: "bg-slate-100 text-slate-700" },
};

export default function BookingsPage() {
  const { t } = useT();
  const router = useRouter();
  const [user, setUser] = useState<AuthUser | null>(null);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [respondingId, setRespondingId] = useState<string | null>(null);

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace("/login");
      return;
    }
    setUser(u);
    refresh();
  }, [router]);

  async function refresh() {
    setLoading(true);
    setError(null);
    try {
      const list = await getMyBookings();
      // Tri : pending d'abord (pour les sitter/walker), puis par date
      list.sort((a, b) => {
        if (a.status === "pending" && b.status !== "pending") return -1;
        if (b.status === "pending" && a.status !== "pending") return 1;
        const da = new Date(a.serviceDate || a.createdAt || 0).getTime();
        const db = new Date(b.serviceDate || b.createdAt || 0).getTime();
        return db - da;
      });
      setBookings(list);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }
      setError(e instanceof Error ? e.message : "Failed to load bookings");
    } finally {
      setLoading(false);
    }
  }

  async function handleRespond(id: string, action: "accept" | "reject") {
    if (
      action === "reject" &&
      !confirm("Refuser cette demande ? Le client devra recommencer.")
    ) {
      return;
    }
    setRespondingId(id);
    try {
      const updated = await respondToBooking(id, action);
      setBookings((list) =>
        list.map((b) => (b.id === id ? { ...b, ...updated } : b)),
      );
    } catch (e) {
      alert(e instanceof Error ? e.message : "Failed to respond");
    } finally {
      setRespondingId(null);
    }
  }

  // v23.1 part 146 — refresh live quand un booking change via socket.
  useSocketEvent<{ bookingId: string; status?: string }>(
    "booking:accepted",
    () => refresh(),
  );
  useSocketEvent<{ bookingId: string; status?: string }>("booking:paid", () =>
    refresh(),
  );

  if (loading) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-24 text-center text-ink-muted">
        {t("common_loading")}
      </div>
    );
  }

  const isOwner = user?.role === "owner";

  return (
    <div className="mx-auto max-w-3xl px-4 py-12 md:py-16">
      <div className="mb-6 flex items-center justify-between">
        <Link href="/dashboard" className="text-sm text-ink-muted hover:text-ink">
          ← Dashboard
        </Link>
        <button
          type="button"
          onClick={refresh}
          className="text-xs text-ink-muted hover:text-ink"
        >
          ↻ Actualiser
        </button>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        Mes réservations
      </h1>
      <p className="mt-2 text-ink-muted">
        {isOwner
          ? "Suivi de tes demandes de pet-sitting / promenade."
          : "Les demandes que tu as reçues. Réponds rapidement pour augmenter ton taux d'acceptation."}
      </p>

      {error && (
        <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {bookings.length === 0 ? (
        <div className="mt-12 rounded-3xl border border-dashed border-ink/15 px-6 py-16 text-center">
          <p className="text-2xl">📭</p>
          <p className="mt-3 font-semibold text-ink">Aucune réservation pour l&apos;instant</p>
          <p className="mt-1 text-sm text-ink-muted">
            {isOwner
              ? "Trouve un sitter ou walker dans l'app pour créer ta première demande."
              : "Quand un owner choisira ton profil, sa demande apparaîtra ici."}
          </p>
        </div>
      ) : (
        <div className="mt-8 space-y-3">
          {bookings.map((booking) => (
            <BookingCard
              key={booking.id}
              booking={booking}
              isOwner={isOwner}
              responding={respondingId === booking.id}
              onAccept={() => handleRespond(booking.id, "accept")}
              onReject={() => handleRespond(booking.id, "reject")}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function BookingCard({
  booking,
  isOwner,
  responding,
  onAccept,
  onReject,
}: {
  booking: Booking;
  isOwner: boolean;
  responding: boolean;
  onAccept: () => void;
  onReject: () => void;
}) {
  const statusInfo = STATUS_LABELS[booking.status] || {
    label: booking.status,
    color: "bg-slate-100 text-slate-700",
  };
  const showActions = !isOwner && booking.status === "pending";
  const counterpart = isOwner
    ? booking.sitterName || booking.walkerName || "Service provider"
    : booking.ownerName || "Owner";
  const price = booking.basePrice ?? booking.totalAmount ?? 0;
  const currency = booking.currency || "EUR";

  return (
    <div className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <span className="font-semibold text-ink">{counterpart}</span>
            <span className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${statusInfo.color}`}>
              {statusInfo.label}
            </span>
          </div>
          <div className="mt-1 text-xs text-ink-muted">
            {booking.serviceType || "Pet care"}
            {booking.serviceDate && (
              <>
                {" · "}
                {new Date(booking.serviceDate).toLocaleDateString("fr-FR", {
                  day: "numeric",
                  month: "short",
                  year: "numeric",
                })}
              </>
            )}
            {price > 0 && (
              <>
                {" · "}
                <span className="font-semibold text-ink">
                  {price} {currency}
                </span>
              </>
            )}
          </div>
        </div>
        <div className="text-xs text-ink-muted">
          #{booking.id.slice(-6)}
        </div>
      </div>

      {showActions && (
        <div className="mt-4 flex gap-2">
          <button
            type="button"
            onClick={onAccept}
            disabled={responding}
            className="flex-1 rounded-full bg-green-600 px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-60"
          >
            {responding ? "…" : "Accepter"}
          </button>
          <button
            type="button"
            onClick={onReject}
            disabled={responding}
            className="rounded-full border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-50 disabled:opacity-60"
          >
            Refuser
          </button>
        </div>
      )}

      {booking.status === "paid" && (
        <div className="mt-3 flex items-center justify-between rounded-xl bg-green-50 px-3 py-2 text-xs text-green-800">
          <span>
            ✓ Paiement reçu{" "}
            {booking.paidAt &&
              `le ${new Date(booking.paidAt).toLocaleDateString("fr-FR")}`}
          </span>
          {/* v23.1 part 146 — bouton suivi live (visible owner uniquement, et
              pour les services walking). */}
          {isOwner &&
            (booking.serviceType || "").toLowerCase().includes("walk") && (
              <Link
                href={`/walk/${booking.id}`}
                className="rounded-full bg-walker px-3 py-1 text-xs font-semibold text-white hover:opacity-90"
              >
                🗺️ Suivre en direct
              </Link>
            )}
        </div>
      )}
    </div>
  );
}
