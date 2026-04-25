"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { ApiError, login } from "@/lib/api";
import { SocialButtons } from "@/components/SocialButtons";

export default function LoginPage() {
  const { t } = useT();
  const router = useRouter();

  const [email, setEmail]       = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy]         = useState(false);
  const [err, setErr]           = useState("");

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr("");
    try {
      await login(email.trim().toLowerCase(), password);
      router.push("/dashboard");
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 400)) {
        setErr(t("auth_error_invalid"));
      } else {
        setErr(e instanceof Error ? e.message : t("auth_error_generic"));
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-md px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
        {t("login_title")}
      </h1>
      <p className="mt-3 text-center text-sm text-ink-muted">{t("login_sub")}</p>

      <form
        onSubmit={onSubmit}
        className="mt-10 space-y-4 rounded-3xl border border-ink/5 bg-white p-7 shadow-card"
      >
        <SocialButtons />
        <Field label={t("login_email")} value={email} onChange={setEmail} type="email" required autoComplete="email" />
        <Field label={t("login_password")} value={password} onChange={setPassword} type="password" required autoComplete="current-password" />
        <button
          disabled={busy}
          className="w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60"
        >
          {busy ? t("common_loading") : t("login_submit")}
        </button>
        {err && <p className="text-center text-sm text-owner-dark">{err}</p>}
      </form>

      <p className="mt-6 text-center text-sm text-ink-muted">
        {t("login_no_account")}{" "}
        <Link href="/signup" className="font-semibold text-owner">
          {t("login_signup_link")}
        </Link>
      </p>
    </div>
  );
}

function Field({
  label, value, onChange, type = "text", required, autoComplete,
}: {
  label: string; value: string; onChange: (v: string) => void;
  type?: string; required?: boolean; autoComplete?: string;
}) {
  return (
    <div>
      <label className="block text-sm font-medium text-ink">{label}</label>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        required={required}
        autoComplete={autoComplete}
        className="mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none"
      />
    </div>
  );
}
