"use client";

import Link from "@/components/SiteLink";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { ApiError, login } from "@/lib/api";
import { SocialButtons } from "@/components/SocialButtons";
import { MagicLinkBox0611 } from "@/components/MagicLinkBox0611";
import type { Lang } from "@/lib/i18n/langs";

// 26/10 — « Mot de passe oublié ? » dans les 9 langues du site.
const FORGOT = { fr: "Mot de passe oublié ?", en: "Forgot password?", es: "¿Olvidaste tu contraseña?", de: "Passwort vergessen?", it: "Password dimenticata?", pt: "Esqueceste-te da palavra-passe?", ko: "비밀번호를 잊으셨나요?", ja: "パスワードをお忘れですか？", pl: "Nie pamiętasz hasła?" } as const;

export default function LoginPage() {
  const { t, lang } = useT();
  const router = useRouter();

  const [email, setEmail]       = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy]         = useState(false);
  const [err, setErr]           = useState("");
  // 06/11 (LEO, mesure de FLO) — un propriétaire renvoyé ici depuis « mes candidats » (/application/<id>)
  // ou /posts n'a souvent PAS de mot de passe (compte créé par la pub) : l'encart « Reçois ton lien par
  // e-mail » passe EN PREMIER, le formulaire mot de passe reste dessous, replié (« J'ai un mot de passe »
  // ou ?pwd=1 l'ouvre). Lu côté navigateur (pas de useSearchParams : Suspense au build).
  const [magicNext, setMagicNext] = useState("");
  const [showPwd, setShowPwd]     = useState(true);
  useEffect(() => {
    try {
      const q = new URLSearchParams(window.location.search);
      const r = q.get("redirect") || "";
      if (r.startsWith("/application/") || r.startsWith("/posts")) {
        setMagicNext(r);
        setShowPwd(q.get("pwd") === "1");
      }
    } catch { /* adresse exotique : formulaire classique */ }
  }, []);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr("");
    const cleanEmail = email.trim().toLowerCase();
    try {
      await login(cleanEmail, password);
      // v23.1.452 — retour vers la page demandée (ex. la PawMap) après login.
      // On lit `redirect` côté navigateur dans le handler pour éviter l'erreur
      // de build Next "useSearchParams must be wrapped in Suspense". On
      // n'accepte que les chemins internes (commençant par "/") par sécurité.
      const params = new URLSearchParams(window.location.search);
      const redirect = params.get("redirect");
      router.push(redirect && redirect.startsWith("/") ? redirect : "/dashboard");
    } catch (e) {
      // v402 — compte non vérifié : le backend renvoie 403 et renvoie un
      // nouveau code par email → on bascule sur la page de vérification.
      if (e instanceof ApiError && e.status === 403) {
        router.push(`/verify-email?email=${encodeURIComponent(cleanEmail)}`);
        return;
      }
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

      {magicNext && (
        <div className="mt-8" data-login-magic0611="">
          <MagicLinkBox0611 next={magicNext} lang={lang as Lang} onHasPassword={showPwd ? undefined : () => setShowPwd(true)} />
        </div>
      )}

      <form
        onSubmit={onSubmit}
        className={`${magicNext ? "mt-6" : "mt-10"} space-y-4 rounded-3xl border border-ink/5 bg-white p-7 shadow-card ${magicNext && !showPwd ? "hidden" : ""}`}
        data-login-form0611={magicNext && !showPwd ? "replie" : "ouvert"}
      >
        <SocialButtons />
        <Field label={t("login_email")} value={email} onChange={setEmail} type="email" required autoComplete="email" />
        <Field label={t("login_password")} value={password} onChange={setPassword} type="password" required autoComplete="current-password" />
        {/* 26/10 (LEO — retour de FLO) : le lien manquait ; les propriétaires venus de la pub n'ont
            jamais choisi de mot de passe et /posts/confirmer leur dit de passer par ici. */}
        <p className="-mt-1 text-right text-sm">
          <Link
            href={`/forgot-password${email.trim() ? `?email=${encodeURIComponent(email.trim())}` : ""}`}
            onClick={(e) => {
              try {
                const r = new URLSearchParams(window.location.search).get("redirect");
                if (r && r.startsWith("/")) { e.preventDefault(); router.push(`/forgot-password?redirect=${encodeURIComponent(r)}${email.trim() ? `&email=${encodeURIComponent(email.trim())}` : ""}`); }
              } catch { /* lien simple */ }
            }}
            className="inline-flex min-h-[44px] items-center font-semibold text-owner"
            data-forgot-link-2610=""
          >
            {FORGOT[lang as keyof typeof FORGOT] || FORGOT.fr}
          </Link>
        </p>
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

// 1011 (ZOE) — libellé d'accessibilité de l'œil du mot de passe, dans les 9 langues du site
// (table locale, comme FORGOT : on ne charge pas langues1011 sur cette page pour un libellé).
const PW_EYE: Record<Lang, [string, string]> = {
  fr: ["Masquer le mot de passe", "Afficher le mot de passe"],
  en: ["Hide password", "Show password"],
  es: ["Ocultar la contraseña", "Mostrar la contraseña"],
  de: ["Passwort verbergen", "Passwort anzeigen"],
  it: ["Nascondi la password", "Mostra la password"],
  pt: ["Ocultar a palavra-passe", "Mostrar a palavra-passe"],
  pl: ["Ukryj hasło", "Pokaż hasło"],
  ko: ["비밀번호 숨기기", "비밀번호 표시"],
  ja: ["パスワードを隠す", "パスワードを表示"],
};

function Field({
  label, value, onChange, type = "text", required, autoComplete,
}: {
  label: string; value: string; onChange: (v: string) => void;
  type?: string; required?: boolean; autoComplete?: string;
}) {
  const { lang } = useT();
  const pwEye = PW_EYE[lang] || PW_EYE.fr;
  // v404 — œil afficher/masquer le mot de passe.
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
            aria-label={show ? pwEye[0] : pwEye[1]}
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
