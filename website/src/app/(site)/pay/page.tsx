// /pay — bridge page that the mobile app opens in a webview to start an
// Airwallex Hosted Payment Page (HPP) checkout.
//
// Why a bridge page (instead of opening checkout.airwallex.com directly)?
// → Airwallex's HPP entry point isn't a single static URL. You must call
//   Airwallex.init() then Airwallex.redirectToCheckout() with intent_id,
//   client_secret, currency, country_code, and the success/fail URLs.
//   Loading airwallex.js in this tiny page is the lightest way to do that
//   without bundling the SDK in the main Next.js app.
//
// Mobile flow:
//   1. App opens   https://hopetsit.com/pay?intent=...&secret=...&currency=EUR&country=FR&env=prod
//   2. This page   loads airwallex.js → Airwallex.init() → redirectToCheckout()
//   3. User pays on the Airwallex checkout page
//   4. Airwallex redirects to /pay/done?status=success&id=<intentId> (or fail)
//   5. Webview detects /pay/done and closes; app reads `status` and proceeds
//
// To open in a desktop browser for testing, hit /pay?intent=foo&secret=bar
// — you'll see the dispatching state.

"use client";

import Link from "@/components/SiteLink";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { PromoCodeBox } from "@/components/PromoCodeBox";
import { useAuth } from "@/lib/useAuth";
import { ApiError, createBookingPaymentIntent } from "@/lib/api";
import { l1011 } from "@/lib/i18n/liens1011";

// Allow `Airwallex` global from the loaded script.
declare global {
  interface Window {
    Airwallex?: {
      init: (cfg: { env: "prod" | "demo" | "staging"; origin: string }) => void;
      redirectToCheckout: (cfg: {
        env: "prod" | "demo" | "staging";
        intent_id: string;
        client_secret: string;
        currency: string;
        country_code: string;
        successUrl?: string;
        failUrl?: string;
        cancelUrl?: string;
        logoUrl?: string;
        appearance?: Record<string, unknown>;
      }) => void;
    };
  }
}

function ensureAirwallexScript(): Promise<void> {
  if (typeof window === "undefined") return Promise.resolve();
  if (window.Airwallex) return Promise.resolve();
  return new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>('script[data-awx="elements"]');
    if (existing) {
      existing.addEventListener("load", () => resolve(), { once: true });
      existing.addEventListener("error", () => reject(new Error("Airwallex script failed to load")), { once: true });
      return;
    }
    const s = document.createElement("script");
    s.src   = "https://checkout.airwallex.com/assets/elements.bundle.min.js";
    s.async = true;
    s.dataset.awx = "elements";
    s.onload  = () => resolve();
    s.onerror = () => reject(new Error("Airwallex script failed to load"));
    document.head.appendChild(s);
  });
}

