"use client";

import { searchCities616 } from "@/components/CityAutocomplete616";
import Link from "@/components/SiteLink";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { LANGUAGES, type Lang } from "@/lib/i18n/langs";
import { ApiError, AuthRole, emailFirstCheck1711, emailFirstSend1711, signup } from "@/lib/api";
import { SocialButtons } from "@/components/SocialButtons";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { ef } from "@/lib/i18n/emailFirst1711";

// 17/11/2026 (NEO, ordre de Daniel transmis par BOB) — INSCRIPTION « E-MAIL D'ABORD ».
// Mesure de BOB (45 j) : 313 inscrits e-mail + mot de passe → 97 vérifiés (~30 %) ; Google / Apple = 100 %. Le compte
// était créé AVANT le code. Désormais : 1) l'adresse e-mail seule (Google / Apple restent au-dessus) → 2) le code à
// 6 chiffres reçu par e-mail → 3) le reste du formulaire (nom, mot de passe, ville, code postal, conditions), l'adresse
// verrouillée et affichée comme confirmée → compte créé déjà vérifié, arrivée connecté. AUCUN compte avant le bon code.
// Toutes les données d'avant sont gardées (rôle, ville, code postal, pays, langue, consentement, parrain, ?next=).
// Repères (admin › Trafic du site) : signup_email_envoye · signup_code_ok · signup_compte_cree (+ signup_code_faux,
// signup_suggestion, signup_deja_compte, signup_code_renvoye). Coupe-circuit : EMAIL_FIRST_1711 = false → formulaire
// d'avant en un écran. Si le serveur ne connaît pas encore la route (déploiement en cours) : formulaire d'avant aussi.
const EMAIL_FIRST_1711 = true;
const RESEND_S = 60;
type Step = "email" | "code" | "form";

