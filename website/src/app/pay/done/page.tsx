// /pay/done — landing page hit at the end of the Airwallex Hosted Payment
// Page flow. The mobile app's webview detects this URL (regardless of the
// `?status=` value) and closes the sheet, then the app reads the status
// from the URL to react.
//
// Web visitors (rare — most traffic is in-webview from the mobile app) get
// a friendly confirmation / retry screen so the page never feels broken.

"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

type Status = "success" | "fail" | "cancel" | "unknown";

export default function PayDonePage() {
  const [status, setStatus] = useState<Status>("unknown");
  const [intentId, setIntentId] = useState<string>("");

  useEffect(() => {
    const url = new URL(window.location.href);
    const s = (url.searchParams.get("status") || "").toLowerCase();
    if (s === "success" || s === "fail" || s === "cancel") {
      setStatus(s as Status);
    } else {
      setStatus("unknown");
    }
    setIntentId(
      url.searchParams.get("id") ||
      url.searchParams.get("paymentIntent") ||
      url.searchParams.get("paymentIntentId") ||
      "",
    );
  }, []);

  const isOk = status === "success";
  return (
    <div className="min-h-[60vh] flex flex-col items-center justify-center px-6 text-center">
      <div className="mt-8 mb-6">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo.svg" alt="HoPetSit" width={64} height={64} className="rounded-2xl" />
      </div>
      {isOk ? (
        <>
          <p className="text-2xl font-display font-extrabold text-walker">Payment received ✓</p>
          <p className="mt-2 text-sm text-ink-muted">Thanks! You can return to the HoPetSit app.</p>
        </>
      ) : status === "cancel" ? (
        <>
          <p className="text-xl font-semibold text-ink">Payment cancelled</p>
          <p className="mt-2 text-sm text-ink-muted">No charge was made. You can try again from the app.</p>
        </>
      ) : status === "fail" ? (
        <>
          <p className="text-xl font-semibold text-owner-dark">Payment failed</p>
          <p className="mt-2 text-sm text-ink-muted">Please try again or use another card.</p>
        </>
      ) : (
        <>
          <p className="text-lg font-semibold text-ink">Processing…</p>
        </>
      )}
      {intentId && (
        <p className="mt-6 text-[11px] text-ink-soft">Reference: {intentId}</p>
      )}
      <Link
        href="/"
        className="mt-10 rounded-full bg-owner px-6 py-2.5 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark"
      >
        Back to HoPetSit
      </Link>
    </div>
  );
}
