"use client";

// Parité app (widgets/service_confirmation_card.dart + _ReviewPromptTile) :
// carte de confirmation de service + invitation à noter.
//
//   PROVIDER (sitter/walker) :
//     awaiting_start / none  → bouton "🐾 J'ai récupéré l'animal"  (start)
//     in_progress            → bouton "✅ J'ai rendu l'animal"      (complete)
//     awaiting_confirmation  → "En attente de la confirmation…"     (info)
//     confirmed / disputed   → ligne d'état finale
//
//   OWNER :
//     awaiting_confirmation  → "Tout est ok ✅" (confirm = Mission terminée) /
//                              "Signaler un problème" (dispute)
//     in_progress / none     → ligne d'état informative
//     confirmed              → ligne "Service confirmé" + invitation à noter
//
// La confirmation owner LIBÈRE le paiement (séquestre) — c'est le même endpoint
// que l'app, le gating reste donc intact côté backend.

import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import {
  Booking,
  ConfirmationStatus,
  completeService,
  confirmService,
  disputeService,
  getMyReview,
  MyReview,
  startService,
  submitReview,
  updateReview,
} from "@/lib/api";

type Role = "owner" | "sitter" | "walker";

function statusOf(b: Booking): ConfirmationStatus {
  const s = (b.confirmationStatus || "none") as ConfirmationStatus;
  return s || "none";
}

export function ServiceConfirmationCard({
  booking,
  role,
  onChanged,
}: {
  booking: Booking;
  role: Role;
  onChanged?: (next: ConfirmationStatus) => void;
}) {
  const { t } = useT();
  const [status, setStatus] = useState<ConfirmationStatus>(statusOf(booking));
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setStatus(statusOf(booking));
  }, [booking]);

  const isProvider = role === "sitter" || role === "walker";
  const paid = (booking.paymentStatus || "").toLowerCase() === "paid";
  if (!paid) return null;
  if (["cancelled", "refunded"].includes((booking.status || "").toLowerCase())) {
    return null;
  }

  async function run(
    action: string,
    fn: () => Promise<{ confirmationStatus?: ConfirmationStatus }>,
  ) {
    setPending(action);
    setError(null);
    try {
      const res = await fn();
      const next = (res.confirmationStatus || status) as ConfirmationStatus;
      setStatus(next);
      onChanged?.(next);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error");
    } finally {
      setPending(null);
    }
  }

  function actionBtn(
    action: string,
    label: string,
    fn: () => Promise<{ confirmationStatus?: ConfirmationStatus }>,
    variant: "green" | "owner" | "danger-outline",
  ) {
    const busy = pending === action;
    const disabled = pending !== null;
    const cls =
      variant === "danger-outline"
        ? "border border-red-300 bg-transparent text-red-600 hover:bg-red-50"
        : variant === "owner"
          ? "bg-owner text-white hover:bg-owner-dark"
          : "bg-walker text-white hover:bg-walker-dark";
    return (
      <button
        type="button"
        onClick={() => run(action, fn)}
        disabled={disabled}
        className={`flex-1 rounded-full px-4 py-2 text-sm font-semibold transition disabled:opacity-60 ${cls}`}
      >
        {busy ? "…" : label}
      </button>
    );
  }

  function infoLine(text: string, tone: "muted" | "green" | "warn" = "muted") {
    const cls =
      tone === "green"
        ? "text-walker-dark font-semibold"
        : tone === "warn"
          ? "text-red-600 font-semibold"
          : "text-ink-muted";
    return <p className={`text-sm ${cls}`}>{text}</p>;
  }

  let body: React.ReactNode;
  if (status === "confirmed") {
    body = infoLine(`✅ ${t("service_card_confirmed")}`, "green");
  } else if (status === "disputed") {
    body = infoLine(
      `⚠️ ${isProvider ? t("service_card_disputed_provider") : t("service_card_disputed_owner")}`,
      "warn",
    );
  } else if (isProvider) {
    if (status === "in_progress") {
      body = (
        <div className="space-y-2.5">
          {infoLine(t("service_card_in_progress"))}
          {actionBtn(
            "complete",
            t("service_card_provider_complete_btn"),
            () => completeService(booking.id),
            "green",
          )}
        </div>
      );
    } else if (status === "awaiting_confirmation") {
      body = infoLine(t("service_card_awaiting_owner"));
    } else {
      // awaiting_start / none
      body = (
        <div className="flex">
          {actionBtn(
            "start",
            t("service_card_provider_start_btn"),
            () => startService(booking.id),
            "owner",
          )}
        </div>
      );
    }
  } else {
    // OWNER
    if (status === "awaiting_confirmation") {
      body = (
        <div className="space-y-3">
          <p className="text-sm text-ink-muted">{t("service_card_owner_confirm_desc")}</p>
          <div className="flex gap-2.5">
            {actionBtn(
              "confirm",
              t("service_card_confirm_btn"),
              () => confirmService(booking.id),
              "green",
            )}
            {actionBtn(
              "dispute",
              t("service_card_dispute_btn"),
              () => disputeService(booking.id),
              "danger-outline",
            )}
          </div>
        </div>
      );
    } else if (status === "in_progress") {
      body = infoLine(t("service_card_owner_in_progress"));
    } else {
      body = infoLine(t("service_card_owner_not_started"));
    }
  }

  // L'owner peut noter dès que le service est confirmé (ou la réservation
  // terminée). On affiche l'invitation sous la carte.
  const canReview =
    role === "owner" &&
    (status === "confirmed" || (booking.status || "").toLowerCase() === "completed");

  return (
    <>
      <div className="mt-3 rounded-2xl border border-owner/20 bg-owner/5 p-4">
        <div className="mb-2.5 flex items-center gap-2">
          <span aria-hidden="true">🛡️</span>
          <span className="text-sm font-extrabold text-ink">{t("service_card_header")}</span>
        </div>
        {body}
        {error && <p className="mt-2 text-xs text-red-600">{error}</p>}
      </div>
      {canReview && <ReviewPrompt booking={booking} />}
    </>
  );
}

