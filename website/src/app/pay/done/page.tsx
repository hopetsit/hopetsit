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

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  BoostTier,
  confirmBoost,
  confirmMapBoost,
  confirmSubscription,
} from "@/lib/api";

type Status = "success" | "fail" | "cancel" | "unknown";
type Purpose = "" | "subscription" | "boost" | "mapboost" | "booking";

const PURPOSE_LABEL: Record<Exclude<Purpose, "">, string> = {
  subscription: "abonnement Premium",
  boost: "boost annonce",
  mapboost: "PawSpot (visibilité carte)",
  booking: "réservation",
};

export default function PayDonePage() {
  const [status, setStatus] = useState<Status>("unknown");
  const [intentId, setIntentId] = useState<string>("");
  const [purpose, setPurpose] = useState<Purpose>("");
  const [planOrTier, setPlanOrTier] = useState<string>("");
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
    setCurrency(url.searchParams.get("currency") || "EUR");
  }, []);

  // v23.1 part 146 — auto-confirmation backend.
  // Quand status=success ET on a un purpose/plan/intent → on appelle
  // l'endpoint /confirm pour activer la subscription/boost côté DB.
  useEffect(() => {
    if (status !== "success" || !purpose || !intentId || !planOrTier) return;
    if (purpose === "booking") return; // bookings ont leur propre webhook backend
    if (confirming || confirmed) return;

    setConfirming(true);
    setConfirmError(null);

    (async () => {
      try {
        if (purpose === "subscription") {
          await confirmSubscription(planOrTier, intentId, currency);
        } else if (purpose === "boost") {
          await confirmBoost(planOrTier as BoostTier, intentId, currency);
        } else if (purpose === "mapboost") {
          await confirmMapBoost(planOrTier as BoostTier, intentId, currency);
        }
        setConfirmed(true);
      } catch (e) {
        // Si confirm fail, l'argent est déjà débité côté Airwallex mais la DB
        // backend ne sait pas. Le user devra recharger ou un cron backend
        // peut reconcilier. On affiche un message clair.
        setConfirmError(
          e instanceof Error
            ? e.message
            : "Le paiement a été reçu mais nous n'avons pas pu activer l'achat. Contacte le support.",
        );
      } finally {
        setConfirming(false);
      }
    })();
  }, [status, purpose, intentId, planOrTier, currency, confirming, confirmed]);

  const isOk = status === "success";
  const purposeLabel = purpose && purpose !== "booking" ? PURPOSE_LABEL[purpose] : null;

  return (
    <div className="min-h-[60vh] flex flex-col items-center justify-center px-6 text-center">
      <div className="mt-8 mb-6">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo.svg" alt="HoPetSit" width={64} height={64} className="rounded-2xl" />
      </div>

      {isOk ? (
        <>
          {confirming ? (
            <>
              <p className="text-lg font-semibold text-ink">Activation en cours…</p>
              <p className="mt-2 text-sm text-ink-muted">
                Paiement reçu. On active ton {purposeLabel || "achat"}.
              </p>
              <div className="mt-6 h-2 w-48 overflow-hidden rounded-full bg-bg-soft">
                <div className="h-full w-1/3 animate-pulse bg-walker" />
              </div>
            </>
          ) : confirmError ? (
            <>
              <p className="text-xl font-semibold text-amber-700">Paiement reçu ✓</p>
              <p className="mt-3 max-w-md text-sm text-ink-muted">
                Mais l&apos;activation a échoué : {confirmError}
                <br />
                <span className="mt-2 block">
                  Reviens sur ta boutique pour retenter, ou contacte le support si le problème persiste.
                </span>
              </p>
            </>
          ) : (
            <>
              <p className="text-2xl font-display font-extrabold text-walker">
                {purposeLabel ? `Ton ${purposeLabel} est actif ✓` : "Payment received ✓"}
              </p>
              <p className="mt-2 text-sm text-ink-muted">
                {purposeLabel
                  ? "Merci ! Tu peux retourner à la boutique ou au dashboard."
                  : "Thanks! You can return to the HoPetSit app."}
              </p>
            </>
          )}
        </>
      ) : status === "cancel" ? (
        <>
          <p className="text-xl font-semibold text-ink">Paiement annulé</p>
          <p className="mt-2 text-sm text-ink-muted">
            Aucun débit n&apos;a été effectué. Tu peux réessayer.
          </p>
        </>
      ) : status === "fail" ? (
        <>
          <p className="text-xl font-semibold text-owner-dark">Échec du paiement</p>
          <p className="mt-2 text-sm text-ink-muted">
            Réessaye ou utilise une autre carte.
          </p>
        </>
      ) : (
        <>
          <p className="text-lg font-semibold text-ink">Processing…</p>
        </>
      )}

      {intentId && (
        <p className="mt-6 text-[11px] text-ink-soft">Reference: {intentId}</p>
      )}

      <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
        {purposeLabel && (
          <Link
            href="/boutique"
            className="rounded-full bg-owner px-6 py-2.5 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark"
          >
            Retour à la boutique
          </Link>
        )}
        <Link
          href={purposeLabel ? "/dashboard" : "/"}
          className="rounded-full border border-ink/15 px-6 py-2.5 text-sm font-semibold text-ink hover:border-ink/30"
        >
          {purposeLabel ? "Dashboard" : "Back to HoPetSit"}
        </Link>
      </div>
    </div>
  );
}
