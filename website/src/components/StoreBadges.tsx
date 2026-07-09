"use client";

import { useT } from "@/lib/i18n/LanguageProvider";

// v508 — Daniel : « ajoute les boutons stores et branche juste Google Play ».
// L'app est EN LIGNE sur le Play Store (com.cardellihermanos.hopetsit).
// - Google Play : lien réel, ?hl=<langue du site> → la fiche s'ouvre dans la
//   bonne langue automatiquement.
// v518 — APP APPROUVÉE PAR APPLE 🎉 : badge App Store activé. URL SANS code
// pays (pas /ca/) → Apple redirige chaque visiteur vers SON App Store
// national, dans sa langue (id 6763645719).
// Design = maquette index.html de Daniel (badges noirs officiels).

const PLAY_URL =
  "https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit";
const APP_STORE_URL = "https://apps.apple.com/app/hopetsit/id6763645719";

export default function StoreBadges({ center = false }: { center?: boolean }) {
  const { lang } = useT();

  const badge =
    "inline-flex items-center gap-3 rounded-xl border border-white/25 bg-black px-4 py-2.5 leading-none text-white transition";

  return (
    <div
      className={`flex flex-wrap items-center gap-3 ${center ? "justify-center" : ""}`}
    >
      {/* Google Play — EN LIGNE */}
      <a
        className={`${badge} hover:opacity-85`}
        href={`${PLAY_URL}&hl=${lang}`}
        target="_blank"
        rel="noopener noreferrer"
      >
        <svg width="24" height="26" viewBox="0 0 512 512" aria-hidden="true">
          <path
            d="M48 59.49v393a4.33 4.33 0 0 0 7.37 3.07L260 256 55.37 56.42A4.33 4.33 0 0 0 48 59.49z"
            fill="#00d3ff"
          />
          <path
            d="M345.8 174L89.22 25.85 89 25.69a4.32 4.32 0 0 0-5.94 1.55L260 256z"
            fill="#00f076"
          />
          <path
            d="M83.06 484.76a4.29 4.29 0 0 0 5.94 1.55l.22-.13L345.8 338 260 256z"
            fill="#ff3a44"
          />
          <path
            d="M457.34 226.67L387.8 187 297.83 256l90 69 69.54-39.68a32.51 32.51 0 0 0 0-58.65z"
            fill="#ffc900"
          />
        </svg>
        <span className="flex flex-col items-start gap-0.5">
          <span className="text-[10px] font-normal uppercase tracking-widest">
            Get it on
          </span>
          <span className="text-lg font-medium">Google Play</span>
        </span>
      </a>

      {/* App Store — EN LIGNE (approuvé par Apple, v518) */}
      <a
        className={`${badge} hover:opacity-85`}
        href={APP_STORE_URL}
        target="_blank"
        rel="noopener noreferrer"
      >
        <svg
          width="26"
          height="26"
          viewBox="0 0 24 24"
          fill="#fff"
          aria-hidden="true"
        >
          <path d="M17.05 12.54c-.02-2.02 1.65-2.99 1.73-3.04-.94-1.38-2.41-1.57-2.93-1.59-1.25-.13-2.44.73-3.07.73-.63 0-1.61-.71-2.65-.69-1.36.02-2.62.79-3.32 2.01-1.42 2.46-.36 6.1 1.01 8.1.67.98 1.47 2.08 2.51 2.04 1.01-.04 1.39-.65 2.61-.65 1.22 0 1.56.65 2.63.63 1.09-.02 1.78-1 2.44-1.99.77-1.14 1.09-2.24 1.11-2.3-.02-.01-2.13-.82-2.15-3.26zM15.03 6.59c.55-.67.93-1.6.82-2.53-.8.03-1.77.53-2.34 1.2-.51.59-.96 1.53-.84 2.44.89.07 1.8-.45 2.36-1.11z" />
        </svg>
        <span className="flex flex-col items-start gap-0.5">
          <span className="text-[11px] font-normal">Download on the</span>
          <span className="text-lg font-medium">App Store</span>
        </span>
      </a>
    </div>
  );
}
