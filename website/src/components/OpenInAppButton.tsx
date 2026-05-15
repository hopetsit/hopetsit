"use client";

import { useState } from "react";
import { openInApp, ApiError } from "@/lib/api";

/**
 * v23.1 part 146 — Bouton "Ouvrir dans l'app".
 *
 * Disponible uniquement quand l'utilisateur est logué côté site (le bouton
 * appelant doit gérer sa visibilité via `useAuth()`). Au clic :
 *   1. Demande au backend un one-time token (TTL 60s, single-use).
 *   2. Redirige vers `hopetsit://auth?ott=<token>`.
 *   3. Si l'app est installée sur le device, elle intercepte le scheme
 *      custom, échange l'OTT contre un JWT et logge l'utilisateur.
 *   4. Si l'app n'est pas installée, rien ne se passe visuellement —
 *      on affiche un message "Téléchargez l'app d'abord" après 1.5s
 *      d'attente sans changement de visibilité (heuristique standard,
 *      `document.visibilityState` reste `visible` car aucune app n'a
 *      pris le focus).
 */
export function OpenInAppButton({
  className = "",
  label = "Ouvrir dans l'app",
}: {
  className?: string;
  label?: string;
}) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hintAppMissing, setHintAppMissing] = useState(false);

  const handleClick = async () => {
    setError(null);
    setHintAppMissing(false);
    setLoading(true);
    try {
      // Note : openInApp() fait `window.location.href = hopetsit://...`
      // qui retourne immédiatement (le navigateur déclenche l'intent).
      // Si l'app prend le focus, `visibilitychange` fire avec hidden.
      let appOpened = false;
      const onVisibilityChange = () => {
        if (document.visibilityState === "hidden") {
          appOpened = true;
        }
      };
      document.addEventListener("visibilitychange", onVisibilityChange);

      await openInApp();

      // Heuristique : si après 1.5s la page n'a pas perdu le focus,
      // c'est que l'app n'est probablement pas installée.
      setTimeout(() => {
        document.removeEventListener("visibilitychange", onVisibilityChange);
        if (!appOpened) {
          setHintAppMissing(true);
        }
        setLoading(false);
      }, 1500);
    } catch (e) {
      setLoading(false);
      if (e instanceof ApiError) {
        setError(e.message);
      } else {
        setError("Une erreur est survenue. Réessaye.");
      }
    }
  };

  return (
    <div className={className}>
      <button
        type="button"
        onClick={handleClick}
        disabled={loading}
        className="inline-flex items-center gap-2 rounded-xl bg-[#EF4324] px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-[#d93a1f] disabled:cursor-not-allowed disabled:opacity-60"
        aria-label={label}
      >
        {loading ? (
          <svg
            className="h-4 w-4 animate-spin"
            viewBox="0 0 24 24"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            aria-hidden="true"
          >
            <circle
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeOpacity="0.25"
              strokeWidth="3"
            />
            <path
              d="M22 12a10 10 0 0 1-10 10"
              stroke="currentColor"
              strokeWidth="3"
              strokeLinecap="round"
            />
          </svg>
        ) : (
          // Icône mobile simple
          <svg
            className="h-4 w-4"
            viewBox="0 0 24 24"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            aria-hidden="true"
          >
            <rect
              x="7"
              y="2"
              width="10"
              height="20"
              rx="2"
              stroke="currentColor"
              strokeWidth="2"
            />
            <circle cx="12" cy="18" r="1" fill="currentColor" />
          </svg>
        )}
        <span>{loading ? "Ouverture…" : label}</span>
      </button>

      {error && (
        <p className="mt-2 text-xs text-red-600" role="alert">
          {error}
        </p>
      )}
      {hintAppMissing && !error && (
        <p className="mt-2 text-xs text-gray-500">
          L&apos;app HoPetSit ne semble pas installée. Télécharge-la depuis
          le Play Store ou l&apos;App Store, puis recommence.
        </p>
      )}
    </div>
  );
}