// ── Invitation à noter (parité _ReviewPromptTile) ───────────────────────────
function ReviewPrompt({ booking }: { booking: Booking }) {
  const { t } = useT();
  const [loading, setLoading] = useState(true);
  const [existing, setExisting] = useState<MyReview | null>(null);
  const [open, setOpen] = useState(false);
  const [initialRating, setInitialRating] = useState(0);

  const revieweeId = booking.otherParty?.id || "";
  const revieweeRole: "sitter" | "walker" = (booking.serviceType || "")
    .toLowerCase()
    .includes("walk")
    ? "walker"
    : "sitter";

  useEffect(() => {
    let alive = true;
    (async () => {
      const r = await getMyReview(booking.id);
      if (alive) {
        setExisting(r);
        setLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [booking.id]);

  if (loading || !revieweeId) return null;

  function openEditor(rating: number) {
    setInitialRating(rating || (existing?.rating ?? 0));
    setOpen(true);
  }

  if (existing) {
    const rating = Math.round(existing.rating || 0);
    return (
      <>
        <button
          type="button"
          onClick={() => openEditor(0)}
          className="mt-3 flex w-full items-center gap-2 rounded-2xl border border-walker/30 bg-walker-light/60 px-4 py-3 text-left"
        >
          <span className="text-walker-dark">✓</span>
          <span className="flex gap-0.5 text-amber-400">
            {Array.from({ length: 5 }).map((_, i) => (
              <span key={i}>{i < rating ? "★" : "☆"}</span>
            ))}
          </span>
          <span className="ml-auto text-sm font-semibold text-owner">
            {t("review_already_rated")}
          </span>
        </button>
        {open && (
          <ReviewDialog
            booking={booking}
            revieweeId={revieweeId}
            revieweeRole={revieweeRole}
            existing={existing}
            initialRating={initialRating}
            onClose={(updated) => {
              setOpen(false);
              if (updated) setExisting(updated);
            }}
          />
        )}
      </>
    );
  }

  return (
    <>
      <div className="mt-3 rounded-2xl border border-owner/20 bg-owner-light/60 p-4">
        <p className="text-sm font-bold text-ink">{t("review_prompt_title")}</p>
        <div className="mt-2.5 flex gap-1.5">
          {Array.from({ length: 5 }).map((_, i) => (
            <button
              key={i}
              type="button"
              onClick={() => openEditor(i + 1)}
              aria-label={`${i + 1}`}
              className="text-3xl leading-none text-ink-soft transition hover:text-amber-400"
            >
              ★
            </button>
          ))}
        </div>
        <button
          type="button"
          onClick={() => openEditor(0)}
          className="mt-2.5 text-sm font-semibold text-owner hover:underline"
        >
          {t("review_prompt_cta")}
        </button>
      </div>
      {open && (
        <ReviewDialog
          booking={booking}
          revieweeId={revieweeId}
          revieweeRole={revieweeRole}
          existing={null}
          initialRating={initialRating}
          onClose={(updated) => {
            setOpen(false);
            if (updated) setExisting(updated);
          }}
        />
      )}
    </>
  );
}

function ReviewDialog({
  booking,
  revieweeId,
  revieweeRole,
  existing,
  initialRating,
  onClose,
}: {
  booking: Booking;
  revieweeId: string;
  revieweeRole: "sitter" | "walker";
  existing: MyReview | null;
  initialRating: number;
  onClose: (updated: MyReview | null) => void;
}) {
  const { t } = useT();
  const [rating, setRating] = useState(initialRating || existing?.rating || 0);
  const [comment, setComment] = useState(existing?.comment || "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save() {
    if (rating < 1) {
      setError(t("review_pick_rating"));
      return;
    }
    setBusy(true);
    setError(null);
    try {
      if (existing && (existing.id || existing._id)) {
        const updated = await updateReview(
          String(existing.id || existing._id),
          rating,
          comment.trim(),
        );
        onClose(updated || { ...existing, rating, comment });
      } else {
        const res = await submitReview({
          revieweeId,
          rating,
          comment: comment.trim(),
          bookingId: booking.id,
          revieweeRole,
        });
        onClose({
          id: res.reviewId || res.id,
          rating,
          comment: comment.trim(),
          bookingId: booking.id,
          revieweeId,
        });
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error");
      setBusy(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      onClick={() => !busy && onClose(null)}
    >
      <div
        className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="font-display text-lg font-extrabold text-ink">
          {t("review_dialog_title")}
        </h2>
        <p className="mt-1 text-sm text-ink-muted">{booking.otherParty?.name}</p>

        <div className="mt-4 flex gap-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <button
              key={i}
              type="button"
              onClick={() => setRating(i + 1)}
              aria-label={`${i + 1}`}
              className={`text-4xl leading-none transition ${
                i < rating ? "text-amber-400" : "text-ink-soft hover:text-amber-300"
              }`}
            >
              ★
            </button>
          ))}
        </div>

        <textarea
          value={comment}
          onChange={(e) => setComment(e.target.value)}
          rows={4}
          placeholder={t("review_comment_ph")}
          className="mt-4 w-full rounded-xl border border-ink/15 px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none focus:ring-2 focus:ring-owner/20"
        />

        {error && <p className="mt-2 text-sm text-red-600">{error}</p>}

        <div className="mt-5 flex gap-2.5">
          <button
            type="button"
            onClick={() => onClose(null)}
            disabled={busy}
            className="flex-1 rounded-full border border-ink/15 px-4 py-2 text-sm font-semibold text-ink-muted hover:bg-bg-soft disabled:opacity-60"
          >
            {t("common_cancel")}
          </button>
          <button
            type="button"
            onClick={save}
            disabled={busy}
            className="flex-1 rounded-full bg-owner px-4 py-2 text-sm font-semibold text-white hover:bg-owner-dark disabled:opacity-60"
          >
            {busy ? "…" : t("review_submit_btn")}
          </button>
        </div>
      </div>
    </div>
  );
}
