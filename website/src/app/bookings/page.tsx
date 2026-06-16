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
  AuthRole,
  AuthUser,
  Booking,
  BookingStatus,
  getMyBookings,
  getStoredUser,
  respondToBooking,
} from "@/lib/api";
import { ServiceConfirmationCard } from "@/components/ServiceConfirmation";
import { useSocketEvent } from "@/lib/useSocket";

const STATUS_META: Record<BookingStatus, { key: string; color: string }> = {
  pending: { key: "booking_status_pending", color: "bg-amber-100 text-amber-800" },
  accepted: { key: "booking_status_accepted", color: "bg-blue-100 text-blue-800" },
  agreed: { key: "booking_status_agreed", color: "bg-blue-100 text-blue-800" },
  paid: { key: "booking_status_paid", color: "bg-green-100 text-green-800" },
  completed: { key: "booking_status_completed", color: "bg-slate-100 text-slate-700" },
  cancelled: { key: "booking_status_cancelled", color: "bg-red-100 text-red-700" },
  rejected: { key: "booking_status_rejected", color: "bg-red-100 text-red-700" },
  refunded: { key: "booking_status_refunded", color: "bg-slate-100 text-slate-700" },
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
    if (action === "reject" && !confirm(t("bookings_reject_confirm"))) {
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
  // Confirmation de service (start/complete/confirm/dispute) → refresh.
  useSocketEvent<{ bookingId: string }>("booking:service-updated", () =>
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
          ← {t("nav_dashboard")}
        </Link>
        <button
          type="button"
          onClick={refresh}
          className="text-xs text-ink-muted hover:text-ink"
        >
          ↻ {t("bookings_refresh")}
        </button>
      </div>

      <h1 className="font-display text-3xl font-extrabold md:text-4xl">
        {t("bookings_title")}
      </h1>
      <p className="mt-2 text-ink-muted">
        {isOwner ? t("bookings_sub_owner") : t("bookings_sub_provider")}
      </p>

      {error && (
        <div className="mt-6 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {bookings.length === 0 ? (
        <div className="mt-12 rounded-3xl border border-dashed border-ink/15 px-6 py-16 text-center">
          <p className="text-2xl">📭</p>
          <p className="mt-3 font-semibold text-ink">{t("bookings_empty_title")}</p>
          <p className="mt-1 text-sm text-ink-muted">
            {isOwner ? t("bookings_empty_owner") : t("bookings_empty_provider")}
          </p>
        </div>
      ) : (
        <div className="mt-8 space-y-3">
          {bookings.map((booking) => (
            <BookingCard
              key={booking.id}
              booking={booking}
              role={user?.role || "owner"}
              isOwner={isOwner}
              responding={respondingId === booking.id}
              onAccept={() => handleRespond(booking.id, "accept")}
              onReject={() => handleRespond(booking.id, "reject")}
              onServiceChanged={refresh}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function BookingCard({
  booking,
  role,
  isOwner,
  responding,
  onAccept,
  onReject,
  onServiceChanged,
}: {
  booking: Booking;
  role: AuthRole;
  isOwner: boolean;
  responding: boolean;
  onAccept: () => void;
  onReject: () => void;
  onServiceChanged: () => void;
}) {
  const { t } = useT();
  const meta = STATUS_META[booking.status];
  const statusInfo = {
    label: meta ? t(meta.key) : booking.status,
    color: meta?.color || "bg-slate-100 text-slate-700",
  };
  const showActions = !isOwner && booking.status === "pending";
  // Le backend renvoie `otherParty` (contrepartie agrégée) sur /bookings/my.
  const counterpart =
    booking.otherParty?.name ||
    (isOwner
      ? booking.sitterName || booking.walkerName || t("bookings_provider")
      : booking.ownerName || t("bookings_owner"));
  const price =
    booking.pricing?.totalPrice ??
    booking.basePrice ??
    booking.totalAmount ??
    0;
  const currency = booking.pricing?.currency || booking.currency || "EUR";
  const serviceDate = booking.serviceDate || booking.startDate || booking.date;
  const paid = (booking.paymentStatus || "").toLowerCase() === "paid";
  const pets = booking.pets || [];

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
            {booking.serviceType || t("bookings_pet_care")}
            {serviceDate && (
              <>
                {" · "}
                {new Date(serviceDate).toLocaleDateString(undefined, {
                  day: "numeric",
                  month: "short",
                  year: "numeric",
                })}
              </>
            )}
            {booking.timeSlot && (
              <>
                {" · "}
                <span className="inline-flex items-center gap-0.5">🕑 {booking.timeSlot}</span>
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
          {/* Animaux concernés (nom · race). */}
          {pets.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-1.5">
              {pets.map((p) => (
                <span
                  key={p.id}
                  className="inline-flex items-center gap-1 rounded-full bg-bg-soft px-2.5 py-1 text-xs font-medium text-ink"
                >
                  🐾 {p.petName || t("bookings_pet")}
                  {p.breed && <span className="text-ink-muted">· {p.breed}</span>}
                </span>
              ))}
            </div>
          )}
        </div>
        <div className="text-xs text-ink-muted">#{booking.id.slice(-6)}</div>
      </div>

      {showActions && (
        <div className="mt-4 flex gap-2">
          <button
            type="button"
            onClick={onAccept}
            disabled={responding}
            className="flex-1 rounded-full bg-walker px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-60"
          >
            {responding ? "…" : t("bookings_accept")}
          </button>
          <button
            type="button"
            onClick={onReject}
            disabled={responding}
            className="rounded-full border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-50 disabled:opacity-60"
          >
            {t("bookings_reject")}
          </button>
        </div>
      )}

      {paid && (
        <div className="mt-3 flex items-center justify-between rounded-xl bg-green-50 px-3 py-2 text-xs text-green-800">
          <span>
            ✓ {t("bookings_payment_received")}{" "}
            {booking.paidAt &&
              new Date(booking.paidAt).toLocaleDateString(undefined)}
          </span>
          {/* v23.1 part 146 — bouton suivi live (owner + services walking). */}
          {isOwner &&
            (booking.serviceType || "").toLowerCase().includes("walk") && (
              <Link
                href={`/walk/${booking.id}`}
                className="rounded-full bg-walker px-3 py-1 text-xs font-semibold text-white hover:opacity-90"
              >
                🗺️ {t("bookings_track_live")}
              </Link>
            )}
        </div>
      )}

      {/* v23.1.259 — carte de confirmation de service (paiement en séquestre).
          Provider : récupéré / rendu l'animal. Owner : Mission terminée / litige
          + invitation à noter. */}
      {paid && (
        <ServiceConfirmationCard
          booking={booking}
          role={role}
          onChanged={onServiceChanged}
        />
      )}
    </div>
  );
}
