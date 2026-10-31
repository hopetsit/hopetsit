"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useT } from "@/lib/i18n/LanguageProvider";
import { ApiError, AuthRole, googleSignIn, appleSignIn } from "@/lib/api";
import { isFirebaseConfigured, signInWithGooglePopup, signInWithApplePopup } from "@/lib/firebase";

type Props = {
  /** Sent to /auth/google when this is the user's first social login on the
   *  platform — backend creates the account under that role. Existing users
   *  keep their original role (the value is ignored server-side). */
  defaultRole?: AuthRole;
  /** v565 — ville saisie sur la page d'inscription (nouveau compte Google). */
  city?: string;
  /** v578 — chemin interne où aller après connexion (défaut /dashboard). */
  next?: string;
};

export function SocialButtons({ defaultRole = "owner", city, next }: Props) {
  const { t, lang } = useT();
  const router = useRouter();
  const [busy, setBusy] = useState<"" | "google" | "apple">("");
  const [err, setErr]   = useState("");
  // 31/10/2026 (BOB) — nouveau compte Google/Apple depuis /login : le serveur répond
  // 400 CITY_REQUIRED (règle du 18/09). On demande la ville ici et on relance avec
  // le même jeton Firebase (valable 1 h), au lieu d'afficher une erreur sans issue.
  const [needCity, setNeedCity] = useState<null | { provider: "google" | "apple"; idToken: string }>(null);
  const [cityInput, setCityInput] = useState("");
  function isCityRequired(e: unknown): boolean {
    if (!(e instanceof ApiError)) return false;
    return /CITY_REQUIRED/.test(JSON.stringify(e.details ?? "")) || /ville|city/i.test(e.message || "");
  }
  async function retryWithCity() {
    if (!needCity || cityInput.trim().length < 2) return;
    const { provider, idToken } = needCity;
    setBusy(provider);
    setErr("");
    try {
      const fn = provider === "apple" ? appleSignIn : googleSignIn;
      await fn(idToken, defaultRole, { city: cityInput.trim(), lang });
      router.push(next && next.startsWith("/") && !next.startsWith("//") ? next : "/dashboard");
    } catch (e) {
      setErr(e instanceof ApiError ? e.message || t("auth_error_generic") : t("auth_error_generic"));
    } finally {
      setBusy("");
    }
  }

  async function onGoogle() {
    if (!isFirebaseConfigured()) {
      setErr(
        "Google sign-in is not configured yet. Add NEXT_PUBLIC_FIREBASE_* env vars."
      );
      return;
    }
    setBusy("google");
    setErr("");
    try {
      const idToken = await signInWithGooglePopup();
      try {
        await googleSignIn(idToken, defaultRole, { city: city?.trim() || undefined, lang });
      } catch (e2) {
        if (isCityRequired(e2)) { setNeedCity({ provider: "google", idToken }); return; }
        throw e2;
      }
      router.push(next && next.startsWith("/") && !next.startsWith("//") ? next : "/dashboard");
    } catch (e) {
      // Firebase popup-cancellation: stay silent, the user just closed the window.
      const message = e instanceof Error ? e.message : "";
      if (
        message.includes("popup-closed-by-user") ||
        message.includes("cancelled-popup-request")
      ) {
        // ignore
      } else if (e instanceof ApiError) {
        setErr(e.message || t("auth_error_generic"));
      } else {
        setErr(message || t("auth_error_generic"));
      }
    } finally {
      setBusy("");
    }
  }

  async function onApple() {
    setBusy("apple");
    setErr("");
    try {
      const idToken = await signInWithApplePopup();
      try {
        await appleSignIn(idToken, defaultRole, { city: city?.trim() || undefined, lang });
      } catch (e2) {
        if (isCityRequired(e2)) { setNeedCity({ provider: "apple", idToken }); return; }
        throw e2;
      }
      router.push(next && next.startsWith("/") && !next.startsWith("//") ? next : "/dashboard");
    } catch (e) {
      const message = e instanceof Error ? e.message : "";
      if (message.includes("popup-closed-by-user") || message.includes("cancelled-popup-request")) {
        // fenêtre fermée par l'utilisateur
      } else if (e instanceof ApiError) {
        setErr(e.message || t("auth_error_generic"));
      } else {
        setErr(t("auth_error_generic"));
      }
    } finally {
      setBusy("");
    }
  }

  return (
    <div className="space-y-2.5">
      <button
        type="button"
        onClick={onGoogle}
        disabled={busy === "google"}
        className="flex w-full items-center justify-center gap-3 rounded-full border border-ink/15 bg-white px-4 py-2.5 text-sm font-semibold text-ink hover:border-ink/40 disabled:opacity-60"
      >
        <GoogleIcon />
        {busy === "google" ? t("common_loading") : (SOCIAL_TXT[lang]?.google ?? SOCIAL_TXT.en.google)}
      </button>

      {/* 31/10/2026 (BOB) — Firebase répond « OPERATION_NOT_ALLOWED : Code flow is not enabled
          for Apple » : le fournisseur Apple n'a pas de Services ID web (il ne sert qu'à l'app iOS).
          Bouton masqué tant que APPLE_WEB_ENABLED est faux, au lieu d'un bouton mort. */}
      {APPLE_WEB_ENABLED && <button
        type="button"
        onClick={onApple}
        disabled={busy === "apple"}
        className="flex w-full items-center justify-center gap-3 rounded-full border border-ink/15 bg-black px-4 py-2.5 text-sm font-semibold text-white hover:bg-ink disabled:opacity-60"
      >
        <AppleIcon />
        {busy === "apple" ? t("common_loading") : (SOCIAL_TXT[lang]?.apple ?? SOCIAL_TXT.en.apple)}
      </button>}

      {needCity && (
        <div className="rounded-2xl border border-ink/15 bg-owner-light/40 p-3" data-testid="social-city">
          <p className="text-sm font-semibold text-ink">{SOCIAL_TXT[lang]?.cityQ ?? SOCIAL_TXT.en.cityQ}</p>
          <div className="mt-2 flex gap-2">
            <input
              autoFocus
              value={cityInput}
              onChange={(e) => setCityInput(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") retryWithCity(); }}
              placeholder={SOCIAL_TXT[lang]?.cityPh ?? SOCIAL_TXT.en.cityPh}
              className="min-w-0 flex-1 rounded-full border border-ink/20 bg-white px-4 py-2 text-sm text-ink outline-none focus:border-owner"
            />
            <button
              type="button"
              onClick={retryWithCity}
              disabled={busy !== "" || cityInput.trim().length < 2}
              className="shrink-0 rounded-full bg-owner px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            >
              {busy ? t("common_loading") : (SOCIAL_TXT[lang]?.cityGo ?? SOCIAL_TXT.en.cityGo)}
            </button>
          </div>
        </div>
      )}

      {err && <p className="text-center text-xs text-owner-dark">{err}</p>}

      <div className="my-2 flex items-center gap-3 text-[11px] uppercase tracking-wider text-ink-soft">
        <span className="h-px flex-1 bg-ink/10" />
        {SOCIAL_TXT[lang]?.or ?? SOCIAL_TXT.en.or}
        <span className="h-px flex-1 bg-ink/10" />
      </div>
    </div>
  );
}

const APPLE_WEB_ENABLED = true; // 31/10 : Firebase › Apple configuré (Services ID com.cardellihermanos.hopetsit.web, équipe 49C67YDPJ5, clé 3QKCSZMGW7), écran Apple vérifié.

// 31/10/2026 (BOB) — libellés en dur en anglais sur toutes les langues.
const SOCIAL_TXT: Record<string, { google: string; or: string; apple: string; cityQ: string; cityPh: string; cityGo: string }> = {
  fr: { google: "Continuer avec Google", or: "ou", apple: "Continuer avec Apple", cityQ: "Dernière étape : dans quelle ville es-tu ?", cityPh: "Ex. Paris", cityGo: "Continuer" },
  en: { google: "Continue with Google", or: "or", apple: "Continue with Apple", cityQ: "Last step: which city are you in?", cityPh: "e.g. New York", cityGo: "Continue" },
  es: { google: "Continuar con Google", or: "o", apple: "Continuar con Apple", cityQ: "Último paso: ¿en qué ciudad estás?", cityPh: "Ej. Madrid", cityGo: "Continuar" },
  de: { google: "Weiter mit Google", or: "oder", apple: "Weiter mit Apple", cityQ: "Letzter Schritt: In welcher Stadt bist du?", cityPh: "z. B. Berlin", cityGo: "Weiter" },
  it: { google: "Continua con Google", or: "oppure", apple: "Continua con Apple", cityQ: "Ultimo passo: in che città sei?", cityPh: "Es. Milano", cityGo: "Continua" },
  pt: { google: "Continuar com o Google", or: "ou", apple: "Continuar com a Apple", cityQ: "Último passo: em que cidade estás?", cityPh: "Ex. Lisboa", cityGo: "Continuar" },
  pl: { google: "Kontynuuj z Google", or: "lub", apple: "Kontynuuj z Apple", cityQ: "Ostatni krok: w jakim mieście jesteś?", cityPh: "Np. Warszawa", cityGo: "Dalej" },
  ko: { google: "Google로 계속하기", or: "또는", apple: "Apple로 계속하기", cityQ: "마지막 단계: 어느 도시에 계세요?", cityPh: "예: 서울", cityGo: "계속" },
  ja: { google: "Googleで続ける", or: "または", apple: "Appleで続ける", cityQ: "最後のステップ：お住まいの都市は？", cityPh: "例：東京", cityGo: "続ける" },
};

function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
      <path d="M17.64 9.2c0-.64-.06-1.25-.17-1.84H9v3.49h4.84a4.14 4.14 0 0 1-1.8 2.71v2.26h2.92a8.78 8.78 0 0 0 2.68-6.62z" fill="#4285F4"/>
      <path d="M9 18c2.43 0 4.47-.81 5.96-2.18l-2.92-2.26c-.81.54-1.84.86-3.04.86-2.34 0-4.32-1.58-5.03-3.7H.96v2.33A9 9 0 0 0 9 18z" fill="#34A853"/>
      <path d="M3.97 10.71A5.41 5.41 0 0 1 3.68 9c0-.59.1-1.17.29-1.71V4.96H.96A9 9 0 0 0 0 9c0 1.45.35 2.83.96 4.04l3.01-2.33z" fill="#FBBC05"/>
      <path d="M9 3.58c1.32 0 2.5.45 3.44 1.35l2.58-2.58A9 9 0 0 0 .96 4.96L3.97 7.29C4.68 5.16 6.66 3.58 9 3.58z" fill="#EA4335"/>
    </svg>
  );
}

function AppleIcon() {
  // 31/10/2026 (BOB) — logo Apple officiel (glyphe standard), l'ancien était redessiné.
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor">
      <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/>
    </svg>
  );
}
