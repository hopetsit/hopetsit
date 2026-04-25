"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useT } from "@/lib/i18n/LanguageProvider";
import { ApiError, AuthRole, googleSignIn } from "@/lib/api";
import { isFirebaseConfigured, signInWithGooglePopup } from "@/lib/firebase";

type Props = {
  /** Sent to /auth/google when this is the user's first social login on the
   *  platform — backend creates the account under that role. Existing users
   *  keep their original role (the value is ignored server-side). */
  defaultRole?: AuthRole;
};

export function SocialButtons({ defaultRole = "owner" }: Props) {
  const { t } = useT();
  const router = useRouter();
  const [busy, setBusy] = useState<"" | "google" | "apple">("");
  const [err, setErr]   = useState("");

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
      await googleSignIn(idToken, defaultRole);
      router.push("/dashboard");
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

  function onApple() {
    // Apple Sign-In needs a Service ID + private key configured on the
    // Apple Developer console. Wire it up once Daniel completes that — until
    // then we keep the button visible so the marketing layout matches the
    // mobile app, and explain the status on click.
    setErr("Apple Sign-In is coming soon.");
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
        {busy === "google" ? t("common_loading") : "Continue with Google"}
      </button>

      <button
        type="button"
        onClick={onApple}
        disabled={busy === "apple"}
        className="flex w-full items-center justify-center gap-3 rounded-full border border-ink/15 bg-black px-4 py-2.5 text-sm font-semibold text-white hover:bg-ink disabled:opacity-60"
      >
        <AppleIcon />
        Continue with Apple
      </button>

      {err && <p className="text-center text-xs text-owner-dark">{err}</p>}

      <div className="my-2 flex items-center gap-3 text-[11px] uppercase tracking-wider text-ink-soft">
        <span className="h-px flex-1 bg-ink/10" />
        OR
        <span className="h-px flex-1 bg-ink/10" />
      </div>
    </div>
  );
}

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
  return (
    <svg width="16" height="18" viewBox="0 0 16 18" aria-hidden="true" fill="currentColor">
      <path d="M11.62 0c.07.97-.32 1.93-.94 2.62-.65.71-1.66 1.26-2.66 1.18-.09-.95.36-1.93.97-2.59C9.65.49 10.7-.05 11.62 0zM15.4 13.04c-.43.99-.63 1.43-1.18 2.31-.77 1.22-1.86 2.74-3.21 2.75-1.2.01-1.51-.78-3.14-.77-1.63.01-1.97.79-3.18.78-1.36-.01-2.39-1.38-3.16-2.6C-.5 12.04-.74 7.86 1.04 5.55c1.27-1.65 3.27-2.62 5.15-2.62 1.91 0 3.12 1.05 4.7 1.05 1.54 0 2.48-1.05 4.69-1.05 1.67 0 3.45.91 4.71 2.49-4.14 2.27-3.47 8.18-1.39 10.62z"/>
    </svg>
  );
}
