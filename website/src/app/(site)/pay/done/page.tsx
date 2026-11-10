// /pay/done — landing page hit at the end of the Airwallex Hosted Payment
// Page flow.
//
// v23.1 part 146 — extension web :
//   Quand le paiement vient de la boutique web (/boutique), on relaie
//   `purpose=subscription|boost|mapboost` + `plan` ou `tier` + `id`
//   dans l'URL. Cette page appelle automatiquement le bon endpoint
//   /confirm pour activer la souscription / le boost côté backend, puis
//   redirige vers /boutique (avec confirmation visuelle) ou /dashboard.
//
// Sans `purpose` (cas mobile app classique), comportement legacy : la
// webview détecte cette URL et la ferme.

"use client";

import { useEffect, useRef, useState } from "react";
import Link from "@/components/SiteLink";
import {
  BoostTier,
  confirmBoost,
  confirmBookingPayment,
  confirmMapBoost,
  confirmSubscription,
} from "@/lib/api";
// 1011 (ZOE, ordre de Daniel « les pages ne sont pas à jour dans les autres langues ») — textes en 9 langues.
import { useT } from "@/lib/i18n/LanguageProvider";
import { g1011 } from "@/lib/i18n/langues1011";
import type { Lang } from "@/lib/i18n/langs";

type Status = "success" | "fail" | "cancel" | "unknown";
type Purpose = "" | "subscription" | "boost" | "mapboost" | "pawspot" | "booking";

const PURPOSE_LABEL: Record<Exclude<Purpose, "">, string> = {
  subscription: "abonnement Premium",
  boost: "boost annonce",
  mapboost: "PawSpot (visibilité carte)",
  booking: "réservation",
  pawspot: "abonnement PawSpot",
};

