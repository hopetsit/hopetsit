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
  // v532 — consentement CGU réel (cf. commentaire dans le formulaire).
  const [acceptTerms, setAcceptTerms] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!acceptTerms) {
      setErr(t("signup_terms_required"));
      return;
    }
    // v532 — le site validait 6 caractères alors que les 3 modèles Mongoose
    // exigent minlength: 8 : un mot de passe de 6-7 caractères passait le
    // contrôle client puis faisait échouer la création en 500, avec le
    // message brut du serveur (en anglais) affiché à l'utilisateur. On
    // s'aligne exactement sur les règles de l'app (8 + majuscule + minuscule
    // + chiffre), avec un message traduit.
    if (
      password.length < 8 ||
      !/[A-Z]/.test(password) ||
      !/[a-z]/.test(password) ||
      !/[0-9]/.test(password)
    ) {
      setErr(t("auth_error_password_rules"));
      return;
    }
    setBusy(true);
    setErr("");
    try {
      const cleanEmail = email.trim().toLowerCase();
      const res = await signup({
        name: name.trim(),
        email: cleanEmail,
        password,
        role,
      });
      // v402 — l'inscription web exige désormais la vérif email (le backend
      // envoie un code par mail). On envoie l'utilisateur sur /verify-email.
      if (res.needsVerification) {
        router.push(`/verify-email?email=${encodeURIComponent(cleanEmail)}`);
      } else {
        router.push("/dashboard");
      }
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

        {/* v532 — les CGU étaient envoyées avec acceptedTerms: true CODÉ EN DUR
            (lib/api.ts) alors qu'aucune case n'était affichée : l'utilisateur
            n'acceptait rien, et aucune trace de consentement n'était conservée.
            L'app mobile, elle, a bien sa case à l'étape 5 du wizard. */}
        <label className="flex items-start gap-2.5 text-sm text-ink-muted">
          <input
            type="checkbox"
            checked={acceptTerms}
            onChange={(e) => setAcceptTerms(e.target.checked)}
            className="mt-0.5 h-4 w-4 shrink-0 accent-owner"
          />
          <span>
            {t("signup_terms_accept")}{" "}
            <Link href="/terms" className="font-semibold text-owner underline">
              {t("terms_title")}
            </Link>
            {" · "}
            <Link href="/privacy" className="font-semibold text-owner underline">
              {t("privacy_title")}
            </Link>
          </span>
        </label>

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
  // v404 — Daniel : œil afficher/masquer le mot de passe.
  const [show, setShow] = useState(false);
  const isPwd = type === "password";
  const inputType = isPwd ? (show ? "text" : "password") : type;
  return (
    <div>
      <label className="block text-sm font-medium text-ink">{label}</label>
      <div className="relative">
        <input
          type={inputType}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          required={required}
          autoComplete={autoComplete}
          className={`mt-1.5 w-full rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-sm text-ink focus:border-owner focus:outline-none ${isPwd ? "pr-11" : ""}`}
        />
        {isPwd && (
          <button
            type="button"
            onClick={() => setShow((s) => !s)}
            aria-label={show ? "Masquer le mot de passe" : "Afficher le mot de passe"}
            className="absolute right-3 top-1/2 mt-[3px] -translate-y-1/2 text-ink-muted hover:text-ink"
          >
            {show ? (
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
            ) : (
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></svg>
            )}
          </button>
        )}
      </div>
    </div>
  );
}