export default function SignupPage() {
  const { t, lang, setLang } = useT();
  const router = useRouter();

  const [role, setRole]         = useState<AuthRole>("owner");
  const [name, setName]         = useState("");
  // v565 audit-inscription — ville obligatoire (décision point 25 : ville
  // OBLIGATOIRE, téléphone/adresse facultatifs). Avant : jamais demandée sur
  // le site → comptes « ville ? » dans l'admin.
  const [city, setCity]         = useState("");
  const [postalCode, setPostalCode] = useState(""); // 23/10 (BOB, ordre de Daniel) — position = code postal, pas le centre de la ville
  const [email, setEmail]       = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy]         = useState(false);
  // v577 — les pages villes propriétaires (pub Meta Paris/Dallas) envoient
  // maintenant ici plutôt que sur le store : on reprend le rôle et la ville
  // passés dans l'URL (?role=owner&city=Paris) pour que le visiteur n'ait plus
  // que trois champs à remplir. Lecture dans un effet (pas useSearchParams :
  // cette page est statique, un bailout CSR casserait le build).
  // v578 — destination promise par le bouton d'origine (?next=/posts/create).
  // Chemin interne uniquement : jamais une URL absolue (redirection ouverte).
  const [nextPath, setNextPath] = useState("");
  const [err, setErr]           = useState("");
  // v532 — consentement CGU réel (cf. commentaire dans le formulaire).
  const [acceptTerms, setAcceptTerms] = useState(false);
  // v583 NEO — code parrain transmis par lien : /signup?ref=AB23CD45.
  // Seul le format exact des codes est retenu (8 caractères, majuscules,
  // sans I/O/0/1) : les QR des affiches portent ?ref=<nom-du-commerce>, en
  // minuscules, qui ne doit pas devenir un faux parrain.
  const [referralCode, setReferralCode] = useState("");
  // 1711 — étapes « e-mail d'abord » : la preuve (60 min) n'existe qu'en mémoire, jamais dans l'adresse ni le stockage.
  const [step, setStep]         = useState<Step>(EMAIL_FIRST_1711 ? "email" : "form");
  const [proof, setProof]       = useState("");
  const [code, setCode]         = useState("");
  const [info, setInfo]         = useState("");
  const [wait, setWait]         = useState(0);
  const [suggestion, setSuggestion] = useState("");
  const [exists, setExists]     = useState(false);
  const codeRef = useRef<HTMLInputElement>(null);
  const topRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const q = new URLSearchParams(window.location.search);
    const r = (q.get("role") || "").toLowerCase();
    if (r === "owner" || r === "sitter" || r === "walker") setRole(r as AuthRole);
    const c = (q.get("city") || "").trim();
    if (c) setCity(c);
    const n = (q.get("next") || "").trim();
    if (n.startsWith("/") && !n.startsWith("//")) setNextPath(n);
    const ref = (q.get("ref") || "").trim();
    if (/^[A-HJ-NP-Z2-9]{8}$/.test(ref)) setReferralCode(ref);
    // 06/10 (GUS) — les pages écrites dans une langue (ex. /tiersitter-werden/
    // duesseldorf) envoient ?lang=de : le formulaire s'affiche dans la langue de
    // la page d'où vient le visiteur, sauf s'il a déjà choisi une langue lui-même.
    const l = (q.get("lang") || "").toLowerCase();
    let chosen: string | null = null;
    try { chosen = window.localStorage.getItem("hopetsit_lang"); } catch { /* stockage bloqué */ }
    if (!chosen && LANGUAGES.some((x) => x.code === l)) setLang(l as Lang);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Compte à rebours du bouton « Renvoyer le code » (le serveur garantit aussi les 60 s).
  useEffect(() => {
    if (wait <= 0) return;
    const id = setTimeout(() => setWait((w) => w - 1), 1000);
    return () => clearTimeout(id);
  }, [wait]);

  // Changement d'étape : la carte remonte sous l'en-tête (375 px) et le champ du code prend le curseur.
  useEffect(() => {
    if (step === "email") return;
    try { topRef.current?.scrollIntoView({ block: "start", behavior: "smooth" }); } catch { /* vieux navigateur */ }
    if (step === "code") setTimeout(() => codeRef.current?.focus(), 350);
  }, [step]);

  const e1 = (k: string, vars?: Record<string, string | number>) => ef(lang, k, vars);
  const detailsOf = (e: unknown) => (e instanceof ApiError && e.details && typeof e.details === "object" ? (e.details as { code?: string; retryAfter?: number; left?: number }) : {});

  /** Étape 1 (et « Renvoyer ») : demande le code. Rien n'est créé côté serveur. */
  async function sendCode(target: string, resend = false) {
    if (busy) return;
    const cleanEmail = target.trim().toLowerCase();
    setErr(""); setInfo(""); setSuggestion(""); setExists(false);
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(cleanEmail)) { setErr(e1("email_bad")); return; }
    setBusy(true);
    try {
      const r = await emailFirstSend1711(cleanEmail, lang);
      if (r.missing) { setStep("form"); return; } // serveur pas encore à jour : parcours d'avant
      if (r.suggestion) { setSuggestion(r.suggestion); trackSiteEvent("cta_click", { label: "signup_suggestion" }); return; }
      if (r.exists) { setExists(true); trackSiteEvent("cta_click", { label: "signup_deja_compte" }); return; }
      setEmail(cleanEmail);
      setWait(r.retryAfter || RESEND_S);
      if (resend) { setInfo(e1("resent")); trackSiteEvent("cta_click", { label: "signup_code_renvoye" }); }
      else { setCode(""); setStep("code"); trackSiteEvent("cta_click", { label: "signup_email_envoye" }); }
    } catch (e) {
      const d = detailsOf(e);
      if (d.code === "RESEND_TOO_SOON") {
        // Un code est déjà parti il y a moins d'une minute pour cette adresse : on passe (ou on reste) à l'écran du code.
        setEmail(cleanEmail); setWait(Number(d.retryAfter) || RESEND_S); setInfo(e1("already_sent")); setStep("code");
      } else if (d.code === "TOO_MANY") setErr(e1("many_sends"));
      else if (d.code === "TEST_ACCOUNT") setErr(e1("test"));
      else if (d.code === "EMAIL_INVALID") setErr(e1("email_bad"));
      else setErr(e1("err"));
    } finally {
      setBusy(false);
    }
  }

  /** Étape 2 : le bon code donne la preuve (60 min) ; toujours aucun compte. */
  async function checkCode() {
    if (busy) return;
    const c = code.replace(/\D/g, "");
    if (c.length !== 6) { setErr(e1("code_need")); return; }
    setBusy(true); setErr(""); setInfo("");
    try {
      const r = await emailFirstCheck1711(email, c);
      setProof(r.emailProof);
      setCode("");
      setStep("form");
      trackSiteEvent("cta_click", { label: "signup_code_ok" });
    } catch (e) {
      const d = detailsOf(e);
      const cd = d.code || (e instanceof ApiError ? String(e.status) : "x");
      trackSiteEvent("cta_click", { label: cd === "CODE_INVALID" ? "signup_code_faux" : `signup_code_refus_${cd.toLowerCase()}` });
      if (cd === "CODE_INVALID") setErr((d.left ?? 0) > 0 ? e1("wrong", { n: d.left ?? 0 }) : e1("wrong_last"));
      else if (cd === "CODE_EXPIRED") setErr(e1("expired"));
      else if (cd === "TOO_MANY_TRIES") setErr(e1("many"));
      else setErr(e1("err"));
    } finally {
      setBusy(false);
    }
  }

  function backToEmail() {
    setStep("email"); setProof(""); setCode(""); setErr(""); setInfo(""); setSuggestion(""); setExists(false);
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (step === "email") { void sendCode(email); return; }
    if (step === "code") { void checkCode(); return; }
    if (!acceptTerms) {
      setErr(t("signup_terms_required"));
      return;
    }
    if (!city.trim()) {
      setErr(t("signup_city_required"));
      return;
    }
    if (postalCode.trim().length < 3) {
      setErr(t("signup_postal_required"));
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
      // 17/10/2026 (SAM, Daniel : « respecter la devise du pays ») — le site
      // n'envoyait ni pays ni devise : 101 comptes sans pays, 20 new-yorkais en
      // euros. Le pays ISO-2 vient de la ville (route /geo/cities) ; si la
      // recherche échoue, on n'invente rien (le serveur garde sa valeur par défaut).
      let country: string | undefined;
      try {
        const sug = await searchCities616(city.trim(), lang);
        country = sug[0]?.countryCode || undefined;
      } catch { /* géocodeur injoignable : pas de pays */ }
      const res = await signup({
        name: name.trim(),
        email: cleanEmail,
        password,
        role,
        city: city.trim(),
        postalCode: postalCode.trim(),
        lang,
        ...(country ? { country } : {}),
        ...(referralCode ? { referralCode } : {}),
        ...(proof ? { emailProof: proof } : {}),
      });
      if (proof) trackSiteEvent("cta_click", { label: "signup_compte_cree" });
      // v402 — l'inscription web exige désormais la vérif email (le backend
      // envoie un code par mail). On envoie l'utilisateur sur /verify-email.
      if (res.needsVerification) {
        router.push(
          `/verify-email?email=${encodeURIComponent(cleanEmail)}` +
            (nextPath ? `&next=${encodeURIComponent(nextPath)}` : ""),
        );
      } else {
        router.push(nextPath || "/dashboard");
      }
    } catch (e) {
      const pc = detailsOf(e).code;
      if (pc === "EMAIL_PROOF_INVALID" || pc === "EMAIL_PROOF_REQUIRED") {
        // Preuve expirée (plus de 60 min sur le formulaire) : on redemande un code, les champs remplis sont gardés.
        setProof(""); setCode(""); setStep("email"); setErr(e1("proof_expired"));
      } else if (e instanceof ApiError && e.status === 409) {
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
        ref={topRef}
        onSubmit={onSubmit}
        noValidate={step !== "form"}
        className="mt-10 scroll-mt-24 space-y-4 rounded-3xl border border-ink/5 bg-white p-5 shadow-card sm:p-7"
      >
        {EMAIL_FIRST_1711 && (
          <p className="text-center text-xs font-semibold uppercase tracking-wide text-ink-muted" data-testid="signup-step-1711" data-step={step}>
            {e1("step", { n: step === "email" ? 1 : step === "code" ? 2 : 3 })}
          </p>
        )}

        {/* ── Étape 2 : le code reçu par e-mail (aucun compte n'existe encore) ── */}
        {step === "code" && (
          <div data-testid="signup-code-1711">
            <p className="text-[20px] font-extrabold leading-tight text-ink">✉ {e1("code_title")}</p>
            <p className="mt-2 break-words text-[15px] leading-snug text-ink">{e1("code_body", { email })}</p>
            <label className="mt-4 block text-xs font-semibold text-ink">{e1("code_label")}
              <input ref={codeRef} value={code} onChange={(ev) => { setCode(ev.target.value.replace(/\D/g, "").slice(0, 6)); setErr(""); }}
                inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]*" maxLength={6} placeholder="••••••"
                className="mt-1 w-full rounded-xl border border-ink/15 bg-white px-3 py-3 text-center text-[28px] font-extrabold tracking-[0.4em] text-ink focus:border-owner focus:outline-none" data-testid="signup-code-input" />
            </label>
            {err && <p className="mt-2 text-center text-sm font-semibold text-owner-dark" role="alert" data-testid="signup-code-err">{err}</p>}
            {!err && info && <p className="mt-2 text-center text-sm font-semibold" style={{ color: "#15803D" }} role="status">{info}</p>}
            <button disabled={busy} className="mt-4 block w-full rounded-full bg-owner px-6 py-3.5 text-center text-base font-extrabold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60" data-testid="signup-code-cta">
              {busy ? e1("code_busy") : e1("code_cta")}
            </button>
            <button type="button" onClick={() => void sendCode(email, true)} disabled={busy || wait > 0}
              className="mt-3 block w-full rounded-full border-2 border-owner px-6 py-3 text-center text-[15px] font-extrabold text-owner disabled:border-ink/15 disabled:text-ink-muted" data-testid="signup-code-resend">
              {wait > 0 ? e1("resend_wait", { s: wait }) : e1("resend")}
            </button>
            <p className="mt-3 text-center text-[12px] leading-snug text-ink-muted">{e1("spam")}</p>
            <button type="button" onClick={backToEmail} className="mt-2 block w-full text-center text-[12px] font-semibold text-ink underline underline-offset-4" data-testid="signup-code-back">
              {e1("back")}
            </button>
          </div>
        )}

        {step !== "code" && (
          <>
            {/* Google / Apple (100 % de comptes vérifiés) : seulement à l'étape 1, au-dessus de l'e-mail. */}
            {step === "email" && <SocialButtons defaultRole={role} city={city} next={nextPath} />}
            {step === "form" && EMAIL_FIRST_1711 && <p className="text-center text-base font-extrabold text-ink">{e1("form_title")}</p>}
            <div className="space-y-2">
              {roles.map((r) => (
                <label
                  key={r.code}
                  className={`flex cursor-pointer items-center gap-3 rounded-xl border ${step === "email" ? "px-3 py-2" : "p-3"} transition ${
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
                  <span className={step === "email" ? "text-xl" : "text-2xl"}>{r.emoji}</span>
                  <span className={`${step === "email" ? "text-sm " : ""}font-semibold ${role === r.code ? `text-${r.color}-dark` : "text-ink"}`}>
                    {r.label}
                  </span>
                </label>
              ))}
            </div>
          </>
        )}

        {/* ── Étape 1 : l'adresse e-mail seule ── */}
        {step === "email" && (
          <div data-testid="signup-email-1711">
            <Field label={t("signup_email")} value={email} onChange={(v) => { setEmail(v); setErr(""); setSuggestion(""); setExists(false); }} type="email" required autoComplete="email" testId="signup-email-input" />
            <p className="mt-2 text-[12.5px] leading-snug text-ink-muted">{e1("email_hint")}</p>
            {suggestion && (
              <div className="mt-3 rounded-xl border border-owner bg-owner-light p-3 text-center" role="alert" data-testid="signup-suggestion">
                <p className="break-words text-sm font-semibold text-owner-dark">{e1("suggest", { email: suggestion })}</p>
                <button type="button" onClick={() => { const fixed = suggestion; setEmail(fixed); setSuggestion(""); void sendCode(fixed); }}
                  className="mt-2 rounded-full bg-owner px-5 py-2 text-sm font-extrabold text-white" data-testid="signup-suggestion-use">
                  {e1("suggest_use")}
                </button>
              </div>
            )}
            {exists && (
              <div className="mt-3 rounded-xl border border-ink/15 bg-bg-soft p-3 text-center" role="alert" data-testid="signup-exists">
                <p className="text-sm font-semibold text-ink">{e1("exists")}</p>
                <Link href={`/login${nextPath ? `?next=${encodeURIComponent(nextPath)}` : ""}`} className="mt-2 inline-block rounded-full bg-ink px-5 py-2 text-sm font-extrabold text-white" data-testid="signup-exists-login">
                  {e1("exists_login")}
                </Link>
              </div>
            )}
            <button disabled={busy} className="mt-4 w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60" data-testid="signup-email-cta">
              {busy ? e1("email_busy") : e1("email_cta")}
            </button>
          </div>
        )}

        {/* ── Étape 3 : le reste du formulaire (toutes les données d'avant), adresse verrouillée ── */}
        {step === "form" && (
          <>
            <Field label={t("signup_name")}     value={name}     onChange={setName}     required autoComplete="name" testId="signup-name" />
            {proof ? (
              <div data-testid="signup-email-locked">
                <label className="block text-sm font-medium text-ink">{t("signup_email")}</label>
                <div className="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-1 rounded-xl border border-ink/15 bg-bg-soft px-3.5 py-2.5 text-sm text-ink">
                  <span className="min-w-0 flex-1 break-all" data-testid="signup-email-shown">{email}</span>
                  <span className="shrink-0 rounded-full px-2 py-0.5 text-[11px] font-extrabold text-white" style={{ background: "#15803D" }}>✓ {e1("confirmed")}</span>
                </div>
              </div>
            ) : (
              <Field label={t("signup_email")}    value={email}    onChange={setEmail}    type="email"    required autoComplete="email" />
            )}
            <Field label={t("signup_city")}     value={city}     onChange={setCity}     required autoComplete="address-level2" testId="signup-city" />
            <Field label={t("signup_postal_code")} value={postalCode} onChange={setPostalCode} required autoComplete="postal-code" testId="signup-postal" />
            <Field label={t("signup_password")} value={password} onChange={setPassword} type="password" required autoComplete="new-password" testId="signup-password" />

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
                data-testid="signup-terms"
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
              data-testid="signup-submit"
            >
              {busy ? t("common_loading") : t("signup_submit")}
            </button>
            {proof && (
              <button type="button" onClick={backToEmail} className="block w-full text-center text-[12px] font-semibold text-ink underline underline-offset-4" data-testid="signup-form-back">
                {e1("back")}
              </button>
            )}
          </>
        )}
        {step !== "code" && err && <p className="text-center text-sm text-owner-dark" role="alert" data-testid="signup-err">{err}</p>}
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
  label, value, onChange, type = "text", required, autoComplete, testId,
}: {
  label: string; value: string; onChange: (v: string) => void;
  type?: string; required?: boolean; autoComplete?: string; testId?: string;
}) {
  const { lang } = useT();
  const pwEye = PW_EYE[lang] || PW_EYE.fr;
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
          data-testid={testId}
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