export default function PayDonePage() {
  const { lang } = useT();
  const langRef = useRef<Lang>(lang);
  langRef.current = lang;
  const g = (k: string) => g1011(lang, k);
  const [status, setStatus] = useState<Status>("unknown");
  const [intentId, setIntentId] = useState<string>("");
  const [purpose, setPurpose] = useState<Purpose>("");
  const [planOrTier, setPlanOrTier] = useState<string>("");
  const [bookingId, setBookingId] = useState<string>("");
  const [currency, setCurrency] = useState<string>("EUR");
  const [confirming, setConfirming] = useState(false);
  const [confirmed, setConfirmed] = useState(false);
  const [confirmError, setConfirmError] = useState<string | null>(null);

  useEffect(() => {
    const url = new URL(window.location.href);
    const s = (url.searchParams.get("status") || "").toLowerCase();
    if (s === "success" || s === "fail" || s === "cancel") {
      setStatus(s as Status);
    } else {
      setStatus("unknown");
    }
    const id =
      url.searchParams.get("id") ||
      url.searchParams.get("paymentIntent") ||
      url.searchParams.get("paymentIntentId") ||
      "";
    setIntentId(id);

    const p = (url.searchParams.get("purpose") || "") as Purpose;
    setPurpose(p);
    setPlanOrTier(
      url.searchParams.get("plan") || url.searchParams.get("tier") || "",
    );
    // Paiement d'une réservation : l'id du booking est relayé sous `booking`.
    setBookingId(url.searchParams.get("booking") || "");
    setCurrency(url.searchParams.get("currency") || "EUR");
  }, []);

  // v23.1 part 146 — auto-confirmation backend.
  // Quand status=success ET on a un purpose/intent → on appelle l'endpoint
  // /confirm pour activer la subscription/boost (ou marquer la réservation
  // payée) côté DB. Les achats abo/boost ont besoin du plan/tier ; le booking
  // n'a besoin que de l'intentId + l'id de la réservation.
  useEffect(() => {
    if (status !== "success" || !purpose || !intentId) return;
    if (purpose === "booking") {
      if (!bookingId) return;
    } else if (!planOrTier) {
      return;
    }
    if (confirming || confirmed) return;

    setConfirming(true);
    setConfirmError(null);

    (async () => {
      try {
        if (purpose === "booking") {
          // POST /bookings/:id/confirm-payment/:paymentIntentId — le backend
          // retrieve le PI Airwallex et marque la réservation payée si SUCCEEDED
          // (idempotent avec le webhook).
          await confirmBookingPayment(bookingId, intentId);
        } else if (purpose === "subscription") {
          await confirmSubscription(planOrTier, intentId, currency);
        } else if (purpose === "boost") {
          await confirmBoost(planOrTier as BoostTier, intentId, currency);
        } else if (purpose === "mapboost") {
          await confirmMapBoost(planOrTier as BoostTier, intentId, currency);
        } else if (purpose === "pawspot") {
          // v23.1.390 — abo PawSpot acheté depuis le site.
          const { confirmPawSpot } = await import("@/lib/api");
          await confirmPawSpot(planOrTier, intentId);
        }
        setConfirmed(true);
      } catch (e) {
        // Si confirm fail, l'argent est déjà débité côté Airwallex mais la DB
        // backend ne sait pas. Le user devra recharger ou un cron backend
        // peut reconcilier. On affiche un message clair.
        setConfirmError(
          e instanceof Error
            ? e.message
            : g1011(langRef.current, "paydone_confirm_fallback"),
        );
      } finally {
        setConfirming(false);
      }
    })();
  }, [status, purpose, intentId, planOrTier, bookingId, currency, confirming, confirmed]);

  const isOk = status === "success";
  const purposeLabel = purpose ? PURPOSE_LABEL[purpose] : null;
  const isBooking = purpose === "booking";
  // Où renvoyer l'utilisateur après l'achat (booking → /bookings).
  const primaryHref = isBooking ? "/bookings" : "/boutique";
  const primaryLabel = isBooking ? g("paydone_my_bookings") : g("paydone_back_shop");

  return (
    <div className="min-h-[60vh] flex flex-col items-center justify-center px-6 text-center">
      <div className="mt-8 mb-6">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo.png" alt="HoPetSit" width={64} height={64} className="rounded-2xl" />
      </div>

      {isOk ? (
        <>
          {confirming ? (
            <>
              <p className="text-lg font-semibold text-ink">{g("paydone_activating")}</p>
              <p className="mt-2 text-sm text-ink-muted">
                {g(purposeLabel ? `paydone_act_${purpose}` : "paydone_act_generic")}
              </p>
              <div className="mt-6 h-2 w-48 overflow-hidden rounded-full bg-bg-soft">
                <div className="h-full w-1/3 animate-pulse bg-walker" />
              </div>
            </>
          ) : confirmError ? (
            <>
              <p className="text-xl font-semibold text-amber-700">{g("paydone_received")}</p>
              <p className="mt-3 max-w-md text-sm text-ink-muted">
                {g("paydone_act_failed")} {confirmError}
                <br />
                <span className="mt-2 block">
                  {g("paydone_retry_shop")}
                </span>
              </p>
            </>
          ) : (
            <>
              <p className="text-2xl font-display font-extrabold text-walker">
                {purposeLabel ? g(`paydone_ok_${purpose}`) : g("paydone_app_received")}
              </p>
              <p className="mt-2 text-sm text-ink-muted">
                {purposeLabel
                  ? g("paydone_thanks")
                  : g("paydone_app_thanks")}
              </p>
            </>
          )}
        </>
      ) : status === "cancel" ? (
        <>
          <p className="text-xl font-semibold text-ink">{g("paydone_cancel_title")}</p>
          <p className="mt-2 text-sm text-ink-muted">
            {g("paydone_cancel_sub")}
          </p>
        </>
      ) : status === "fail" ? (
        <>
          <p className="text-xl font-semibold text-owner-dark">{g("paydone_fail_title")}</p>
          <p className="mt-2 text-sm text-ink-muted">
            {g("paydone_fail_sub")}
          </p>
        </>
      ) : (
        <>
          <p className="text-lg font-semibold text-ink">{g("paydone_processing")}</p>
        </>
      )}

      {intentId && (
        <p className="mt-6 text-[11px] text-ink-soft">{g("paydone_reference")} {intentId}</p>
      )}

      <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
        {purposeLabel && (
          <Link
            href={primaryHref}
            className="rounded-full bg-owner px-6 py-2.5 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark"
          >
            {primaryLabel}
          </Link>
        )}
        <Link
          href={purposeLabel ? "/dashboard" : "/"}
          className="rounded-full border border-ink/15 px-6 py-2.5 text-sm font-semibold text-ink hover:border-ink/30"
        >
          {purposeLabel ? g("paydone_dashboard") : g("paydone_back_app")}
        </Link>
      </div>
    </div>
  );
}