export default function PayPage() {
  const { t, lang } = useT();
  const { user, ready } = useAuth();
  // 1011 (ZOE point 4) — `/pay?bookingId=` (bouton des e-mails « réservation à payer ») : au lieu
  // d'une impasse, un bouton « Payer maintenant » qui prépare le paiement de CETTE réservation.
  // Toujours sur un clic du propriétaire, jamais tout seul (une carte enregistrée serait débitée).
  const [payBookingId, setPayBookingId] = useState("");
  const [payBusy, setPayBusy] = useState(false);
  const [payMsg, setPayMsg] = useState("");
  const [status, setStatus] = useState<"loading" | "redirecting" | "error">("loading");
  const [errorMsg, setErrorMsg] = useState<string>("");
  // v565 (point 29) — `/pay?bookingId=` est la route « thème » des e-mails
  // booking_accepted / payment_failed : sans intent Airwallex, on explique
  // où payer (app ou réservations) au lieu de « Missing payment parameters ».
  const [bookingHint, setBookingHint] = useState(false);
  // 16/10/2026 (LEO) — montant relayé par /posts et /bookings (`amount` + `currency`) : affiché
  // pendant la redirection pour que le propriétaire voie ce qu'il va payer. Textes traduits
  // (FLO 16/10 : la page était en anglais sur le site en français).
  const [amountLabel, setAmountLabel] = useState<string>("");

  useEffect(() => {
    const url = new URL(window.location.href);
    const params = url.searchParams;

    const intentId     = params.get("intent")   || params.get("intent_id")   || "";
    const clientSecret = params.get("secret")   || params.get("client_secret") || "";
    const currency     = (params.get("currency") || "EUR").toUpperCase();
    const countryCode  = (params.get("country")  || "FR").toUpperCase();
    const envParam     = (params.get("env") || "prod").toLowerCase();
    const env: "prod" | "demo" | "staging" =
      envParam === "demo" ? "demo" :
      envParam === "staging" ? "staging" :
      "prod";

    // v23.1 part 146 — relais des metadata "à quoi sert ce paiement".
    // Permet à /pay/done d'appeler le bon endpoint /confirm une fois
    // qu'Airwallex a confirmé le paiement.
    const purpose = params.get("purpose") || "";        // booking | subscription | boost | mapboost
    const planParam = params.get("plan") || "";          // monthly | yearly | family
    const tierParam = params.get("tier") || "";          // bronze | silver | gold | platinum
    // v23.1 — paiement d'une réservation : l'id du booking est distinct de
    // l'intentId (qui sert de référence Airwallex). On le relaie sous `booking`
    // pour que /pay/done puisse appeler confirm-payment/:bookingId/:intentId.
    const bookingParam = params.get("booking") || params.get("id") || "";
    const amountParam = Number(params.get("amount") || "");
    if (Number.isFinite(amountParam) && amountParam > 0) {
      try {
        setAmountLabel(new Intl.NumberFormat(document.documentElement.lang || "fr", { style: "currency", currency }).format(amountParam));
      } catch {
        setAmountLabel(`${amountParam.toFixed(2)} ${currency}`);
      }
    }
    const extraParams = new URLSearchParams();
    if (purpose) extraParams.set("purpose", purpose);
    if (planParam) extraParams.set("plan", planParam);
    if (tierParam) extraParams.set("tier", tierParam);
    if (currency) extraParams.set("currency", currency);
    if (intentId) extraParams.set("id", intentId);
    if (purpose === "booking" && bookingParam) extraParams.set("booking", bookingParam);
    const extra = extraParams.toString();
    const extraQs = extra ? `&${extra}` : "";

    // Mobile webview detects these — never visible to the user.
    const successUrl = `${url.origin}/pay/done?status=success${extraQs}`;
    const failUrl    = `${url.origin}/pay/done?status=fail${extraQs}`;
    const cancelUrl  = `${url.origin}/pay/done?status=cancel${extraQs}`;

    if (!intentId || !clientSecret) {
      setStatus("error");
      const fromEmail = !!(params.get("bookingId") || bookingParam);
      setBookingHint(fromEmail);
      const bid = params.get("bookingId") || bookingParam;
      if (/^[A-Za-z0-9_-]{6,64}$/.test(bid)) setPayBookingId(bid);
      setErrorMsg(fromEmail ? "" : "Missing payment parameters.");
      return;
    }

    (async () => {
      try {
        await ensureAirwallexScript();
        const Airwallex = window.Airwallex;
        if (!Airwallex) throw new Error("Airwallex SDK not available after load.");

        Airwallex.init({ env, origin: window.location.origin });
        setStatus("redirecting");

        // Hands off to https://checkout.airwallex.com/... — full-page redirect.
        Airwallex.redirectToCheckout({
          env,
          intent_id:    intentId,
          client_secret: clientSecret,
          currency,
          country_code: countryCode,
          successUrl,
          failUrl,
          cancelUrl,
          logoUrl: `${url.origin}/logo.png`,
        });
      } catch (e) {
        setStatus("error");
        setErrorMsg(e instanceof Error ? e.message : String(e));
      }
    })();
  }, []);

  async function payThisBooking() {
    if (!payBookingId || payBusy) return;
    setPayBusy(true);
    setPayMsg("");
    try {
      const intent = await createBookingPaymentIntent(payBookingId);
      if (!intent.clientSecret || !intent.paymentIntentId) throw new Error(intent.savedCardError || l1011(lang, "pay_error"));
      const bk = intent.booking;
      const currency = (intent.currency || bk?.pricing?.currency || bk?.currency || "EUR").toUpperCase();
      const qs = new URLSearchParams({ intent: intent.paymentIntentId, secret: intent.clientSecret, currency, purpose: "booking", booking: payBookingId });
      // `intent.amount` est en centimes : on n'affiche que le prix de la réservation quand il est connu.
      const amt = bk?.pricing?.totalPrice ?? bk?.totalAmount ?? 0;
      if (amt > 0) qs.set("amount", String(amt));
      window.location.assign(`/pay?${qs.toString()}`);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        window.location.assign(`/login?redirect=${encodeURIComponent(`/pay?bookingId=${payBookingId}`)}`);
        return;
      }
      setPayMsg(e instanceof ApiError && e.status === 409 ? l1011(lang, "pay_done") : l1011(lang, "pay_error"));
      setPayBusy(false);
    }
  }

  return (
    <div className="min-h-[60vh] flex flex-col items-center justify-center px-6 text-center">
      <div className="mt-8 mb-6">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo.png" alt="HoPetSit" width={64} height={64} className="rounded-2xl" />
      </div>
      {status !== "error" ? (
        <>
          <p className="text-lg font-semibold text-ink">{t("c1610_pay_preparing")}</p>
          {amountLabel && (
            <p className="mt-2 text-xl font-extrabold text-owner-dark" data-pay-amount={amountLabel}>
              {t("c1610_pay_amount").replace("{amount}", amountLabel)}
            </p>
          )}
          <p className="mt-2 text-sm text-ink-muted">{t("c1610_pay_redirect")}</p>
          <div className="mt-6 h-2 w-48 overflow-hidden rounded-full bg-bg-soft">
            <div className="h-full w-1/3 animate-pulse bg-owner" />
          </div>
        </>
      ) : (
        <>
          {bookingHint && payBookingId && ready ? (
            <div data-pay-booking-1011="" className="flex w-full max-w-sm flex-col items-center">
              <p className="text-xl font-extrabold text-ink">{l1011(lang, "pay_title")}</p>
              <p className="mt-2 text-sm font-semibold" style={{ color: "#15803D" }}>{l1011(lang, "pay_sub")}</p>
              {user ? (
                <button
                  type="button"
                  onClick={payThisBooking}
                  disabled={payBusy}
                  className="mt-5 inline-flex min-h-[52px] w-full items-center justify-center rounded-full bg-[#C92A12] px-6 py-3 text-base font-extrabold text-white transition hover:bg-[#9E1F0B] disabled:opacity-70"
                >
                  {payBusy ? l1011(lang, "pay_wait") : l1011(lang, "pay_btn")}
                </button>
              ) : (
                <>
                  <Link
                    href={`/login?redirect=${encodeURIComponent(`/pay?bookingId=${payBookingId}`)}`}
                    className="mt-5 inline-flex min-h-[52px] w-full items-center justify-center rounded-full bg-[#C92A12] px-6 py-3 text-base font-extrabold text-white transition hover:bg-[#9E1F0B]"
                  >
                    {l1011(lang, "pay_login")}
                  </Link>
                  <p className="mt-2 text-xs text-ink-muted">{l1011(lang, "pay_login_sub")}</p>
                </>
              )}
              {payMsg && <p role="alert" className="mt-3 text-sm font-bold" style={{ color: "#9E1F0B" }}>{payMsg}</p>}
              <Link href="/bookings" className="mt-4 text-sm font-semibold underline" style={{ color: "#6E4F48" }}>
                {t("pay_open_bookings")} →
              </Link>
            </div>
          ) : bookingHint ? (
            <>
              <p className="max-w-sm text-lg font-semibold text-ink">{t("pay_booking_hint")}</p>
              <Link
                href="/bookings"
                className="mt-5 inline-flex rounded-full bg-[#231715] px-6 py-3 text-sm font-semibold text-white transition hover:bg-black"
              >
                {t("pay_open_bookings")} →
              </Link>
            </>
          ) : (
            <>
              <p className="text-lg font-semibold text-owner-dark">{t("c1610_pay_fail")}</p>
              <p className="mt-2 max-w-sm text-sm text-ink-muted">{errorMsg}</p>
              <p className="mt-6 text-xs text-ink-soft">{t("c1610_pay_retry")}</p>
            </>
          )}
        </>
      )}

      {/* v565 (point 27) — « J'ai un code » sur la page de paiement : le code
          (abonnement offert / remise) s'applique au compte avant de payer. */}
      <div className="mt-8 flex w-full max-w-md flex-col items-center gap-2">
        <p className="text-xs text-ink-muted">{t("promo_pay_hint")}</p>
        <PromoCodeBox collapsible className="w-full text-left" />
      </div>
    </div>
  );
}
