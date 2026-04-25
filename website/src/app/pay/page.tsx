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

import { useEffect, useState } from "react";

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
  const [status, setStatus] = useState<"loading" | "redirecting" | "error">("loading");
  const [errorMsg, setErrorMsg] = useState<string>("");

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

    // Mobile webview detects these — never visible to the user.
    const successUrl = `${url.origin}/pay/done?status=success`;
    const failUrl    = `${url.origin}/pay/done?status=fail`;
    const cancelUrl  = `${url.origin}/pay/done?status=cancel`;

    if (!intentId || !clientSecret) {
      setStatus("error");
      setErrorMsg("Missing payment parameters.");
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
          logoUrl: `${url.origin}/logo.svg`,
        });
      } catch (e) {
        setStatus("error");
        setErrorMsg(e instanceof Error ? e.message : String(e));
      }
    })();
  }, []);

  return (
    <div className="min-h-[60vh] flex flex-col items-center justify-center px-6 text-center">
      <div className="mt-8 mb-6">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo.svg" alt="HoPetSit" width={64} height={64} className="rounded-2xl" />
      </div>
      {status !== "error" ? (
        <>
          <p className="text-lg font-semibold text-ink">Preparing your secure payment…</p>
          <p className="mt-2 text-sm text-ink-muted">
            You're being redirected to the secure payment page. Please don't close this window.
          </p>
          <div className="mt-6 h-2 w-48 overflow-hidden rounded-full bg-bg-soft">
            <div className="h-full w-1/3 animate-pulse bg-owner" />
          </div>
        </>
      ) : (
        <>
          <p className="text-lg font-semibold text-owner-dark">Couldn't start payment.</p>
          <p className="mt-2 max-w-sm text-sm text-ink-muted">{errorMsg}</p>
          <p className="mt-6 text-xs text-ink-soft">
            You can close this window and try again from the app.
          </p>
        </>
      )}
    </div>
  );
}
