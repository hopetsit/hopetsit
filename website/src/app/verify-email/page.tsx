"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { ApiError, verifyEmail, resendVerificationCode } from "@/lib/api";

// v402 — vérification email depuis le SITE (parité app). Le backend a créé le
// compte avec verified:false et a envoyé un code 6 chiffres par email. Cette
// page le saisit → /auth/verify renvoie un JWT → on file au dashboard.
function VerifyEmailInner() {
  const { t } = useT();
  const router = useRouter();
  const params = useSearchParams();
  const email = (params.get("email") || "").trim().toLowerCase();

  const [code, setCode]   = useState("");
  const [busy, setBusy]   = useState(false);
  const [err, setErr]     = useState("");
  const [info, setInfo]   = useState("");
  const [resending, setResending] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email) {
      setErr(t("verify_no_email"));
      return;
    }
    setBusy(true);
    setErr("");
    setInfo("");
    try {
      await verifyEmail(email, code);
      router.push("/dashboard");
    } catch (e) {
      setErr(e instanceof ApiError ? e.message : t("verify_error"));
    } finally {
      setBusy(false);
    }
  }

  async function onResend() {
    if (!email) {
      setErr(t("verify_no_email"));
      return;
    }
    setResending(true);
    setErr("");
    setInfo("");
    try {
      await resendVerificationCode(email);
      setInfo(t("verify_resent"));
    } catch (e) {
      setErr(e instanceof ApiError ? e.message : t("verify_error"));
    } finally {
      setResending(false);
    }
  }

  return (
    <div className="mx-auto max-w-md px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
        {t("verify_title")}
      </h1>
      <p className="mt-3 text-center text-sm text-ink-muted">{t("verify_sub")}</p>
      {email && (
        <p className="mt-1 text-center text-sm font-semibold text-ink">{email}</p>
      )}

      <form
        onSubmit={onSubmit}
        className="mt-10 space-y-4 rounded-3xl border border-ink/5 bg-white p-7 shadow-card"
      >
        <div>
          <label className="block text-sm font-medium text-ink">{t("verify_code_label")}</label>
          <input
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/[^0-9]/g, "").slice(0, 6))}
            required
            placeholder="••••••"
            className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-center text-lg tracking-[0.4em] text-ink focus:border-owner focus:outline-none"
          />
        </div>

        <button
          disabled={busy || code.length < 4}
          className="w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60"
        >
          {busy ? t("common_loading") : t("verify_submit")}
        </button>

        {err && <p className="text-center text-sm text-owner-dark">{err}</p>}
        {info && <p className="text-center text-sm text-green-600">{info}</p>}

        <button
          type="button"
          onClick={onResend}
          disabled={resending}
          className="w-full rounded-full border border-ink/15 py-3 text-sm font-semibold text-ink hover:border-ink/30 disabled:opacity-60"
        >
          {resending ? t("common_loading") : t("verify_resend")}
        </button>
      </form>

      <p className="mt-6 text-center text-sm text-ink-muted">
        <Link href="/login" className="font-semibold text-owner">
          {t("signup_login_link")}
        </Link>
      </p>
    </div>
  );
}

export default function VerifyEmailPage() {
  return (
    <Suspense fallback={<div className="mx-auto max-w-md px-4 py-24 text-center text-sm text-ink-muted">…</div>}>
      <VerifyEmailInner />
    </Suspense>
  );
}
