"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { ApiError, AuthRole, signup } from "@/lib/api";
import { SocialButtons } from "@/components/SocialButtons";

export default function SignupPage() {
  const { t } = useT();
  const router = useRouter();

  const [role, setRole]         = useState<AuthRole>("owner");
  const [name, setName]         = useState("");
  const [email, setEmail]       = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy]         = useState(false);
  const [err, setErr]           = useState("");

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (password.length < 6) {
      setErr("Password must be at least 6 characters.");
      return;
    }
    setBusy(true);
    setErr("");
    try {
      await signup({
        name: name.trim(),
        email: email.trim().toLowerCase(),
        password,
        role,
      });
      router.push("/dashboard");
    } catch (e) {
      if (e instanceof ApiError && e.status === 409) {
        setErr(t("auth_error_taken"));
      } else if (e instanceof ApiError && e.status === 400) {
        setErr(e.message || t("auth_error_generic"));
      } else {
        setErr(e instanceof Error ? e.message : t("auth_error_generic"));
      }
    } finally {
      setBusy(false);
    }
  }

  const roles: { code: AuthRole; label: string; color: "owner"|"sitter"|"walker"; emoji: string }[] = [
    { code: "owner",  label: t("signup_role_owner"),  color: "owner",  emoji: "🐾" },
    { code: "sitter", label: t("signup_role_sitter"), color: "sitter", emoji: "🏠" },
    { code: "walker", label: t("signup_role_walker"), color: "walker", emoji: "🚶" },
  ];

  return (
    <div className="mx-auto max-w-md px-4 py-16 md:py-24">
      <h1 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">
        {t("signup_title")}
      </h1>
      <p className="mt-3 text-center text-sm text-ink-muted">{t("signup_sub")}</p>

      <form
        onSubmit={onSubmit}
        className="mt-10 space-y-4 rounded-3xl border border-ink/5 bg-white p-7 shadow-card"
      >
        <SocialButtons defaultRole={role} />
        <div className="space-y-2">
          {roles.map((r) => (
            <label
              key={r.code}
              className={`flex cursor-pointer items-center gap-3 rounded-xl border p-3 transition ${
                role === r.code
                  ? `border-${r.color} bg-${r.color}-light`
                  : "border-ink/10 bg-white hover:border-ink/30"
              }`}
            >
              <input
                type="radio"
                name="role"
                checked={role === r.code}
                onChange={() => setRole(r.code)}
                className="sr-only"
              />
              <span className="text-2xl">{r.emoji}</span>
              <span className={`font-semibold ${role === r.code ? `text-${r.color}-dark` : "text-ink"}`}>
                {r.label}
              </span>
            </label>
          ))}
        </div>

        <Field label={t("signup_name")}     value={name}     onChange={setName}     required autoComplete="name" />
        <Field label={t("signup_email")}    value={email}    onChange={setEmail}    type="email"    required autoComplete="email" />
        <Field label={t("signup_password")} value={password} onChange={setPassword} type="password" required autoComplete="new-password" />

        <button
          disabled={busy}
          className="w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60"
        >
          {busy ? t("common_loading") : t("signup_submit")}
        </button>
        {err && <p className="text-center text-sm text-owner-dark">{err}</p>}
      </form>

      <p className="mt-6 text-center text-sm text-ink-muted">
        {t("signup_have")}{" "}
        <Link href="/login" className="font-semibold text-owner">
          {t("signup_login_link")}
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
