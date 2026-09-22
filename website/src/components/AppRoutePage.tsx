"use client";

// v565 (point 29) — page « thème » d'un e-mail ou d'un push qui n'a PAS
// d'équivalent web complet (/friends/requests, /subscription, /paw-spot,
// /notifications, /wallet, /post/:id…). Sans l'app (desktop, client mail
// qui ouvre une vue web), on affiche quelque chose d'UTILE :
//   - sur mobile, `AppLinkOpener` (layout) a déjà tenté `hopetsit://<chemin>` ;
//     on propose le bouton « Ouvrir dans l'app » qui retente ;
//   - un bouton « Continuer sur le web » vers la page web équivalente, et
//     une redirection automatique vers cette page après `redirectAfterMs`
//     (0 = pas de redirection automatique) ;
//   - les deux stores.
// Un visiteur non connecté est envoyé sur /login?next=<page web>.

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { getStoredUser } from "@/lib/api";
// v576 — mesure d'audience : clics vers les stores depuis la page de repli.
import { trackSiteEvent } from "@/components/SiteAnalytics";

const APP_STORE_URL = "https://apps.apple.com/app/id6763645719";
const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit";

export function AppRoutePage({
  appPath,
  webHref,
  webLabel,
  title,
  subtitle,
  redirectAfterMs = 2500,
  requiresAuth = true,
}: {
  /** Chemin dans l'app, sans slash initial (ex. `friends/requests`). */
  appPath: string;
  /** Page web équivalente. */
  webHref: string;
  /** Libellé du bouton web (défaut : clé approute_web). */
  webLabel?: string;
  title?: string;
  subtitle?: string;
  redirectAfterMs?: number;
  requiresAuth?: boolean;
}) {
  const { t } = useT();
  const router = useRouter();
  const [mobile, setMobile] = useState(false);

  const target =
    requiresAuth && typeof window !== "undefined" && !getStoredUser()
      ? `/login?next=${encodeURIComponent(webHref)}`
      : webHref;

  useEffect(() => {
    if (typeof window === "undefined") return;
    setMobile(/iphone|ipad|ipod|android/i.test(window.navigator.userAgent));
    if (redirectAfterMs <= 0) return;
    const timer = window.setTimeout(() => router.replace(target), redirectAfterMs);
    // Si l'app s'ouvre (onglet caché), on n'arrache pas l'utilisateur.
    const onVisibility = () => {
      if (document.visibilityState === "hidden") window.clearTimeout(timer);
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      window.clearTimeout(timer);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, [redirectAfterMs, router, target]);

  const openApp = () => {
    if (typeof window === "undefined") return;
    window.location.href = `hopetsit://${appPath.replace(/^\/+/, "")}${window.location.search ?? ""}`;
  };

  return (
    <main className="flex min-h-[70vh] items-center justify-center px-4 py-16">
      <div className="w-full max-w-md rounded-[24px] bg-[#FAF1EC] p-8 text-center">
        <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-white text-3xl shadow-sm">
          🐾
        </div>
        <h1 className="mt-6 font-display text-2xl font-bold tracking-[-0.02em] text-[#231715]">
          {title ?? t("approute_title")}
        </h1>
        <p className="mt-2 text-sm text-[#6E4F48]">{subtitle ?? t("approute_sub")}</p>

        <div className="mt-6 flex flex-col gap-2">
          {mobile && (
            <button
              type="button"
              onClick={openApp}
              className="w-full rounded-full bg-[#D83C28] px-6 py-3 text-sm font-semibold text-white transition hover:brightness-105"
            >
              {t("approute_open")}
            </button>
          )}
          <Link
            href={target}
            className="w-full rounded-full bg-[#231715] px-6 py-3 text-sm font-semibold text-white transition hover:bg-black"
          >
            {webLabel ?? t("approute_web")}
          </Link>
        </div>

        <div className="mt-4 grid grid-cols-2 gap-2">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => trackSiteEvent("store_click", { store: "ios" })}
            className="rounded-full bg-white py-2.5 text-xs font-semibold text-[#231715] ring-1 ring-black/5 transition hover:bg-[#F0E3DF]"
          >
            App Store
          </a>
          <a
            href={PLAY_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => trackSiteEvent("store_click", { store: "android" })}
            className="rounded-full bg-white py-2.5 text-xs font-semibold text-[#231715] ring-1 ring-black/5 transition hover:bg-[#F0E3DF]"
          >
            Google Play
          </a>
        </div>

        {redirectAfterMs > 0 && (
          <p className="mt-5 text-xs text-[#6E4F48]">{t("approute_redirecting")}</p>
        )}
      </div>
    </main>
  );
}

export default AppRoutePage;
